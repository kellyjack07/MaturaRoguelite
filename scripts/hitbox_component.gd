extends Area2D
class_name HitboxComponent

@export var damage: int = 1
@export var max_targets_per_swing: int = 2
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_damage: int = 1
var hitbox_active: bool = false
var total_hits_landed: int = 0
var already_hit_hurtboxes: Array[HurtboxComponent] = []
var pulse_hit_hurtboxes: Array[HurtboxComponent] = []
var allow_repeat_hits_this_pulse: bool = false


func _ready() -> void:
	set_hitbox_active(false)


func set_damage(new_damage: int) -> void:
	current_damage = new_damage


func start_attack(max_total_targets: int = max_targets_per_swing) -> void:
	max_targets_per_swing = max_total_targets
	total_hits_landed = 0
	already_hit_hurtboxes.clear()
	pulse_hit_hurtboxes.clear()
	set_hitbox_active(false)


func start_swing() -> void:
	start_attack(max_targets_per_swing)


func begin_pulse(allow_repeat_hits: bool = false) -> void:
	allow_repeat_hits_this_pulse = allow_repeat_hits
	pulse_hit_hurtboxes.clear()


func cancel_attack() -> void:
	set_hitbox_active(false)
	already_hit_hurtboxes.clear()
	pulse_hit_hurtboxes.clear()
	total_hits_landed = 0


func set_hitbox_active(active: bool) -> void:
	hitbox_active = active
	set_deferred("monitoring", active)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)


func deal_damage() -> int:
	if not hitbox_active or collision_shape == null or collision_shape.shape == null:
		return 0
	if max_targets_per_swing > 0 and total_hits_landed >= max_targets_per_swing:
		set_hitbox_active(false)
		return 0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var valid_hurtboxes: Array[HurtboxComponent] = []
	for result in results:
		var collider = result.collider
		if not collider is HurtboxComponent:
			continue
		if collider.get_parent() == get_parent():
			continue
		if pulse_hit_hurtboxes.has(collider):
			continue
		if not allow_repeat_hits_this_pulse and already_hit_hurtboxes.has(collider):
			continue
		valid_hurtboxes.append(collider)

	valid_hurtboxes.sort_custom(func(a: HurtboxComponent, b: HurtboxComponent) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var hits_this_pulse := 0
	for target_hurtbox in valid_hurtboxes:
		if max_targets_per_swing > 0 and total_hits_landed >= max_targets_per_swing:
			break

		pulse_hit_hurtboxes.append(target_hurtbox)
		if not target_hurtbox.take_hit(current_damage, global_position):
			continue

		if not already_hit_hurtboxes.has(target_hurtbox):
			already_hit_hurtboxes.append(target_hurtbox)
		total_hits_landed += 1
		hits_this_pulse += 1

		var current_scene := get_tree().current_scene
		if current_scene != null and current_scene.has_method("trigger_hit_stop"):
			current_scene.trigger_hit_stop()

	set_hitbox_active(false)
	return hits_this_pulse
