extends AnimatableBody3D

@export var start_position: Vector3
@export var end_position: Vector3
@export var speed: float = 3.5
@export var wait_time: float = 0.6
@export var rotation_speed_degrees: Vector3 = Vector3.ZERO

var platform_velocity: Vector3 = Vector3.ZERO
var platform_angular_velocity: Vector3 = Vector3.ZERO

var _target: Vector3
var _waiting: bool = false

func _ready():
	global_position = start_position
	_target = end_position

func _physics_process(delta):
	platform_velocity = Vector3.ZERO
	platform_angular_velocity = _get_rotation_speed_radians()
	rotation += platform_angular_velocity * delta

	if _waiting:
		return

	var direction = (_target - global_position)
	var distance = direction.length()

	if distance < 0.05:
		_start_wait()
		return

	var move = direction.normalized() * speed * delta

	if move.length() > distance:
		move = direction

	platform_velocity = move / delta
	global_position += move

func get_platform_velocity() -> Vector3:
	return platform_velocity

func get_platform_angular_velocity() -> Vector3:
	return platform_angular_velocity

func _get_rotation_speed_radians() -> Vector3:
	return Vector3(
		deg_to_rad(rotation_speed_degrees.x),
		deg_to_rad(rotation_speed_degrees.y),
		deg_to_rad(rotation_speed_degrees.z)
	)

func _start_wait():
	_waiting = true
	await get_tree().create_timer(wait_time).timeout
	
	# swap direction
	if _target == end_position:
		_target = start_position
	else:
		_target = end_position
	
	_waiting = false
