extends Control

signal close_requested

@onready var current_label: Label = $Background/Panel/Margin/Content/CurrentLabel
@onready var stats_label: Label = $Background/Panel/Margin/Content/StatsLabel
@onready var controls_label: Label = $Background/Panel/Margin/Content/ControlsLabel
@onready var weapon_buttons: VBoxContainer = $Background/Panel/Margin/Content/WeaponButtons
@onready var close_button: Button = $Background/Panel/Margin/Content/CloseButton

var coordinator: Node
var buttons_by_weapon: Dictionary = {}
var dev_fields: Dictionary = {}
var dev_status: Label
var floor_button: Button
var changing_floor := false


func _ready() -> void:
	build_run_controls()
	close_button.pressed.connect(func() -> void: close_requested.emit())
	hide()


func setup(main_node: Node) -> void:
	coordinator = main_node
	build_weapon_buttons()


func build_weapon_buttons() -> void:
	if coordinator == null:
		return
	for child in weapon_buttons.get_children():
		child.queue_free()
	buttons_by_weapon.clear()

	for weapon_id in coordinator.get_weapon_ids():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_weapon_pressed.bind(str(weapon_id)))
		weapon_buttons.add_child(button)
		buttons_by_weapon[str(weapon_id)] = button


func open_screen() -> void:
	refresh()
	dev_fields.stage.value = coordinator.get_stage_world_number()
	dev_fields.floor.value = coordinator.get_stage_floor_number()
	dev_fields.gold.value = int(coordinator.current_run.get("gold", 0))
	dev_fields.essence.value = int(coordinator.meta_progression.get("essence", 0))
	dev_status.text = ""
	show()
	var selected_id: String = coordinator.get_selected_weapon_id()
	var selected_button := buttons_by_weapon.get(selected_id) as Button
	if selected_button != null:
		selected_button.grab_focus()
	else:
		close_button.grab_focus()


func refresh() -> void:
	if coordinator == null:
		return
	var selected_id: String = coordinator.get_selected_weapon_id()
	var definition: Resource = coordinator.get_weapon_definition(selected_id)
	current_label.text = "Current: %s" % definition.display_name
	stats_label.text = "Basic damage: %s\nSpecial damage: %s\nSpecial cooldown: %.1fs (%.1fs remaining)" % [
		coordinator.player.effective_basic_damage,
		coordinator.player.effective_special_damage,
		coordinator.player.get_special_cooldown_duration(),
		coordinator.player.get_special_cooldown_left(),
	]
	controls_label.text = "F6/Escape closes. Jump replaces this floor, preserving HP and gear.\nGold is run currency; essence is permanent. No clear credit for jumps."

	for weapon_key in buttons_by_weapon.keys():
		var weapon_id := str(weapon_key)
		var button := buttons_by_weapon[weapon_id] as Button
		var weapon_definition: Resource = coordinator.get_weapon_definition(weapon_id)
		var ownership := "unlocked" if coordinator.is_weapon_unlocked(weapon_id) else "locked - developer test"
		var selected := "  [equipped]" if weapon_id == selected_id else ""
		button.text = "%s (%s)%s" % [weapon_definition.display_name, ownership, selected]


func _on_weapon_pressed(weapon_id: String) -> void:
	if coordinator == null:
		return
	coordinator.equip_developer_weapon(weapon_id)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_F6:
		close_requested.emit()
		get_viewport().set_input_as_handled()


func build_run_controls() -> void:
	# Scroll the existing content so added controls also fit the 640x360 viewport.
	var content := close_button.get_parent()
	var margin := content.get_parent()
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content.reparent(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel: Control = $Background/Panel
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_top = 12
	panel.offset_right = -20
	panel.offset_bottom = -12
	content.get_node("TitleLabel").text = "Developer Controls"
	var grid := GridContainer.new()
	grid.columns = 4
	content.add_child(grid)
	content.move_child(grid, 1)
	for key in ["stage", "floor", "gold", "essence"]:
		var label := Label.new()
		label.text = "Level / Floor" if key == "floor" else key.capitalize()
		grid.add_child(label)
		var field := SpinBox.new()
		field.min_value = 1 if key in ["stage", "floor"] else 0
		field.max_value = 3 if key in ["stage", "floor"] else 999999999
		field.step = 1
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(field)
		dev_fields[key] = field
	var actions := HBoxContainer.new()
	content.add_child(actions)
	content.move_child(actions, 2)
	floor_button = Button.new()
	floor_button.text = "Jump to Stage / Floor"
	floor_button.pressed.connect(_request_floor_change)
	actions.add_child(floor_button)
	var currency_button := Button.new()
	currency_button.text = "Apply Gold / Essence"
	currency_button.pressed.connect(_apply_currency)
	actions.add_child(currency_button)
	dev_status = Label.new()
	dev_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(dev_status)
	content.move_child(dev_status, 3)


func _apply_currency() -> void:
	if changing_floor or not visible or not coordinator.run_active or not coordinator.dev_tools_enabled:
		return
	var old_gold: int = int(coordinator.current_run.get("gold", 0))
	var old_essence: int = int(coordinator.meta_progression.get("essence", 0))
	coordinator.current_run["gold"] = int(dev_fields.gold.value)
	coordinator.meta_progression["essence"] = int(dev_fields.essence.value)
	var error: Error = coordinator.save_progress()
	if error != OK:
		coordinator.current_run["gold"] = old_gold
		coordinator.meta_progression["essence"] = old_essence
	dev_status.text = "Currency saved." if error == OK else "Save failed. Currency unchanged."
	coordinator.update_debug_ui()
	if coordinator.skill_tree != null:
		coordinator.skill_tree.changed.emit()


func _request_floor_change() -> void:
	if changing_floor or not visible or not coordinator.run_active or not coordinator.dev_tools_enabled:
		return
	changing_floor = true
	floor_button.disabled = true
	close_button.disabled = true
	_apply_floor_change.call_deferred(int(dev_fields.stage.value), int(dev_fields.floor.value))


func _apply_floor_change(stage: int, floor_number: int) -> void:
	coordinator.player.cancel_actions_for_modal()
	coordinator.clear_active_room()
	# Allow queued room/enemy removals to finish before creating replacement nodes.
	await get_tree().process_frame
	coordinator.current_stage = (clampi(stage, 1, 3) - 1) * 3 + clampi(floor_number, 1, 3)
	var empty_rooms: Array[Dictionary] = []
	coordinator.current_stage_rooms = empty_rooms
	coordinator.current_room_id = -1
	coordinator.current_room_number = 0
	coordinator.start_room_id = -1
	coordinator.boss_room_id = -1
	coordinator.start_stage()
	var error: Error = coordinator.save_progress()
	dev_status.text = "Moved to %d-%d." % [stage, floor_number] if error == OK else "Floor changed, but saving failed. Retry saving before quitting."
	changing_floor = false
	floor_button.disabled = false
	close_button.disabled = false
	refresh()
