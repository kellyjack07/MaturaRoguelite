extends "res://scripts/base_enemy.gd"
class_name Stage2Enemy

const FROG_LANDING_EFFECT := preload("res://effects/frog_landing_effect.tscn")
const FROG_LANDING_SHADOW := preload("res://effects/frog_landing_shadow.tscn")
const MUSHROOM_SPELL_PROJECTILE := preload("res://enemies/mushroom_spell_projectile.tscn")

enum Kind { FROG_MONSTER, ENT1, ENT2, ENT3, MUSHROOM, CYCLOP_ARCHER, FROG_BOSS }
enum State { IDLE, CHASE, PREPARE, ATTACK, RECOVER }
signal summon_requested(count: int)

@export var kind: Kind = Kind.FROG_MONSTER
@export var enemy_max_health: int = 20
@export var enemy_damage: int = 5
@export var aggro_radius: float = 160.0
@export var attack_range: float = 60.0
@export var prepare_fallback: float = 0.4
@export var attack_fallback: float = 0.8
@export var recovery_duration: float = 1.0
@export_range(0.0, 1.0, 0.01) var action_point: float = 0.0
@export var projectile_speed: float = 140.0
@export var projectile_lifetime: float = 3.0
@export var jump_distance: float = 120.0
@export var landing_radius: float = 24.0
@export var burn_duration: float = 3.0
@export var summon_interval: float = 10.0
@export var summon_count: int = 2

var state := State.IDLE
var state_timer := 0.0
var action_duration := 0.8
var mushroom_attack_loop_duration := 0.0
var action_direction := Vector2.RIGHT
var action_target := Vector2.ZERO
var action_applied := false
var airborne := false
var burn_contact_cooldown := 0.0
var summon_timer := 10.0
var ent3_pass := 0
var ent1_burning_left := 0.0
var landing_shadow: Node2D = null

func on_enemy_ready() -> void:
	receives_knockback = false
	health_component.max_health = enemy_max_health
	health_component.current_health = enemy_max_health
	hitbox.damage = enemy_damage
	hitbox.set_active(false)
	if kind == Kind.ENT1:
		prepare_fallback = maxf(prepare_fallback, 0.4)
		recovery_duration = maxf(recovery_duration, 2.0)
	play_slot(&"idle")

func update_behavior(delta: float) -> void:
	if kind == Kind.ENT1 and ent1_burning_left > 0.0:
		ent1_burning_left = maxf(ent1_burning_left - delta, 0.0)
		if ent1_burning_left <= 0.0:
			state = State.RECOVER
			state_timer = recovery_duration
			return
		move_toward_player()
		play_slot(&"burning")
		if player != null and global_position.distance_to(player.global_position) <= attack_range:
			_apply_burn()
		return
	if kind == Kind.FROG_BOSS:
		summon_timer -= delta
		if summon_timer <= 0.0 and state != State.ATTACK:
			summon_timer = summon_interval
			summon_requested.emit(summon_count)
	if burn_contact_cooldown > 0.0:
		burn_contact_cooldown -= delta
	match state:
		State.IDLE:
			stop_moving()
			play_slot(&"idle")
			if player != null and global_position.distance_to(player.global_position) <= aggro_radius:
				state = State.CHASE
		State.CHASE:
			if player == null:
				return
			if kind == Kind.ENT1 and global_position.distance_to(player.global_position) <= attack_range:
				_enter_prepare(&"ignite")
			elif kind in [Kind.MUSHROOM, Kind.CYCLOP_ARCHER] and global_position.distance_to(player.global_position) <= attack_range and _has_line_of_sight():
				_enter_prepare(&"prepare")
			elif kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS] and global_position.distance_to(player.global_position) <= attack_range:
				_enter_prepare(&"prepare")
			elif kind in [Kind.ENT2, Kind.ENT3] and global_position.distance_to(player.global_position) <= attack_range:
				_enter_prepare(&"prepare")
			else:
				move_toward_player()
				play_slot(&"jump" if kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS] else &"move")
		State.PREPARE:
			stop_moving()
			play_slot(&"ignite" if kind == Kind.ENT1 else &"prepare")
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_attack()
		State.ATTACK:
			_update_attack(delta)
		State.RECOVER:
			stop_moving()
			play_slot(&"recover")
			state_timer -= delta
			if state_timer <= 0.0:
				if airborne:
					_set_airborne(false)
				state = State.CHASE

func _enter_prepare(animation_name: StringName) -> void:
	state = State.PREPARE
	state_timer = get_authored_animation_duration(animation_name, prepare_fallback)
	stop_moving()

func _enter_attack() -> void:
	state = State.ATTACK
	var animation_name: StringName = &"jump" if kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS] else &"attack"
	if kind == Kind.MUSHROOM:
		# Mushroom has a two-part cast: wand swing, then spell release.
		mushroom_attack_loop_duration = get_authored_animation_duration(&"attack_loop", attack_fallback)
		var spell_duration := get_authored_animation_duration(&"attack_fire", attack_fallback)
		action_duration = mushroom_attack_loop_duration + spell_duration
	else:
		action_duration = get_authored_animation_duration(animation_name, attack_fallback)
	state_timer = action_duration
	action_applied = false
	if player != null:
		action_target = player.global_position
		action_direction = global_position.direction_to(action_target).normalized()
	if action_direction == Vector2.ZERO:
		action_direction = Vector2.RIGHT
	if kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS]:
		_set_airborne(true)
		_spawn_landing_shadow(action_target)

func _update_attack(delta: float) -> void:
	var elapsed := action_duration - state_timer
	if kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS]:
		play_slot(&"jump")
		global_position = global_position.lerp(action_target, clampf(elapsed / maxf(action_duration, 0.01), 0.0, 1.0))
		if not action_applied and elapsed >= action_duration * maxf(action_point, 0.0):
			action_applied = true
			_damage_player_once()
	elif kind == Kind.MUSHROOM:
		if elapsed < mushroom_attack_loop_duration:
			play_slot(&"attack_loop")
		elif not action_applied:
			# Start the casting animation and release the projectile together.
			action_applied = true
			play_slot(&"attack_fire")
			_fire_projectile()
		else:
			play_slot(&"attack_fire")
	else:
		play_slot(&"attack")
		if kind in [Kind.ENT2, Kind.ENT3]:
			velocity = action_direction * move_speed * 3.0
		elif not action_applied and elapsed >= action_duration * maxf(action_point, 0.0):
			action_applied = true
			if kind == Kind.ENT1:
				_apply_burn()
			elif kind == Kind.CYCLOP_ARCHER:
				_fire_projectile()
	state_timer -= delta
	if state_timer <= 0.0:
		if kind == Kind.ENT1:
			ent1_burning_left = 5.0
			state = State.CHASE
			return
		if kind == Kind.ENT3 and ent3_pass == 0:
			ent3_pass = 1
			state = State.PREPARE
			state_timer = 0.4
			return
		if kind == Kind.ENT3:
			ent3_pass = 0
		if kind in [Kind.ENT2, Kind.ENT3]:
			velocity = Vector2.ZERO
		state = State.RECOVER
		state_timer = recovery_duration
		if kind in [Kind.FROG_MONSTER, Kind.FROG_BOSS]:
			_spawn_landing_effect()
			_set_airborne(false)
			_clear_landing_shadow()

func _damage_player_once() -> void:
	if player == null or global_position.distance_to(player.global_position) > landing_radius:
		return
	var player_hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
	if player_hurtbox != null:
		player_hurtbox.take_hit(hitbox.damage, global_position)

func _apply_burn() -> void:
	if player != null and player.has_method("apply_burn") and burn_contact_cooldown <= 0.0:
		player.apply_burn(burn_duration)
		burn_contact_cooldown = burn_duration

func _fire_projectile() -> void:
	if player == null or not _has_line_of_sight():
		return
	var projectile: EnemyProjectile
	if kind == Kind.MUSHROOM:
		projectile = MUSHROOM_SPELL_PROJECTILE.instantiate() as EnemyProjectile
	else:
		projectile = preload("res://enemies/enemy_projectile.tscn").instantiate() as EnemyProjectile
	if projectile == null:
		return
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.speed = projectile_speed
	projectile.lifetime = projectile_lifetime
	projectile.projectile_radius = 8.0 if kind == Kind.MUSHROOM else 2.0
	projectile.setup(global_position.direction_to(player.global_position), hitbox.damage)

func _has_line_of_sight() -> bool:
	if player == null or get_world_2d() == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _set_airborne(value: bool) -> void:
	airborne = value
	# Frog jumps remain damageable. The attack state still prevents hit
	# reactions from interrupting the jump animation.
	hurtbox.set_enabled(true)
	animated_sprite.position.y = -12.0 if value else 0.0

func _spawn_landing_effect() -> void:
	var effect := FROG_LANDING_EFFECT.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position


func _spawn_landing_shadow(landing_position: Vector2) -> void:
	_clear_landing_shadow()
	landing_shadow = FROG_LANDING_SHADOW.instantiate() as Node2D
	get_parent().add_child(landing_shadow)
	landing_shadow.global_position = landing_position


func _clear_landing_shadow() -> void:
	if landing_shadow != null and is_instance_valid(landing_shadow):
		landing_shadow.queue_free()
	landing_shadow = null

func play_slot(animation_name: StringName) -> void:
	if not play_animation_if_exists(animation_name):
		play_animation_if_exists(&"idle")

func apply_hit_reaction(from_position: Vector2, damage: int) -> void:
	if airborne or state == State.ATTACK:
		play_invulnerability_visual()
		return
	super.apply_hit_reaction(from_position, damage)

func on_died() -> void:
	_set_airborne(false)
	_clear_landing_shadow()
	hitbox.set_active(false)
	set_physics_process(false)
	queue_free()
