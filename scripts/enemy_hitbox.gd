extends Area2D

@export var damage: int = 1
@export var is_active: bool = true

#hit
func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return

	if area is HurtboxComponent:
		if area.get_parent() == get_parent():
			return

		area.take_hit(damage, global_position)


func set_active(active: bool) -> void:
	is_active = active
	monitoring = active


func damage_overlapping_hurtboxes() -> void:
	if not is_active:
		return

	var collision_shape := $CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider is HurtboxComponent:
			if collider.get_parent() == get_parent():
				continue

			collider.take_hit(damage, global_position)
