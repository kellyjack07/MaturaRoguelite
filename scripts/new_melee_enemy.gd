extends "res://scripts/base_enemy.gd"
class_name NewMeleeEnemy

enum State { IDLE, CHASE, PREPARE, DASH, ATTACK, RECOVER }

@export var uses_dash: bool = true
@export var difficulty_weight: float = 1.0
@export var enemy_max_health: int = 20
@export var enemy_damage: int = 5
@export var aggro_radius: float = 80.0
@export var attack_range: float = 25.0
@export var prepare_duration: float = 0.18
@export var dash_speed: float = 75.0
@export var dash_duration: float = 0.5
@export var attack_duration: float = 0.32
@export_range(0.0, 1.0, 0.01) var attack_hit_point: float = 0.375
@export var attack_recover_duration: float = 0.8
@export var attack_damage_radius: float = 20.0

var state := State.IDLE
var state_timer := 0.0
var attack_direction := Vector2.DOWN
var attack_damage_applied := false
var is_awake := false

func on_enemy_ready() -> void:
	receives_knockback = false
	hitbox.damage = enemy_damage
	health_component.max_health = enemy_max_health
	health_component.current_health = enemy_max_health
	prepare_duration = get_authored_animation_duration(&"prepare", prepare_duration)
	attack_duration = get_authored_animation_duration(&"attack", attack_duration)
	hitbox.set_active(false)
	play_idle_animation()

func update_behavior(delta: float) -> void:
	match state:

		State.IDLE:
			stop_moving()
			play_idle_animation()
			if _should_wake_from_player_movement():
				is_awake = true
				state = State.CHASE
		State.CHASE:
			if player != null and global_position.distance_to(player.global_position) <= attack_range:
				_enter_prepare()
			else:
				move_toward_player()
				play_move_animation()
		State.PREPARE:
			stop_moving()
			play_prepare_animation()
			state_timer -= delta
			if state_timer <= 0.0:
				if uses_dash:
					state = State.DASH
					state_timer = dash_duration
				else:
					_enter_attack()
		State.DASH:
			velocity = attack_direction * dash_speed
			update_visual_facing(attack_direction)
			play_dash_animation()
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_attack()
		State.ATTACK:
			stop_moving()
			play_attack_animation()
			state_timer -= delta
			if not attack_damage_applied and state_timer <= attack_duration * (1.0 - attack_hit_point):
				attack_damage_applied = true
				_damage_player_if_in_range()
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = attack_recover_duration
		State.RECOVER:
			stop_moving()
			play_idle_animation()
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.CHASE

func _enter_prepare() -> void:
	state = State.PREPARE
	state_timer = prepare_duration
	attack_damage_applied = false
	stop_moving()
	if player != null:
		attack_direction = global_position.direction_to(player.global_position).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN
	update_visual_facing(attack_direction)

func _enter_attack() -> void:
	state = State.ATTACK
	state_timer = attack_duration
	attack_damage_applied = false
	stop_moving()

func _should_wake_from_player_movement() -> bool:
	if is_awake or player == null or global_position.distance_to(player.global_position) > aggro_radius:
		return is_awake
	if player.velocity.length() <= 1.0:
		return false
	var direction_to_enemy := player.global_position.direction_to(global_position)
	return player.velocity.normalized().dot(direction_to_enemy) >= 0.4

func _damage_player_if_in_range() -> void:
	if player == null or global_position.distance_to(player.global_position) > attack_damage_radius:
		return
	var player_hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
	if player_hurtbox != null:
		player_hurtbox.take_hit(hitbox.damage, global_position)

func play_idle_animation() -> void: play_animation_if_exists(&"idle")
func play_move_animation() -> void: play_animation_if_exists(&"move")
func play_prepare_animation() -> void: play_animation_if_exists(&"prepare")
func play_dash_animation() -> void: play_animation_if_exists(&"dash")
func play_attack_animation() -> void: play_animation_if_exists(&"attack")
