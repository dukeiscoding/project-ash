extends StaticBody3D

@export var max_health: int = 3
@export var destroy_on_death: bool = true

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hit_flash_timer: Timer = $HitFlashTimer

var current_health: int
var base_color: Color

func _ready() -> void:
	current_health = max_health

	# Save original material color so we can restore it after flashing
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material != null:
		base_color = material.albedo_color
	else:
		base_color = Color(0.8, 0.2, 0.2, 1.0)

	hit_flash_timer.timeout.connect(_on_hit_flash_timer_timeout)

func take_damage(amount: int) -> void:
	current_health -= amount
	print(name, " took damage. Health: ", current_health)

	_flash_on_hit()

	if current_health <= 0:
		_die()

func _flash_on_hit() -> void:
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return

	# Flash white briefly
	var color := material.albedo_color
	color = Color(1.0, 1.0, 1.0, color.a)
	material.albedo_color = color

	hit_flash_timer.start()

func _on_hit_flash_timer_timeout() -> void:
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return

	# Restore original color
	material.albedo_color = base_color

func _die() -> void:
	print(name, " destroyed")

	if destroy_on_death:
		queue_free()
