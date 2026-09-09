@tool
extends Control
class_name MainMenuScreen

## Presentation-only controller. Main owns all menu actions and game state.

@export var layout_resource: MainMenuLayout:
	set(value):
		if is_instance_valid(layout_resource) and layout_resource.changed.is_connected(_on_layout_changed):
			layout_resource.changed.disconnect(_on_layout_changed)
		layout_resource = value
		_connect_layout_changed()
		if is_inside_tree():
			call_deferred("apply_layout")

@onready var background: ColorRect = $Background
@onready var content_scroll: ScrollContainer = $ContentScroll
@onready var content: VBoxContainer = $ContentScroll/Content
@onready var title_label: Label = $ContentScroll/Content/TitleLabel
@onready var title_gap: Control = $ContentScroll/Content/TitleGap
@onready var status_label: Label = $ContentScroll/Content/MenuStatusLabel
@onready var status_gap: Control = $ContentScroll/Content/StatusGap
@onready var primary_buttons: VBoxContainer = $ContentScroll/Content/PrimaryButtons
@onready var reset_gap: Control = $ContentScroll/Content/ResetGap
@onready var continue_button: Button = $ContentScroll/Content/PrimaryButtons/ContinueRunButton
@onready var start_button: Button = $ContentScroll/Content/PrimaryButtons/StartRunButton
@onready var gear_store_button: Button = $ContentScroll/Content/PrimaryButtons/GearStoreButton
@onready var settings_button: Button = $ContentScroll/Content/PrimaryButtons/SettingsButton
@onready var quit_button: Button = $ContentScroll/Content/PrimaryButtons/QuitButton
@onready var reset_button: Button = $ContentScroll/Content/ResetSaveButton


func _ready() -> void:
	_connect_layout_changed()
	call_deferred("apply_layout")


func _connect_layout_changed() -> void:
	if is_instance_valid(layout_resource) and not layout_resource.changed.is_connected(_on_layout_changed):
		layout_resource.changed.connect(_on_layout_changed)


func _on_layout_changed() -> void:
	if is_inside_tree():
		call_deferred("apply_layout")


func apply_layout() -> void:
	if layout_resource == null or not is_inside_tree():
		return
	if not is_instance_valid(background) or not is_instance_valid(content_scroll):
		return

	var margin := layout_resource.outer_margin
	background.color = layout_resource.background_color
	title_label.text = layout_resource.placeholder_title
	content_scroll.offset_left = margin.x
	content_scroll.offset_top = margin.y
	content_scroll.offset_right = -margin.z
	content_scroll.offset_bottom = -margin.w
	content.custom_minimum_size = Vector2(layout_resource.button_width, 0.0)
	content.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_gap.custom_minimum_size = Vector2(0.0, layout_resource.title_gap)
	status_gap.custom_minimum_size = Vector2(0.0, layout_resource.status_gap)
	reset_gap.custom_minimum_size = Vector2(0.0, layout_resource.button_gap * 2.0)
	primary_buttons.add_theme_constant_override("separation", layout_resource.button_gap)
	for button: Button in [continue_button, start_button, gear_store_button, settings_button, quit_button, reset_button]:
		button.custom_minimum_size = Vector2(layout_resource.button_width, layout_resource.button_min_height)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func focus_initial_control() -> void:
	if Engine.is_editor_hint():
		return
	var target: Button = start_button
	if continue_button.visible and not continue_button.disabled:
		target = continue_button
	target.grab_focus()
