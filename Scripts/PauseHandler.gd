extends Node

@onready var pause_menu: Object = get_node("../PauseMenu")

func _process(_delta):
	if Input.is_action_just_pressed("Pause"):
		pause()

func pause():
	pause_menu.visible = !pause_menu.visible

func menu():
	get_tree().paused = true
	if multiplayer.is_server():
		get_tree().create_timer(0.1).timeout.connect(multiplayer.multiplayer_peer.close)
	else:
		multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
