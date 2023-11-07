extends CharacterBody3D

const ACCEL: int = 4
const DEACCEL: int = 8

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var WALK_SPEED: float = 10.0
@export var RUN_SPEED: float = 40.0
@export var jump_force: float = 10.0

@export var clock: Node
@export var health_bar: ProgressBar
@export var game_over_popup: Node

var health: int = 100

var powerup_time: bool = false

var enemies_destroyed: int = 0
var time_alive: float = 0

class LocationData:
	var spawn_point: Vector3
	var death_barrier: float
	var barrier_hurt: int
	var camera: Camera3D
	func _init(spawn: Vector3, barrier: float, hurt: int, cam: Camera3D = null):
		spawn_point = spawn
		death_barrier = barrier
		barrier_hurt = hurt
		camera = cam

@onready var locations: Array[LocationData] = [
	LocationData.new(Vector3(0, 501, 0), 450, 0, get_node("../../LobbyCam")),
	LocationData.new(Vector3(0, 1, 0), -5, 5, get_node("../../MainCam")),
]

var current_location: int = 0:
	set(value):
		current_location = value
		if locations[current_location].camera:
			locations[current_location].camera.make_current()
		if value != 1:
			powerup_time = true
			_on_Timer_timeout()
			$Timer.stop()
		else:
			powerup_time = true
			_on_Timer_timeout()
	get:
		return current_location

# The point of this file is to allow the player to experience a sense of power through the control of a character on the digital screen

####################
# Common Overrides #
####################

func _ready():
	var master: Node = get_parent().get_parent()
	clock = master.clock
	health_bar = master.health_bar
	game_over_popup = master.game_over_popup
	global_position = locations[current_location].spawn_point
	
	if not is_multiplayer_authority() and not multiplayer.is_server():
		refresh_info()

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if health<=0:
		
		current_location = 0
		global_position = locations[current_location].spawn_point
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
	
	if transform.origin.y < locations[current_location].death_barrier:
		transform.origin = locations[current_location].spawn_point
		health -= locations[current_location].barrier_hurt

func _process(delta):
	if multiplayer.is_server():
		if Input.is_action_just_pressed("start_server"):
			rpc("begin_game")
	if not is_multiplayer_authority():
		return
	time_alive += delta
	update_clock()
	update_health_bar()

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

####################
# Helper functions #
####################

func update_health_bar():
	if health_bar:
		health_bar.value = health

func update_clock():
	if clock:
		var time_percent = $Timer.wait_time - $Timer.time_left / $Timer.wait_time
		clock.get_node("Hand").rotation.y = (-2 * PI) * time_percent

func set_color(color: Color) -> void:
	var mat: StandardMaterial3D = $LilBot/RobotMasterPos/Body.get_surface_override_material(0)
	mat = mat.duplicate()
	mat.albedo_color = color
	$LilBot/RobotMasterPos/Body.set_surface_override_material(0, mat)

##################
# Networky Stuff #
##################

@rpc("call_local", "any_peer")
func begin_game():
	current_location = 1
	if not is_multiplayer_authority():
		return
	global_position = locations[current_location].spawn_point

@rpc("any_peer")
func set_auth(id: int) -> void:
	set_multiplayer_authority(id)
	
	if is_multiplayer_authority():
		set_info(GlobalData.username, GlobalData.player_color)
	
	if not multiplayer.is_server():
		return
	rpc("set_auth", id)

@rpc
func set_info(username: String, new_color: Color) -> void:
	$Usertag.text = username
	set_color(new_color)
	
	if not is_multiplayer_authority():
		return
	rpc("set_info", username, new_color)

@rpc("any_peer")
func refresh_info() -> void:
	if not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "refresh_info")
		return
	rpc_id(multiplayer.get_remote_sender_id(), "set_info", GlobalData.username, GlobalData.player_color)

@rpc("any_peer")
func get_hit(direction: Vector3) -> void:
	velocity += direction * 75
	health -= 5
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	rpc("get_hit", direction)
