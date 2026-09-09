@tool
extends Control

var layout: Resource
var rooms: Array[Dictionary] = []
var current_id: int = -1

func set_map(data: Array[Dictionary], selected_id: int) -> void:
	if rooms == data and current_id == selected_id:
		return
	rooms = data
	current_id = selected_id
	queue_redraw()

func _draw() -> void:
	if rooms.is_empty() or layout == null:
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in rooms:
		var point: Vector2 = room.position
		low = low.min(point)
		high = high.max(point)
	var span := high - low + Vector2.ONE
	var padding: float = layout.gap
	var cell: float = minf((size.x - padding * 2) / span.x, (size.y - padding * 2) / span.y)
	cell = maxf(cell, 1)
	var origin := (size - span * cell) / 2 + Vector2.ONE * cell / 2
	var positions: Dictionary = {}
	for room in rooms:
		positions[room.id] = (origin + (Vector2(room.position) - low) * cell).round()
	for room in rooms:
		for neighbor in room.neighbors:
			if positions.has(neighbor) and int(neighbor) > int(room.id):
				draw_line(positions[room.id], positions[neighbor], layout.connector_color, 2)
	var font := get_theme_font("font", "HUDText")
	var font_size := get_theme_font_size("font_size", "HUDText")
	var extent: float = minf(layout.map_room_size, cell * 0.72)
	for room in rooms:
		var center: Vector2 = positions[room.id]
		var rect := Rect2(center - Vector2.ONE * extent / 2, Vector2.ONE * extent)
		var color: Color = layout.visited_color if room.visited else layout.unknown_color
		if int(room.id) == current_id:
			color = layout.current_color
		draw_rect(rect, color)
		draw_rect(rect, layout.connector_color, false, 2 if int(room.id) == current_id else 1)
		var text: String = room.label
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		# Keep tiny maps legible without letting type labels overlap neighbours.
		if text_size.x <= cell - 2 and font.get_height(font_size) <= cell:
			draw_string(font, center + Vector2(-text_size.x / 2, font.get_ascent(font_size) - font.get_height(font_size) / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", "Label"))
