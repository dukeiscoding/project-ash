extends CharacterBody3D

@export var move_speed: float = 7.5
@export var acceleration: float = 14.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var rotation_speed: float = 12.0

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = deg_to_rad(-60.0)
@export var max_pitch: float = deg_to_rad(35.0)

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_yaw.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch.rotation.x -= event.relative.y * mouse_sensitivity
		camera_pitch.rotation.x = clamp(camera_pitch.rotation.x, min_pitch, max_pitch)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3.ZERO

	if input_dir != Vector2.ZERO:
		var basis := camera_yaw.global_transform.basis
		var forward := -basis.z
		var right := basis.x

		forward.y = 0.0
		right.y = 0.0

		forward = forward.normalized()
		right = right.normalized()

		move_dir = (right * input_dir.x - forward * input_dir.y).normalized()

	var target_speed := move_speed
	var target_velocity_x := move_dir.x * target_speed
	var target_velocity_z := move_dir.z * target_speed

	var current_accel := acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, current_accel * delta * move_speed)
	velocity.z = move_toward(velocity.z, target_velocity_z, current_accel * delta * move_speed)

	if move_dir != Vector3.ZERO:
		var target_rotation := atan2(move_dir.x, move_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation, rotation_speed * delta)

	move_and_slide()
