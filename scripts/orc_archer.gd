extends "res://scripts/base_enemy.gd"
class_name OrcArcher

const PROJECTILE_SCENE := preload("res://enemies/enemy_projectile.tscn")
enum State { IDLE, CHASE, PREPARE, ATTACK, RECOVER }
@export var skin_variant: int = 1
@export var difficulty_weight: float = 1.0
@export var enemy_max_health: int = 20
@export var enemy_damage: int = 5
@export var aggro_radius := 160.0
@export var firing_range := 100.0
@export var prepare_duration := 0.3
@export var attack_duration := 0.4
@export_range(0.0, 1.0, 0.01) var attack_release_point := 0.5
@export var recovery_duration := 1
@export var projectile_speed := 180.0
@export var projectile_lifetime := 2.0
var state := State.IDLE
var timer := 0.0
var release_direction := Vector2.RIGHT
var released := false

func on_enemy_ready() -> void:
	receives_knockback = false
	health_component.max_health = enemy_max_health
	health_component.current_health = enemy_max_health
	hitbox.damage = enemy_damage
	prepare_duration = get_authored_animation_duration(&"prepare", prepare_duration)
	attack_duration = get_authored_animation_duration(&"attack", attack_duration)
	hitbox.set_active(false)
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
			if not released and timer <= attack_duration * (1.0 - attack_release_point):
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
