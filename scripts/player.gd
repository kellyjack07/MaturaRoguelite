extends CharacterBody2D

enum MovementState {
	STATIONARY,
	WALKING,
	DASHING,
}

@export var move_speed: float = 120.0
@export var dash_speed: float = 260.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

@export var base_attack_damage: int = 50
@export var stationary_multiplier: float = 1.0
@export var walking_multiplier: float = 1.25
@export var dashing_multiplier: float = 1.75
@export var attack_hit_delay: float = 0.08

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var attack_area: HitboxComponent = $AttackArea
@onready var hurtbox: HurtboxComponent = $Hurtbox

@export var hit_flash_duration: float = 0.25
@export var hit_flash_color: Color = Color(1.2, 0.9, 0.9, 1.0)
@export var invulnerability_blink_count: int = 2
var hit_flash_active: bool = false
var invulnerability_blink_active: bool = false
var default_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var input_direction: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.DOWN
var is_attacking: bool = false
var movement_state: MovementState = MovementState.STATIONARY
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var last_damage_dealt: int = 0
var attack_direction: Vector2 = Vector2.DOWN

signal died
signal debug_state_changed

#start
func _ready() -> void:
	health_component.died.connect(on_died)
	default_modulate = animated_sprite.modulate
	play_idle_animation()


#updates
func _physics_process(_delta: float) -> void:
	update_dash_cooldown(_delta)
	handle_dash_input()
	handle_attack_input()
	get_input_direction()
	update_facing_direction()
	update_movement_state()

	if is_dashing:
		update_dash(_delta)
	else:
		move_player()

	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")


#attack
func handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

#multiplicator
func get_damage_multiplier() -> float:
	if movement_state == MovementState.DASHING:
		return dashing_multiplier
	elif movement_state == MovementState.WALKING:
		return walking_multiplier
	else:
		return stationary_multiplier

#damage
func get_attack_damage() -> int:
	var damage: int = round(base_attack_damage * get_damage_multiplier())
	last_damage_dealt = damage
	debug_state_changed.emit()
	return damage

#attack start
func start_attack() -> void:
	is_attacking = true
	update_attack_direction()
	attack_area.start_swing()
	update_attack_area_direction()
	play_attack_animation()
	run_attack_hit()


func run_attack_hit() -> void:
	await get_tree().create_timer(attack_hit_delay).timeout

	if not is_attacking:
		return

	attack_area.set_damage(get_attack_damage())
	attack_area.set_hitbox_active(true)
	attack_area.deal_damage()


#attack area
func update_attack_area_direction() -> void:
	attack_area.position = attack_direction.normalized() * 12.0
	attack_area.rotation = attack_direction.angle()


func update_attack_direction() -> void:
	if is_dashing and dash_direction != Vector2.ZERO:
		attack_direction = dash_direction.normalized()
	elif input_direction != Vector2.ZERO:
		attack_direction = input_direction.normalized()
	else:
		attack_direction = move_direction.normalized()


#movement
func move_player() -> void:
	velocity = input_direction * move_speed
	move_and_slide()


#direction
func update_facing_direction() -> void:
	if input_direction == Vector2.ZERO:
		return

	move_direction = input_direction.normalized()


#state
func update_movement_state() -> void:
	var previous_state: MovementState = movement_state

	if is_dashing:
		movement_state = MovementState.DASHING
	elif input_direction == Vector2.ZERO:
		movement_state = MovementState.STATIONARY
	else:
		movement_state = MovementState.WALKING

	if movement_state != previous_state:
		debug_state_changed.emit()


#dash cooldown
func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta


#dash input
func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash():
		start_dash()


#dash check
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_left <= 0.0


#dash start
func start_dash() -> void:
	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown

	if input_direction != Vector2.ZERO:
		dash_direction = input_direction.normalized()
	else:
		dash_direction = move_direction.normalized()


#dash update
func update_dash(delta: float) -> void:
	dash_time_left -= delta

	velocity = dash_direction * dash_speed
	move_and_slide()

	if dash_time_left <= 0.0:
		end_dash()


#dash end
func end_dash() -> void:
	is_dashing = false
	velocity = Vector2.ZERO


func update_animation() -> void:
	if is_attacking:
		return
	
	if input_direction == Vector2.ZERO:
		play_idle_animation()
	else:
		play_walk_animation()


func get_facing_suffix() -> String:
	if abs(move_direction.x) >= abs(move_direction.y):
		return "side"
	if move_direction.y > 0:
		return "down"
	return "up"


func play_directional_animation(animation_prefix: String) -> void:
	var facing_suffix: String = get_facing_suffix()

	animated_sprite.play(animation_prefix + "_" + facing_suffix)

	if facing_suffix == "side":
		animated_sprite.flip_h = move_direction.x > 0
	else:
		animated_sprite.flip_h = false


func play_idle_animation() -> void:
	play_directional_animation("idle")


func play_walk_animation() -> void:
	play_directional_animation("walk")


#attack animation
func play_attack_animation() -> void:
	play_directional_animation("attack")


#attack end
func _on_animated_sprite_2d_animation_finished() -> void:
	if not animated_sprite.animation.begins_with("attack"):
		return
	
	attack_area.set_hitbox_active(false)
	is_attacking = false
	
	update_animation()


#hit flash
func play_hit_flash() -> void:
	if hit_flash_active:
		return
	
	hit_flash_active = true
	animated_sprite.modulate = hit_flash_color
	
	await get_tree().create_timer(hit_flash_duration).timeout
	
	animated_sprite.modulate = default_modulate
	hit_flash_active = false

func play_invulnerability_blink() -> void:
	if invulnerability_blink_active:
		return

	invulnerability_blink_active = true

	var total_blinks: int = max(invulnerability_blink_count, 1)
	var blink_interval: float = max(hurtbox.invulnerability_duration / float(total_blinks * 2), 0.03)

	for _blink in total_blinks:
		animated_sprite.visible = false
		await get_tree().create_timer(blink_interval).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(blink_interval).timeout

	animated_sprite.visible = true
	invulnerability_blink_active = false

func apply_hit_reaction(_from_position: Vector2, _damage: int) -> void:
	play_hit_flash()
	play_invulnerability_blink()

#death
func on_died() -> void:
	set_physics_process(false)
	attack_area.set_hitbox_active(false)
	$Hurtbox.monitoring = false
	animated_sprite.visible = true
	hide()
	died.emit()
