@tool
extends Control

const MapScript = preload("res://scripts/ui/hud_minimap.gd")
const GLASS = preload("res://ui/themes/hud_glass.tres")
const INFO = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_player_infos.png")
const HEALTH = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_player_infos_health_bar.png")
const ABILITY = preload("res://assets/UI/Tiny Dungeons - UI Pack/hud/hud_ability_icon_border.png")
const BOSS_BAR_SCENE := preload("res://ui/boss_health_bar.tscn")
const POTION_SLOT = preload("res://assets/UI/Tiny Dungeons - UI Pack/inventory/inventory_slot.png")
const POTION_SMALL = preload("res://assets/items/Pixel Potion Pack - FINISHED/Small Vial/RED/Small Vial - RED - Spritesheet.png")
const POTION_BIG = preload("res://assets/items/Pixel Potion Pack - FINISHED/Round Potion/RED/Round Potion - RED - Spritesheet.png")
const POTION_STAMINA = preload("res://assets/items/Pixel Potion Pack - FINISHED/Small Bottle/BLUE/Sprites/Small Bottle - BLUE - 0000.png")
@export var layout: Resource
@export var show_debug_overlay: bool = false
var player: Node
var health_text: Label
var gold_text: Label
var weapon_text: Label
var special_text: Label
var stage_text: Label
var debug_text: Label
var stamina_text: Label
var bottle_text: Label
var boost_text: Label
var equipped_potion_slot: TextureRect
var equipped_potion_icon: TextureRect
var health_fill: TextureProgressBar
var stamina_fill: ProgressBar
var cooldown_fill: ProgressBar
var minimap: Control
var health_panel: PanelContainer
var weapon_panel: PanelContainer
var map_panel: PanelContainer
var stage_panel: PanelContainer
var boss_panel: PanelContainer
var boss_rows: VBoxContainer
var health_art: HBoxContainer
var ability_art: TextureRect
var elapsed := 0.0
var boss_entries: Dictionary = {}

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
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	stamina_text = _label(stats, "Stamina: 0/0")
	stamina_fill = ProgressBar.new()
	stamina_fill.show_percentage = false
	stamina_fill.custom_minimum_size.y = 6
	stats.add_child(stamina_fill)
	gold_text = _label(stats, "Gold: 0")
	var potion_row := HBoxContainer.new()
	health_column.add_child(potion_row)
	equipped_potion_slot = TextureRect.new()
	equipped_potion_slot.texture = POTION_SLOT
	equipped_potion_slot.custom_minimum_size = Vector2(27, 27)
	equipped_potion_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipped_potion_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipped_potion_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	potion_row.add_child(equipped_potion_slot)
	equipped_potion_icon = TextureRect.new()
	equipped_potion_slot.add_child(equipped_potion_icon)
	equipped_potion_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipped_potion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipped_potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var potion_labels := VBoxContainer.new()
	potion_labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(potion_labels)
	bottle_text = _label(potion_labels, "Potion [F]: None")
	bottle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boost_text = _label(potion_labels, "")
	boost_text.visible = false
	stage_panel = _panel()
	stage_text = _label(stage_panel, "Stage: 1-1")
	boss_panel = _panel()
	boss_rows = VBoxContainer.new()
	boss_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_panel.add_child(boss_rows)
	boss_panel.visible = false
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
	visibility_changed.connect(_on_visibility_changed)
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
	equipped_potion_slot.custom_minimum_size = Vector2.ONE * layout.potion_slot_size
	for side in [SIDE_LEFT, SIDE_TOP]:
		equipped_potion_icon.set_offset(side, layout.potion_icon_padding)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		equipped_potion_icon.set_offset(side, -layout.potion_icon_padding)
	for panel in [health_panel, weapon_panel]:
		_set_gaps(panel, int(gap))
	health_panel.custom_minimum_size.x = layout.health_width
	weapon_panel.custom_minimum_size.x = layout.weapon_width
	minimap.custom_minimum_size = layout.minimap_size
	boss_panel.custom_minimum_size.x = layout.boss_width
	_set_gaps(boss_panel, int(layout.boss_gap))
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.z_index = 20
	for panel in [health_panel, weapon_panel, stage_panel, map_panel, boss_panel]:
		panel.size = panel.get_combined_minimum_size()
	health_panel.position = Vector2(m, m)
	map_panel.position = Vector2(maxf(m, size.x - m - map_panel.size.x), m)
	stage_panel.position = Vector2((size.x - stage_panel.size.x) / 2, m)
	if health_panel.get_rect().intersects(stage_panel.get_rect()) or map_panel.get_rect().intersects(stage_panel.get_rect()):
		stage_panel.position.y = maxf(health_panel.size.y, map_panel.size.y) + m + gap
	var boss_top_y := maxf(m + layout.boss_top_offset, stage_panel.position.y + stage_panel.size.y + gap)
	boss_panel.position = Vector2((size.x - boss_panel.size.x) / 2.0, boss_top_y)
	if boss_panel.get_rect().intersects(health_panel.get_rect()) or boss_panel.get_rect().intersects(map_panel.get_rect()):
		boss_panel.position.y = maxf(
			health_panel.position.y + health_panel.size.y,
			map_panel.position.y + map_panel.size.y
		) + gap
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


func set_stamina(current: float, maximum: float, equipped_id: String, available: bool, boost_seconds: float) -> void:
	var safe_maximum := maxf(maximum, 0.0)
	var safe_current := clampf(current, 0.0, safe_maximum)
	var stamina_label := "Stamina: %.0f/%.0f" % [safe_current, safe_maximum]
	if stamina_text.text != stamina_label:
		stamina_text.text = stamina_label
		_schedule_layout()
	stamina_fill.max_value = maxf(safe_maximum, 1.0)
	stamina_fill.value = safe_current
	var binding := "Unbound"
	for event in InputMap.action_get_events("use_stamina_bottle"):
		binding = event.as_text().replace(" (Physical)", "")
		break
	var display_name: String = {"small_healing": "Small heal", "big_healing": "Big heal", "stamina": "Stamina"}.get(equipped_id, "None")
	var next_text := "[%s] %s%s" % [binding, display_name, " (empty)" if not available and not equipped_id.is_empty() else ""]
	if bottle_text.text != next_text:
		bottle_text.text = next_text
		equipped_potion_icon.texture = _get_potion_icon(equipped_id)
		equipped_potion_icon.modulate.a = 1.0 if available else 0.3
		_schedule_layout()
	if boost_text.visible != (boost_seconds > 0.0):
		boost_text.visible = boost_seconds > 0.0
		_schedule_layout()
	boost_text.text = "Boost: %.1fs" % boost_seconds


func _get_potion_icon(potion_id: String) -> Texture2D:
	var texture: Texture2D
	var frame_size := Vector2i.ZERO
	match potion_id:
		"small_healing":
			texture = POTION_SMALL
			frame_size = Vector2i(14, 24)
		"big_healing":
			texture = POTION_BIG
			frame_size = Vector2i(19, 38)
		"stamina":
			return POTION_STAMINA
		_:
			return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, frame_size)
	return atlas

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


func register_boss(enemy: Node, boss_name: String, encounter_id: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var key := encounter_id if not encounter_id.is_empty() else str(enemy.get_instance_id())
	unregister_boss(key)
	var health := enemy.get_node_or_null("Health") as HealthComponent
	if health == null:
		return
	var row := BOSS_BAR_SCENE.instantiate()
	boss_rows.add_child(row)
	row.setup(boss_name, health, layout.boss_width)
	var exiting := Callable(self, "_on_boss_exiting").bind(key, enemy)
	var died := Callable(self, "_on_boss_row_died").bind(key)
	enemy.tree_exiting.connect(exiting)
	row.boss_died.connect(died)
	boss_entries[key] = {"enemy": enemy, "row": row, "exiting": exiting}
	boss_panel.visible = true
	_schedule_layout()


func unregister_boss(encounter_id: String) -> void:
	if not boss_entries.has(encounter_id):
		return
	var entry: Dictionary = boss_entries[encounter_id]
	var enemy: Node = entry.get("enemy") as Node
	var exiting: Callable = entry.get("exiting") as Callable
	if enemy != null and is_instance_valid(enemy) and enemy.tree_exiting.is_connected(exiting):
		enemy.tree_exiting.disconnect(exiting)
	var row: Node = entry.get("row") as Node
	if row != null and is_instance_valid(row):
		row.queue_free()
	boss_entries.erase(encounter_id)
	boss_panel.visible = not boss_entries.is_empty()
	_schedule_layout()


func clear_bosses() -> void:
	for encounter_id: String in boss_entries.keys():
		unregister_boss(encounter_id)


func _on_boss_exiting(encounter_id: String, _enemy: Node) -> void:
	unregister_boss(encounter_id)


func _on_boss_row_died(encounter_id: String) -> void:
	unregister_boss(encounter_id)


func _on_visibility_changed() -> void:
	if not visible:
		clear_bosses()
	_refresh_special()

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
