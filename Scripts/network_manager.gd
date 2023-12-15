extends Node3D

@export var stat_entry_scene: PackedScene 
@export var player_scene: PackedScene
@export var players_node: Node3D
@export var enemies_node: Node3D
@export var clock: Node3D
@export var health_bar: Node
@export var game_over_popup: Node

@export var play_detector: Area3D
@export var spectate_detector: Area3D
@export var lobby_status: Label3D
@export var stats_label: Label
@export var stats_list_container: Control

@export var start_timer: Timer
@export var clock_timer: Timer

var game_running: bool = false

var stats_visible: bool = false:
	set(value):
		stats_visible = value
		stats_list_container.get_node("StatsList/Header/HideButton").text = "v" if stats_visible else "^"
		for child in stats_list_container.get_node("StatsList").get_children():
			if child.name != "Header":
				child.visible = stats_visible
	get:
		return stats_visible

var player_stats: Dictionary = {}

func _ready() -> void:
	if verify_existance(enemies_node):
		enemies_node.players_node = verify_existance(players_node)
	
	multiplayer.connected_to_server.connect(func():
		print("Connected to server.")
	)
	multiplayer.server_disconnected.connect(func():
		print("Disconnected from server.")
		$CanvasLayer/PauseHandler.menu()
	)
	multiplayer.connection_failed.connect(func():
		print("Connection to server failed.")
	)
	multiplayer.peer_connected.connect(self.player_connected)
	multiplayer.peer_disconnected.connect(self.player_disconnected)
	
	clock_timer.timeout.connect(func():
		var player: Node3D = players_node.get_node_or_null(str(multiplayer.get_unique_id()))
		if player:
			player.rpc("set_zenith", false, true)
	)
	start_timer.timeout.connect(attempt_begin.bind(true))
	stats_list_container.get_node("StatsList/Header/HideButton").pressed.connect(func():
		stats_visible = not stats_visible
	)
	
	GlobalData.username = GlobalData.username.lstrip(" \t").rstrip(" \t")
	if GlobalData.username == "" and (not GlobalData.is_hosting or GlobalData.allow_other_players):
		GlobalData.username = [
			"No Name", "Blank", "Forgot to pick a name", "Nameless",
			"Null", "Void", "Nil", "...", "Oh hi! I'm ____",
			"NPC", "Client", "Player", "Robot", "username = \"\"",
			"I forgor 💀", "🤖", "🦊", ":)", "<keyboard spam>",
			"Doesn't type", "Me", "Who?", "That person", "._."
			].pick_random()
	if "server" in OS.get_cmdline_args():
		start_server(false)
		multiplayer.multiplayer_peer.refuse_new_connections = false
	elif GlobalData.is_hosting:
		start_server(true)
		multiplayer.multiplayer_peer.refuse_new_connections = not GlobalData.allow_other_players
	else:
		start_client(GlobalData.server_ip)

func _process(_delta):
	var time_amount = clock_timer.wait_time - clock_timer.time_left
	var time_int = int(time_amount)
	var time_fraction = time_amount - time_int
	var time_percent = (time_int + time_fraction * time_fraction * time_fraction) / clock_timer.wait_time
	clock.get_node("Hand").rotation.y = (-2 * PI) * time_percent
	
	for player in players_node.get_children():
		var player_id: int = player.get_multiplayer_authority()
		set_stats(player_id, player.get_node("Usertag").text, player.enemies_destroyed, player.time_alive, player.color, player.is_spectating and not player.is_dead)
	
	if not start_timer.is_stopped() and lobby_status.text != "Starting in %d..." % int(start_timer.time_left):
		rpc("set_lobby_status", "Starting in %d..." % int(start_timer.time_left))
	if not multiplayer.is_server():
		return
	if game_running:
		var game_over: bool = true
		for player in players_node.get_children():
			if not player.is_spectating:
				game_over = false
		if game_over:
			game_running = false
			for player in players_node.get_children():
				player.rpc("end_game")
				rpc_id(player.get_multiplayer_authority(), "game_ended")
			if multiplayer.is_server() and not players_node.has_node("1"):
				game_ended()
			enemies_node.stop()
			attempt_begin()

@rpc("any_peer", "call_local")
func set_lobby_status(text: String):
	lobby_status.text = text

func set_stats(id: int, username: String, destroys: int, time: int, color: Color, spectating: bool):
	player_stats[id] = [id, username, destroys, time, color, spectating]
	update_stats_list()

func update_stats_list():
	var player_stats_array: Array = player_stats.values()
	player_stats_array.sort_custom(func(a, b):
		return a[2] + a[3] > b[2] + b[3] 
	)
	var stats_list: Control = stats_list_container.get_node("StatsList")
	for i in range(player_stats_array.size()):
		var entry: Control = stats_list.get_node_or_null(str(player_stats_array[i][0]))
		if not entry:
			entry = stat_entry_scene.instantiate()
			entry.name = str(player_stats_array[i][0])
			stats_list_container.get_node("StatsList").add_child(entry)
			entry.get_node("Username").text = player_stats_array[i][1]
			entry.modulate = player_stats_array[i][4]
			entry.visible = stats_visible
		if player_stats_array[i][5]:
			entry.get_node("Destroys").text = "---"
			entry.get_node("Time").text = "---"
			entry.get_node("Score").text = "Spectating"
		else:
			entry.get_node("Destroys").text = str(player_stats_array[i][2])
			entry.get_node("Time").text = str(player_stats_array[i][3])
			entry.get_node("Score").text = str(player_stats_array[i][2] + player_stats_array[i][3])
		stats_list.move_child(entry, i + 1)

func players_not_ready() -> int:
	var not_ready: int = 0
	var spectating_players: Array[Node3D] = spectate_detector.get_overlapping_bodies()
	var playing_players: Array[Node3D] = play_detector.get_overlapping_bodies()
	for player in players_node.get_children():
		if not player in spectating_players and not player in playing_players:
			not_ready += 1
	return not_ready

func attempt_begin(is_final: bool = false) -> void:
	if not multiplayer.is_server():
		return
	if game_running:
		return
	if players_node.get_child_count() == 0:
		return
	var not_ready: int = players_not_ready()
	if not_ready > 0:
		rpc("set_lobby_status", "Enter the play or spectate zones\nWaiting on %d player%s" % [not_ready, "s" if not_ready != 1 else ""])
		start_timer.stop()
		return
	
	if not is_final:
		if start_timer.is_stopped():
			start_timer.start(6)
	else:
		game_running = true
		for player in players_node.get_children():
			var is_spectator: bool = player in spectate_detector.get_overlapping_bodies()
			player.rpc("begin_game", is_spectator)
			if multiplayer.is_server():
				rpc_id(player.get_multiplayer_authority(), "game_started", is_spectator)
		if verify_existance(enemies_node):
			enemies_node.begin()
		if multiplayer.is_server() and not players_node.has_node("1"):
			game_started(false)

@rpc("call_local", "any_peer")
func game_started(is_spectator: bool) -> void:
	$LobbyMusic.stop()
	$MainMusic.play()
	clock_timer.start()
	stats_visible = is_spectator
	for child in stats_list_container.get_node("StatsList").get_children():
		if child.name != "Header":
			child.queue_free()

@rpc("call_local", "any_peer")
func game_ended() -> void:
	$MainMusic.stop()
	$LobbyMusic.play()
	clock_timer.stop()
	stats_visible = true
	var player: Node3D = players_node.get_node_or_null(str(multiplayer.get_unique_id()))
	if player:
		player.rpc("set_zenith", false)

func on_player_ready(_body: Node3D) -> void:
	attempt_begin()

func on_player_not_ready(_body: Node3D) -> void:
	attempt_begin()

func spawn_player(id: int = 1) -> Node3D:
	var new_player: Node3D = null
	if verify_existance(player_scene) and verify_existance(players_node):
		new_player = player_scene.instantiate()
		new_player.name = str(id)
		players_node.add_child(new_player)
	attempt_begin()
	return new_player
	
func verify_existance(obj: Object) -> Object:
	if not obj:
		push_warning("Object doesn't exist!")
		return null
	return obj

func start_server(is_playing: bool = false) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(1342)
	multiplayer.set_multiplayer_peer(peer)
	print("Server started")
	
	if is_playing:
		spawn_player(1)

func start_client(ip: String) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# Connect to the server.
	peer.create_client(ip, 1342)
	multiplayer.set_multiplayer_peer(peer)
	print("Connecting to server...")

#############
# Callbacks #
#############
func player_connected(id: int) -> void:
	# Cancel if not running on server.
	if not multiplayer.is_server():
		return
	print("Player (" + str(id) + ") connected")
	
	var new_player: Node3D = spawn_player(id)
	if game_running:
		new_player.rpc("begin_game", true)

func player_disconnected(id: int) -> void:
	# Cancel if not running on server.
	if not multiplayer.is_server():
		return
	attempt_begin()
	players_node.get_node(str(id)).queue_free()
	print("Player (" + str(id) + ") disconnected")

