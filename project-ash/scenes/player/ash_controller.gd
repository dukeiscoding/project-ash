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
@export var controller_look_sensitivity: float = 3.2
@export var min_pitch: float = deg_to_rad(-60.0)
@export var max_pitch: float = deg_to_rad(35.0)

@export var normal_fov: float = 75.0
@export var dash_fov: float = 84.0
@export var fov_lerp_speed: float = 14.0

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.35

@export var fall_respawn_y: float = -10.0
@export var respawn_marker_path: NodePath

@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.25

@export var max_air_jumps: int = 1

@export var run_anim_speed_threshold: float = 0.15
@export var land_anim_duration: float = 0.12
@export var jump_start_min_duration: float = 1.0
@export var jump_start_playback_speed: float = 1.0
@export var double_jump_anim_duration: float = 0.35
@export var double_jump_playback_speed: float = 1.0
@export var double_jump_min_duration: float = 0.45

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var respawn_marker: Marker3D = get_node_or_null(respawn_marker_path)
@onready var attack_pivot: Node3D = $AttackPivot
@onready var attack_hitbox: Area3D = $AttackPivot/AttackHitbox
@onready var attack_debug_mesh: MeshInstance3D = $AttackPivot/AttackHitbox/MeshInstance3D

@onready var jak_root: Node3D = $"VisualRoot/Jak(T-Pose)"
@onready var animation_player: AnimationPlayer = $"VisualRoot/Jak(T-Pose)/AnimationPlayer2"
@onready var animation_tree: AnimationTree = $"VisualRoot/Jak(T-Pose)/AnimationTree"

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var air_jumps_remaining: int = 0

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO

var is_attacking := false
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var hit_targets_this_swing: Array[Node] = []

var current_anim: String = ""
var was_on_floor_last_frame: bool = false
var land_timer: float = 0.0
var jump_start_timer: float = 0.0
var double_jump_timer: float = 0.0
var double_jump_elapsed: float = 0.0
var animation_playback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = normal_fov
	attack_hitbox.monitoring = false
	attack_debug_mesh.visible = false
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	air_jumps_remaining = max_air_jumps
	was_on_floor_last_frame = is_on_floor()
	_disable_unused_animation_players()
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	if animation_playback != null:
		animation_player.speed_scale = 1.0
		animation_playback.start("Idle")
		current_anim = "Idle"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_apply_camera_look(
			-event.relative.x * mouse_sensitivity,
			-event.relative.y * mouse_sensitivity
		)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	_handle_controller_camera_input(delta)
	_update_timers(delta)
	_try_start_attack()

	if is_dashing:
		_handle_dash(delta)
	else:
		_handle_jump_input()
		_apply_gravity(delta)
		_handle_horizontal_movement(delta)
		_try_start_dash()

	_update_attack_state(delta)
	_update_attack_pivot()
	_handle_visual_rotation(delta)
	move_and_slide()
	_update_camera_fov(delta)
	_check_fall_respawn()
	_update_character_animation(delta)

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_remaining = max_air_jumps
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	jump_start_timer = max(jump_start_timer - delta, 0.0)
	if double_jump_timer > 0.0:
		double_jump_timer = max(double_jump_timer - delta, 0.0)
		double_jump_elapsed += delta

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_start_timer = jump_start_min_duration
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return

	if Input.is_action_just_pressed("jump") and not is_on_floor() and air_jumps_remaining > 0:
		velocity.y = jump_velocity
		double_jump_timer = double_jump_anim_duration
		double_jump_elapsed = 0.0
		jump_start_timer = 0.0
		air_jumps_remaining -= 1
		jump_buffer_timer = 0.0

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
	var input_dir := _get_move_input()
	var move_dir := Vector3.ZERO
	var input_strength := input_dir.length()

	if input_dir != Vector2.ZERO:
		move_dir = _get_camera_relative_direction(input_dir)

	var target_velocity_x := move_dir.x * move_speed * input_strength
	var target_velocity_z := move_dir.z * move_speed * input_strength
	var current_accel := acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, current_accel * delta * move_speed)
	velocity.z = move_toward(velocity.z, target_velocity_z, current_accel * delta * move_speed)

func _try_start_dash() -> void:
	if not Input.is_action_just_pressed("dash"):
		return

	if dash_cooldown_timer > 0.0:
		return

	var input_dir := _get_move_input()
	var forward := _get_camera_forward()

	if input_dir != Vector2.ZERO:
		dash_direction = _get_camera_relative_direction(input_dir)
	else:
		dash_direction = forward

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

func _try_start_attack() -> void:
	if not Input.is_action_just_pressed("attack"):
		return

	if is_attacking:
		return

	if attack_cooldown_timer > 0.0:
		return

	is_attacking = true
	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	hit_targets_this_swing.clear()
	attack_hitbox.monitoring = true
	attack_debug_mesh.visible = false

	print("Attack started")

func _update_attack_state(delta: float) -> void:
	if not is_attacking:
		return

	attack_timer -= delta

	if attack_timer <= 0.0:
		is_attacking = false
		attack_hitbox.monitoring = false
		attack_debug_mesh.visible = false
		hit_targets_this_swing.clear()

func _update_attack_pivot() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if horizontal_velocity.length() > 0.05:
		var facing_dir := horizontal_velocity.normalized()
		attack_pivot.rotation.y = atan2(facing_dir.x, facing_dir.z)
	else:
		attack_pivot.rotation.y = visual_root.rotation.y

func _handle_visual_rotation(delta: float) -> void:
	var input_dir := _get_move_input()

	if input_dir != Vector2.ZERO:
		var move_dir := _get_camera_relative_direction(input_dir)
		var target_rotation := atan2(move_dir.x, move_dir.z)

		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			target_rotation,
			rotation_speed * delta
		)

func _update_camera_fov(delta: float) -> void:
	var target_fov := dash_fov if is_dashing else normal_fov
	camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)

func _handle_controller_camera_input(delta: float) -> void:
	var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down")

	if look_input == Vector2.ZERO:
		return

	_apply_camera_look(
		-look_input.x * controller_look_sensitivity * delta,
		-look_input.y * controller_look_sensitivity * delta
	)

func _apply_camera_look(yaw_delta: float, pitch_delta: float) -> void:
	camera_yaw.rotate_y(yaw_delta)
	camera_pitch.rotation.x = clamp(
		camera_pitch.rotation.x + pitch_delta,
		min_pitch,
		max_pitch
	)

func _get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _get_camera_forward() -> Vector3:
	var forward := -camera_yaw.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func _get_camera_right() -> Vector3:
	var right := camera_yaw.global_transform.basis.x
	right.y = 0.0
	return right.normalized()

func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	var forward := _get_camera_forward()
	var right := _get_camera_right()
	return (right * input_dir.x - forward * input_dir.y).normalized()

func _check_fall_respawn() -> void:
	if global_position.y < fall_respawn_y:
		_respawn_player()

func _respawn_player() -> void:
	if respawn_marker == null:
		return

	global_position = respawn_marker.global_position
	velocity = Vector3.ZERO
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	is_attacking = false
	attack_timer = 0.0
	attack_cooldown_timer = 0.0
	attack_hitbox.monitoring = false
	attack_debug_mesh.visible = false
	air_jumps_remaining = max_air_jumps
	camera.fov = normal_fov
	land_timer = 0.0
	jump_start_timer = 0.0
	double_jump_timer = 0.0
	double_jump_elapsed = 0.0
	if animation_playback != null:
		animation_player.speed_scale = 1.0
		animation_playback.start("Idle")
		current_anim = "Idle"

func _update_character_animation(delta: float) -> void:
	var on_floor_now := is_on_floor()
	var just_landed := on_floor_now and not was_on_floor_last_frame
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()

	if just_landed:
		land_timer = land_anim_duration

	if land_timer > 0.0:
		land_timer -= delta

	# FUTURE ANIMATIONS: add new animation priority rules here.
	# Higher in this list = higher priority.
	# Example later:
	# hurt > death > melee_combo > dash > double_jump > jump_start > fall > land > run > idle

	if is_attacking:
		_play_character_animation("Melee")
	elif is_dashing:
		_play_character_animation("Dash")
	elif not on_floor_now and _should_play_double_jump():
		_play_character_animation("DoubleJump")
	elif not on_floor_now and jump_start_timer > 0.0:
		_play_character_animation("JumpStart")
	elif not on_floor_now and jump_start_timer <= 0.0:
		_play_character_animation("FallLoop")
	elif land_timer > 0.0:
		_play_character_animation("Land")
	elif horizontal_speed > run_anim_speed_threshold:
		_play_character_animation("Run")
	else:
		_play_character_animation("Idle")

	was_on_floor_last_frame = on_floor_now

func _should_play_double_jump() -> bool:
	if double_jump_timer <= 0.0:
		return false

	return double_jump_elapsed < double_jump_min_duration or velocity.y > 0.0

func _play_character_animation(anim_name: String) -> void:
	if current_anim == anim_name:
		return

	if animation_playback == null:
		return

	if anim_name == "JumpStart":
		animation_player.speed_scale = jump_start_playback_speed
	elif anim_name == "DoubleJump":
		animation_player.speed_scale = double_jump_playback_speed
	else:
		animation_player.speed_scale = 1.0
	animation_playback.travel(anim_name)

	print("Playing animation:", anim_name)
	current_anim = anim_name

func _disable_unused_animation_players() -> void:
	for child in jak_root.get_children():
		if child is AnimationPlayer and child != animation_player:
			child.stop()
			child.active = false

	animation_player.stop()
	animation_player.active = true
	animation_player.speed_scale = 1.0

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body == self:
		return

	if hit_targets_this_swing.has(body):
		return

	hit_targets_this_swing.append(body)

	if body is Node3D:
		var body_3d: Node3D = body
		var hit_direction: Vector3 = body_3d.global_position - global_position
		hit_direction.y = 0.0
		hit_direction = hit_direction.normalized()

		if body.has_method("take_damage"):
			body.take_damage(1, hit_direction)

	print("Hit body:", body.name)

func _on_attack_hitbox_area_entered(area: Area3D) -> void:
	if area == attack_hitbox:
		return

	if hit_targets_this_swing.has(area):
		return

	hit_targets_this_swing.append(area)

	var hit_direction: Vector3 = area.global_position - global_position
	hit_direction.y = 0.0
	hit_direction = hit_direction.normalized()

	if area.has_method("take_damage"):
		area.take_damage(1, hit_direction)

	print("Hit area:", area.name)
