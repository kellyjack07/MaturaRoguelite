extends "res://scripts/base_enemy.gd"
class_name NewMeleeEnemy

enum State { IDLE, CHASE, PREPARE, DASH, ATTACK, RECOVER }

@export var sprite_folder: String = "Goblin_Regular_01 (Green Skinned)"
@export var sprite_prefix: String = "Goblin_Regular_01"
@export var sprite_frame_size := Vector2(38, 26)
@export var move_frame_count := 10
@export var prepare_frame_count := 5
@export var attack_frame_count := 10
@export var uses_dash: bool = true
@export var aggro_radius: float = 80.0
@export var attack_range: float = 25.0
@export var prepare_duration: float = 0.18
@export var dash_speed: float = 75.0
@export var dash_duration: float = 0.5
@export var attack_duration: float = 0.32
@export var attack_hit_delay: float = 0.12
@export var attack_recover_duration: float = 0.8
@export var attack_damage_radius: float = 20.0

var state := State.IDLE
var state_timer := 0.0
var attack_direction := Vector2.DOWN
var attack_damage_applied := false
var is_awake := false

func on_enemy_ready() -> void:
	receives_knockback = false
	hitbox.damage = 5
	health_component.max_health = 20
	hitbox.set_active(false)
	_build_sprite_frames()
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
			if not attack_damage_applied and state_timer <= attack_duration - attack_hit_delay:
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

func _sheet(path: String, frame_count: int, frame_size: Vector2) -> Array[Texture2D]:
	var texture := load(path) as Texture2D
	var result: Array[Texture2D] = []
	if texture == null:
		return result
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_size.x * index, 0), frame_size)
		result.append(atlas)
	return result

func _build_sprite_frames() -> void:
	var root := "res://assets/Enemies/CHARACTER MEGAPACK/%s/" % sprite_folder
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", _sheet(root + sprite_prefix + "_Idle_1x1.png", 1, sprite_frame_size), true, 3.0)
	_add_animation(frames, &"move", _sheet(root + sprite_prefix + "_Move_%dx1.png" % move_frame_count, move_frame_count, sprite_frame_size), true, 12.0)
	_add_animation(frames, &"prepare", _sheet(root + sprite_prefix + "_Prepare_%dx1.png" % prepare_frame_count, prepare_frame_count, sprite_frame_size), false, 12.0)
	_add_animation(frames, &"attack", _sheet(root + sprite_prefix + "_ATK_Full_%dx1.png" % attack_frame_count, attack_frame_count, sprite_frame_size), false, 12.0)
	if uses_dash:
		_add_animation(frames, &"dash", _sheet(root + sprite_prefix + "_Dash_1x1.png", 1, sprite_frame_size), false, 8.0)
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle"

func _add_animation(frames: SpriteFrames, name: StringName, textures: Array[Texture2D], loop: bool, speed: float) -> void:
	if textures.is_empty():
		return
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, speed)
	for texture in textures:
		frames.add_frame(name, texture)

func play_idle_animation() -> void: play_animation_if_exists(&"idle")
func play_move_animation() -> void: play_animation_if_exists(&"move")
func play_prepare_animation() -> void: play_animation_if_exists(&"prepare")
func play_dash_animation() -> void: play_animation_if_exists(&"dash")
func play_attack_animation() -> void: play_animation_if_exists(&"attack")
