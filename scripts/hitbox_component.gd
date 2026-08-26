extends Area2D
class_name HitboxComponent

@export var damage: int = 1
@export var max_targets_per_swing: int = 2
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var current_damage: int = 1
var already_hit_hurtboxes: Array[HurtboxComponent] = []
var hitbox_active: bool = false


func _ready() -> void:
	set_hitbox_active(false)

#damage set
func set_damage(new_damage: int) -> void:
	current_damage = new_damage


func start_swing() -> void:
	already_hit_hurtboxes.clear()
	set_hitbox_active(false)


func set_hitbox_active(active: bool) -> void:
	hitbox_active = active
	monitoring = active
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)


#hit
func deal_damage() -> void:
	if not hitbox_active:
		return

	var shape: Shape2D = $CollisionShape2D.shape
	var query := PhysicsShapeQueryParameters2D.new()
	
	query.shape = shape
	query.transform = $CollisionShape2D.global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = get_world_2d().direct_space_state.intersect_shape(query)
	var valid_hurtboxes: Array[HurtboxComponent] = []
	
	for result in results:
		var collider = result.collider
		if collider is HurtboxComponent:
			if collider.get_parent() == get_parent():
				continue

			if already_hit_hurtboxes.has(collider):
				continue

			valid_hurtboxes.append(collider)

	valid_hurtboxes.sort_custom(func(a: HurtboxComponent, b: HurtboxComponent) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var targets_hit: int = 0
	for hurtbox in valid_hurtboxes:
		if max_targets_per_swing > 0 and targets_hit >= max_targets_per_swing:
			break

		hurtbox.take_hit(current_damage, global_position)
		already_hit_hurtboxes.append(hurtbox)
		targets_hit += 1

		if get_tree().current_scene.has_method("trigger_hit_stop"):
			get_tree().current_scene.trigger_hit_stop()

	set_hitbox_active(false)
