extends CharacterBody2D

@export var move_speed: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var attack_area: HitboxComponent = $AttackArea

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var is_attacking: bool = false

signal died

#start
func _ready() -> void:
	health_component.died.connect(on_died)
	print(is_in_group("player"))
	play_idle_animation()


#updates
func _physics_process(_delta: float) -> void:
	handle_attack_input()

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	get_input_direction()
	move_player()
	update_facing_direction()
	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")


#attack
func handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()


#attack start
func start_attack() -> void:
	is_attacking = true
	update_attack_area_direction()
	play_attack_animation()
	attack_area.deal_damage()


#attack area
func update_attack_area_direction() -> void:
	if facing_direction == Vector2.DOWN:
		attack_area.position = Vector2(0, 12)
	elif facing_direction == Vector2.UP:
		attack_area.position = Vector2(0, -12)
	elif facing_direction == Vector2.RIGHT:
		attack_area.position = Vector2(12, 0)
	else:
		attack_area.position = Vector2(-12, 0)


#movement
func move_player() -> void:
	velocity = input_direction * move_speed
	move_and_slide()


#direction
func update_facing_direction() -> void:
	if input_direction == Vector2.ZERO:
		return

	if abs(input_direction.x) > abs(input_direction.y):
		facing_direction = Vector2.RIGHT if input_direction.x > 0 else Vector2.LEFT
	else:
		facing_direction = Vector2.DOWN if input_direction.y > 0 else Vector2.UP


func update_animation() -> void:
	if input_direction == Vector2.ZERO:
		play_idle_animation()
	else:
		play_walk_animation()


func play_idle_animation() -> void:
	if facing_direction == Vector2.DOWN:
		animated_sprite.play("idle_down")
	elif facing_direction == Vector2.UP:
		animated_sprite.play("idle_up")
	else:
		animated_sprite.play("idle_side")
		animated_sprite.flip_h = facing_direction == Vector2.RIGHT


func play_walk_animation() -> void:
	if facing_direction == Vector2.DOWN:
		animated_sprite.play("walk_down")
		animated_sprite.flip_h = false
	elif facing_direction == Vector2.UP:
		animated_sprite.play("walk_up")
		animated_sprite.flip_h = false
	else:
		animated_sprite.play("walk_side")
		animated_sprite.flip_h = facing_direction == Vector2.RIGHT


#attack animation
func play_attack_animation() -> void:
	if facing_direction == Vector2.DOWN:
		animated_sprite.play("attack_down")
		animated_sprite.flip_h = false
	elif facing_direction == Vector2.UP:
		animated_sprite.play("attack_up")
		animated_sprite.flip_h = false
	else:
		animated_sprite.play("attack_side")
		animated_sprite.flip_h = facing_direction == Vector2.RIGHT


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
