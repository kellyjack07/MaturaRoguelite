extends "res://scripts/base_enemy.gd"
class_name OrcArcher

const PROJECTILE_SCENE := preload("res://enemies/enemy_projectile.tscn")
enum State { IDLE, CHASE, PREPARE, ATTACK, RECOVER }
@export var skin_variant: int = 1
@export var aggro_radius := 160.0
@export var firing_range := 100.0
@export var prepare_duration := 0.18
@export var attack_duration := 0.32
@export var attack_release_delay := 0.12
@export var recovery_duration := 0.8
@export var projectile_speed := 180.0
@export var projectile_lifetime := 2.0
var state := State.IDLE
var timer := 0.0
var release_direction := Vector2.RIGHT
var released := false

func on_enemy_ready() -> void:
	receives_knockback = false
	health_component.max_health = 20
	hitbox.damage = 5
	hitbox.set_active(false)
	_build_frames()
	play_animation_if_exists(&"idle")

func update_behavior(delta: float) -> void:
	match state:
		State.IDLE:
			stop_moving(); play_animation_if_exists(&"idle")
			if player != null and global_position.distance_to(player.global_position) <= aggro_radius: state = State.CHASE
		State.CHASE:
			if player != null and global_position.distance_to(player.global_position) <= firing_range and _has_line_of_sight(): _enter_prepare()
			else: move_toward_player(); play_animation_if_exists(&"move")
		State.PREPARE:
			stop_moving(); play_animation_if_exists(&"prepare"); timer -= delta
			if timer <= 0.0: _enter_attack()
		State.ATTACK:
			stop_moving(); play_animation_if_exists(&"attack"); timer -= delta
			if not released and timer <= attack_duration - attack_release_delay:
				released = true
				_fire_arrow()
			if timer <= 0.0: state = State.RECOVER; timer = recovery_duration
		State.RECOVER:
			stop_moving(); play_animation_if_exists(&"idle"); timer -= delta
			if timer <= 0.0: state = State.CHASE

func _enter_prepare() -> void:
	state = State.PREPARE; timer = prepare_duration; released = false; stop_moving()

func _enter_attack() -> void:
	state = State.ATTACK; timer = attack_duration; released = false
	if player != null: release_direction = global_position.direction_to(player.global_position).normalized()
	if release_direction == Vector2.ZERO: release_direction = Vector2.RIGHT
	update_visual_facing(release_direction)

func _has_line_of_sight() -> bool:
	if player == null: return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func _fire_arrow() -> void:
	if not _has_line_of_sight(): return
	var arrow := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	arrow.speed = projectile_speed
	arrow.lifetime = projectile_lifetime
	arrow.setup(release_direction, hitbox.damage)

func _build_frames() -> void:
	var folder := "Orc_Archer_%02d (Green Skinned)" % skin_variant
	if skin_variant == 2: folder = "Orc_Archer_02 (Blue Skinned)"
	if skin_variant == 3: folder = "Orc_Archer_03 (Red Skinned)"
	var prefix := "Orc_Archer_%02d" % skin_variant
	var root := "res://assets/Enemies/CHARACTER MEGAPACK/%s/" % folder
	var frames := SpriteFrames.new()
	for name in [&"idle", &"move", &"prepare", &"attack"]: frames.add_animation(name)
	_add(frames, &"idle", root + prefix + "_Idle_1x1.png", 1, 74, 41, true, 3.0)
	_add(frames, &"move", root + prefix + "_Move_6x1.png", 6, 74, 41, true, 10.0)
	_add(frames, &"prepare", root + prefix + "_Prepare_11x1.png", 11, 74, 41, false, 12.0)
	_add(frames, &"attack", root + prefix + "_ATK_Full_18x1.png", 18, 74, 41, false, 12.0)
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle"

func _add(frames: SpriteFrames, name: StringName, path: String, count: int, width: int, height: int, loop: bool, speed: float) -> void:
	var texture := load(path) as Texture2D
	if texture == null: return
	frames.set_animation_loop(name, loop); frames.set_animation_speed(name, speed)
	for i in count:
		var atlas := AtlasTexture.new(); atlas.atlas = texture; atlas.region = Rect2(i * width, 0, width, height); frames.add_frame(name, atlas)

