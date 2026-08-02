extends CharacterBody2D

@export var move_speed: float = 120.0
@export var dash_speed: float = 260.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

@export var base_attack_damage: int = 8
@export var stationary_multiplier: float = 1.0
@export var walking_multiplier: float = 1.25
@export var dashing_multiplier: float = 1.75

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var attack_area: HitboxComponent = $AttackArea

var input_direction: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.DOWN
var is_attacking: bool = false
var movement_state: String = "stationary"
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var last_damage_dealt: int = 0


signal died

#start
func _ready() -> void:
	health_component.died.connect(on_died)
	print(is_in_group("player"))
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
	if movement_state == "dashing":
		return dashing_multiplier
	elif movement_state == "walking":
		return walking_multiplier
	else:
		return stationary_multiplier

#damage
func get_attack_damage() -> int:
	var damage: int = round(base_attack_damage * get_damage_multiplier())
	last_damage_dealt = damage
	return damage

#attack start
func start_attack() -> void:
	is_attacking = true
	update_attack_area_direction()
	attack_area.set_damage(get_attack_damage())
	play_attack_animation()
	attack_area.deal_damage()


#attack area
func update_attack_area_direction() -> void:
	attack_area.position = move_direction.normalized() * 12.0


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
	if is_dashing:
		movement_state = "dashing"
	elif input_direction == Vector2.ZERO:
		movement_state = "stationary"
	else:
		movement_state = "walking"


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


func play_idle_animation() -> void:
	if abs(move_direction.x) >= abs(move_direction.y):
		animated_sprite.play("idle_side")
		animated_sprite.flip_h = move_direction.x > 0
	elif move_direction.y > 0:
		animated_sprite.play("idle_down")
		animated_sprite.flip_h = false
	else:
		animated_sprite.play("idle_up")
		animated_sprite.flip_h = false


func play_walk_animation() -> void:
	if abs(move_direction.x) >= abs(move_direction.y):
		animated_sprite.play("walk_side")
		animated_sprite.flip_h = move_direction.x > 0
	elif move_direction.y > 0:
		animated_sprite.play("walk_down")
		animated_sprite.flip_h = false
	else:
		animated_sprite.play("walk_up")
		animated_sprite.flip_h = false


#attack animation
func play_attack_animation() -> void:
	if abs(move_direction.x) >= abs(move_direction.y):
		animated_sprite.play("attack_side")
		animated_sprite.flip_h = move_direction.x > 0
	elif move_direction.y > 0:
		animated_sprite.play("attack_down")
		animated_sprite.flip_h = false
	else:
		animated_sprite.play("attack_up")
		animated_sprite.flip_h = false


#attack end
func _on_animated_sprite_2d_animation_finished() -> void:
	if not animated_sprite.animation.begins_with("attack"):
		return
	
	is_attacking = false
	
	if input_direction == Vector2.ZERO:
		play_idle_animation()
	else:
		play_walk_animation()


#death
func on_died() -> void:
	set_physics_process(false)
	attack_area.monitoring = false
	$Hurtbox.monitoring = false
	hide()
	died.emit()
