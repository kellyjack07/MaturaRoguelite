extends Control

signal equip_requested(potion_id: String)

const SLOT_TEXTURE = preload("res://assets/UI/Tiny Dungeons - UI Pack/inventory/inventory_slot.png")
const SMALL_TEXTURE = preload("res://assets/items/Pixel Potion Pack - FINISHED/Small Vial/RED/Small Vial - RED - Spritesheet.png")
const BIG_TEXTURE = preload("res://assets/items/Pixel Potion Pack - FINISHED/Round Potion/RED/Round Potion - RED - Spritesheet.png")
const STAMINA_TEXTURE = preload("res://assets/items/Pixel Potion Pack - FINISHED/Small Bottle/BLUE/Sprites/Small Bottle - BLUE - 0000.png")

var main: Node
var previous_pause := false
var status: Label
var buttons: Dictionary = {}

const DEFINITIONS := {
	"small_healing": ["Small Healing", "Heal 20% max HP", SMALL_TEXTURE],
	"big_healing": ["Big Healing", "Heal 50% max HP", BIG_TEXTURE],
	"stamina": ["Stamina", "40 stamina/sec for 8 sec", STAMINA_TEXTURE],
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 210)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(48, 64)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Potion Inventory"
	title.theme_type_variation = "HUDText"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for id in ["small_healing", "big_healing", "stamina"]:
		_make_slot(row, id)
	status = Label.new()
	status.theme_type_variation = "HUDText"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_inventory)
	column.add_child(close)
	hide()


func _make_slot(parent: Node, id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(105, 115)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_slot_pressed.bind(id))
	var definition: Array = DEFINITIONS[id]
	button.text = definition[0] + "\n" + definition[1]
	button.icon = _first_frame(definition[2])
	parent.add_child(button)
	buttons[id] = button


func _first_frame(texture: Texture2D) -> Texture2D:
	if texture == STAMINA_TEXTURE:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 19 if texture == BIG_TEXTURE else 14, 38 if texture == BIG_TEXTURE else 24)
	return atlas


func open_screen(owner_main: Node) -> void:
	main = owner_main
	previous_pause = get_tree().paused
	main.player.cancel_actions_for_modal()
	get_tree().paused = true
	show()
	refresh()
	for id in buttons:
		if not buttons[id].disabled:
			buttons[id].grab_focus()
			break


func refresh() -> void:
	if not is_instance_valid(main):
		return
	var in_combat: bool = main.is_potion_combat_active()
	for id in buttons:
		var owned: bool = main.potion_inventory.has(id)
		buttons[id].disabled = not owned or in_combat
		buttons[id].tooltip_text = "Cannot change potion during combat." if in_combat else ("Empty slot." if not owned else "Equip this potion.")
		buttons[id].modulate = Color(1.0, 0.85, 0.45) if main.potion_inventory.equipped_id == id else Color.WHITE
	status.text = "Combat: equipment locked." if in_combat else "Select an owned potion."


func _on_slot_pressed(id: String) -> void:
	if not is_instance_valid(main):
		return
	var result: Dictionary = main.request_potion_equip(id)
	status.text = result.get("reason", "")
	refresh()


func close_inventory() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = previous_pause


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()
