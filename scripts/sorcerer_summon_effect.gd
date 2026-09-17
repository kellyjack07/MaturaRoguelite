extends Node2D

## One-shot VFX played at the Sorcerer's position when a summon wave begins.
## The SpriteFrames resource is intentionally editable so the final summon
## artwork can be authored without changing the Sorcerer or room logic.
@export var fallback_duration: float = 0.45
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var remaining_fallback_time: float = 0.0


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	if animated_sprite.sprite_frames == null or animated_sprite.sprite_frames.get_frame_count(&"summon") == 0:
		remaining_fallback_time = maxf(fallback_duration, 0.05)
		return
	animated_sprite.play(&"summon")


func _process(delta: float) -> void:
	if remaining_fallback_time <= 0.0:
		return
	remaining_fallback_time -= delta
	if remaining_fallback_time <= 0.0:
		queue_free()


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"summon":
		queue_free()
