extends CharacterBody3D

const ACCEL: int = 4
const DEACCEL: int = 8

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var WALK_SPEED: float = 10.0
@export var RUN_SPEED: float = 40.0
@export var jump_force: float = 10.0

@export var clock: Node
@export var health_bar: ProgressBar

var health: int = 100

var powerup_time: bool = false

var enemies_destroyed: int = 0
var time_alive: float = 0

@export var game_over_popup: Node

# The point of this file is to allow the player to experience a sense of power through the control of a character on the digital screen

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if health<=0:
		transform.origin.y=500
		if game_over_popup and not game_over_popup.visible:
			game_over_popup.get_node("VBoxContainer/Time").text = "Time survived:\n" + str(int(time_alive)) + "s"
			game_over_popup.get_node("VBoxContainer/Destroyed").text = "Robots destroyed:\n" + str(enemies_destroyed)
			game_over_popup.visible = true
		return
	var move_dir = Vector3()
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if Input.is_action_pressed("Forward"):
		move_dir.z -= 1
	if Input.is_action_pressed("Backward"):
		move_dir.z += 1
	if Input.is_action_pressed("Left"):
		move_dir.x -= 1
	if Input.is_action_pressed("Right"):
		move_dir.x += 1
	
	move_dir.y = 0
	move_dir = move_dir.normalized()
	var hvel = velocity
	hvel.y = 0
	var target = move_dir * (RUN_SPEED if powerup_time else WALK_SPEED)
	var accel
	if (move_dir.dot(hvel) > 0):
		accel = ACCEL
	else:
		accel = DEACCEL
		
	hvel = hvel.lerp(target, accel * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	
	if transform.origin.distance_to(hvel + transform.origin) > 0.1:
		look_at(transform.origin + hvel, Vector3.UP)
	
	move_and_slide()
	
	if transform.origin.y<-5:
		transform.origin = Vector3(0,1,0)
		health -= 5

func _process(delta):
	if not is_multiplayer_authority():
		return
	time_alive += delta
	update_clock()
	update_health_bar()

func update_health_bar():
	if health_bar:
		health_bar.value = health

func update_clock():
	if clock:
		var time_percent = $Timer.wait_time - $Timer.time_left / $Timer.wait_time
		clock.get_node("Hand").rotation.y = (-2 * PI) * time_percent

func _on_Timer_timeout():
	$Timer.start()
	powerup_time = !powerup_time
	$Particles.emitting = powerup_time && health > 0
	if powerup_time:
		get_node("LilBot/AnimationPlayer").speed_scale = 4.0
		get_node("CollisionShape3D").shape.size = Vector3(4.0, 6.0, 4.0)
	else:
		get_node("LilBot/AnimationPlayer").speed_scale = 1.0
		get_node("CollisionShape3D").shape.size = Vector3(2.0, 6.0, 2.0)
