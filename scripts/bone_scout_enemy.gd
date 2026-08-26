extends "res://scripts/base_enemy.gd"
class_name BoneScoutEnemy

enum EnemyState {
	CHASE,
	WINDUP,
	LUNGE,
	RECOVER,
}

@export var lunge_trigger_distance: float = 52.0
@export var lunge_speed: float = 135.0
@export var lunge_duration: float = 0.32
@export var lunge_windup_duration: float = 0.22
@export var lunge_recover_duration: float = 0.38
@export var lunge_cooldown: float = 1.4
@export var windup_tint: Color = Color(1.25, 0.78, 0.78, 1.0)

var enemy_state: EnemyState = EnemyState.CHASE
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var lunge_direction: Vector2 = Vector2.ZERO


func update_behavior(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = max(cooldown_timer - delta, 0.0)

	match enemy_state:
		EnemyState.CHASE:
			update_chase_state()
		EnemyState.WINDUP:
			update_windup_state(delta)
		EnemyState.LUNGE:
			update_lunge_state(delta)
		EnemyState.RECOVER:
			update_recover_state(delta)


func update_chase_state() -> void:
	move_toward_player()
	if player == null or cooldown_timer > 0.0:
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	if distance_to_player <= lunge_trigger_distance:
		enter_windup_state()


func update_windup_state(delta: float) -> void:
	stop_moving()
	state_timer -= delta
	if state_timer <= 0.0:
		enter_lunge_state()


func update_lunge_state(delta: float) -> void:
	velocity = lunge_direction * lunge_speed
	update_visual_facing(lunge_direction)
	state_timer -= delta
	if state_timer <= 0.0:
		enter_recover_state()


func update_recover_state(delta: float) -> void:
	stop_moving()
	state_timer -= delta
	if state_timer <= 0.0:
		enter_chase_state()


func enter_chase_state() -> void:
	enemy_state = EnemyState.CHASE
	animated_sprite.modulate = default_modulate


func enter_windup_state() -> void:
	enemy_state = EnemyState.WINDUP
	state_timer = lunge_windup_duration
	animated_sprite.modulate = windup_tint
	lunge_direction = global_position.direction_to(player.global_position).normalized()
	if lunge_direction == Vector2.ZERO:
		lunge_direction = Vector2.DOWN
	update_visual_facing(lunge_direction)


func enter_lunge_state() -> void:
	enemy_state = EnemyState.LUNGE
	state_timer = lunge_duration
	animated_sprite.modulate = default_modulate
	cooldown_timer = lunge_cooldown


func enter_recover_state() -> void:
	enemy_state = EnemyState.RECOVER
	state_timer = lunge_recover_duration


func on_hit_received() -> void:
	enter_chase_state()
	cooldown_timer = max(cooldown_timer, 0.45)
