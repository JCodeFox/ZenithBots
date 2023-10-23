extends CharacterBody3D

const ACCEL: int = 4
const DEACCEL: int = 8

var player: Object

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var spawn: Vector3 = transform.origin

@export var WALK_SPEED: float = 9

@onready var offset: Vector3 = Vector3(randf_range(-20,20),0,randf_range(-20,20))

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if not player:
		move_and_slide()
		return
	
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
	if body == player:
		if player.powerup_time:
			player.enemies_destroyed += 1
			var particle_node: Object = get_node("../../ExplosionParticles")
			particle_node.transform.origin = transform.origin
			particle_node.emitting = true
			particle_node.restart()
			queue_free()
		else:
			var d = (player.transform.origin - transform.origin).normalized()
			d.y = 0
			player.velocity += d * 75
			player.health -= 5
