extends CharacterBody2D

const WeaponRegistryScript := preload("res://scripts/weapons/weapon_registry.gd")

enum MovementState {
	STATIONARY,
	WALKING,
	DASHING,
}

enum ActionState {
	NORMAL,
	BASIC_ATTACK,
	SPECIAL_ATTACK,
	HURT,
	DEAD,
}

@export var move_speed: float = 120.0
@export var dash_speed: float = 260.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var base_attack_damage: int = 5
@export var stationary_multiplier: float = 1.0
@export var walking_multiplier: float = 1.25
@export var dashing_multiplier: float = 1.75
@export var hit_flash_duration: float = 0.25
@export var hit_flash_color: Color = Color(1.2, 0.9, 0.9, 1.0)
@export var invulnerability_blink_count: int = 2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var attack_area: HitboxComponent = $AttackArea
@onready var hurtbox: HurtboxComponent = $Hurtbox

var input_direction: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.DOWN
var attack_direction: Vector2 = Vector2.DOWN
var movement_state: MovementState = MovementState.STATIONARY
var action_state: ActionState = ActionState.NORMAL
var is_attacking: bool = false
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var last_damage_dealt: int = 0
var sampled_movement_multiplier: float = 1.0

var equipped_weapon: Resource
var equipped_weapon_id: String = "sword"
var effective_basic_damage: int = 5
var effective_special_damage: int = 8
var current_attack: Resource
var action_elapsed: float = 0.0
var current_pulse_index: int = 0
var hurt_time_left: float = 0.0
var special_cooldowns: Dictionary = {}
var visual_generation: int = 0
var death_emitted: bool = false
var default_modulate: Color = Color.WHITE

signal died
signal death_started
signal debug_state_changed
signal weapon_equipped(weapon_id: String)


func _ready() -> void:
	health_component.died.connect(on_died)
	default_modulate = animated_sprite.modulate
	equip_weapon(equipped_weapon_id)
	play_idle_animation()


func _physics_process(delta: float) -> void:
	update_cooldowns(delta)
	get_input_direction()
	update_facing_direction()

	if action_state != ActionState.DEAD and action_state != ActionState.HURT:
		handle_dash_input()
		update_movement_state()
		handle_attack_input()

	update_action(delta)

	if action_state == ActionState.DEAD or action_state == ActionState.HURT:
		velocity = Vector2.ZERO
	elif is_dashing:
		update_dash(delta)
	else:
		move_player()

	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")


func handle_attack_input() -> void:
	if is_attacking:
		return
	if Input.is_action_just_pressed("special_attack") and can_use_special():
		start_special_attack()
	elif Input.is_action_just_pressed("attack"):
		start_attack()


func get_damage_multiplier() -> float:
	if movement_state == MovementState.DASHING:
		return dashing_multiplier
	if movement_state == MovementState.WALKING:
		return walking_multiplier
	return stationary_multiplier


func get_attack_damage() -> int:
	return last_damage_dealt


func start_attack() -> void:
	start_configured_attack(false)


func start_special_attack() -> void:
	start_configured_attack(true)


func start_configured_attack(is_special: bool) -> void:
	if equipped_weapon == null or action_state != ActionState.NORMAL:
		return

	current_attack = equipped_weapon.special_attack if is_special else equipped_weapon.basic_attack
	if current_attack == null:
		return

	action_state = ActionState.SPECIAL_ATTACK if is_special else ActionState.BASIC_ATTACK
	is_attacking = true
	action_elapsed = 0.0
	current_pulse_index = 0
	update_attack_direction()
	sampled_movement_multiplier = get_damage_multiplier()
	var base_damage := effective_special_damage if is_special else effective_basic_damage
	last_damage_dealt = maxi(roundi(float(base_damage) * sampled_movement_multiplier), 1)

	attack_area.start_attack(current_attack.max_targets)
	attack_area.set_damage(last_damage_dealt)
	apply_attack_shape(current_attack)
	update_attack_area_direction()
	play_action_animation("special" if is_special else "basic")

	if is_special:
		special_cooldowns[equipped_weapon_id] = current_attack.cooldown
	debug_state_changed.emit()


func update_action(delta: float) -> void:
	if action_state == ActionState.HURT:
		hurt_time_left -= delta
		if hurt_time_left <= 0.0:
			action_state = ActionState.NORMAL
			update_animation()
		return

	if not is_attacking or current_attack == null:
		return

	# A hit can synchronously clear a room and cancel this action through UI/game-state signals.
	# Keep the resource reference for this frame and stop cleanly if that happens mid-pulse.
	var active_attack: Resource = current_attack
	action_elapsed += delta
	while current_pulse_index < active_attack.pulse_times.size():
		var pulse_time: float = active_attack.pulse_times[current_pulse_index]
		if action_elapsed < pulse_time:
			break
		attack_area.begin_pulse(active_attack.allow_repeat_hits_between_pulses)
		attack_area.set_hitbox_active(true)
		attack_area.deal_damage()
		if not is_attacking or current_attack != active_attack:
			return
		current_pulse_index += 1

	if action_elapsed >= active_attack.get_action_duration():
		finish_current_action()


func finish_current_action() -> void:
	attack_area.cancel_attack()
	current_attack = null
	is_attacking = false
	action_elapsed = 0.0
	current_pulse_index = 0
	if action_state == ActionState.BASIC_ATTACK or action_state == ActionState.SPECIAL_ATTACK:
		action_state = ActionState.NORMAL
	update_animation()
	debug_state_changed.emit()


func cancel_transient_actions(cancel_dash: bool = true) -> void:
	visual_generation += 1
	attack_area.cancel_attack()
	current_attack = null
	is_attacking = false
	action_elapsed = 0.0
	current_pulse_index = 0
	if action_state != ActionState.DEAD:
		action_state = ActionState.NORMAL
	if cancel_dash:
		end_dash()
	animated_sprite.modulate = default_modulate
	animated_sprite.visible = true


func cancel_actions_for_modal() -> void:
	cancel_transient_actions(true)
	velocity = Vector2.ZERO
	update_animation()


func apply_attack_shape(attack_definition: Resource) -> void:
	var new_shape: Shape2D
	match int(attack_definition.shape_kind):
		2:
			var circle := CircleShape2D.new()
			circle.radius = attack_definition.shape_radius
			new_shape = circle
		1:
			var capsule := CapsuleShape2D.new()
			capsule.radius = attack_definition.shape_radius
			capsule.height = maxf(attack_definition.shape_size.x, capsule.radius * 2.0)
			new_shape = capsule
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = attack_definition.shape_size
			new_shape = rectangle
	attack_area.collision_shape.shape = new_shape


func update_attack_area_direction() -> void:
	if current_attack == null:
		return
	attack_area.position = attack_direction.normalized() * current_attack.reach
	if int(current_attack.shape_kind) == 2:
		attack_area.rotation = 0.0
	elif int(current_attack.shape_kind) == 1:
		attack_area.rotation = attack_direction.angle() + PI * 0.5
	else:
		attack_area.rotation = attack_direction.angle()


func update_attack_direction() -> void:
	if is_dashing and dash_direction != Vector2.ZERO:
		attack_direction = dash_direction.normalized()
	elif input_direction != Vector2.ZERO:
		attack_direction = input_direction.normalized()
	else:
		attack_direction = move_direction.normalized()


func move_player() -> void:
	velocity = input_direction * move_speed
	move_and_slide()


func update_facing_direction() -> void:
	if input_direction != Vector2.ZERO:
		move_direction = input_direction.normalized()


func update_movement_state() -> void:
	var previous_state := movement_state
	if is_dashing:
		movement_state = MovementState.DASHING
	elif input_direction == Vector2.ZERO:
		movement_state = MovementState.STATIONARY
	else:
		movement_state = MovementState.WALKING
	if movement_state != previous_state:
		debug_state_changed.emit()


func update_cooldowns(delta: float) -> void:
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)

	for weapon_key in special_cooldowns.keys():
		var previous_remaining := float(special_cooldowns[weapon_key])
		var remaining := maxf(previous_remaining - delta, 0.0)
		special_cooldowns[weapon_key] = remaining
		if str(weapon_key) == equipped_weapon_id and previous_remaining > 0.0 and remaining <= 0.0:
			debug_state_changed.emit()


func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash():
		start_dash()


func can_dash() -> bool:
	return not is_dashing and dash_cooldown_left <= 0.0


func start_dash() -> void:
	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown
	dash_direction = input_direction.normalized() if input_direction != Vector2.ZERO else move_direction.normalized()


func update_dash(delta: float) -> void:
	dash_time_left -= delta
	velocity = dash_direction * dash_speed
	move_and_slide()
	if dash_time_left <= 0.0:
		end_dash()


func end_dash() -> void:
	is_dashing = false
	dash_time_left = 0.0
	velocity = Vector2.ZERO
	update_movement_state()


func update_animation() -> void:
	if action_state != ActionState.NORMAL:
		return
	if is_dashing:
		play_directional_animation("dash", dash_direction, false, get_dash_animation_speed_scale())
	elif input_direction == Vector2.ZERO:
		play_idle_animation()
	else:
		play_walk_animation()


func get_facing_suffix(direction: Vector2 = move_direction) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "side"
	if direction.y > 0.0:
		return "down"
	return "up"


func get_mapped_animation(action_name: String, direction: Vector2 = move_direction) -> StringName:
	if equipped_weapon == null:
		return StringName()
	return equipped_weapon.get_animation(action_name, get_facing_suffix(direction))


func play_directional_animation(
	action_name: String,
	direction: Vector2 = move_direction,
	restart: bool = false,
	custom_speed: float = 1.0
) -> void:
	var animation_name := get_mapped_animation(action_name, direction)
	play_animation(animation_name, direction, restart, custom_speed)


func play_animation(
	animation_name: StringName,
	direction: Vector2,
	restart: bool = false,
	custom_speed: float = 1.0
) -> void:
	if animation_name.is_empty() or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	var is_side := get_facing_suffix(direction) == "side"
	animated_sprite.flip_h = is_side and direction.x > 0.0
	if restart or animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name, custom_speed)


func play_idle_animation() -> void:
	play_directional_animation("idle")


func play_walk_animation() -> void:
	play_directional_animation("walk")


func play_action_animation(action_name: String) -> void:
	var animation_name := get_mapped_animation(action_name, attack_direction)
	play_animation(animation_name, attack_direction, true)


func get_dash_animation_speed_scale() -> float:
	var animation_name := get_mapped_animation("dash", dash_direction)
	if animation_name.is_empty() or dash_duration <= 0.0:
		return 1.0
	var frame_count := animated_sprite.sprite_frames.get_frame_count(animation_name)
	var fps := animated_sprite.sprite_frames.get_animation_speed(animation_name)
	if frame_count <= 0 or fps <= 0.0:
		return 1.0
	return (float(frame_count) / fps) / dash_duration


func equip_weapon(requested_weapon_id: String) -> String:
	var normalized_id: String = WeaponRegistryScript.normalize_weapon_id(requested_weapon_id)
	cancel_transient_actions(true)
	equipped_weapon = WeaponRegistryScript.get_definition(normalized_id)
	equipped_weapon_id = normalized_id
	effective_basic_damage = equipped_weapon.basic_attack.base_damage
	effective_special_damage = equipped_weapon.special_attack.base_damage
	play_idle_animation()
	weapon_equipped.emit(equipped_weapon_id)
	debug_state_changed.emit()
	return equipped_weapon_id


func set_effective_attack_damage(basic_damage: int, special_damage: int) -> void:
	effective_basic_damage = maxi(basic_damage, 1)
	effective_special_damage = maxi(special_damage, 1)
	base_attack_damage = effective_basic_damage
	debug_state_changed.emit()


func can_use_special() -> bool:
	return action_state == ActionState.NORMAL and get_special_cooldown_left() <= 0.0


func get_special_cooldown_left() -> float:
	return float(special_cooldowns.get(equipped_weapon_id, 0.0))


func get_special_cooldown_duration() -> float:
	if equipped_weapon == null or equipped_weapon.special_attack == null:
		return 0.0
	return equipped_weapon.special_attack.cooldown


func get_cooldown_snapshot() -> Dictionary:
	return special_cooldowns.duplicate(true)


func set_cooldown_snapshot(snapshot: Dictionary) -> void:
	special_cooldowns.clear()
	for weapon_key in snapshot.keys():
		var normalized_id: String = WeaponRegistryScript.normalize_weapon_id(str(weapon_key))
		special_cooldowns[normalized_id] = maxf(float(snapshot[weapon_key]), 0.0)


func reset_for_run(clear_cooldowns: bool = true) -> void:
	set_physics_process(true)
	death_emitted = false
	visual_generation += 1
	input_direction = Vector2.ZERO
	move_direction = Vector2.DOWN
	attack_direction = Vector2.DOWN
	dash_direction = Vector2.ZERO
	movement_state = MovementState.STATIONARY
	action_state = ActionState.NORMAL
	last_damage_dealt = 0
	sampled_movement_multiplier = 1.0
	if clear_cooldowns:
		special_cooldowns.clear()
	dash_cooldown_left = 0.0
	hurt_time_left = 0.0
	hurtbox.reset_state()
	cancel_transient_actions(true)
	animated_sprite.visible = true
	animated_sprite.modulate = default_modulate
	show()
	play_idle_animation()


func apply_hit_reaction(_from_position: Vector2, _damage: int) -> void:
	if action_state == ActionState.DEAD or health_component.is_dead():
		return
	cancel_transient_actions(true)
	action_state = ActionState.HURT
	hurt_time_left = 0.4
	var hurt_animation: StringName = equipped_weapon.get_animation("hurt")
	play_animation(hurt_animation, move_direction, true)
	play_invulnerability_blink()
	debug_state_changed.emit()


func play_invulnerability_blink() -> void:
	visual_generation += 1
	var generation := visual_generation
	var total_blinks := maxi(invulnerability_blink_count, 1)
	var blink_interval := maxf(hurtbox.invulnerability_duration / float(total_blinks * 2), 0.03)
	var dimmed := default_modulate
	dimmed.a = 0.45

	for _blink in total_blinks:
		if generation != visual_generation or action_state == ActionState.DEAD:
			return
		animated_sprite.modulate = dimmed
		await get_tree().create_timer(blink_interval).timeout
		if generation != visual_generation or action_state == ActionState.DEAD:
			return
		animated_sprite.modulate = default_modulate
		await get_tree().create_timer(blink_interval).timeout

	if generation == visual_generation:
		animated_sprite.modulate = default_modulate


func on_died() -> void:
	if action_state == ActionState.DEAD:
		return
	death_started.emit()
	visual_generation += 1
	cancel_transient_actions(true)
	action_state = ActionState.DEAD
	death_emitted = false
	set_physics_process(false)
	attack_area.cancel_attack()
	hurtbox.set_enabled(false)
	animated_sprite.visible = true
	animated_sprite.modulate = default_modulate
	var death_animation: StringName = equipped_weapon.get_animation("death")
	if death_animation.is_empty() or not animated_sprite.sprite_frames.has_animation(death_animation):
		call_deferred("finish_death")
		return
	play_animation(death_animation, move_direction, true)


func finish_death() -> void:
	if death_emitted:
		return
	death_emitted = true
	animated_sprite.visible = false
	died.emit()


func _on_animated_sprite_2d_animation_finished() -> void:
	if action_state != ActionState.DEAD:
		return
	var death_animation: StringName = equipped_weapon.get_animation("death")
	if animated_sprite.animation == death_animation:
		finish_death()
