extends CharacterBody2D
class_name BaseEnemy

@export var move_speed: float = 50.0
@export var stop_distance: float = 14.0
@export var hit_knockback_speed: float = 120.0
@export var hit_stun_duration: float = 0.3
@export var invulnerability_blink_alpha: float = 0.35
@export var invulnerability_blink_count: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

var player: Node2D = null
var hit_stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var default_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var invulnerability_visual_active: bool = false


func _ready() -> void:
	health_component.died.connect(on_died)
	default_modulate = animated_sprite.modulate
	on_enemy_ready()


func _physics_process(delta: float) -> void:
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_speed * delta * 6.0)
		return

	if not ensure_player_reference():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	update_behavior(delta)
	move_and_slide()


func ensure_player_reference() -> bool:
	if player != null and is_instance_valid(player):
		return true

	player = get_tree().get_first_node_in_group("player") as Node2D
	return player != null and is_instance_valid(player)


func update_behavior(_delta: float) -> void:
	move_toward_player()


func on_enemy_ready() -> void:
	pass


func move_toward_player() -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	if distance_to_player <= stop_distance:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	update_visual_facing(direction)


func move_toward_position(target_position: Vector2, speed: float = move_speed, min_distance: float = stop_distance) -> void:
	var distance_to_target: float = global_position.distance_to(target_position)
	if distance_to_target <= min_distance:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(target_position)
	velocity = direction * speed
	update_visual_facing(direction)


func stop_moving() -> void:
	velocity = Vector2.ZERO


func update_visual_facing(direction: Vector2) -> void:
	if direction.x == 0.0:
		return

	animated_sprite.flip_h = direction.x < 0.0


func has_animation(animation_name: StringName) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)


func play_animation_if_exists(animation_name: StringName) -> bool:
	if not has_animation(animation_name):
		return false

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play()
	return true


func apply_hit_reaction(from_position: Vector2, damage: int) -> void:
	var knockback_direction: Vector2 = from_position.direction_to(global_position).normalized()
	knockback_velocity = knockback_direction * hit_knockback_speed * (float(damage) / 8.0)
	hit_stun_timer = hit_stun_duration
	play_invulnerability_visual()
	on_hit_received()


func on_hit_received() -> void:
	pass


func play_invulnerability_visual() -> void:
	if invulnerability_visual_active:
		return

	invulnerability_visual_active = true

	var total_blinks: int = max(invulnerability_blink_count, 1)
	var blink_interval: float = max(hurtbox.invulnerability_duration / float(total_blinks * 2), 0.03)
	var blink_modulate := default_modulate
	blink_modulate.a = invulnerability_blink_alpha

	for _blink in total_blinks:
		animated_sprite.modulate = blink_modulate
		await get_tree().create_timer(blink_interval).timeout
		animated_sprite.modulate = default_modulate
		await get_tree().create_timer(blink_interval).timeout

	animated_sprite.modulate = default_modulate
	invulnerability_visual_active = false


func on_died() -> void:
	queue_free()
