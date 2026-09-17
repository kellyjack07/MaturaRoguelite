extends CharacterBody2D
class_name BaseEnemy

const HEALTH_BAR_SCENE := preload("res://ui/enemy_health_bar.tscn")

@export var move_speed: float = 50.0
@export var stop_distance: float = 14.0
@export var hit_knockback_speed: float = 120.0
@export var hit_stun_duration: float = 0.3
@export var receives_knockback: bool = true
@export var invulnerability_blink_alpha: float = 0.35
@export var invulnerability_blink_count: int = 3
@export var health_bar_use_style_offset: bool = true
@export var health_bar_offset: Vector2 = Vector2.ZERO
@export var health_bar_width: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

var player: Node2D = null
var hit_stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var default_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var invulnerability_visual_active: bool = false
var health_bar: Control
var health_presentation_configured := false


func _ready() -> void:
	health_component.died.connect(on_died)
	default_modulate = animated_sprite.modulate
	on_enemy_ready()
	call_deferred("_configure_default_health_presentation")


func configure_health_presentation(show_overhead_bar: bool = true) -> void:
	if health_presentation_configured:
		return
	health_presentation_configured = true
	if not show_overhead_bar or health_component == null:
		return
	health_bar = HEALTH_BAR_SCENE.instantiate()
	add_child(health_bar)
	var offset_override := Vector2.INF if health_bar_use_style_offset else health_bar_offset
	health_bar.setup(health_component, offset_override, health_bar_width)


func _configure_default_health_presentation() -> void:
	if health_presentation_configured:
		return
	configure_health_presentation(not bool(get_meta("designated_boss", false)))


func _physics_process(delta: float) -> void:
	# During room changes/death cleanup an enemy can receive one final physics
	# tick after its body has left the active physics space. Do not call
	# move_and_slide() without a valid world, or Godot reports body->get_space()
	# as null.
	if not is_inside_tree() or get_world_2d() == null:
		return

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_speed * delta * 6.0)
		return

	if not ensure_player_reference():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	update_behavior(delta)
	if not is_inside_tree() or get_world_2d() == null:
		return
	move_and_slide()


func ensure_player_reference() -> bool:
	if player != null and is_instance_valid(player):
		return true

	player = get_tree().get_first_node_in_group("player") as Node2D
	return player != null and is_instance_valid(player)


func update_behavior(_delta: float) -> void:
	move_toward_player()


func on_enemy_ready() -> void:
	pass


func move_toward_player() -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	if distance_to_player <= stop_distance:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	update_visual_facing(direction)


func move_toward_position(target_position: Vector2, speed: float = move_speed, min_distance: float = stop_distance) -> void:
	var distance_to_target: float = global_position.distance_to(target_position)
	if distance_to_target <= min_distance:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = global_position.direction_to(target_position)
	velocity = direction * speed
	update_visual_facing(direction)


func stop_moving() -> void:
	velocity = Vector2.ZERO


func update_visual_facing(direction: Vector2) -> void:
	if direction.x == 0.0:
		return

	animated_sprite.flip_h = direction.x < 0.0


func has_animation(animation_name: StringName) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)


func get_authored_animation_duration(animation_name: StringName, fallback: float) -> float:
	if not has_animation(animation_name):
		return maxf(fallback, 0.01)
	var frames := animated_sprite.sprite_frames
	var frame_count := frames.get_frame_count(animation_name)
	var speed := frames.get_animation_speed(animation_name)
	if frame_count <= 0 or speed <= 0.0:
		return maxf(fallback, 0.01)
	var duration := 0.0
	for frame_index in frame_count:
		duration += frames.get_frame_duration(animation_name, frame_index)
	return maxf(duration / speed, 0.01)


func play_animation_if_exists(animation_name: StringName) -> bool:
	if not has_animation(animation_name):
		return false

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	# State update methods run every physics tick. Do not restart a completed
	# authored clip here; state transitions select a different animation and
	# start it once. This preserves editor loop settings and avoids visible
	# per-tick animation resets.
	return true


func apply_hit_reaction(from_position: Vector2, damage: int) -> void:
	if not receives_knockback:
		play_invulnerability_visual()
		on_hit_received()
		return
	var knockback_direction: Vector2 = from_position.direction_to(global_position).normalized()
	knockback_velocity = knockback_direction * hit_knockback_speed * (float(damage) / 8.0)
	hit_stun_timer = hit_stun_duration
	play_invulnerability_visual()
	on_hit_received()


func on_hit_received() -> void:
	pass


func play_invulnerability_visual() -> void:
	if invulnerability_visual_active:
		return

	invulnerability_visual_active = true

	var total_blinks: int = max(invulnerability_blink_count, 1)
	var blink_interval: float = max(hurtbox.invulnerability_duration / float(total_blinks * 2), 0.03)
	var blink_modulate := default_modulate
	blink_modulate.a = invulnerability_blink_alpha

	for _blink in total_blinks:
		animated_sprite.modulate = blink_modulate
		await get_tree().create_timer(blink_interval).timeout
		animated_sprite.modulate = default_modulate
		await get_tree().create_timer(blink_interval).timeout

	animated_sprite.modulate = default_modulate
	invulnerability_visual_active = false


func on_died() -> void:
	queue_free()
