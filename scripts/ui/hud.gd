@tool
extends Control

const MapScript = preload("res://scripts/ui/hud_minimap.gd")
const GLASS = preload("res://ui/themes/hud_glass.tres")
const INFO = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_player_infos.png")
const HEALTH = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_player_infos_health_bar.png")
const ABILITY = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_ability_icon_border.png")
@export var layout: Resource
@export var show_debug_overlay: bool = false
var player: Node
var health_text: Label
var gold_text: Label
var weapon_text: Label
var special_text: Label
var stage_text: Label
var debug_text: Label
var health_fill: TextureProgressBar
var cooldown_fill: ProgressBar
var minimap: Control
var health_panel: PanelContainer
var weapon_panel: PanelContainer
var map_panel: PanelContainer
var stage_panel: PanelContainer
var health_art: HBoxContainer
var ability_art: TextureRect
var elapsed := 0.0

func _ready() -> void:
	# Capture the world once, before any HUD panels or text are drawn.
	var world_copy := BackBufferCopy.new()
	world_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(world_copy)
	health_panel = _panel()
	var health_column := _column(health_panel)
	health_art = HBoxContainer.new()
	health_column.add_child(health_art)
	var frame := TextureRect.new()
	var portrait := AtlasTexture.new()
	portrait.atlas = INFO
	# The first 42 pixels are the portrait frame; omit both unused bar tracks.
	portrait.region = Rect2(0, 0, 42, 44)
	frame.texture = portrait
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	health_art.add_child(frame)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_art.add_child(stats)
	health_text = _label(stats, "HP: 0/0")
	health_fill = TextureProgressBar.new()
	health_fill.texture_progress = HEALTH
	health_fill.nine_patch_stretch = true
	health_fill.custom_minimum_size.y = 8
	stats.add_child(health_fill)
	gold_text = _label(stats, "Gold: 0")
	stage_panel = _panel()
	stage_text = _label(stage_panel, "Stage: 1-1")
	weapon_panel = _panel()
	var row := HBoxContainer.new()
	weapon_panel.add_child(row)
	ability_art = TextureRect.new()
	ability_art.texture = ABILITY
	ability_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ability_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ability_art)
	var weapon_column := VBoxContainer.new()
	weapon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(weapon_column)
	weapon_text = _label(weapon_column, "Sword")
	special_text = _label(weapon_column, "Special: Locked")
	cooldown_fill = ProgressBar.new()
	cooldown_fill.show_percentage = false
	cooldown_fill.custom_minimum_size.y = 6
	weapon_column.add_child(cooldown_fill)
	map_panel = _panel()
	minimap = Control.new()
	minimap.set_script(MapScript)
	minimap.layout = layout
	map_panel.add_child(minimap)
	debug_text = _label(self, "")
	debug_text.visible = false
	_ignore_mouse(self)
	resized.connect(_arrange)
	theme_changed.connect(_schedule_layout)
	layout.changed.connect(_schedule_layout)
	visibility_changed.connect(_refresh_special)
	_schedule_layout()

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HUDPanel"
	panel.material = GLASS
	add_child(panel)
	return panel

func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	parent.add_child(column)
	return column

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "HUDText"
	label.text = text
	parent.add_child(label)
	return label

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _schedule_layout() -> void:
	call_deferred("_arrange")

func _arrange() -> void:
	if not is_instance_valid(health_panel):
		return
	var m: float = layout.margin
	var gap: float = layout.gap
	health_art.get_child(0).custom_minimum_size = Vector2(42, 44) * layout.artwork_scale
	ability_art.custom_minimum_size = ABILITY.get_size() * layout.artwork_scale
	for panel in [health_panel, weapon_panel]:
		_set_gaps(panel, int(gap))
	health_panel.custom_minimum_size.x = layout.health_width
	weapon_panel.custom_minimum_size.x = layout.weapon_width
	minimap.custom_minimum_size = layout.minimap_size
	for panel in [health_panel, weapon_panel, stage_panel, map_panel]:
		panel.size = panel.get_combined_minimum_size()
	health_panel.position = Vector2(m, m)
	map_panel.position = Vector2(maxf(m, size.x - m - map_panel.size.x), m)
	stage_panel.position = Vector2((size.x - stage_panel.size.x) / 2, m)
	if health_panel.get_rect().intersects(stage_panel.get_rect()) or map_panel.get_rect().intersects(stage_panel.get_rect()):
		stage_panel.position.y = maxf(health_panel.size.y, map_panel.size.y) + m + gap
	if health_panel.get_rect().intersects(map_panel.get_rect()):
		map_panel.position.y = health_panel.position.y + health_panel.size.y + gap
	weapon_panel.position = Vector2(m, maxf(m, size.y - m - weapon_panel.size.y))
	debug_text.position = Vector2(m, health_panel.position.y + health_panel.size.y + gap)
	minimap.queue_redraw()

func _set_gaps(node: Node, gap: int) -> void:
	if node is BoxContainer and node.get_theme_constant("separation") != gap:
		node.add_theme_constant_override("separation", gap)
	for child in node.get_children():
		_set_gaps(child, gap)

func bind_player(value: Node) -> void:
	player = value
	_refresh_special()

func set_health(current: int, maximum: int) -> void:
	var text := "HP: %d/%d" % [current, maximum]
	if health_text.text != text:
		health_text.text = text
		_schedule_layout()
	health_fill.max_value = maxi(maximum, 1)
	health_fill.value = clampi(current, 0, maxi(maximum, 0))

func set_gold(value: int) -> void:
	var text := "Gold: %d" % value
	if gold_text.text != text:
		gold_text.text = text
		_schedule_layout()

func set_stage(value: String) -> void:
	if stage_text.text != "Stage: " + value:
		stage_text.text = "Stage: " + value
		_schedule_layout()

func set_weapon(value: String) -> void:
	if weapon_text.text != value:
		weapon_text.text = value
		_schedule_layout()
	_refresh_special()

func set_map(rooms: Array[Dictionary], current_id: int) -> void:
	minimap.set_map(rooms, current_id)

func set_debug_text(value: String) -> void:
	debug_text.text = value
	debug_text.visible = show_debug_overlay and OS.is_debug_build()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	elapsed += delta
	if elapsed >= 0.1:
		elapsed = 0.0
		_refresh_special()

func _refresh_special() -> void:
	if not is_instance_valid(player) or not is_instance_valid(special_text):
		return
	var unlocked: bool = player.special_unlocked or player.developer_combat_bypass
	var remaining: float = player.get_special_cooldown_left()
	var duration: float = player.get_special_cooldown_duration()
	var status := "Locked"
	if unlocked:
		status = "Ready" if remaining <= 0 else "%.1fs" % remaining
	var binding := "Unbound"
	for event in InputMap.action_get_events("special_attack"):
		binding = event.as_text().replace(" (Physical)", "")
		break
	special_text.text = "Special [%s]: %s" % [binding, status]
	cooldown_fill.value = (100.0 if remaining <= 0 else clampf(1.0 - remaining / maxf(duration, 0.001), 0, 1) * 100.0) if unlocked else 0.0
