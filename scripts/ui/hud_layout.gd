@tool
extends Resource

@export var margin: float = 10.0:
	set(v):
		margin = v
		emit_changed()
@export var gap: float = 6.0:
	set(v):
		gap = v
		emit_changed()
@export var health_width: float = 180.0:
	set(v):
		health_width = v
		emit_changed()
@export var weapon_width: float = 210.0:
	set(v):
		weapon_width = v
		emit_changed()
@export var artwork_scale: int = 1:
	set(v):
		artwork_scale = maxi(v, 1)
		emit_changed()
@export var minimap_size: Vector2 = Vector2(144, 100):
	set(v):
		minimap_size = v
		emit_changed()
@export var map_room_size: float = 18.0:
	set(v):
		map_room_size = v
		emit_changed()
@export var current_color: Color = Color(1, 0.85, 0.35):
	set(v):
		current_color = v
		emit_changed()
@export var visited_color: Color = Color(0.7, 0.8, 0.85):
	set(v):
		visited_color = v
		emit_changed()
@export var unknown_color: Color = Color(0.4, 0.46, 0.52):
	set(v):
		unknown_color = v
		emit_changed()
@export var connector_color: Color = Color(0.42, 0.52, 0.62):
	set(v):
		connector_color = v
		emit_changed()
