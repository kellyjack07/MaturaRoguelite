extends Area2D
class_name HurtboxComponent

@export var health_path: NodePath
@onready var health_component: HealthComponent = get_node(health_path)

@export var invulnerability_duration: float = 0.5
var is_invulnerable: bool = false

#damage
#damage
func take_hit(damage: int, from_position: Vector2) -> void:
	if health_component == null:
		return
	
	if is_invulnerable:
		return
	
	health_component.take_damage(damage)
	start_invulnerability()
	
	if get_parent().has_method("apply_hit_reaction"):
		get_parent().apply_hit_reaction(from_position, damage)
	
	print("damage taken")

func start_invulnerability() -> void:
	is_invulnerable = true
	
	await get_tree().create_timer(invulnerability_duration).timeout
	
	is_invulnerable = false
