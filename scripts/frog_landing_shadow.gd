extends Node2D

## Small destination marker for a Frog jump. It is deliberately plain so its
## size, opacity, and vertical squash remain easy to tune in one place.
@export var radius: float = 9.0
@export var vertical_scale: float = 0.45
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, vertical_scale))
	draw_circle(Vector2.ZERO, radius, shadow_color)
