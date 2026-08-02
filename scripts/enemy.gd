extends CharacterBody2D

@export var move_speed: float = 50.0
@export var stop_distance: float = 14.0
@export var hit_knockback_speed: float = 120.0
@export var hit_stun_duration: float = 0.3

@onready var health_component: HealthComponent = $Health

var player: Node2D = null
var hit_stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

#start
func _ready() -> void:
	health_component.died.connect(on_died)


#updates
func _physics_process(delta: float) -> void:
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_speed * delta * 6.0)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	move_toward_player()



#movement
func move_toward_player() -> void:
	var distance_to_player: float = global_position.distance_to(player.global_position)
	
	if distance_to_player <= stop_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var direction: Vector2 = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	move_and_slide()

#hit reaction
func apply_hit_reaction(from_position: Vector2, damage: int) -> void:
	var knockback_direction: Vector2 = from_position.direction_to(global_position).normalized()
	knockback_velocity = knockback_direction * hit_knockback_speed * float(damage/8)
	hit_stun_timer = hit_stun_duration

#death
func on_died() -> void:
	print("enemy died")
	queue_free()
