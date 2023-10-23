extends Node

@onready var pause_menu :Object= get_node("../PauseMenu")

func _process(_delta):
	if Input.is_action_just_pressed("Pause"):
		pause()
		
	if Input.is_action_just_pressed("Restart"):
		restart()
		
func pause():
	get_tree().paused = !get_tree().paused
	pause_menu.visible = get_tree().paused

func restart():
	get_tree().paused=false
	get_tree().change_scene_to_file("res://Scenes/World.tscn")

func menu():
	get_tree().paused=false
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
