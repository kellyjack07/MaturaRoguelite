extends Node2D

@export var fallback_duration: float = 0.45
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var remaining_fallback_time: float = 0.0

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	if animated_sprite.sprite_frames == null or animated_sprite.sprite_frames.get_frame_count(&"landing") == 0:
		remaining_fallback_time = maxf(fallback_duration, 0.05)
		return
	animated_sprite.play(&"landing")

func _process(delta: float) -> void:
	if remaining_fallback_time <= 0.0:
		return
	remaining_fallback_time -= delta
	if remaining_fallback_time <= 0.0:
		queue_free()

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"landing":
		queue_free()
