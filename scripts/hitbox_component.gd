extends Area2D
class_name HitboxComponent

@export var damage: int = 1

#hit
func deal_damage() -> void:
	var shape: Shape2D = $CollisionShape2D.shape
	var query := PhysicsShapeQueryParameters2D.new()
	
	query.shape = shape
	query.transform = $CollisionShape2D.global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = get_world_2d().direct_space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		if collider is HurtboxComponent:
			collider.take_hit(damage)
