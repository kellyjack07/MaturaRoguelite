extends Area2D
class_name HurtboxComponent

@export var health_path: NodePath
@onready var health_component: HealthComponent = get_node(health_path)

@export var invulnerability_duration: float = 0.5
var is_invulnerable: bool = false
var enabled: bool = true
var invulnerability_generation: int = 0


func take_hit(damage: int, from_position: Vector2) -> bool:
	if not enabled or health_component == null or is_invulnerable:
		return false
	if health_component.is_dead():
		return false

	health_component.take_damage(damage)
	if health_component.is_dead():
		return true
	start_invulnerability()

	if get_parent().has_method("apply_hit_reaction"):
		get_parent().apply_hit_reaction(from_position, damage)
	return true


func start_invulnerability() -> void:
	is_invulnerable = true
	invulnerability_generation += 1
	var generation := invulnerability_generation

	await get_tree().create_timer(invulnerability_duration).timeout
	if generation == invulnerability_generation and enabled:
		is_invulnerable = false


func set_enabled(value: bool) -> void:
	enabled = value
	set_deferred("monitoring", value)
	set_deferred("monitorable", value)
	invulnerability_generation += 1
	if not value:
		is_invulnerable = false

	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not value)


func reset_state() -> void:
	set_enabled(true)
	is_invulnerable = false
