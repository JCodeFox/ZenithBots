extends Node

@export var player_scene: PackedScene
@export var players_node: Node3D
@export var enemies_node: Node3D
@export var clock: Node3D
@export var health_bar: Node
@export var game_over_popup: Node
var is_started: bool = false

func _ready() -> void:
	if verify_existance(enemies_node):
		enemies_node.players_node = verify_existance(players_node)
	
	multiplayer.connected_to_server.connect(self.connected_to_server)
	multiplayer.server_disconnected.connect(self.disconnected_from_server)
	multiplayer.connection_failed.connect(self.connection_failed)
	multiplayer.peer_connected.connect(self.player_connected)
	multiplayer.peer_disconnected.connect(self.player_disconnected)

func _process(_delta):
	if is_started:
		return
	
	if Input.is_action_just_pressed("start_server"):
		start_server()
		is_started = true
	if Input.is_action_just_pressed("start_client"):
		start_client("127.0.0.1")
		is_started = true

func spawn_player() -> Node3D:
	var new_player: Node3D = null
	if verify_existance(player_scene) and verify_existance(players_node):
		new_player = player_scene.instantiate()
		players_node.add_child(new_player, true)
		new_player.global_position = Vector3(0, 2, 33)
		#new_player.clock = verify_existance(clock)
		#new_player.health_bar = verify_existance(health_bar)
		#new_player.game_over_popup = verify_existance(game_over_popup)
	return new_player
	
func verify_existance(obj: Object) -> Object:
	if not obj:
		push_warning("Object doesn't exist!")
		return null
	return obj

func start_server() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(1342)
	multiplayer.set_multiplayer_peer(peer)
	print("Server started")
	
	var new_player: Node3D = spawn_player()
	new_player.set_info(1, "Server", Color.BLUE)
	
	if verify_existance(enemies_node):
		enemies_node.begin()

func start_client(ip: String) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# Connect to the server.
	peer.create_client(ip, 1342)
	multiplayer.set_multiplayer_peer(peer)
	print("Connecting to server...")

#############
# Callbacks #
#############
func connected_to_server() -> void:
	print("Connected to server.")

func disconnected_from_server() -> void:
	print("Disconnected from server.")
	$CanvasLayer/PauseHandler.menu()

func connection_failed() -> void:
	print("Connection to server failed.")

func player_connected(id: int) -> void:
	# Cancel if not running on server.
	if not multiplayer.is_server():
		return
	print("Player (" + str(id) + ") connected")
	
	var new_player: Node3D = spawn_player()
	new_player.set_info(id, "Client: " + str(id), Color.RED)
	
	multiplayer.multiplayer_peer.refuse_new_connections = true

func player_disconnected(id: int) -> void:
	# Cancel if not running on server.
	if not multiplayer.is_server():
		return
	print("Player (" + str(id) + ") disconnected")
