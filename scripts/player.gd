extends CharacterBody2D

@export var move_speed: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN

#start
func _ready() -> void:
	play_idle_animation()


#updates
func _physics_process(_delta: float) -> void:
	get_input_direction()
	move_player()
	update_facing_direction()
	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")


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
