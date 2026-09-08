extends Control

signal close_requested

@onready var current_label: Label = $Background/Panel/Margin/Content/CurrentLabel
@onready var stats_label: Label = $Background/Panel/Margin/Content/StatsLabel
@onready var controls_label: Label = $Background/Panel/Margin/Content/ControlsLabel
@onready var weapon_buttons: VBoxContainer = $Background/Panel/Margin/Content/WeaponButtons
@onready var close_button: Button = $Background/Panel/Margin/Content/CloseButton

var coordinator: Node
var buttons_by_weapon: Dictionary = {}


func _ready() -> void:
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
	controls_label.text = "Move WASD/arrows | Basic Space | Special Q | Dash Shift\nF6/Escape closes. Selection is saved for this run only."

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
