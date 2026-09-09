@tool
extends Resource
class_name MainMenuLayout

## Shared, inspector-friendly geometry and content defaults for the main menu.
## outer_margin is left, top, right, bottom in logical viewport pixels.

@export var placeholder_title: String = "Matura Roguelite":
	set(value):
		if placeholder_title == value:
			return
		placeholder_title = value
		emit_changed()

@export var outer_margin: Vector4 = Vector4(48.0, 28.0, 48.0, 28.0):
	set(value):
		if outer_margin == value:
			return
		outer_margin = value
		emit_changed()

@export_range(120.0, 600.0, 1.0) var button_width: float = 180.0:
	set(value):
		if is_equal_approx(button_width, value):
			return
		button_width = value
		emit_changed()

@export_range(24.0, 120.0, 1.0) var button_min_height: float = 32.0:
	set(value):
		if is_equal_approx(button_min_height, value):
			return
		button_min_height = value
		emit_changed()

@export_range(0.0, 48.0, 1.0) var button_gap: float = 6.0:
	set(value):
		if is_equal_approx(button_gap, value):
			return
		button_gap = value
		emit_changed()

@export_range(0.0, 64.0, 1.0) var title_gap: float = 12.0:
	set(value):
		if is_equal_approx(title_gap, value):
			return
		title_gap = value
		emit_changed()

@export_range(0.0, 64.0, 1.0) var status_gap: float = 8.0:
	set(value):
		if is_equal_approx(status_gap, value):
			return
		status_gap = value
		emit_changed()

@export var background_color: Color = Color(0.394, 0.465, 0.597, 1.0):
	set(value):
		if background_color == value:
			return
		background_color = value
		emit_changed()
