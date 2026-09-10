extends Control

const LAYOUT = preload("res://data/ui/rest_shop_layout.tres")
const PANEL = preload("res://assets/UI/Tiny Dungeons - UI Pack/components/component_9slices_panel.png")
const TITLE = preload("res://assets/UI/Tiny Dungeons - UI Pack/components/component_3slices_window_title.png")
const SMALL = preload("res://assets/items/Pixel Potion Pack - FINISHED/Small Vial/RED/Small Vial - RED - Spritesheet.png")
const BIG = preload("res://assets/items/Pixel Potion Pack - FINISHED/Round Potion/RED/Round Potion - RED - Spritesheet.png")
var main: Node
var room_id: int = -1
var previous_pause: bool = false
var info: Label
var status: Label
var buttons: Dictionary = {}
var descriptions: Dictionary = {}
var close_button: Button

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, LAYOUT.margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = LAYOUT.panel_width
	column.add_theme_constant_override("separation", LAYOUT.gap)
	center.add_child(column)
	var title_panel := _panel(TITLE)
	column.add_child(title_panel)
	_label(title_panel, "Rest Room")
	var panel := _panel(PANEL)
	column.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", LAYOUT.gap)
	panel.add_child(contents)
	info = _label(contents, "")
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", LAYOUT.gap)
	contents.add_child(choices)
	_make_offer(choices, "small", SMALL, Vector2i(14, 24))
	_make_offer(choices, "big", BIG, Vector2i(19, 38))
	status = _label(contents, "Choose one potion.")
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close_shop)
	contents.add_child(close_button)
	hide()

func _panel(texture: Texture2D) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var horizontal: bool = side == SIDE_LEFT or side == SIDE_RIGHT
		style.set_texture_margin(side, (32 if horizontal else 4) if texture == TITLE else 12)
		style.set_content_margin(side, (4 if texture == TITLE else maxi(LAYOUT.gap, 12)))
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "RestShopText"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _make_offer(parent: Node, id: String, texture: Texture2D, frame_size: Vector2i) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", LAYOUT.gap)
	parent.add_child(column)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(48, 38) * LAYOUT.potion_scale
	column.add_child(preview)
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", LAYOUT.animation_fps)
	for index in texture.get_width() / frame_size.x:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(index * frame_size.x, 0), frame_size)
		frames.add_frame("default", frame)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * LAYOUT.potion_scale
	preview.add_child(sprite)
	preview.resized.connect(func(): sprite.position = preview.size / 2)
	sprite.play()
	descriptions[id] = _label(column, "")
	var button := Button.new()
	button.text = "Take Small" if id == "small" else "Buy Big"
	button.pressed.connect(_choose.bind(id))
	column.add_child(button)
	buttons[id] = button

func open_shop(owner_main: Node, id: int) -> void:
	if visible:
		return
	main = owner_main
	room_id = id
	previous_pause = get_tree().paused
	main.player.cancel_actions_for_modal()
	get_tree().paused = true
	show()
	status.text = "Choose one potion."
	refresh()
	if not buttons.small.disabled:
		buttons.small.grab_focus()
	elif not buttons.big.disabled:
		buttons.big.grab_focus()
	else:
		close_button.grab_focus()
	main.get_room_node(room_id).set_rest_chest_pose("opening")

func refresh() -> void:
	info.text = "HP: %d/%d    Gold: %d" % [main.health_component.current_health, main.health_component.max_health, main.current_run.get("gold", 0)]
	for id in buttons:
		var offer: Dictionary = main.get_rest_shop_offer(room_id, id)
		descriptions[id].text = "%s\nHeal %d HP | %s" % ["Small Potion" if id == "small" else "Big Potion", offer.heal, "Free" if offer.cost == 0 else "%d Gold" % offer.cost]
		buttons[id].disabled = not offer.available
		buttons[id].tooltip_text = offer.reason

func _choose(id: String) -> void:
	var result: Dictionary = main.select_rest_shop_offer(room_id, id)
	if result.success:
		close_shop()
	else:
		refresh()
		status.text = result.reason

func close_shop() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = previous_pause
	if is_instance_valid(main):
		var room = main.get_room_node(room_id)
		if room != null:
			room.configure_rest_chest(main.get_room_data_by_id(room_id).get("completed", false))
	room_id = -1

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
