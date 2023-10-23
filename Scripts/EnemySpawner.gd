extends Node3D

var scene := preload("res://GameObjects/Enemy.tscn")
@onready var player :Object= get_tree().get_root().get_node("World/Player")

func _on_SpawnTimer_timeout():
	if get_child_count()<101 and not player.powerup_time:
		var scene_instance = scene.instantiate()
		scene_instance.set_name("enemy")
		var pos_mult = Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))
		pos_mult = pos_mult.normalized()
		scene_instance.transform.origin.x = pos_mult.x*40
		scene_instance.transform.origin.z = pos_mult.y*40
		add_child(scene_instance)
	if $SpawnTimer.wait_time>0.10 and not player.powerup_time:
		$SpawnTimer.wait_time-=$SpawnTimer.wait_time/100
	$SpawnTimer.start()
