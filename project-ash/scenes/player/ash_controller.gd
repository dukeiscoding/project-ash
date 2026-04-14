extends CharacterBody3D

@export var move_speed: float = 7.5
@export var acceleration: float = 14.0
@export var air_acceleration: float = 6.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var fall_gravity_multiplier: float = 1.8
@export var low_jump_gravity_multiplier: float = 2.4
@export var rotation_speed: float = 12.0

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = deg_to_rad(-60.0)
@export var max_pitch: float = deg_to_rad(35.0)

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.35

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO

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
	_update_timers(delta)

	if is_dashing:
		_handle_dash(delta)
	else:
		_handle_jump_input()
		_apply_gravity(delta)
		_handle_horizontal_movement(delta)
		_try_start_dash()

	_handle_visual_rotation(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity_to_apply := gravity

	if velocity.y < 0.0:
		gravity_to_apply *= fall_gravity_multiplier
	elif velocity.y > 0.0 and not Input.is_action_pressed("jump"):
		gravity_to_apply *= low_jump_gravity_multiplier

	velocity.y -= gravity_to_apply * delta

func _handle_horizontal_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3.ZERO

	if input_dir != Vector2.ZERO:
		var basis := camera_yaw.global_transform.basis
		var forward := -basis.z
		var right := basis.x

		forward.y = 0
		right.y = 0

		forward = forward.normalized()
		right = right.normalized()

		move_dir = (right * input_dir.x - forward * input_dir.y).normalized()

	var target_velocity_x := move_dir.x * move_speed
	var target_velocity_z := move_dir.z * move_speed
	var current_accel := acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, current_accel * delta * move_speed)
	velocity.z = move_toward(velocity.z, target_velocity_z, current_accel * delta * move_speed)

func _try_start_dash() -> void:
	if not Input.is_action_just_pressed("dash"):
		return

	if dash_cooldown_timer > 0.0:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := camera_yaw.global_transform.basis
	var forward := -basis.z
	var right := basis.x

	forward.y = 0
	right.y = 0

	forward = forward.normalized()
	right = right.normalized()

	if input_dir != Vector2.ZERO:
		dash_direction = (right * input_dir.x - forward * input_dir.y).normalized()
	else:
		dash_direction = forward.normalized()

	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown

func _handle_dash(delta: float) -> void:
	dash_timer -= delta

	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	velocity.y = 0.0

	if dash_timer <= 0.0:
		is_dashing = false

func _handle_visual_rotation(delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if horizontal_velocity.length() > 0.05:
		var facing_dir := horizontal_velocity.normalized()
		var target_rotation := atan2(facing_dir.x, facing_dir.z)
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			target_rotation,
			rotation_speed * delta
		)
