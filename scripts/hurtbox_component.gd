extends Area2D
class_name HurtboxComponent

@export var health_path: NodePath
@onready var health_component: HealthComponent = get_node(health_path)

#damage
func take_hit(damage: int) -> void:
	if health_component == null:
		return
	
	health_component.take_damage(damage)
	print("damage taken")
