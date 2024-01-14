extends CharacterBody3D

const ACCEL: int = 4
const DEACCEL: int = 8

@export var WALK_SPEED: float = 9

var players_node: Node

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var spawn: Vector3 = transform.origin

@onready var offset: Vector3 = Vector3(randf_range(-20,20),0,randf_range(-20,20))

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if not players_node or players_node.get_child_count() == 0:
		move_and_slide()
		return
	
	var player: Node = players_node.get_child(0)
	for p in players_node.get_children():
		if global_position.distance_to(p.global_position) < global_position.distance_to(player.global_position):
			player = p
	
	var move_dir = player.transform.origin - transform.origin
	if player.powerup_time and move_dir.length() < 20:
		move_dir = -move_dir * 0.25
	move_dir = move_dir.normalized()
	move_dir.y = 0
	look_at(move_dir + transform.origin, Vector3.UP)
	
	var hvel = velocity
	hvel.y = 0
	var target = move_dir * WALK_SPEED
	var accel
	if (move_dir.dot(hvel) > 0):
		accel = ACCEL
	else:
		accel = DEACCEL
	hvel = hvel.lerp(target, accel * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	
	move_and_slide()
	
	if transform.origin.y < -10:
		transform.origin = spawn

func _on_Area_body_entered(body):
	if not multiplayer.is_server():
		return
	if players_node and body in players_node.get_children():
		if body.powerup_time:
			body.rpc_id(body.get_multiplayer_authority(), "enemy_destroyed")
			queue_free()
		else:
			var d = (body.transform.origin - transform.origin).normalized()
			d.y = 0
			body.get_hit(d)
