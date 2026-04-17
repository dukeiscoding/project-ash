extends StaticBody3D

@export var max_health: int = 3
@export var respawn_enabled: bool = true
@export var respawn_delay: float = 2.0

@export var knockback_distance: float = 0.6
@export var knockback_duration: float = 0.08

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hit_flash_timer: Timer = $HitFlashTimer

var current_health: int
var base_color: Color
var knockback_tween: Tween
var spawn_position: Vector3
var is_dead := false

func _ready() -> void:
	spawn_position = global_position
	current_health = max_health

	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material != null:
		base_color = material.albedo_color
	else:
		base_color = Color(0.8, 0.2, 0.2, 1.0)

	hit_flash_timer.timeout.connect(_on_hit_flash_timer_timeout)

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	print(name, " took damage. Health: ", current_health)

	_flash_on_hit()
	_apply_knockback(hit_direction)

	if current_health <= 0:
		_die()

func _flash_on_hit() -> void:
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return

	var color := material.albedo_color
	color = Color(1.0, 1.0, 1.0, color.a)
	material.albedo_color = color

	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return

	material.albedo_color = base_color

func _apply_knockback(hit_direction: Vector3) -> void:
	var knockback_dir := hit_direction
	knockback_dir.y = 0.0

	if knockback_dir.length() <= 0.001:
		knockback_dir = Vector3.BACK
	else:
		knockback_dir = knockback_dir.normalized()

	var target_position := global_position + knockback_dir * knockback_distance

	if knockback_tween != null:
		knockback_tween.kill()

	knockback_tween = create_tween()
	knockback_tween.tween_property(self, "global_position", target_position, knockback_duration)

func _die() -> void:
	print(name, " destroyed")

	is_dead = true
	mesh_instance.visible = false
	collision_shape.disabled = true

	if respawn_enabled:
		await get_tree().create_timer(respawn_delay).timeout
		_respawn()
	else:
		queue_free()

func _respawn() -> void:
	global_position = spawn_position
	current_health = max_health
	is_dead = false

	mesh_instance.visible = true
	collision_shape.disabled = false

	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material != null:
		material.albedo_color = base_color

	print(name, " respawned")
