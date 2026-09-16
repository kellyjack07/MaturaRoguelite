extends CharacterBody2D
class_name EnemyProjectile

@export var damage: int = 5
@export var speed: float = 180.0
@export var lifetime: float = 2.0
var direction := Vector2.RIGHT
var previous_position := Vector2.ZERO

func setup(travel_direction: Vector2, projectile_damage: int = 5) -> void:
	direction = travel_direction.normalized()
	damage = projectile_damage
	rotation = direction.angle()

func _ready() -> void:
	previous_position = global_position

func _physics_process(delta: float) -> void:
	previous_position = global_position
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(previous_position, next_position, 1)
	query.exclude = [self]
	var wall_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not wall_hit.is_empty():
		queue_free()
		return
	global_position = next_position
	var player := get_tree().get_first_node_in_group("player")
	var hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent if player != null else null
	if hurtbox != null and global_position.distance_to(hurtbox.global_position) <= 10.0:
		hurtbox.take_hit(damage, global_position)
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

