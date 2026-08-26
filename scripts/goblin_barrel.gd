extends "res://scripts/base_enemy.gd"
class_name GoblinBarrel

const ENEMY_ID := "goblin_barrel"

enum EnemyState {
	IDLE,
	CHASE,
	PREPARE,
	DASH,
	ATTACK,
	RECOVER,
}

@export var aggro_radius: float = 80.0
@export var attack_range: float = 25.0
@export var prepare_duration: float = 0.18
@export var dash_speed: float = 75.0
@export var dash_duration: float = 0.5
@export var attack_duration: float = 0.32
@export var attack_hit_delay: float = 0.12
@export var attack_recover_duration: float = 0.8
@export var attack_damage_radius: float = 20.0
@export var wake_direction_threshold: float = 0.4

var enemy_state: EnemyState = EnemyState.IDLE
var state_timer: float = 0.0
var attack_direction: Vector2 = Vector2.DOWN
var is_awake: bool = false
var attack_damage_applied: bool = false


func on_enemy_ready() -> void:
	hitbox.set_active(false)
	play_idle_animation()


func update_behavior(delta: float) -> void:
	match enemy_state:
		EnemyState.IDLE:
			update_idle_state()
		EnemyState.CHASE:
			update_chase_state()
		EnemyState.PREPARE:
			update_prepare_state(delta)
		EnemyState.DASH:
			update_dash_state(delta)
		EnemyState.ATTACK:
			update_attack_state(delta)
		EnemyState.RECOVER:
			update_recover_state(delta)


func update_idle_state() -> void:
	stop_moving()
	play_idle_animation()

	if is_awake:
		enter_chase_state()
		return

	if should_wake_from_player_movement():
		is_awake = true
		enter_chase_state()


func update_chase_state() -> void:
	if is_player_in_attack_range():
		enter_prepare_state()
		return

	move_toward_player()
	play_move_animation()


func update_prepare_state(delta: float) -> void:
	stop_moving()
	play_prepare_animation()
	state_timer -= delta

	if state_timer <= 0.0:
		enter_dash_state()


func update_dash_state(delta: float) -> void:
	velocity = attack_direction * dash_speed
	update_visual_facing(attack_direction)
	play_dash_animation()
	state_timer -= delta

	if state_timer <= 0.0:
		enter_attack_state()


func update_attack_state(delta: float) -> void:
	stop_moving()
	play_attack_animation()
	state_timer -= delta

	if not attack_damage_applied and state_timer <= attack_duration - attack_hit_delay:
		attack_damage_applied = true
		damage_player_in_attack_radius()

	if state_timer <= 0.0:
		enter_recover_state()


func update_recover_state(delta: float) -> void:
	stop_moving()
	play_idle_animation()
	state_timer -= delta

	if state_timer <= 0.0:
		enter_chase_state()


func enter_chase_state() -> void:
	enemy_state = EnemyState.CHASE
	hitbox.set_active(false)


func enter_prepare_state() -> void:
	enemy_state = EnemyState.PREPARE
	state_timer = prepare_duration
	stop_moving()
	hitbox.set_active(false)

	if player != null:
		attack_direction = global_position.direction_to(player.global_position).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN

	update_visual_facing(attack_direction)
	play_prepare_animation()


func enter_dash_state() -> void:
	enemy_state = EnemyState.DASH
	state_timer = dash_duration
	hitbox.set_active(false)
	play_dash_animation()


func enter_attack_state() -> void:
	enemy_state = EnemyState.ATTACK
	state_timer = attack_duration
	attack_damage_applied = false
	hitbox.set_active(false)
	stop_moving()
	play_attack_animation()


func enter_recover_state() -> void:
	enemy_state = EnemyState.RECOVER
	state_timer = attack_recover_duration
	hitbox.set_active(false)
	stop_moving()


func should_wake_from_player_movement() -> bool:
	if player == null:
		return false

	if global_position.distance_to(player.global_position) > aggro_radius:
		return false

	if player.velocity.length() <= 1.0:
		return false

	var direction_to_enemy: Vector2 = player.global_position.direction_to(global_position)
	var player_move_direction: Vector2 = player.velocity.normalized()
	return player_move_direction.dot(direction_to_enemy) >= wake_direction_threshold


func is_player_in_attack_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= attack_range


func damage_player_in_attack_radius() -> void:
	if player == null:
		return

	if global_position.distance_to(player.global_position) > attack_damage_radius:
		return

	var player_hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
	if player_hurtbox == null:
		return

	player_hurtbox.take_hit(hitbox.damage, global_position)


func play_idle_animation() -> void:
	if play_animation_if_exists(&"idle"):
		return
	play_animation_if_exists(&"default")


func play_move_animation() -> void:
	if play_animation_if_exists(&"move"):
		return
	play_idle_animation()


func play_prepare_animation() -> void:
	if play_animation_if_exists(&"atk"):
		return
	play_idle_animation()


func play_dash_animation() -> void:
	if play_animation_if_exists(&"dash"):
		return
	play_move_animation()


func play_attack_animation() -> void:
	if play_animation_if_exists(&"atk"):
		return
	play_idle_animation()


func on_died() -> void:
	hitbox.set_active(false)
	velocity = Vector2.ZERO
	set_physics_process(false)
	var blink_count: int = 4
	for _blink in blink_count:
		animated_sprite.visible = false
		await get_tree().create_timer(0.08).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(0.08).timeout
	queue_free()
