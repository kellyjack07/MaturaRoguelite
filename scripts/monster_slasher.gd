extends "res://scripts/base_enemy.gd"
class_name MonsterSlasher

const ENEMY_ID := "monster_slasher"

enum EnemyState {
	IDLE,
	CHASE,
	PREPARE,
	PASS_ONE,
	PASS_TWO,
	RECOVER,
}

# These values intentionally start as local copies of Goblin Barrel's current
# tuning. They are not a shared tuning resource and can be adjusted here later.
@export var aggro_radius: float = 80.0
@export var attack_range: float = 25.0
@export var prepare_duration: float = 0.18
@export var dash_speed: float = 75.0
@export var pass_duration: float = 0.5
@export var attack_duration: float = 0.32
@export_range(0.0, 1.0, 0.01) var attack_hit_point: float = 0.5
@export var attack_recover_duration: float = 0.8
@export var attack_damage_radius: float = 20.0
@export var pass_distance: float = 38.0
@export var knockback_parameter: float = 0.0

var enemy_state: EnemyState = EnemyState.IDLE
var state_timer: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var target_center: Vector2 = Vector2.ZERO
var attack_damage_applied: bool = false
var next_pass_from_left: bool = true


func on_enemy_ready() -> void:
	receives_knockback = false
	prepare_duration = get_authored_animation_duration(&"prepare", prepare_duration)
	attack_duration = get_authored_animation_duration(&"attack", attack_duration)
	pass_duration = attack_duration * 0.5
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
		EnemyState.PASS_ONE:
			update_pass_state(delta, false)
		EnemyState.PASS_TWO:
			update_pass_state(delta, true)
		EnemyState.RECOVER:
			update_recover_state(delta)


func update_idle_state() -> void:
	stop_moving()
	play_idle_animation()
	if player != null and global_position.distance_to(player.global_position) <= aggro_radius:
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
		enter_first_pass_state()


func update_pass_state(delta: float, second_pass: bool) -> void:
	# The slasher remains committed to both passes even when damaged.
	velocity = attack_direction * dash_speed
	update_visual_facing(attack_direction)
	if second_pass:
		play_pass_two_animation()
	else:
		play_pass_one_animation()

	# Check the player's live position at the hit frame. The position captured
	# during preparation is only the pass target and must not authorize a stale hit.
	var pass_elapsed := pass_duration - state_timer
	if not attack_damage_applied and pass_elapsed >= pass_duration * attack_hit_point and player != null and global_position.distance_to(player.global_position) <= attack_damage_radius:
		attack_damage_applied = true
		damage_player_in_attack_radius()

	state_timer -= delta
	if state_timer <= 0.0:
		if second_pass:
			enter_recover_state()
		else:
			enter_second_pass_state()


func update_recover_state(delta: float) -> void:
	stop_moving()
	play_recover_animation()
	state_timer -= delta
	if state_timer <= 0.0:
		enter_chase_state()


func enter_chase_state() -> void:
	enemy_state = EnemyState.CHASE
	hitbox.set_active(false)


func enter_prepare_state() -> void:
	enemy_state = EnemyState.PREPARE
	state_timer = prepare_duration
	attack_damage_applied = false
	stop_moving()
	hitbox.set_active(false)
	if player != null:
		target_center = player.global_position
		var horizontal_side := signf(global_position.x - target_center.x)
		if is_zero_approx(horizontal_side):
			horizontal_side = -1.0 if next_pass_from_left else 1.0
		attack_direction = Vector2(-horizontal_side, 0.0)
		next_pass_from_left = not next_pass_from_left
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.RIGHT
	update_visual_facing(attack_direction)
	play_prepare_animation()


func enter_first_pass_state() -> void:
	enemy_state = EnemyState.PASS_ONE
	state_timer = pass_duration
	attack_damage_applied = false
	play_pass_one_animation()


func enter_second_pass_state() -> void:
	enemy_state = EnemyState.PASS_TWO
	state_timer = pass_duration
	attack_direction = -attack_direction
	attack_damage_applied = false
	play_pass_two_animation()


func enter_recover_state() -> void:
	enemy_state = EnemyState.RECOVER
	state_timer = attack_recover_duration
	hitbox.set_active(false)
	stop_moving()


func is_player_in_attack_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= attack_range


func damage_player_in_attack_radius() -> void:
	if player == null:
		return
	var player_hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
	if player_hurtbox == null:
		return
	player_hurtbox.take_hit(hitbox.damage, global_position)


func play_idle_animation() -> void:
	play_animation_if_exists(&"idle")


func play_move_animation() -> void:
	if not play_animation_if_exists(&"move"):
		play_idle_animation()


func play_prepare_animation() -> void:
	if not play_animation_if_exists(&"prepare"):
		play_idle_animation()


func play_pass_one_animation() -> void:
	if not play_animation_if_exists(&"attack"):
		play_animation_if_exists(&"idle")


func play_pass_two_animation() -> void:
	if not play_animation_if_exists(&"attack"):
		play_animation_if_exists(&"idle")


func play_recover_animation() -> void:
	if not play_animation_if_exists(&"recover"):
		play_idle_animation()


func apply_hit_reaction(from_position: Vector2, damage: int) -> void:
	if enemy_state == EnemyState.PASS_ONE or enemy_state == EnemyState.PASS_TWO:
		# Damage may flash the creature, but never cancels an attack pass.
		play_invulnerability_visual()
		on_hit_received()
		return
	super.apply_hit_reaction(from_position, damage)
	play_recover_animation()


func on_died() -> void:
	hitbox.set_active(false)
	velocity = Vector2.ZERO
	set_physics_process(false)
	for _blink in 4:
		animated_sprite.visible = false
		await get_tree().create_timer(0.08).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(0.08).timeout
	queue_free()
