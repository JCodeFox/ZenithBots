extends Node3D

var scene := preload("res://GameObjects/Enemy.tscn")
@export var players_node: Node
var wait: float = 1.0

func begin():
	if multiplayer.is_server():
		get_tree().create_timer(wait).timeout.connect(spawnTimer_timeout)

func spawnTimer_timeout():
	if not players_node:
		push_warning("Players node not set!")
		return
	# TODO: Put back check for powerup_time
	if get_child_count() < 101:# and not player.powerup_time:
		var scene_instance = scene.instantiate()
		scene_instance.set_name("enemy")
		var pos_mult = Vector2(randf_range(-1.0, 1.0),randf_range(-1.0, 1.0))
		pos_mult = pos_mult.normalized()
		scene_instance.transform.origin.x = pos_mult.x * 40
		scene_instance.transform.origin.z = pos_mult.y * 40
		scene_instance.players_node = players_node
		add_child(scene_instance, true)
	# TODO: Put back check for powerup_time
	if wait > 0.10:# and not player.powerup_time:
		get_tree().create_timer(wait).timeout.connect(spawnTimer_timeout)
		wait -= wait / 100
