extends Node3D

func _ready():
	get_tree().paused = false

func _on_Play_pressed():
	get_tree().change_scene_to_file("res://Scenes/World.tscn")

func _on_Quit_pressed():
	get_tree().quit()
