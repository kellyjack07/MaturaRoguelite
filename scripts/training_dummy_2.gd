extends "res://scripts/base_enemy.gd"
class_name TrainingDummy2

const ENEMY_ID := "training_dummy_2"

enum EnemyState {
	IDLE,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_DASH,
	ATTACK_SPIN,
	RECOVER,
}

@export var aggro_radius: float = 96.0
@export var attack_range: float = 16.0
@export var attack_start_delay: float = 0.5
@export var attack_dash_speed: float = 110.0
@export var attack_dash_duration: float = 0.3
@export var attack_spin_duration: float = 3.0
@export var attack_recover_duration: float = 0.35
@export var attack_spin_damage_radius: float = 22.0

var enemy_state: EnemyState = EnemyState.IDLE
var state_timer: float = 0.0
var attack_direction: Vector2 = Vector2.DOWN
var attack_dash_remaining_distance: float = 0.0


func on_enemy_ready() -> void:
	hitbox.set_active(false)
	play_idle_animation()


func update_behavior(delta: float) -> void:
	match enemy_state:
		EnemyState.IDLE:
			update_idle_state()
		EnemyState.CHASE:
			update_chase_state()
		EnemyState.ATTACK_WINDUP:
			update_attack_windup_state(delta)
		EnemyState.ATTACK_DASH:
			update_attack_dash_state(delta)
		EnemyState.ATTACK_SPIN:
			update_attack_spin_state(delta)
		EnemyState.RECOVER:
			update_recover_state(delta)


func update_idle_state() -> void:
	stop_moving()
	play_idle_animation()

	if not is_player_in_aggro_range():
		return

	enter_chase_state()


func update_chase_state() -> void:
	if not is_player_in_aggro_range():
		enter_idle_state()
		return

	if is_player_in_attack_range():
		enter_attack_windup_state()
		return

	move_toward_player()
	play_move_animation()


func update_attack_windup_state(delta: float) -> void:
	stop_moving()
	play_dash_animation()
	state_timer -= delta

	if state_timer <= 0.0:
		enter_attack_dash_state()


func update_attack_dash_state(delta: float) -> void:
	var dash_step_distance: float = min(attack_dash_speed * delta, attack_dash_remaining_distance)
	velocity = attack_direction * (dash_step_distance / max(delta, 0.0001))
	update_visual_facing(attack_direction)
	play_dash_animation()
	state_timer -= delta
	attack_dash_remaining_distance = max(attack_dash_remaining_distance - dash_step_distance, 0.0)

	if state_timer <= 0.0 or attack_dash_remaining_distance <= 0.0:
		enter_attack_spin_state()


func update_attack_spin_state(delta: float) -> void:
	stop_moving()
	play_attack_spin_animation()
	state_timer -= delta
	damage_player_during_spin()

	if state_timer <= 0.0:
		enter_recover_state()


func update_recover_state(delta: float) -> void:
	stop_moving()
	play_idle_animation()
	state_timer -= delta

	if state_timer <= 0.0:
		if is_player_in_aggro_range():
			enter_chase_state()
		else:
			enter_idle_state()


func enter_idle_state() -> void:
	enemy_state = EnemyState.IDLE
	stop_moving()
	hitbox.set_active(false)
	play_idle_animation()


func enter_chase_state() -> void:
	enemy_state = EnemyState.CHASE
	hitbox.set_active(false)


func enter_attack_windup_state() -> void:
	enemy_state = EnemyState.ATTACK_WINDUP
	state_timer = attack_start_delay
	hitbox.set_active(false)
	stop_moving()
	if player != null:
		attack_direction = global_position.direction_to(player.global_position).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN
	var distance_to_player: float = attack_range
	if player != null:
		distance_to_player = global_position.distance_to(player.global_position)
	attack_dash_remaining_distance = distance_to_player + (attack_range * 0.5)
	update_visual_facing(attack_direction)
	play_dash_animation()


func enter_attack_dash_state() -> void:
	enemy_state = EnemyState.ATTACK_DASH
	state_timer = attack_dash_duration
	hitbox.set_active(false)
	play_dash_animation()


func enter_attack_spin_state() -> void:
	enemy_state = EnemyState.ATTACK_SPIN
	state_timer = attack_spin_duration
	hitbox.set_active(false)
	stop_moving()
	play_attack_spin_animation()


func enter_recover_state() -> void:
	enemy_state = EnemyState.RECOVER
	state_timer = attack_recover_duration
	hitbox.set_active(false)
	stop_moving()


func is_player_in_aggro_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= aggro_radius


func is_player_in_attack_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= attack_range


func damage_player_during_spin() -> void:
	if player == null:
		return

	if global_position.distance_to(player.global_position) > attack_spin_damage_radius:
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


func play_dash_animation() -> void:
	if play_animation_if_exists(&"dash"):
		return
	play_idle_animation()


func play_attack_spin_animation() -> void:
	if play_animation_if_exists(&"attack_spin"):
		return
	play_idle_animation()


func on_hit_received() -> void:
	if enemy_state == EnemyState.ATTACK_SPIN:
		hitbox.set_active(false)


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
