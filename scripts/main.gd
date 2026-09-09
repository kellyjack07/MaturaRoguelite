extends Node2D

const WeaponRegistryScript := preload("res://scripts/weapons/weapon_registry.gd")
const SkillTreeServiceScript := preload("res://scripts/progression/skill_tree_service.gd")
const DEFAULT_ROOM_SCENE := preload("res://rooms/graph_room.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://enemies/bone_scout_enemy.tscn")
const TRAINING_DUMMY_2_SCENE := preload("res://enemies/training_dummy_2.tscn")
const GOBLIN_BARREL_SCENE := preload("res://enemies/goblin_barrel.tscn")
const SAVE_FILE_PATH := "user://savegame.cfg"

enum RoomType {
	START,
	COMBAT,
	BOSS,
	REWARD,
	REST,
	DEBUFF,
}

enum RoomEventType {
	NONE,
	COMBAT_REWARD,
	BOSS_CHEST_REWARD,
	REWARD_CHOICE,
	DEBUFF_NOTICE,
}

@export var available_room_scenes: Array[PackedScene] = [DEFAULT_ROOM_SCENE]
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var stage_one_combat_min: int = 3
@export var stage_one_combat_max: int = 4
@export var reward_rooms_per_stage: int = 1
@export var rest_rooms_per_stage: int = 1
@export var rest_room_heal_amount: int = 3
@export var replay_debuff_rooms_min: int = 2
@export var replay_debuff_rooms_max: int = 3
@export var reward_room_buy_heal_amount: int = 2
@export var reward_room_buy_heal_cost: int = 3
@export var combat_clear_gold_reward: int = 1
@export var stage_grid_room_count: int = 7
@export var room_world_spacing: Vector2 = Vector2(320.0, 224.0)
@export var enable_dev_weapon_screen_in_release: bool = false

@onready var player: CharacterBody2D = $Player
@onready var room_container: Node2D = $RoomContainer
@onready var enemy_container: Node2D = $EnemyContainer
@onready var health_component: HealthComponent = $Player/Health
@onready var death_screen: Control = $UI/DeathScreen
@onready var stage_transition_screen: Control = $UI/StageTransitionScreen
@onready var stage_transition_label: Label = $UI/StageTransitionScreen/StageTransitionLabel
@onready var room_event_screen: Control = $UI/RoomEventScreen
@onready var room_event_title_label: Label = $UI/RoomEventScreen/Panel/TitleLabel
@onready var room_event_body_label: Label = $UI/RoomEventScreen/Panel/BodyLabel
@onready var room_event_status_label: Label = $UI/RoomEventScreen/Panel/StatusLabel
@onready var room_event_primary_button: Button = $UI/RoomEventScreen/Panel/PrimaryButton
@onready var room_event_secondary_button: Button = $UI/RoomEventScreen/Panel/SecondaryButton
@onready var room_event_tertiary_button: Button = $UI/RoomEventScreen/Panel/TertiaryButton
@onready var main_menu_screen: Control = $UI/MainMenuScreen
@onready var gear_store_screen: Control = $UI/GearStoreScreen
@onready var settings_screen: Control = $UI/SettingsScreen
@onready var pause_menu_screen: Control = $UI/PauseMenuScreen
@onready var health_label: Label = $UI/HealthLabel
@onready var gold_label: Label = $UI/GoldLabel
@onready var weapon_label: Label = $UI/WeaponLabel
@onready var state_label: Label = $UI/StateLabel
@onready var multiplier_label: Label = $UI/MultiplierLabel
@onready var damage_label: Label = $UI/DamageLabel
@onready var stage_label: Label = $UI/StageLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var room_type_label: Label = $UI/RoomTypeLabel
@onready var stage_map_label: Label = $UI/StageMapLabel
@onready var main_menu_status_label: Label = $UI/MainMenuScreen/ContentScroll/Content/MenuStatusLabel
@onready var continue_run_button: Button = $UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/ContinueRunButton
@onready var reset_save_button: Button = $UI/MainMenuScreen/ContentScroll/Content/ResetSaveButton
@onready var gear_store_essence_label: Label = $UI/GearStoreScreen/OuterMargin/MainVBox/Header/EssenceLabel
@onready var pause_run_info_label: Label = $UI/PauseMenuScreen/Panel/RunInfoLabel
@onready var volume_slider: HSlider = $UI/SettingsScreen/VolumeSlider
@onready var volume_value_label: Label = $UI/SettingsScreen/VolumeValueLabel
@onready var starter_gold_button: Button = $UI/GearStoreScreen/OuterMargin/MainVBox/Footer/OtherGearRow/StarterGoldButton
@onready var rest_bonus_button: Button = $UI/GearStoreScreen/OuterMargin/MainVBox/Footer/OtherGearRow/RestBonusButton
@onready var luck_button: Button = $UI/GearStoreScreen/OuterMargin/MainVBox/Footer/OtherGearRow/LuckButton
@onready var dev_weapon_screen: Control = $UI/DevWeaponScreen

var hit_stop_active: bool = false
var hit_stop_duration: float = 0.01
var hit_stop_scale: float = 0.05
var stage_transition_duration: float = 1.2
var current_stage: int = 1
var current_room_number: int = 0
var current_stage_rooms: Array[Dictionary] = []
var remaining_room_enemies: int = 0
var current_room: StageRoom = null
var current_room_id: int = -1
var start_room_id: int = -1
var boss_room_id: int = -1
var stage_transition_active: bool = false
var run_active: bool = false
var previous_menu_context: String = "main_menu"
var default_player_base_attack_damage: int = 0
var default_player_move_speed: float = 0.0
var default_player_max_health: int = 0
var meta_progression: Dictionary = {}
var current_run: Dictionary = {}
var skill_tree: SkillTreeService
var loaded_legacy_skill_tree: bool = false
var current_room_event_type: RoomEventType = RoomEventType.NONE
var stage_room_nodes: Dictionary = {}
var hallway_container: Node2D = null
var dev_tools_enabled: bool = false
var dev_menu_previous_pause_state: bool = false


#start
func _ready() -> void:
	default_player_base_attack_damage = player.base_attack_damage
	default_player_move_speed = player.move_speed
	default_player_max_health = health_component.max_health

	player.visible = false
	player.set_physics_process(false)
	death_screen.visible = false
	stage_transition_screen.visible = false
	room_event_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	dev_tools_enabled = OS.is_debug_build() or enable_dev_weapon_screen_in_release
	ensure_developer_input_action()
	dev_weapon_screen.setup(self)
	dev_weapon_screen.close_requested.connect(close_developer_weapon_screen)
	dev_weapon_screen.visible = false
	player.death_started.connect(_on_player_death_started)

	load_progress()
	skill_tree = SkillTreeServiceScript.new()
	skill_tree.name = "SkillTreeCore"
	add_child(skill_tree)
	skill_tree.setup(
		meta_progression,
		Callable(self, "save_progress"),
		Callable(self, "_apply_skill_tree_purchase_to_run"),
		loaded_legacy_skill_tree
	)
	skill_tree.changed.connect(_on_skill_tree_changed)
	gear_store_screen.setup(self)
	connect_ui_signals()
	apply_settings_to_ui()
	set_run_ui_visible(false)
	update_debug_ui()
	show_main_menu()


func connect_ui_signals() -> void:
	health_component.health_changed.connect(_on_player_health_changed)
	player.debug_state_changed.connect(update_debug_ui)

	$UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/StartRunButton.pressed.connect(start_new_run)
	$UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/ContinueRunButton.pressed.connect(continue_saved_run)
	$UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/GearStoreButton.pressed.connect(open_gear_store)
	$UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/SettingsButton.pressed.connect(open_settings_from_main_menu)
	$UI/MainMenuScreen/ContentScroll/Content/ResetSaveButton.pressed.connect(reset_all_save_data)
	$UI/MainMenuScreen/ContentScroll/Content/PrimaryButtons/QuitButton.pressed.connect(save_and_quit_game)

	$UI/PauseMenuScreen/Panel/ResumeButton.pressed.connect(resume_run)
	$UI/PauseMenuScreen/Panel/SettingsButton.pressed.connect(open_settings_from_pause_menu)
	$UI/PauseMenuScreen/Panel/SaveQuitButton.pressed.connect(save_and_quit_game)
	room_event_primary_button.pressed.connect(_on_room_event_primary_button_pressed)
	room_event_secondary_button.pressed.connect(_on_room_event_secondary_button_pressed)
	room_event_tertiary_button.pressed.connect(_on_room_event_tertiary_button_pressed)

	$UI/SettingsScreen/BackButton.pressed.connect(close_settings_screen)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)

	$UI/GearStoreScreen/OuterMargin/MainVBox/Footer/BackRow/BackButton.pressed.connect(close_gear_store)
	starter_gold_button.pressed.connect(_on_starter_gold_button_pressed)
	rest_bonus_button.pressed.connect(_on_rest_bonus_button_pressed)
	luck_button.pressed.connect(_on_luck_button_pressed)


#input
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.is_action_pressed("dev_weapon_menu") or event.keycode == KEY_F6:
		if dev_weapon_screen.visible:
			close_developer_weapon_screen()
		else:
			open_developer_weapon_screen()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE:
		return

	if dev_weapon_screen.visible:
		close_developer_weapon_screen()
		get_viewport().set_input_as_handled()
		return

	if settings_screen.visible:
		close_settings_screen()
		get_viewport().set_input_as_handled()
		return

	if gear_store_screen.visible:
		close_gear_store()
		get_viewport().set_input_as_handled()
		return

	if room_event_screen.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_on_room_event_primary_button_pressed()
		elif event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			_on_room_event_tertiary_button_pressed()
		get_viewport().set_input_as_handled()
		return

	if main_menu_screen.visible or death_screen.visible or stage_transition_active:
		return

	if pause_menu_screen.visible:
		resume_run()
	else:
		open_pause_menu()

	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not room_event_screen.visible:
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_room_event_primary_button_pressed()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_1:
		_on_room_event_primary_button_pressed()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_2:
		_on_room_event_secondary_button_pressed()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_3:
		_on_room_event_tertiary_button_pressed()
		get_viewport().set_input_as_handled()
		return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if skill_tree != null:
			skill_tree.commit_pending_eligibility()
		save_progress()


func ensure_developer_input_action() -> void:
	if not InputMap.has_action("dev_weapon_menu"):
		InputMap.add_action("dev_weapon_menu")
	if InputMap.action_get_events("dev_weapon_menu").is_empty():
		var shortcut := InputEventKey.new()
		shortcut.keycode = KEY_F6
		InputMap.action_add_event("dev_weapon_menu", shortcut)


#save/load
func get_default_meta_progression() -> Dictionary:
	return {
		"essence": 0,
		"highest_stage_completed": 0,
		"skill_tree_version": 1,
		"purchased_skill_nodes": [],
		"tutorial_reward": {
			"claimed": false,
			"essence_granted": 0,
		},
		"pending_unlock_eligibility": [],
		"committed_unlock_eligibility": [],
		"legacy_skill_tree_bonuses": {
			"sword": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
			"spear": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
			"hammer": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
		},
		"weapon_unlocks": {
			"sword": true,
			"spear": false,
			"hammer": false,
		},
		"weapon_trees": {
			"sword": {
				"base_damage": 0,
				"special_damage": 0,
			},
			"spear": {
				"base_damage": 0,
				"special_damage": 0,
			},
			"hammer": {
				"base_damage": 0,
				"special_damage": 0,
			},
		},
		"gear": {
			"starter_gold": 0,
			"rest_bonus": 0,
			"luck": 0,
		},
		"settings": {
			"master_volume": 0.8,
		},
	}


func get_default_debuff_state() -> Dictionary:
	return {
		"attack_penalty": 0,
		"speed_penalty": 0.0,
		"rest_penalty": 0,
		"active_names": [],
	}


func ensure_meta_progression_shape() -> void:
	var defaults: Dictionary = get_default_meta_progression()
	if meta_progression.has("weapon_unlocks") and meta_progression["weapon_unlocks"].has("heavy") and not meta_progression["weapon_unlocks"].has("hammer"):
		meta_progression["weapon_unlocks"]["hammer"] = meta_progression["weapon_unlocks"]["heavy"]
	if meta_progression.has("weapon_trees") and meta_progression["weapon_trees"].has("heavy") and not meta_progression["weapon_trees"].has("hammer"):
		meta_progression["weapon_trees"]["hammer"] = meta_progression["weapon_trees"]["heavy"].duplicate(true)

	for key in defaults.keys():
		if not meta_progression.has(key):
			meta_progression[key] = defaults[key]

	for weapon_name in defaults["weapon_unlocks"].keys():
		if not meta_progression["weapon_unlocks"].has(weapon_name):
			meta_progression["weapon_unlocks"][weapon_name] = defaults["weapon_unlocks"][weapon_name]

	for weapon_name in defaults["weapon_trees"].keys():
		if not meta_progression["weapon_trees"].has(weapon_name):
			meta_progression["weapon_trees"][weapon_name] = defaults["weapon_trees"][weapon_name]
			continue

		for stat_name in defaults["weapon_trees"][weapon_name].keys():
			if not meta_progression["weapon_trees"][weapon_name].has(stat_name):
				meta_progression["weapon_trees"][weapon_name][stat_name] = defaults["weapon_trees"][weapon_name][stat_name]

	for gear_name in defaults["gear"].keys():
		if not meta_progression["gear"].has(gear_name):
			meta_progression["gear"][gear_name] = defaults["gear"][gear_name]

	for setting_name in defaults["settings"].keys():
		if not meta_progression["settings"].has(setting_name):
			meta_progression["settings"][setting_name] = defaults["settings"][setting_name]


func ensure_current_run_shape() -> void:
	if current_run.is_empty():
		return

	if not current_run.has("stage"):
		var saved_world: int = int(current_run.get("stage_world", 1))
		var saved_floor: int = int(current_run.get("stage_floor", 1))
		current_run["stage"] = ((saved_world - 1) * 3) + saved_floor

	if not current_run.has("stage_world"):
		current_run["stage_world"] = int((int(current_run.get("stage", 1)) - 1) / 3) + 1

	if not current_run.has("stage_floor"):
		current_run["stage_floor"] = int((int(current_run.get("stage", 1)) - 1) % 3) + 1

	current_run["weapon"] = WeaponRegistryScript.normalize_weapon_id(str(current_run.get("weapon", "sword")))
	if not current_run.has("weapon_cooldowns"):
		current_run["weapon_cooldowns"] = {}

	if not current_run.has("debuff_state"):
		current_run["debuff_state"] = get_default_debuff_state()
	else:
		var default_debuff_state: Dictionary = get_default_debuff_state()
		for key in default_debuff_state.keys():
			if not current_run["debuff_state"].has(key):
				current_run["debuff_state"][key] = default_debuff_state[key]

	if not current_run.has("stage_rooms"):
		return

	for room_index in current_run["stage_rooms"].size():
		current_run["stage_rooms"][room_index] = ensure_stage_room_shape(current_run["stage_rooms"][room_index])


func ensure_stage_room_shape(room_data: Dictionary) -> Dictionary:
	if not room_data.has("boss_reward_collected"):
		room_data["boss_reward_collected"] = false

	return room_data


func load_progress() -> void:
	meta_progression = get_default_meta_progression()
	current_run = {}
	loaded_legacy_skill_tree = false

	var config := ConfigFile.new()
	if config.load(SAVE_FILE_PATH) != OK:
		ensure_meta_progression_shape()
		return

	meta_progression = config.get_value("meta", "progression", meta_progression)
	loaded_legacy_skill_tree = not meta_progression.has("skill_tree_version")
	current_run = config.get_value("run", "snapshot", {})
	ensure_meta_progression_shape()
	ensure_current_run_shape()


func save_progress() -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "progression", meta_progression)
	config.set_value("run", "snapshot", build_run_snapshot())
	return config.save(SAVE_FILE_PATH)


func delete_save_file() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE_PATH))


func build_run_snapshot() -> Dictionary:
	if not run_active:
		return {"has_saved_run": false}

	return {
		"has_saved_run": true,
		"stage": current_stage,
		"stage_world": get_stage_world_number(),
		"stage_floor": get_stage_floor_number(),
		"room": current_room_number,
		"room_id": current_room_id,
		"start_room_id": start_room_id,
		"boss_room_id": boss_room_id,
		"stage_rooms": current_stage_rooms,
		"gold": current_run.get("gold", 0),
		"weapon": current_run.get("weapon", "sword"),
		"weapon_cooldowns": player.get_cooldown_snapshot(),
		"player_health": health_component.current_health,
		"debuff_state": current_run.get("debuff_state", get_default_debuff_state()),
	}


func clear_saved_run_snapshot() -> void:
	current_run = {}
	save_progress()


func apply_settings_to_ui() -> void:
	var volume_value: float = meta_progression["settings"]["master_volume"]
	volume_slider.value = volume_value
	apply_master_volume(volume_value)


func apply_master_volume(volume_value: float) -> void:
	var clamped_value: float = clampf(volume_value, 0.0, 1.0)
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index == -1:
		master_bus_index = 0

	AudioServer.set_bus_mute(master_bus_index, clamped_value <= 0.001)
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(max(clamped_value, 0.0001)))
	volume_value_label.text = str(roundi(clamped_value * 100.0)) + "%"


#menu ui
func show_main_menu() -> void:
	player.cancel_actions_for_modal()
	player.visible = false
	player.set_physics_process(false)
	main_menu_screen.visible = true
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	room_event_screen.visible = false
	dev_weapon_screen.visible = false
	get_tree().paused = false
	continue_run_button.visible = has_saved_run()
	continue_run_button.disabled = not has_saved_run()
	main_menu_status_label.text = get_main_menu_status_text()
	if main_menu_screen.has_method("focus_initial_control"):
		main_menu_screen.focus_initial_control()
	set_run_ui_visible(false)
	update_gear_store_ui()


func get_main_menu_status_text() -> String:
	if has_saved_run():
		return "Saved run available."
	return "Meta progression saves automatically."


func has_saved_run() -> bool:
	return current_run.get("has_saved_run", false)


func open_gear_store() -> void:
	previous_menu_context = "main_menu"
	main_menu_screen.visible = false
	settings_screen.visible = false
	gear_store_screen.visible = true
	update_gear_store_ui()
	if gear_store_screen.has_method("focus_first_control"):
		gear_store_screen.focus_first_control()


func close_gear_store() -> void:
	gear_store_screen.visible = false
	show_main_menu()


func open_settings_from_main_menu() -> void:
	previous_menu_context = "main_menu"
	main_menu_screen.visible = false
	settings_screen.visible = true


func open_settings_from_pause_menu() -> void:
	previous_menu_context = "pause_menu"
	pause_menu_screen.visible = false
	settings_screen.visible = true


func close_settings_screen() -> void:
	settings_screen.visible = false

	if previous_menu_context == "pause_menu" and run_active:
		pause_menu_screen.visible = true
	else:
		show_main_menu()


func open_pause_menu() -> void:
	if not run_active:
		return

	pause_menu_screen.visible = true
	update_pause_menu_info()
	get_tree().paused = true


func can_open_developer_weapon_screen() -> bool:
	return (
		dev_tools_enabled
		and run_active
		and not get_tree().paused
		and not death_screen.visible
		and not stage_transition_active
		and not room_event_screen.visible
		and not settings_screen.visible
		and not gear_store_screen.visible
		and not main_menu_screen.visible
		and not pause_menu_screen.visible
	)


func open_developer_weapon_screen() -> void:
	if not can_open_developer_weapon_screen():
		return
	dev_menu_previous_pause_state = get_tree().paused
	player.cancel_actions_for_modal()
	get_tree().paused = true
	dev_weapon_screen.open_screen()


func close_developer_weapon_screen() -> void:
	if not dev_weapon_screen.visible:
		return
	dev_weapon_screen.hide()
	get_tree().paused = dev_menu_previous_pause_state
	if run_active and not get_tree().paused:
		player.set_physics_process(true)


func get_weapon_ids() -> Array:
	return WeaponRegistryScript.get_weapon_ids()


func get_weapon_definition(weapon_id: String) -> Resource:
	return WeaponRegistryScript.get_definition(weapon_id)


func get_selected_weapon_id() -> String:
	return WeaponRegistryScript.normalize_weapon_id(str(current_run.get("weapon", "sword")))


func is_weapon_unlocked(weapon_id: String) -> bool:
	return skill_tree != null and skill_tree.is_weapon_owned(WeaponRegistryScript.normalize_weapon_id(weapon_id))


func get_skill_tree_core() -> SkillTreeService:
	return skill_tree


func purchase_skill_node(node_id: String) -> Dictionary:
	if skill_tree == null:
		return {"success": false, "node_id": node_id, "code": "not_ready", "reason": "Skill tree is not ready.", "essence": 0}
	return skill_tree.purchase(node_id)


func _apply_skill_tree_purchase_to_run() -> void:
	if run_active:
		apply_run_modifiers(player.developer_combat_bypass)
	update_debug_ui()


func _on_skill_tree_changed() -> void:
	update_gear_store_ui()


func equip_developer_weapon(weapon_id: String) -> void:
	if not dev_weapon_screen.visible or not run_active:
		return
	current_run["weapon"] = WeaponRegistryScript.normalize_weapon_id(weapon_id)
	apply_run_modifiers(true)
	save_progress()
	update_debug_ui()


func resume_run() -> void:
	pause_menu_screen.visible = false
	settings_screen.visible = false
	get_tree().paused = false


func update_pause_menu_info() -> void:
	pause_run_info_label.text = "Stage: %s\nRoom: %s/%s\nGold: %s\nWeapon: %s" % [
		str(current_stage),
		str(current_room_number),
		str(current_stage_rooms.size()),
		str(current_run.get("gold", 0)),
		str(current_run.get("weapon", "sword")),
	]


func save_and_quit_game() -> void:
	if skill_tree != null:
		skill_tree.commit_pending_eligibility()
	save_progress()
	get_tree().quit()


func complete_run() -> void:
	if skill_tree != null:
		skill_tree.commit_pending_eligibility()
	run_active = false
	clear_saved_run_snapshot()
	show_main_menu()


func reset_all_save_data() -> void:
	run_active = false
	current_stage = 1
	current_room_number = 0
	current_room_id = -1
	start_room_id = -1
	boss_room_id = -1
	current_stage_rooms = []
	clear_active_room()
	get_tree().paused = false
	meta_progression = get_default_meta_progression()
	current_run = {}
	loaded_legacy_skill_tree = false
	if skill_tree != null:
		skill_tree.setup(
			meta_progression,
			Callable(self, "save_progress"),
			Callable(self, "_apply_skill_tree_purchase_to_run"),
			false
		)
	save_progress()
	show_main_menu()


#meta progression
func can_afford_essence(cost: int) -> bool:
	return meta_progression["essence"] >= cost


func spend_essence(cost: int) -> void:
	meta_progression["essence"] -= cost
	save_progress()
	update_gear_store_ui()


func update_gear_store_ui() -> void:
	if gear_store_screen.has_method("refresh_ui"):
		gear_store_screen.refresh_ui()
	else:
		gear_store_essence_label.text = "Essence: " + str(skill_tree.get_essence_balance() if skill_tree != null else meta_progression["essence"])

	var starter_gold_level: int = meta_progression["gear"]["starter_gold"]
	var starter_gold_cost: int = 4 + starter_gold_level * 2
	starter_gold_button.text = "Gold %s | %sE" % [to_roman(starter_gold_level + 1), str(starter_gold_cost)]
	starter_gold_button.tooltip_text = "Starter Gold %s (%s Essence)" % [to_roman(starter_gold_level + 1), str(starter_gold_cost)]
	starter_gold_button.disabled = not can_afford_essence(starter_gold_cost)

	var rest_bonus_level: int = meta_progression["gear"]["rest_bonus"]
	var rest_bonus_cost: int = 4 + rest_bonus_level * 2
	rest_bonus_button.text = "Rest %s | %sE" % [to_roman(rest_bonus_level + 1), str(rest_bonus_cost)]
	rest_bonus_button.tooltip_text = "Rest Heal Bonus %s (%s Essence)" % [to_roman(rest_bonus_level + 1), str(rest_bonus_cost)]
	rest_bonus_button.disabled = not can_afford_essence(rest_bonus_cost)

	var luck_level: int = meta_progression["gear"]["luck"]
	var luck_cost: int = 4 + luck_level * 2
	luck_button.text = "Luck %s | %sE" % [to_roman(luck_level + 1), str(luck_cost)]
	luck_button.tooltip_text = "Lucky Charm %s (%s Essence)" % [to_roman(luck_level + 1), str(luck_cost)]
	luck_button.disabled = not can_afford_essence(luck_cost)


func to_roman(value: int) -> String:
	var numerals := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	if value <= 0:
		return "0"
	if value > numerals.size():
		return str(value)
	return numerals[value - 1]


func _on_starter_gold_button_pressed() -> void:
	var level: int = meta_progression["gear"]["starter_gold"]
	var cost: int = 4 + level * 2
	if not can_afford_essence(cost):
		return
	meta_progression["gear"]["starter_gold"] += 1
	spend_essence(cost)


func _on_rest_bonus_button_pressed() -> void:
	var level: int = meta_progression["gear"]["rest_bonus"]
	var cost: int = 4 + level * 2
	if not can_afford_essence(cost):
		return
	meta_progression["gear"]["rest_bonus"] += 1
	spend_essence(cost)


func _on_luck_button_pressed() -> void:
	var level: int = meta_progression["gear"]["luck"]
	var cost: int = 4 + level * 2
	if not can_afford_essence(cost):
		return
	meta_progression["gear"]["luck"] += 1
	spend_essence(cost)


func _on_volume_slider_value_changed(new_value: float) -> void:
	meta_progression["settings"]["master_volume"] = new_value
	apply_master_volume(new_value)
	save_progress()


#run setup
func start_new_run() -> void:
	get_tree().paused = false
	enemy_container.process_mode = Node.PROCESS_MODE_INHERIT
	run_active = true
	stage_transition_active = false
	main_menu_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	room_event_screen.visible = false
	dev_weapon_screen.visible = false
	player.reset_for_run(true)
	player.visible = true
	player.set_physics_process(true)
	player.move_speed = default_player_move_speed
	health_component.max_health = default_player_max_health
	clear_active_room()
	current_stage = 1
	current_room_number = 0
	current_stage_rooms = []
	current_run = {
		"has_saved_run": true,
		"stage": 1,
		"stage_world": 1,
		"stage_floor": 1,
		"gold": get_starting_gold(),
		"weapon": "sword",
		"weapon_cooldowns": {},
		"debuff_state": get_default_debuff_state(),
	}
	apply_run_modifiers()
	health_component.reset_health()
	set_run_ui_visible(true)
	update_debug_ui()
	start_stage()


func continue_saved_run() -> void:
	if not has_saved_run():
		return

	get_tree().paused = false
	enemy_container.process_mode = Node.PROCESS_MODE_INHERIT
	run_active = true
	stage_transition_active = false
	main_menu_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	dev_weapon_screen.visible = false
	player.reset_for_run(true)
	player.visible = true
	player.set_physics_process(true)
	player.move_speed = default_player_move_speed
	health_component.max_health = default_player_max_health
	clear_active_room()

	var saved_world: int = int(current_run.get("stage_world", 1))
	var saved_floor: int = int(current_run.get("stage_floor", 1))
	current_stage = int(current_run.get("stage", ((saved_world - 1) * 3) + saved_floor))
	current_room_number = int(current_run.get("room", 1))
	current_room_id = int(current_run.get("room_id", -1))
	start_room_id = int(current_run.get("start_room_id", -1))
	boss_room_id = int(current_run.get("boss_room_id", current_run.get("exit_room_id", -1)))
	current_stage_rooms = current_run.get("stage_rooms", [])
	ensure_current_run_shape()
	player.set_cooldown_snapshot(current_run.get("weapon_cooldowns", {}))
	if current_stage_rooms.is_empty():
		current_stage_rooms = build_stage_graph()
		current_room_number = 0
		current_room_id = -1
		boss_room_id = -1
		start_room_id = -1

	var saved_health: int = int(current_run.get("player_health", health_component.max_health))
	apply_run_modifiers()
	health_component.current_health = clampi(saved_health, 0, health_component.max_health)
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	set_run_ui_visible(true)
	update_debug_ui()
	start_stage()


func get_starting_gold() -> int:
	return meta_progression["gear"]["starter_gold"] * 3


func apply_run_modifiers(developer_bypass: bool = false) -> void:
	var weapon_name: String = WeaponRegistryScript.normalize_weapon_id(str(current_run.get("weapon", "sword")))
	if not developer_bypass and (skill_tree == null or not skill_tree.is_weapon_owned(weapon_name)):
		weapon_name = "sword"
	current_run["weapon"] = player.equip_weapon(weapon_name)
	player.set_developer_combat_bypass(developer_bypass)
	var weapon_definition: Resource = WeaponRegistryScript.get_definition(weapon_name)
	var stat_profile: Dictionary = skill_tree.get_stat_profile(weapon_name) if skill_tree != null else {}
	var debuff_state: Dictionary = current_run.get("debuff_state", get_default_debuff_state())
	var attack_penalty: float = float(debuff_state.get("attack_penalty", 0))
	var speed_penalty: float = float(debuff_state.get("speed_penalty", 0.0))

	# Immutable weapon/player bases -> migrated flat value -> weapon multiplier ->
	# summed character multiplier -> existing flat run debuff -> final clamp/rounding.
	var character_damage_multiplier := 1.0 + float(stat_profile.get("character_damage_bonus", 0.0))
	var basic_before_debuff := (
		(float(weapon_definition.basic_attack.base_damage) + float(stat_profile.get("legacy_basic_damage_flat", 0.0)))
		* (1.0 + float(stat_profile.get("basic_damage_bonus", 0.0)))
		* character_damage_multiplier
	)
	var special_before_debuff := (
		(float(weapon_definition.special_attack.base_damage) + float(stat_profile.get("legacy_special_damage_flat", 0.0)))
		* (1.0 + float(stat_profile.get("special_damage_bonus", 0.0)))
		* character_damage_multiplier
	)
	var effective_basic: float = maxf(basic_before_debuff - attack_penalty, 1.0)
	var effective_special: float = maxf(special_before_debuff - attack_penalty, 1.0)
	player.set_effective_attack_damage(effective_basic, effective_special)
	player.set_effective_weapon_modifiers(
		1.0 + float(stat_profile.get("basic_reach_bonus", 0.0)),
		1.0 + float(stat_profile.get("basic_width_bonus", 0.0)),
		1.0 + float(stat_profile.get("basic_area_bonus", 0.0)),
		int(stat_profile.get("basic_target_limit_add", 0)),
		1.0 + float(stat_profile.get("special_cooldown_bonus", 0.0)),
		bool(stat_profile.get("special_unlocked", false))
	)
	player.move_speed = maxf(
		default_player_move_speed * (1.0 + float(stat_profile.get("character_move_speed_bonus", 0.0))) - speed_penalty,
		60.0
	)
	var previous_health := health_component.current_health
	health_component.max_health = maxi(roundi(
		float(default_player_max_health) * (1.0 + float(stat_profile.get("character_max_health_bonus", 0.0)))
	), 1)
	health_component.current_health = mini(previous_health, health_component.max_health)
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)


func add_run_gold(amount: int) -> void:
	current_run["gold"] = current_run.get("gold", 0) + amount
	update_debug_ui()


func spend_run_gold(amount: int) -> bool:
	var current_gold: int = int(current_run.get("gold", 0))
	if current_gold < amount:
		return false

	current_run["gold"] = current_gold - amount
	update_debug_ui()
	return true


#debug ui
func set_run_ui_visible(is_visible: bool) -> void:
	health_label.visible = is_visible
	gold_label.visible = is_visible
	weapon_label.visible = is_visible
	state_label.visible = is_visible
	multiplier_label.visible = is_visible
	damage_label.visible = is_visible
	stage_label.visible = is_visible
	room_label.visible = is_visible
	room_type_label.visible = is_visible
	stage_map_label.visible = is_visible


func update_debug_ui() -> void:
	health_label.text = "HP: " + str(health_component.current_health) + "/" + str(health_component.max_health)
	gold_label.text = "Gold: " + str(current_run.get("gold", 0))
	var weapon_definition: Resource = WeaponRegistryScript.get_definition(get_selected_weapon_id())
	var special_status := "Locked"
	if player.special_unlocked or player.developer_combat_bypass:
		special_status = "Ready" if player.get_special_cooldown_left() <= 0.0 else "%.1fs" % player.get_special_cooldown_left()
	weapon_label.text = "Weapon: %s | Special: %s" % [weapon_definition.display_name, special_status]
	state_label.text = "State: " + get_player_state_text()
	multiplier_label.text = "Multiplier: " + str(player.get_damage_multiplier())
	damage_label.text = "Last Damage: %s (x%s sampled)" % [player.last_damage_dealt, player.sampled_movement_multiplier]
	stage_label.text = "Stage: " + get_stage_display_text()
	room_label.text = "Room: " + str(current_room_number) + "/" + str(current_stage_rooms.size())
	room_type_label.text = "Room Type: " + get_current_room_type_text()
	stage_map_label.text = get_stage_map_text()

	if pause_menu_screen.visible:
		update_pause_menu_info()


func get_player_state_text() -> String:
	match player.action_state:
		player.ActionState.BASIC_ATTACK:
			return "basic attack"
		player.ActionState.SPECIAL_ATTACK:
			return "special attack"
		player.ActionState.HURT:
			return "hurt"
		player.ActionState.DEAD:
			return "dead"
	match player.movement_state:
		player.MovementState.DASHING:
			return "dashing"
		player.MovementState.WALKING:
			return "walking"
		_:
			return "stationary"


#stage flow
func start_stage() -> void:
	var spawn_room_id: int = current_room_id
	if current_stage_rooms.is_empty():
		current_stage_rooms = build_stage_graph()

	instantiate_stage_graph()

	if spawn_room_id == -1:
		spawn_room_id = get_start_room_id()

	current_room_id = spawn_room_id
	var spawn_room: StageRoom = get_room_node(current_room_id)
	if spawn_room == null:
		current_room_id = get_start_room_id()
		spawn_room = get_room_node(current_room_id)

	if spawn_room != null:
		player.global_position = spawn_room.get_player_spawn_position()

	call_deferred("refresh_current_room_from_player_position")


func build_stage_graph() -> Array[Dictionary]:
	var regular_combat_room_count: int = get_regular_combat_room_count()
	var debuff_room_count: int = get_stage_debuff_room_count()
	var required_path_room_count: int = regular_combat_room_count + reward_rooms_per_stage + rest_rooms_per_stage + 1
	var required_room_count: int = 1 + required_path_room_count + debuff_room_count
	var total_room_count: int = max(stage_grid_room_count, required_room_count)
	var best_stage_rooms: Array[Dictionary] = []
	var best_path_ids: Array[int] = []

	for _attempt in 24:
		var grid_positions: Array[Vector2i] = generate_connected_grid_positions(total_room_count)
		var stage_rooms: Array[Dictionary] = build_stage_rooms_from_positions(grid_positions)
		var candidate_start_room_id: int = choose_outer_start_room_id(stage_rooms)
		var candidate_boss_room_id: int = get_farthest_leaf_room_id(stage_rooms, candidate_start_room_id)
		var critical_path_ids: Array[int] = get_path_room_ids(stage_rooms, candidate_start_room_id, candidate_boss_room_id)

		if critical_path_ids.size() > best_path_ids.size():
			best_stage_rooms = stage_rooms
			best_path_ids = critical_path_ids.duplicate()
			start_room_id = candidate_start_room_id
			boss_room_id = candidate_boss_room_id

		if critical_path_ids.size() - 1 >= required_path_room_count:
			best_stage_rooms = stage_rooms
			best_path_ids = critical_path_ids.duplicate()
			start_room_id = candidate_start_room_id
			boss_room_id = candidate_boss_room_id
			break

	current_stage_rooms = best_stage_rooms
	assign_room_types(current_stage_rooms, best_path_ids, regular_combat_room_count, debuff_room_count)
	reveal_room(get_start_room_id())
	reveal_connected_rooms(get_start_room_id())
	return current_stage_rooms


func build_stage_rooms_from_positions(grid_positions: Array[Vector2i]) -> Array[Dictionary]:
	var position_to_id: Dictionary = {}

	for position_index in grid_positions.size():
		position_to_id[grid_positions[position_index]] = position_index

	var stage_rooms: Array[Dictionary] = []
	for room_index in grid_positions.size():
		var room_grid_position: Vector2i = grid_positions[room_index]
		var connection_directions: Array[String] = []
		var neighbor_ids: Array[int] = []

		for direction in get_cardinal_directions():
			var neighbor_position: Vector2i = room_grid_position + get_direction_offset(direction)
			if not position_to_id.has(neighbor_position):
				continue

			connection_directions.append(direction)
			neighbor_ids.append(int(position_to_id[neighbor_position]))

		stage_rooms.append({
			"id": room_index,
			"grid_x": room_grid_position.x,
			"grid_y": room_grid_position.y,
			"room_type": RoomType.COMBAT,
			"visited": false,
			"revealed": false,
			"completed": false,
			"initialized": false,
			"connections": connection_directions,
			"neighbors": neighbor_ids,
			"enemies_remaining": 0,
			"boss_reward_collected": false,
		})

	return stage_rooms


func get_stage_debuff_room_count() -> int:
	if not is_replay_stage():
		return 0

	var min_debuff_rooms: int = min(replay_debuff_rooms_min, replay_debuff_rooms_max)
	var max_debuff_rooms: int = max(replay_debuff_rooms_min, replay_debuff_rooms_max)
	return randi_range(min_debuff_rooms, max_debuff_rooms)


func get_stage_world_number() -> int:
	return int((current_stage - 1) / 3) + 1


func get_stage_floor_number() -> int:
	return int((current_stage - 1) % 3) + 1


func get_stage_display_text(stage_number: int = current_stage) -> String:
	var world_number: int = int((stage_number - 1) / 3) + 1
	var floor_number: int = int((stage_number - 1) % 3) + 1
	return "%s-%s" % [str(world_number), str(floor_number)]


func get_regular_combat_room_count() -> int:
	var world_number: int = get_stage_world_number()
	var min_regular_combat_rooms: int = stage_one_combat_min
	var max_regular_combat_rooms: int = stage_one_combat_max

	if world_number == 2:
		max_regular_combat_rooms += 1
	elif world_number >= 3:
		min_regular_combat_rooms += 1
		max_regular_combat_rooms += 2

	return randi_range(min_regular_combat_rooms, max_regular_combat_rooms)


func generate_connected_grid_positions(room_count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = [Vector2i.ZERO]
	var used_positions: Dictionary = {Vector2i.ZERO: true}
	var max_grid_radius_x: int = 4
	var max_grid_radius_y: int = 3

	while positions.size() < room_count:
		var candidate_positions: Array[Vector2i] = []
		var candidate_scores: Array[float] = []

		for anchor in positions:
			for direction in get_cardinal_directions():
				var candidate: Vector2i = anchor + get_direction_offset(direction)
				if used_positions.has(candidate):
					continue
				if abs(candidate.x) > max_grid_radius_x or abs(candidate.y) > max_grid_radius_y:
					continue
				if candidate_positions.has(candidate):
					continue
				if get_adjacent_room_count(candidate, positions) > 1:
					continue

				candidate_positions.append(candidate)
				candidate_scores.append(score_growth_candidate(candidate, positions))

		if candidate_positions.is_empty():
			var fallback_position := Vector2i(positions.size(), 0)
			used_positions[fallback_position] = true
			positions.append(fallback_position)
			continue

		var next_position: Vector2i = pick_weighted_grid_position(candidate_positions, candidate_scores)
		used_positions[next_position] = true
		positions.append(next_position)

	return positions


func score_growth_candidate(candidate: Vector2i, existing_positions: Array[Vector2i]) -> float:
	var side_room_count: int = get_direction_density(candidate, existing_positions)
	var local_neighbor_count: int = get_adjacent_room_count(candidate, existing_positions)
	var outward_distance: int = abs(candidate.x) + abs(candidate.y)
	return max(1.0 + float(outward_distance) * 0.75 - float(side_room_count) * 0.9 - float(local_neighbor_count) * 0.6, 0.2)


func get_direction_density(candidate: Vector2i, existing_positions: Array[Vector2i]) -> int:
	var density: int = 0

	for position in existing_positions:
		if candidate.x > 0 and position.x > 0:
			density += 1
		elif candidate.x < 0 and position.x < 0:
			density += 1
		elif candidate.y > 0 and position.y > 0:
			density += 1
		elif candidate.y < 0 and position.y < 0:
			density += 1

	return density


func get_adjacent_room_count(candidate: Vector2i, existing_positions: Array[Vector2i]) -> int:
	var existing_lookup: Dictionary = {}
	for position in existing_positions:
		existing_lookup[position] = true

	var neighbor_count: int = 0
	for direction in get_cardinal_directions():
		if existing_lookup.has(candidate + get_direction_offset(direction)):
			neighbor_count += 1

	return neighbor_count


func pick_weighted_grid_position(candidate_positions: Array[Vector2i], candidate_scores: Array[float]) -> Vector2i:
	var total_score: float = 0.0
	for score in candidate_scores:
		total_score += score

	if total_score <= 0.0:
		return candidate_positions.pick_random()

	var roll: float = randf() * total_score
	for index in candidate_positions.size():
		roll -= candidate_scores[index]
		if roll <= 0.0:
			return candidate_positions[index]

	return candidate_positions.back()


func get_cardinal_directions() -> Array[String]:
	return ["north", "south", "west", "east"]


func get_direction_offset(direction: String) -> Vector2i:
	match direction:
		"north":
			return Vector2i(0, -1)
		"south":
			return Vector2i(0, 1)
		"west":
			return Vector2i(-1, 0)
		"east":
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO


func get_opposite_direction(direction: String) -> String:
	match direction:
		"north":
			return "south"
		"south":
			return "north"
		"west":
			return "east"
		"east":
			return "west"
		_:
			return ""


func get_start_room_id() -> int:
	if start_room_id != -1:
		return start_room_id

	for room_data in current_stage_rooms:
		if room_data.get("room_type", RoomType.COMBAT) as RoomType == RoomType.START:
			return int(room_data["id"])

	return 0


func choose_outer_start_room_id(stage_rooms: Array[Dictionary]) -> int:
	if stage_rooms.is_empty():
		return 0

	var min_x: int = int(stage_rooms[0]["grid_x"])
	var max_x: int = min_x
	var min_y: int = int(stage_rooms[0]["grid_y"])
	var max_y: int = min_y

	for room_data in stage_rooms:
		min_x = min(min_x, int(room_data["grid_x"]))
		max_x = max(max_x, int(room_data["grid_x"]))
		min_y = min(min_y, int(room_data["grid_y"]))
		max_y = max(max_y, int(room_data["grid_y"]))

	var outer_room_ids: Array[int] = []
	for room_data in stage_rooms:
		var grid_x: int = int(room_data["grid_x"])
		var grid_y: int = int(room_data["grid_y"])
		if grid_x == min_x or grid_x == max_x or grid_y == min_y or grid_y == max_y:
			outer_room_ids.append(int(room_data["id"]))

	if outer_room_ids.is_empty():
		return 0

	var outer_leaf_room_ids: Array[int] = []
	for outer_room_id in outer_room_ids:
		if int(stage_rooms[outer_room_id]["neighbors"].size()) <= 1:
			outer_leaf_room_ids.append(outer_room_id)

	var supported_outer_leaf_room_ids: Array[int] = []
	for outer_leaf_room_id in outer_leaf_room_ids:
		if has_premade_scene_for_room_data(stage_rooms[outer_leaf_room_id], RoomType.START):
			supported_outer_leaf_room_ids.append(outer_leaf_room_id)

	if not supported_outer_leaf_room_ids.is_empty():
		return supported_outer_leaf_room_ids.pick_random()

	if not outer_leaf_room_ids.is_empty():
		return outer_leaf_room_ids.pick_random()

	return outer_room_ids.pick_random()


func get_farthest_room_id(stage_rooms: Array[Dictionary], start_room_id: int) -> int:
	var queue: Array[int] = [start_room_id]
	var visited_rooms: Dictionary = {start_room_id: true}
	var distances: Dictionary = {start_room_id: 0}
	var farthest_room_id: int = start_room_id

	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		var room_data: Dictionary = stage_rooms[room_id]
		var room_distance: int = int(distances[room_id])
		if room_distance > int(distances.get(farthest_room_id, 0)):
			farthest_room_id = room_id

		for neighbor_id in room_data["neighbors"]:
			if visited_rooms.has(neighbor_id):
				continue

			visited_rooms[neighbor_id] = true
			distances[neighbor_id] = room_distance + 1
			queue.append(neighbor_id)

	return farthest_room_id


func get_farthest_leaf_room_id(stage_rooms: Array[Dictionary], start_room_id: int) -> int:
	var queue: Array[int] = [start_room_id]
	var visited_rooms: Dictionary = {start_room_id: true}
	var distances: Dictionary = {start_room_id: 0}
	var leaf_room_ids: Array[int] = []

	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		var room_data: Dictionary = stage_rooms[room_id]
		if int(room_data["neighbors"].size()) <= 1 and room_id != start_room_id:
			leaf_room_ids.append(room_id)

		for neighbor_id in room_data["neighbors"]:
			if visited_rooms.has(neighbor_id):
				continue

			visited_rooms[neighbor_id] = true
			distances[neighbor_id] = int(distances[room_id]) + 1
			queue.append(neighbor_id)

	if leaf_room_ids.is_empty():
		return get_farthest_room_id(stage_rooms, start_room_id)

	var best_leaf_room_id: int = leaf_room_ids[0]
	for leaf_room_id in leaf_room_ids:
		if int(distances.get(leaf_room_id, 0)) > int(distances.get(best_leaf_room_id, 0)):
			best_leaf_room_id = leaf_room_id

	return best_leaf_room_id


func get_path_room_ids(stage_rooms: Array[Dictionary], start_id: int, end_id: int) -> Array[int]:
	var queue: Array[int] = [start_id]
	var visited_rooms: Dictionary = {start_id: true}
	var previous_room_by_id: Dictionary = {}

	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		if room_id == end_id:
			break

		for neighbor_id in stage_rooms[room_id]["neighbors"]:
			if visited_rooms.has(neighbor_id):
				continue

			visited_rooms[neighbor_id] = true
			previous_room_by_id[neighbor_id] = room_id
			queue.append(neighbor_id)

	if not visited_rooms.has(end_id):
		return [start_id, end_id]

	var path_room_ids: Array[int] = [end_id]
	var current_path_room_id: int = end_id
	while current_path_room_id != start_id:
		current_path_room_id = int(previous_room_by_id[current_path_room_id])
		path_room_ids.push_front(current_path_room_id)

	return path_room_ids


func assign_room_types(stage_rooms: Array[Dictionary], critical_path_ids: Array[int], regular_combat_room_count: int, debuff_room_count: int) -> void:
	for room_index in stage_rooms.size():
		stage_rooms[room_index]["room_type"] = RoomType.COMBAT
		stage_rooms[room_index]["completed"] = false

	stage_rooms[get_start_room_id()]["room_type"] = RoomType.START
	stage_rooms[get_start_room_id()]["completed"] = true

	var path_room_ids: Array[int] = []
	for path_index in range(1, critical_path_ids.size()):
		path_room_ids.append(int(critical_path_ids[path_index]))

	if path_room_ids.is_empty():
		return

	var stage_boss_room_id: int = path_room_ids.back()
	stage_rooms[stage_boss_room_id]["room_type"] = RoomType.BOSS

	var first_combat_room_id: int = path_room_ids[0]
	if first_combat_room_id != stage_boss_room_id:
		stage_rooms[first_combat_room_id]["room_type"] = RoomType.COMBAT

	var middle_room_ids: Array[int] = []
	for middle_index in range(1, max(path_room_ids.size() - 1, 1)):
		if middle_index >= path_room_ids.size() - 1:
			break
		middle_room_ids.append(int(path_room_ids[middle_index]))

	var middle_room_types: Array = []
	for _combat_index in max(regular_combat_room_count - 1, 0):
		middle_room_types.append(RoomType.COMBAT)
	for _reward_index in reward_rooms_per_stage:
		middle_room_types.append(RoomType.REWARD)
	for _rest_index in rest_rooms_per_stage:
		middle_room_types.append(RoomType.REST)

	while middle_room_types.size() < middle_room_ids.size():
		middle_room_types.append(RoomType.COMBAT)

	middle_room_types = shuffle_middle_room_types(middle_room_types)

	for middle_room_index in min(middle_room_ids.size(), middle_room_types.size()):
		stage_rooms[middle_room_ids[middle_room_index]]["room_type"] = middle_room_types[middle_room_index]

	var critical_room_lookup: Dictionary = {}
	for path_room_id in critical_path_ids:
		critical_room_lookup[int(path_room_id)] = true

	var side_room_ids: Array[int] = []
	for room_data in stage_rooms:
		var room_id: int = int(room_data["id"])
		if critical_room_lookup.has(room_id):
			continue
		side_room_ids.append(room_id)

	side_room_ids.shuffle()

	for debuff_index in min(debuff_room_count, side_room_ids.size()):
		stage_rooms[side_room_ids[debuff_index]]["room_type"] = RoomType.DEBUFF


func instantiate_stage_graph() -> void:
	clear_active_room()

	hallway_container = Node2D.new()
	hallway_container.name = "HallwayContainer"
	room_container.add_child(hallway_container)
	stage_room_nodes = {}

	for room_data in current_stage_rooms:
		var room_scene: PackedScene = get_room_scene_for_room(room_data)
		var room_instance := room_scene.instantiate() as StageRoom
		room_container.add_child(room_instance)
		room_instance.global_position = grid_to_world_position(get_room_grid_position(room_data))
		room_instance.configure(
			int(room_data["id"]),
			get_current_room_type_text_from_value(room_data["room_type"] as RoomType),
			room_data["connections"]
		)
		room_instance.room_entered.connect(_on_generated_room_entered)
		room_instance.reward_interaction_requested.connect(_on_reward_interaction_requested)
		room_instance.stage_exit_requested.connect(_on_stage_exit_requested)
		stage_room_nodes[int(room_data["id"])] = room_instance

	draw_stage_hallways()
	update_stage_room_visuals()


func get_room_scene_for_room(room_data: Dictionary) -> PackedScene:
	var connection_folder_name: String = get_connection_folder_name(room_data["connections"])
	var stage_folder_name: String = "stage_%s" % str(get_stage_world_number())
	var scene_candidates: Array[PackedScene] = get_room_scene_candidates(
		stage_folder_name,
		room_data["room_type"] as RoomType,
		connection_folder_name
	)

	if scene_candidates.is_empty():
		return DEFAULT_ROOM_SCENE

	return scene_candidates.pick_random()


func has_premade_scene_for_room_data(room_data: Dictionary, room_type: RoomType) -> bool:
	var connection_folder_name: String = get_connection_folder_name(room_data["connections"])
	var stage_folder_name: String = "stage_%s" % str(get_stage_world_number())
	return not get_room_scene_candidates(stage_folder_name, room_type, connection_folder_name).is_empty()


func get_room_scene_candidates(stage_folder_name: String, room_type: RoomType, connection_folder_name: String) -> Array[PackedScene]:
	var room_type_folder_names: Array[String] = get_room_type_folder_candidates(room_type)

	for room_type_folder in room_type_folder_names:
		var folder_path: String = "res://rooms/premade/%s/%s/%s" % [stage_folder_name, room_type_folder, connection_folder_name]
		var scene_candidates: Array[PackedScene] = get_packed_scenes_in_folder(folder_path)
		if not scene_candidates.is_empty():
			return scene_candidates

	return []


func get_room_type_folder_candidates(room_type: RoomType) -> Array[String]:
	var primary_folder_name: String = get_room_type_folder_name(room_type)

	match room_type:
		RoomType.BOSS, RoomType.REWARD, RoomType.REST:
			return [primary_folder_name, "combat"]
		_:
			return [primary_folder_name]


func get_connection_folder_name(connection_directions: Array) -> String:
	var normalized_connections: Array[String] = []
	for direction in connection_directions:
		normalized_connections.append(str(direction))
	normalized_connections.sort()

	if normalized_connections.is_empty():
		return "isolated"

	return "_".join(PackedStringArray(normalized_connections))


func get_room_type_folder_name(room_type: RoomType) -> String:
	match room_type:
		RoomType.START:
			return "start"
		RoomType.BOSS:
			return "boss"
		RoomType.REWARD:
			return "reward"
		RoomType.REST:
			return "rest"
		RoomType.DEBUFF:
			return "debuff"
		_:
			return "combat"


func get_packed_scenes_in_folder(folder_path: String) -> Array[PackedScene]:
	var packed_scenes: Array[PackedScene] = []
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return packed_scenes

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension() == "tscn":
			var scene_path: String = folder_path.path_join(file_name)
			var scene_resource := load(scene_path)
			if scene_resource is PackedScene:
				packed_scenes.append(scene_resource)
		file_name = directory.get_next()
	directory.list_dir_end()

	return packed_scenes


func clear_active_room() -> void:
	for enemy in enemy_container.get_children():
		enemy.queue_free()

	for room_child in room_container.get_children():
		room_child.queue_free()

	stage_room_nodes.clear()
	hallway_container = null
	current_room = null
	current_room_id = -1
	remaining_room_enemies = 0
	hide_room_event()


func grid_to_world_position(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position.x * room_world_spacing.x, grid_position.y * room_world_spacing.y)


func get_room_grid_position(room_data: Dictionary) -> Vector2i:
	return Vector2i(int(room_data["grid_x"]), int(room_data["grid_y"]))


func draw_stage_hallways() -> void:
	for room_data in current_stage_rooms:
		var room_id: int = int(room_data["id"])
		var room_node: StageRoom = get_room_node(room_id)
		if room_node == null:
			continue

		var connection_directions: Array = room_data["connections"]
		var neighbor_ids: Array = room_data["neighbors"]
		for connection_index in connection_directions.size():
			var neighbor_id: int = int(neighbor_ids[connection_index])
			if room_id > neighbor_id:
				continue

			var direction: String = str(connection_directions[connection_index])
			var neighbor_node: StageRoom = get_room_node(neighbor_id)
			if neighbor_node == null:
				continue

			create_hallway(
				room_node.get_door_world_position(direction),
				neighbor_node.get_door_world_position(get_opposite_direction(direction))
			)


func create_hallway(start_position: Vector2, end_position: Vector2) -> void:
	var hallway_shadow := Line2D.new()
	hallway_shadow.default_color = Color(0.08, 0.08, 0.1, 1.0)
	hallway_shadow.width = 48.0
	hallway_shadow.add_point(start_position)
	hallway_shadow.add_point(end_position)
	hallway_container.add_child(hallway_shadow)

	var hallway_floor := Line2D.new()
	hallway_floor.default_color = Color(0.58, 0.58, 0.62, 1.0)
	hallway_floor.width = 30.0
	hallway_floor.add_point(start_position)
	hallway_floor.add_point(end_position)
	hallway_container.add_child(hallway_floor)


func refresh_current_room_from_player_position() -> void:
	var active_room: StageRoom = get_room_node(current_room_id)
	if active_room == null:
		active_room = get_room_node(get_start_room_id())

	if active_room != null:
		call_deferred("_on_generated_room_entered", active_room)


func _on_generated_room_entered(room: StageRoom) -> void:
	current_room = room
	current_room_id = room.room_id
	current_room_number = current_room_id + 1

	var room_data: Dictionary = get_room_data_by_id(current_room_id)
	var first_visit: bool = not room_data.get("visited", false)
	if first_visit:
		room_data["visited"] = true
		reveal_connected_rooms(current_room_id)

	set_room_data_by_id(room_data)
	handle_room_entry(room_data)
	update_stage_room_visuals()
	update_debug_ui()


func handle_room_entry(room_data: Dictionary) -> void:
	var room_type: RoomType = room_data["room_type"] as RoomType
	var room_node: StageRoom = get_room_node(int(room_data["id"]))
	if room_node == null:
		return

	match room_type:
		RoomType.START:
			room_data["completed"] = true
			room_node.hide_reward_interactable()
			room_node.hide_stage_exit()
			room_node.set_connected_doors_locked(false)
			room_node.set_room_label("Start Room")
		RoomType.COMBAT:
			room_node.hide_stage_exit()
			room_node.set_connected_doors_locked(not room_data.get("completed", false))
			if not room_data.get("initialized", false):
				room_data["initialized"] = true
				set_room_data_by_id(room_data)
				call_deferred("spawn_room_enemies", int(room_data["id"]))
			if room_data.get("completed", false):
				room_node.set_room_label("Combat Clear")
		RoomType.BOSS:
			room_node.set_connected_doors_locked(not room_data.get("completed", false))
			if not room_data.get("completed", false) and not room_data.get("initialized", false):
				room_data["initialized"] = true
				set_room_data_by_id(room_data)
				call_deferred("spawn_room_enemies", int(room_data["id"]))
			if room_data.get("completed", false):
				if room_data.get("boss_reward_collected", false):
					room_node.hide_reward_interactable()
					room_node.show_stage_exit("Press E\nEnter Portal")
					room_node.set_room_label("Boss Cleared")
				else:
					room_node.show_reward_interactable("Press E\nOpen Chest")
					room_node.hide_stage_exit()
					room_node.set_room_label("Boss Defeated")
			else:
				room_node.hide_reward_interactable()
				room_node.hide_stage_exit()
				room_node.set_room_label("Boss Room")
		RoomType.REWARD:
			room_node.hide_stage_exit()
			room_node.set_connected_doors_locked(false)
			if room_data.get("completed", false):
				room_node.hide_reward_interactable()
				room_node.set_room_label("Reward Taken")
			else:
				room_node.show_reward_interactable("Press E\nChoose Reward")
		RoomType.REST:
			if not room_data.get("initialized", false):
				apply_rest_room_effect()
				room_data["initialized"] = true
				room_data["completed"] = true
			room_node.hide_reward_interactable()
			room_node.hide_stage_exit()
			room_node.set_connected_doors_locked(false)
			room_node.set_room_label("Rest Room")
		RoomType.DEBUFF:
			if not room_data.get("initialized", false):
				room_data["initialized"] = true
				show_debuff_room_event()
			room_node.hide_reward_interactable()
			room_node.hide_stage_exit()
			room_node.set_connected_doors_locked(false)
			room_node.set_room_label("Debuff Room")


func apply_rest_room_effect() -> void:
	var previous_health: int = health_component.current_health
	var debuff_state: Dictionary = current_run.get("debuff_state", get_default_debuff_state())
	var heal_amount: int = rest_room_heal_amount + meta_progression["gear"]["rest_bonus"] - int(debuff_state.get("rest_penalty", 0))
	heal_amount = max(heal_amount, 0)
	health_component.heal(heal_amount)
	var healed_amount: int = health_component.current_health - previous_health

	if current_room != null:
		if healed_amount > 0:
			current_room.set_room_label("Rested +" + str(healed_amount) + " HP")
		else:
			current_room.set_room_label("Rested 0 HP")


func show_debuff_room_event() -> void:
	var debuff_data: Dictionary = apply_random_stage_debuff()
	show_room_event(
		"Debuff Applied",
		"%s\n\n%s\n\nActive debuffs: %s" % [
			debuff_data.get("title", "Debuff"),
			debuff_data.get("description", ""),
			get_active_debuff_text(),
		],
		"Continue",
		RoomEventType.DEBUFF_NOTICE
	)


func spawn_room_enemies(room_id: int) -> void:
	var room_node: StageRoom = get_room_node(room_id)
	if room_node == null:
		return

	var room_data: Dictionary = get_room_data_by_id(room_id)
	var enemy_spawn_positions: Array[Vector2] = room_node.get_enemy_spawn_positions()
	var enemy_count: int = get_enemy_count_for_room(room_id, enemy_spawn_positions.size())
	room_data["enemies_remaining"] = enemy_count
	set_room_data_by_id(room_data)

	if enemy_count == 0:
		mark_room_completed(room_id)
		return

	var room_enemy_scene: PackedScene = get_enemy_scene_for_room(room_data)
	for enemy_index in enemy_count:
		var enemy = room_enemy_scene.instantiate()
		enemy_container.add_child(enemy)
		enemy.global_position = enemy_spawn_positions[enemy_index]
		enemy.set_meta("room_id", room_id)

		var enemy_health: HealthComponent = enemy.get_node("Health")
		enemy_health.died.connect(_on_room_enemy_died.bind(room_id))


func get_enemy_count_for_room(room_id: int, max_spawn_count: int) -> int:
	if max_spawn_count <= 0:
		return 0

	var target_room_data: Dictionary = get_room_data_by_id(room_id)
	if target_room_data.is_empty():
		return 0

	var combat_index: int = 1
	for room_data in current_stage_rooms:
		if int(room_data["id"]) == room_id:
			break
		var room_type: RoomType = room_data["room_type"] as RoomType
		if room_type == RoomType.COMBAT or room_type == RoomType.BOSS:
			combat_index += 1

	var current_room_type: RoomType = target_room_data["room_type"] as RoomType
	if current_room_type == RoomType.BOSS:
		return max_spawn_count

	var scaled_enemy_count: int = current_stage + combat_index - 1
	return clampi(scaled_enemy_count, 1, max_spawn_count)


func get_enemy_scene_for_room(room_data: Dictionary) -> PackedScene:
	var room_type: RoomType = room_data["room_type"] as RoomType
	if room_type != RoomType.COMBAT:
		return enemy_scene

	var stage_world: int = get_stage_world_number()
	var stage_floor: int = get_stage_floor_number()
	var highest_stage_completed: int = int(meta_progression.get("highest_stage_completed", 0))
	var has_cleared_stage_1_1_before: bool = highest_stage_completed >= 1

	if stage_world == 1 and stage_floor == 1 and not has_cleared_stage_1_1_before:
		return TRAINING_DUMMY_2_SCENE

	if stage_world == 1 and stage_floor >= 2 and stage_floor <= 3:
		return GOBLIN_BARREL_SCENE

	if stage_world == 1 and stage_floor == 1 and has_cleared_stage_1_1_before:
		return GOBLIN_BARREL_SCENE

	return enemy_scene


func get_room_node(room_id: int) -> StageRoom:
	return stage_room_nodes.get(room_id, null) as StageRoom


func get_room_data_by_id(room_id: int) -> Dictionary:
	for room_data in current_stage_rooms:
		if int(room_data["id"]) == room_id:
			return room_data

	return {}


func set_room_data_by_id(updated_room_data: Dictionary) -> void:
	for room_index in current_stage_rooms.size():
		if int(current_stage_rooms[room_index]["id"]) == int(updated_room_data["id"]):
			current_stage_rooms[room_index] = updated_room_data
			return


func get_current_room_data() -> Dictionary:
	return get_room_data_by_id(current_room_id)


func get_current_room_type() -> RoomType:
	var room_data: Dictionary = get_current_room_data()
	if room_data.is_empty():
		return RoomType.START

	return room_data["room_type"] as RoomType


func mark_room_completed(room_id: int) -> void:
	var room_data: Dictionary = get_room_data_by_id(room_id)
	if room_data.is_empty():
		return

	room_data["completed"] = true
	set_room_data_by_id(room_data)
	update_stage_room_visuals()
	update_debug_ui()


func mark_current_room_completed() -> void:
	mark_room_completed(current_room_id)


func get_current_room_type_text() -> String:
	return get_current_room_type_text_from_value(get_current_room_type())


func get_current_room_type_text_from_value(room_type: RoomType) -> String:
	match room_type:
		RoomType.START:
			return "start"
		RoomType.BOSS:
			return "boss"
		RoomType.REWARD:
			return "reward"
		RoomType.REST:
			return "rest"
		RoomType.DEBUFF:
			return "debuff"
		_:
			return "combat"


func get_stage_map_text() -> String:
	if not run_active or current_stage_rooms.is_empty():
		return ""

	var min_x: int = 0
	var max_x: int = 0
	var min_y: int = 0
	var max_y: int = 0
	var room_lookup: Dictionary = {}

	for room_data in current_stage_rooms:
		var grid_position: Vector2i = get_room_grid_position(room_data)
		min_x = min(min_x, grid_position.x)
		max_x = max(max_x, grid_position.x)
		min_y = min(min_y, grid_position.y)
		max_y = max(max_y, grid_position.y)
		room_lookup[grid_position] = room_data

	var row_texts: Array[String] = []
	for grid_y in range(min_y, max_y + 1):
		var row_parts: Array[String] = []
		for grid_x in range(min_x, max_x + 1):
			var grid_position := Vector2i(grid_x, grid_y)
			if not room_lookup.has(grid_position):
				row_parts.append("   ")
				continue

			var room_data: Dictionary = room_lookup[grid_position]
			var room_id: int = int(room_data["id"])
			var room_text: String = "?"
			if room_id == current_room_id or room_data.get("visited", false) or is_room_connected_to_current(room_id):
				room_text = get_room_type_short_text(room_data["room_type"] as RoomType)

			if room_id == current_room_id:
				room_parts_append(row_parts, "[" + room_text + "]")
			elif room_data.get("visited", false):
				room_parts_append(row_parts, " " + room_text + " ")
			elif is_room_connected_to_current(room_id):
				room_parts_append(row_parts, "(" + room_text + ")")
			else:
				room_parts_append(row_parts, " ? ")

		row_texts.append("".join(PackedStringArray(row_parts)))

	return "Map:\n" + "\n".join(PackedStringArray(row_texts))


func room_parts_append(parts: Array[String], value: String) -> void:
	parts.append(value)


func is_room_connected_to_current(room_id: int) -> bool:
	if current_room_id == -1 or room_id == current_room_id:
		return false

	var current_room_data: Dictionary = get_current_room_data()
	if current_room_data.is_empty():
		return false

	for neighbor_id in current_room_data.get("neighbors", []):
		if int(neighbor_id) == room_id:
			return true

	return false


func shuffle_middle_room_types(room_types: Array) -> Array:
	var shuffled_room_types: Array = room_types.duplicate()

	for _attempt in 20:
		shuffled_room_types.shuffle()
		var has_connected_reward_and_rest: bool = false

		for room_index in range(shuffled_room_types.size() - 1):
			var current_room_type: RoomType = shuffled_room_types[room_index]
			var next_room_type: RoomType = shuffled_room_types[room_index + 1]
			if (current_room_type == RoomType.REWARD and next_room_type == RoomType.REST) or (current_room_type == RoomType.REST and next_room_type == RoomType.REWARD):
				has_connected_reward_and_rest = true
				break

		if not has_connected_reward_and_rest:
			return shuffled_room_types

	return shuffled_room_types


func get_room_type_short_text(room_type: RoomType) -> String:
	match room_type:
		RoomType.START:
			return "S"
		RoomType.BOSS:
			return "B"
		RoomType.REWARD:
			return "R"
		RoomType.REST:
			return "H"
		RoomType.DEBUFF:
			return "D"
		_:
			return "C"


func update_stage_room_visuals() -> void:
	for room_data in current_stage_rooms:
		var room_node: StageRoom = get_room_node(int(room_data["id"]))
		if room_node == null:
			continue

		room_node.set_room_state(
			int(room_data["id"]) == current_room_id,
			room_data.get("visited", false),
			room_data.get("revealed", false)
		)


func reveal_room(room_id: int) -> void:
	var room_data: Dictionary = get_room_data_by_id(room_id)
	if room_data.is_empty():
		return

	room_data["revealed"] = true
	set_room_data_by_id(room_data)


func reveal_connected_rooms(room_id: int) -> void:
	reveal_room(room_id)
	var room_data: Dictionary = get_room_data_by_id(room_id)
	for neighbor_id in room_data.get("neighbors", []):
		reveal_room(int(neighbor_id))


func start_stage_transition() -> void:
	meta_progression["highest_stage_completed"] = max(int(meta_progression.get("highest_stage_completed", 0)), current_stage)
	if skill_tree != null:
		skill_tree.record_stage_clear(current_stage)
	else:
		save_progress()
	stage_transition_active = true
	stage_transition_label.text = "Stage %s Complete\nStage %s Starting..." % [
		get_stage_display_text(current_stage),
		get_stage_display_text(current_stage + 1),
	]
	stage_transition_screen.visible = true
	player.cancel_actions_for_modal()
	player.set_physics_process(false)
	call_deferred("finish_stage_transition")


func finish_stage_transition() -> void:
	await get_tree().create_timer(stage_transition_duration).timeout

	stage_transition_screen.visible = false
	current_stage += 1
	current_stage_rooms = []
	current_room_id = -1
	start_room_id = -1
	boss_room_id = -1
	clear_active_room()
	stage_transition_active = false
	player.set_physics_process(true)
	start_stage()


func _on_room_enemy_died(room_id: int) -> void:
	var room_data: Dictionary = get_room_data_by_id(room_id)
	if room_data.is_empty():
		return

	room_data["enemies_remaining"] = max(int(room_data.get("enemies_remaining", 0)) - 1, 0)
	set_room_data_by_id(room_data)

	if int(room_data["enemies_remaining"]) == 0:
		on_combat_room_cleared(room_id)


func on_combat_room_cleared(room_id: int) -> void:
	current_room_id = room_id
	current_room = get_room_node(room_id)
	if get_current_room_type() == RoomType.BOSS:
		var boss_data: Dictionary = get_current_room_data()
		boss_data["completed"] = true
		boss_data["enemies_remaining"] = 0
		set_room_data_by_id(boss_data)
		if current_room != null:
			current_room.set_connected_doors_locked(false)
			current_room.show_reward_interactable("Press E\nOpen Chest")
			current_room.hide_stage_exit()
			current_room.set_room_label("Boss Defeated")
		update_stage_room_visuals()
		update_debug_ui()
		return

	show_room_event(
		"Combat Cleared",
		"Room reward:\n+%s Gold" % str(combat_clear_gold_reward),
		"Collect",
		RoomEventType.COMBAT_REWARD
	)


func is_current_room_completed() -> bool:
	var room_data: Dictionary = get_current_room_data()
	if room_data.is_empty():
		return false

	return room_data.get("completed", false)


func is_replay_stage() -> bool:
	return int(meta_progression.get("highest_stage_completed", 0)) >= current_stage


func get_active_debuff_text() -> String:
	var debuff_state: Dictionary = current_run.get("debuff_state", get_default_debuff_state())
	var active_names: Array = debuff_state.get("active_names", [])
	if active_names.is_empty():
		return "None"

	var debuff_names: Array[String] = []
	for active_name in active_names:
		debuff_names.append(str(active_name))

	return ", ".join(PackedStringArray(debuff_names))


func get_random_debuff_data() -> Dictionary:
	var debuff_pool: Array[Dictionary] = [
		{
			"id": "heavy_steps",
			"title": "Heavy Steps",
			"description": "Your movement speed is reduced for the rest of this run.",
			"speed_penalty": 15.0,
		},
		{
			"id": "blunted_edge",
			"title": "Blunted Edge",
			"description": "Your base attack damage is reduced for the rest of this run.",
			"attack_penalty": 1,
		},
		{
			"id": "cold_camp",
			"title": "Cold Camp",
			"description": "Rest rooms heal less for the rest of this run.",
			"rest_penalty": 1,
		},
	]

	return debuff_pool.pick_random()


func apply_random_stage_debuff() -> Dictionary:
	ensure_current_run_shape()

	var debuff_data: Dictionary = get_random_debuff_data()
	var debuff_state: Dictionary = current_run.get("debuff_state", get_default_debuff_state())
	debuff_state["attack_penalty"] = int(debuff_state.get("attack_penalty", 0)) + int(debuff_data.get("attack_penalty", 0))
	debuff_state["speed_penalty"] = float(debuff_state.get("speed_penalty", 0.0)) + float(debuff_data.get("speed_penalty", 0.0))
	debuff_state["rest_penalty"] = int(debuff_state.get("rest_penalty", 0)) + int(debuff_data.get("rest_penalty", 0))

	var active_names: Array = debuff_state.get("active_names", [])
	active_names.append(debuff_data.get("title", "Debuff"))
	debuff_state["active_names"] = active_names
	current_run["debuff_state"] = debuff_state

	apply_run_modifiers(player.developer_combat_bypass)
	update_debug_ui()
	return debuff_data


func show_room_event(
	title: String,
	body: String,
	primary_text: String,
	room_event_type: RoomEventType,
	secondary_text: String = "",
	tertiary_text: String = "",
) -> void:
	room_event_title_label.text = title
	room_event_body_label.text = body
	room_event_status_label.text = ""

	room_event_primary_button.text = primary_text
	room_event_primary_button.disabled = false
	room_event_primary_button.focus_mode = Control.FOCUS_ALL
	room_event_secondary_button.visible = not secondary_text.is_empty()
	room_event_secondary_button.text = secondary_text
	room_event_secondary_button.disabled = false
	room_event_secondary_button.focus_mode = Control.FOCUS_ALL
	room_event_tertiary_button.visible = not tertiary_text.is_empty()
	room_event_tertiary_button.text = tertiary_text
	room_event_tertiary_button.disabled = false
	room_event_tertiary_button.focus_mode = Control.FOCUS_ALL

	current_room_event_type = room_event_type

	room_event_screen.visible = true
	if run_active:
		player.cancel_actions_for_modal()
		player.set_physics_process(false)

	room_event_primary_button.grab_focus()


func hide_room_event() -> void:
	room_event_screen.visible = false
	room_event_status_label.text = ""
	current_room_event_type = RoomEventType.NONE

	if run_active and not stage_transition_active and not get_tree().paused and death_screen.visible == false:
		player.set_physics_process(true)


func _on_room_event_primary_button_pressed() -> void:
	if not room_event_screen.visible:
		return

	match current_room_event_type:
		RoomEventType.COMBAT_REWARD:
			_on_combat_reward_collected()
		RoomEventType.BOSS_CHEST_REWARD:
			_on_boss_chest_reward_collected()
		RoomEventType.REWARD_CHOICE:
			_on_reward_room_free_reward_pressed()
		RoomEventType.DEBUFF_NOTICE:
			_on_debuff_room_continue_pressed()


func _on_room_event_secondary_button_pressed() -> void:
	if not room_event_screen.visible:
		return
	if current_room_event_type == RoomEventType.REWARD_CHOICE:
		_on_reward_room_buy_healing_pressed()


func _on_room_event_tertiary_button_pressed() -> void:
	if not room_event_screen.visible:
		return
	if current_room_event_type == RoomEventType.REWARD_CHOICE:
		_on_reward_room_leave_pressed()


func _on_reward_interaction_requested(room: StageRoom) -> void:
	current_room = room
	current_room_id = room.room_id
	if current_room == null:
		return
	if get_current_room_type() == RoomType.BOSS:
		var boss_room_data: Dictionary = get_current_room_data()
		if boss_room_data.get("completed", false) and not boss_room_data.get("boss_reward_collected", false):
			current_room.hide_reward_interactable()
			show_room_event(
				"Boss Chest",
				"Boss reward:\n+%s Gold" % str(combat_clear_gold_reward),
				"Open Chest",
				RoomEventType.BOSS_CHEST_REWARD
			)
		return
	if get_current_room_type() != RoomType.REWARD:
		return
	if is_current_room_completed():
		return

	current_room.hide_reward_interactable()
	show_room_event(
		"Reward Room",
		"Choose one reward.\n\nFree: +1 Gold\nBuy: Heal %s HP for %s Gold" % [
			str(reward_room_buy_heal_amount),
			str(reward_room_buy_heal_cost),
		],
		"Take Free Reward",
		RoomEventType.REWARD_CHOICE,
		"Buy Healing",
		"Leave",
	)


func resolve_reward_room(exit_text: String) -> void:
	hide_room_event()
	mark_current_room_completed()
	if current_room != null:
		current_room.hide_reward_interactable()
		current_room.set_room_label(exit_text)


func _on_reward_room_free_reward_pressed() -> void:
	add_run_gold(1)
	resolve_reward_room("Reward Claimed\nExit")


func _on_reward_room_buy_healing_pressed() -> void:
	if not spend_run_gold(reward_room_buy_heal_cost):
		room_event_status_label.text = "Not enough gold."
		return

	health_component.heal(reward_room_buy_heal_amount)
	resolve_reward_room("Healing Bought\nExit")


func _on_reward_room_leave_pressed() -> void:
	resolve_reward_room("Skipped Reward\nExit")


func _on_combat_reward_collected() -> void:
	add_run_gold(combat_clear_gold_reward)
	hide_room_event()
	mark_current_room_completed()
	if current_room != null:
		current_room.set_connected_doors_locked(false)
		current_room.set_room_label("Combat Clear")


func _on_boss_chest_reward_collected() -> void:
	add_run_gold(combat_clear_gold_reward)
	hide_room_event()

	var room_data: Dictionary = get_current_room_data()
	if room_data.is_empty():
		return

	room_data["boss_reward_collected"] = true
	room_data["completed"] = true
	set_room_data_by_id(room_data)

	if current_room != null:
		current_room.hide_reward_interactable()
		current_room.show_stage_exit("Press E\nEnter Portal")
		current_room.set_room_label("Boss Cleared")

	update_stage_room_visuals()
	update_debug_ui()


func _on_debuff_room_continue_pressed() -> void:
	hide_room_event()
	mark_current_room_completed()
	if current_room != null:
		current_room.set_room_label("Debuff Applied")


func _on_stage_exit_requested(room: StageRoom) -> void:
	current_room = room
	current_room_id = room.room_id
	if current_room_id != boss_room_id:
		return
	var room_data: Dictionary = get_current_room_data()
	if room_data.is_empty():
		return
	if not room_data.get("completed", false):
		return
	if not room_data.get("boss_reward_collected", false):
		return

	start_stage_transition()


#player death
func _on_player_death_started() -> void:
	close_developer_weapon_screen()
	enemy_container.process_mode = Node.PROCESS_MODE_DISABLED


func _on_player_died() -> void:
	if skill_tree != null:
		skill_tree.commit_pending_eligibility()
	run_active = false
	clear_saved_run_snapshot()
	call_deferred("show_death_screen")


func show_death_screen() -> void:
	death_screen.visible = true
	get_tree().paused = true


func trigger_hit_stop() -> void:
	if hit_stop_active:
		return

	hit_stop_active = true
	Engine.time_scale = hit_stop_scale

	await get_tree().create_timer(hit_stop_duration, true, false, true).timeout

	Engine.time_scale = 1.0
	hit_stop_active = false


#health ui
func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "HP: " + str(current_health) + "/" + str(max_health)


#restart
func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	start_new_run()
