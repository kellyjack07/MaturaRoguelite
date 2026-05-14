extends Area2D

@export var damage: int = 1

#hit
func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(damage)
