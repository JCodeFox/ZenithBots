extends CharacterBody3D

const ACCEL: int = 4
const DEACCEL: int = 8

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var WALK_SPEED: float = 10.0
@export var RUN_SPEED: float = 40.0
@export var jump_force: float = 10.0
@export var IFrames: int = 0
@export var IFrameMax: int = 10

@export var health_bar: ProgressBar

var powerup_time: bool = false

var enemies_destroyed: int = 0
var time_alive: float = 0
var is_spectating: bool = false
var is_dead: bool = true

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
	LocationData.new(Vector3(0, 515, 0), 450, 0, get_node("../../Lobby/LobbyCam")),
	LocationData.new(Vector3(0, 5, 0), -5, 5, get_node("../../PlayArea/MainCam")),
]

var current_location: int = 0:
	set(value):
		current_location = value
		if locations[current_location].camera:
			locations[current_location].camera.make_current()
	get:
		return current_location

var health: int = 100:
	set(value):
		health = value
		if health_bar and is_multiplayer_authority():
			health_bar.value = health
	get:
		return health

var color: Color = Color.BLUE:
	set(value):
		color = value
		var mat: StandardMaterial3D = $LilBot/RobotMasterPos/Body.get_surface_override_material(0)
		mat = mat.duplicate()
		mat.albedo_color = color
		$LilBot/RobotMasterPos/Body.set_surface_override_material(0, mat)
	get:
		return color

# The point of this file is to allow the player to experience a sense of power through the control of a character on the digital screen

####################
# Common Overrides #
####################

func checkbump(body):
	if not multiplayer.is_server():
		return
	if get_parent() and body in get_parent().get_children():
		var d = (body.transform.origin - transform.origin).normalized()
		d.y = 0
		body.bump(d)

func _enter_tree():
	set_multiplayer_authority(int(str(name)))
	
	if is_multiplayer_authority():
		set_info(GlobalData.username, GlobalData.player_color)

func _ready():
	$Particles.emitting = false
	get_node("../../ExplosionParticles").emitting = false
	var master: Node = get_parent().get_parent()
	health_bar = master.health_bar
	global_position = locations[current_location].spawn_point
	
	if not is_multiplayer_authority() and not multiplayer.is_server():
		refresh_info()

func _process(delta):
	if not is_multiplayer_authority():
		return
	if not is_spectating and not is_dead:
		time_alive += delta
	
	if IFrames > 0:
		IFrames -= 1

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if is_spectating:
		global_position = locations[0].spawn_point
		return
	
	if health<=0:
		is_spectating = true
		is_dead = true
		global_position = locations[0].spawn_point
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
		

##################
# Networky Stuff #
##################

@rpc("call_local", "any_peer")
func begin_game(is_spectator: bool = false):
	current_location = 1
	if not is_multiplayer_authority():
		return
	if not is_spectator:
		global_position = locations[current_location].spawn_point
	time_alive = 0
	is_spectating = is_spectator
	is_dead = false
	enemies_destroyed = 0

@rpc("call_local", "any_peer")
func end_game():
	current_location = 0
	if not is_multiplayer_authority():
		return
	global_position = locations[current_location].spawn_point
	is_spectating = false
	health = 100

@rpc
func set_info(username: String, new_color: Color) -> void:
	$Usertag.text = username
	color = new_color
	
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
func refresh_auth():
	if not multiplayer.is_server():
		return
	rpc_id(multiplayer.get_remote_sender_id(), "set_auth", get_multiplayer_authority())


@rpc("any_peer", "call_local")
func set_zenith(value: bool = true, toggle: bool = false):
	if toggle:
		powerup_time = !powerup_time
	else:
		powerup_time = value
	$Particles.emitting = powerup_time
	if powerup_time:
		get_node("LilBot/AnimationPlayer").speed_scale = 4.0
		get_node("CollisionShape3D").shape.size = Vector3(4.0, 6.0, 4.0)
	else:
		get_node("LilBot/AnimationPlayer").speed_scale = 1.0
		get_node("CollisionShape3D").shape.size = Vector3(2.0, 6.0, 2.0)

@rpc("any_peer")
func get_hit(direction: Vector3) -> void:
	if IFrames == 0:
		IFrames = IFrameMax
		velocity += direction * 75
		health -= 5
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	rpc("get_hit", direction)

@rpc("any_peer")
func bump(direction: Vector3) -> void:
	if IFrames == 0:
		IFrames = IFrameMax
		velocity += direction * 100
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	rpc("bump", direction)


@rpc("any_peer", "call_local")
func enemy_destroyed() -> void:
	enemies_destroyed += 1
	var particle_node: Object = get_node("../../ExplosionParticles")
	particle_node.transform.origin = transform.origin
	particle_node.emitting = true
	particle_node.restart()


func _on_area_3d_area_entered(area):
	var body = area.get_parent()
	if not multiplayer.is_server():
		return
	if body in get_parent().get_children():
		if body.powerup_time:
			body.rpc_id(body.get_multiplayer_authority(), "enemy_destroyed")
			queue_free()
		else:
			var d = (body.transform.origin - transform.origin).normalized()
			d.y = 0
			body.bump(d)
