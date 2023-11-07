extends Node3D

func _ready():
	get_tree().paused = false
	$Multiplayer/VBoxContainer/HBoxContainer/ColorPickerButton.color = GlobalData.player_color
	$Multiplayer/VBoxContainer/HBoxContainer/Name.text = GlobalData.username
	$Multiplayer/VBoxContainer/IP.text = GlobalData.server_ip

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
