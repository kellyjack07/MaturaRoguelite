extends "res://scripts/base_enemy.gd"
class_name Sorcerer

const ENEMY_ID := "sorcerer"

signal summon_wave_requested(wave_number: int)

# Sorcerer is intentionally a summon-only placeholder until its attack
# behavior and animation set are specified. Main owns summon registration.
@export var summon_initial_delay: float = 3.0
@export var sorcerer_wave_count: int = 3

var summon_timer: float = 0.0
var wave_number: int = 0
var next_wave_ready: bool = false


func on_enemy_ready() -> void:
	hitbox.set_active(false)
	summon_timer = summon_initial_delay
	play_idle_animation()


func update_behavior(delta: float) -> void:
	stop_moving()
	play_idle_animation()
	summon_timer -= delta
	if wave_number >= sorcerer_wave_count:
		return
	if wave_number > 0:
		if not next_wave_ready:
			return
	else:
		if summon_timer > 0.0:
			return
	wave_number += 1
	play_summon_animation()
	summon_wave_requested.emit(wave_number)
	next_wave_ready = false


func notify_summon_wave_cleared(cleared_wave_number: int) -> void:
	if cleared_wave_number != wave_number or wave_number >= sorcerer_wave_count:
		return
	next_wave_ready = true


func restore_summon_progress(completed_wave_number: int) -> void:
	wave_number = clampi(completed_wave_number, 0, sorcerer_wave_count)
	next_wave_ready = wave_number > 0 and wave_number < sorcerer_wave_count


func play_idle_animation() -> void:
	if not play_animation_if_exists(&"idle"):
		play_animation_if_exists(&"default")


func play_move_animation() -> void:
	if not play_animation_if_exists(&"move"):
		play_idle_animation()


func play_summon_animation() -> void:
	if not play_animation_if_exists(&"summon"):
		play_idle_animation()


func on_died() -> void:
	hitbox.set_active(false)
	velocity = Vector2.ZERO
	set_physics_process(false)
	for _blink in 4:
		animated_sprite.visible = false
		await get_tree().create_timer(0.08).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(0.08).timeout
	queue_free()
