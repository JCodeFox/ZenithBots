extends Node3D

@export var clock: Node3D
@export var clock_timer: Timer

func _ready():
	get_tree().paused = false
	$Multiplayer/VBoxContainer/HBoxContainer/ColorPickerButton.color = GlobalData.player_color
	$Multiplayer/VBoxContainer/HBoxContainer/Name.text = GlobalData.username
	$Multiplayer/VBoxContainer/IP.text = GlobalData.server_ip
	if "server" in OS.get_cmdline_args():
		print("Running dedicated server...")
		_on_host_pressed()

func _on_Play_pressed():
	GlobalData.is_hosting = true
	GlobalData.allow_other_players = false
	GlobalData.server_ip = $Multiplayer/VBoxContainer/IP.text
	GlobalData.username = $Multiplayer/VBoxContainer/HBoxContainer/Name.text
	GlobalData.player_color = $Multiplayer/VBoxContainer/HBoxContainer/ColorPickerButton.color
	get_tree().change_scene_to_file("res://Scenes/World.tscn")

func _on_Quit_pressed():
	get_tree().quit()

func _on_play_multiplayer_pressed():
	$Main.visible = false
	$Multiplayer.visible = true

func _on_back_pressed():
	$Main.visible = true
	$Multiplayer.visible = false

func _on_join_pressed():
	GlobalData.is_hosting = false
	GlobalData.allow_other_players = true
	GlobalData.server_ip = $Multiplayer/VBoxContainer/IP.text
	GlobalData.username = $Multiplayer/VBoxContainer/HBoxContainer/Name.text
	GlobalData.player_color = $Multiplayer/VBoxContainer/HBoxContainer/ColorPickerButton.color
	get_tree().change_scene_to_file("res://Scenes/World.tscn")

func _on_host_pressed():
	GlobalData.is_hosting = true
	GlobalData.allow_other_players = true
	GlobalData.server_ip = $Multiplayer/VBoxContainer/IP.text
	GlobalData.username = $Multiplayer/VBoxContainer/HBoxContainer/Name.text
	GlobalData.player_color = $Multiplayer/VBoxContainer/HBoxContainer/ColorPickerButton.color
	get_tree().change_scene_to_file("res://Scenes/World.tscn")

func _process(delta):
	var time_amount = clock_timer.wait_time - clock_timer.time_left
	var time_int = int(time_amount)
	var time_fraction = time_amount - time_int
	var time_percent = (time_int + time_fraction * time_fraction * time_fraction) / clock_timer.wait_time
	clock.get_node("Hand").rotation.y = (-2 * PI) * time_percent
