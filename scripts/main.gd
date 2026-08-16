extends Node2D

const DEFAULT_ROOM_SCENE := preload("res://rooms/test_room.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://enemies/enemy.tscn")
const SAVE_FILE_PATH := "user://savegame.cfg"

enum RoomType {
	COMBAT,
	REWARD,
	REST,
	DEBUFF,
}

@export var available_room_scenes: Array[PackedScene] = [DEFAULT_ROOM_SCENE]
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var base_combat_rooms_per_stage: int = 5
@export var reward_rooms_per_stage: int = 1
@export var rest_rooms_per_stage: int = 1
@export var rest_room_heal_amount: int = 3

@onready var player: CharacterBody2D = $Player
@onready var room_container: Node2D = $RoomContainer
@onready var enemy_container: Node2D = $EnemyContainer
@onready var health_component: HealthComponent = $Player/Health
@onready var death_screen: Control = $UI/DeathScreen
@onready var stage_transition_screen: Control = $UI/StageTransitionScreen
@onready var stage_transition_label: Label = $UI/StageTransitionScreen/StageTransitionLabel
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
@onready var main_menu_status_label: Label = $UI/MainMenuScreen/MenuStatusLabel
@onready var continue_run_button: Button = $UI/MainMenuScreen/ContinueRunButton
@onready var reset_save_button: Button = $UI/MainMenuScreen/ResetSaveButton
@onready var gear_store_essence_label: Label = $UI/GearStoreScreen/EssenceLabel
@onready var gear_store_info_label: Label = $UI/GearStoreScreen/StoreInfoLabel
@onready var pause_run_info_label: Label = $UI/PauseMenuScreen/Panel/RunInfoLabel
@onready var volume_slider: HSlider = $UI/SettingsScreen/VolumeSlider
@onready var volume_value_label: Label = $UI/SettingsScreen/VolumeValueLabel
@onready var unlock_spear_button: Button = $UI/GearStoreScreen/UnlockSpearButton
@onready var sword_damage_button: Button = $UI/GearStoreScreen/SwordDamageButton
@onready var sword_special_button: Button = $UI/GearStoreScreen/SwordSpecialButton
@onready var spear_damage_button: Button = $UI/GearStoreScreen/SpearDamageButton
@onready var spear_special_button: Button = $UI/GearStoreScreen/SpearSpecialButton
@onready var starter_gold_button: Button = $UI/GearStoreScreen/StarterGoldButton
@onready var rest_bonus_button: Button = $UI/GearStoreScreen/RestBonusButton
@onready var luck_button: Button = $UI/GearStoreScreen/LuckButton

var hit_stop_active: bool = false
var hit_stop_duration: float = 0.01
var hit_stop_scale: float = 0.05
var stage_transition_duration: float = 1.2
var current_stage: int = 1
var current_room_number: int = 0
var current_stage_rooms: Array[Dictionary] = []
var remaining_room_enemies: int = 0
var current_room: StageRoom = null
var stage_transition_active: bool = false
var run_active: bool = false
var previous_menu_context: String = "main_menu"
var default_player_base_attack_damage: int = 0
var default_player_move_speed: float = 0.0
var meta_progression: Dictionary = {}
var current_run: Dictionary = {}


#start
func _ready() -> void:
	default_player_base_attack_damage = player.base_attack_damage
	default_player_move_speed = player.move_speed

	player.visible = false
	player.set_physics_process(false)
	death_screen.visible = false
	stage_transition_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false

	load_progress()
	connect_ui_signals()
	apply_settings_to_ui()
	set_run_ui_visible(false)
	update_debug_ui()
	show_main_menu()


func connect_ui_signals() -> void:
	health_component.health_changed.connect(_on_player_health_changed)
	player.debug_state_changed.connect(update_debug_ui)

	$UI/MainMenuScreen/StartRunButton.pressed.connect(start_new_run)
	$UI/MainMenuScreen/ContinueRunButton.pressed.connect(continue_saved_run)
	$UI/MainMenuScreen/GearStoreButton.pressed.connect(open_gear_store)
	$UI/MainMenuScreen/SettingsButton.pressed.connect(open_settings_from_main_menu)
	$UI/MainMenuScreen/ResetSaveButton.pressed.connect(reset_all_save_data)
	$UI/MainMenuScreen/QuitButton.pressed.connect(save_and_quit_game)

	$UI/PauseMenuScreen/Panel/ResumeButton.pressed.connect(resume_run)
	$UI/PauseMenuScreen/Panel/SettingsButton.pressed.connect(open_settings_from_pause_menu)
	$UI/PauseMenuScreen/Panel/SaveQuitButton.pressed.connect(save_and_quit_game)

	$UI/SettingsScreen/BackButton.pressed.connect(close_settings_screen)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)

	$UI/GearStoreScreen/BackButton.pressed.connect(close_gear_store)
	unlock_spear_button.pressed.connect(_on_unlock_spear_button_pressed)
	sword_damage_button.pressed.connect(_on_sword_damage_button_pressed)
	sword_special_button.pressed.connect(_on_sword_special_button_pressed)
	spear_damage_button.pressed.connect(_on_spear_damage_button_pressed)
	spear_special_button.pressed.connect(_on_spear_special_button_pressed)
	starter_gold_button.pressed.connect(_on_starter_gold_button_pressed)
	rest_bonus_button.pressed.connect(_on_rest_bonus_button_pressed)
	luck_button.pressed.connect(_on_luck_button_pressed)


#input
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return

	if settings_screen.visible:
		close_settings_screen()
		get_viewport().set_input_as_handled()
		return

	if gear_store_screen.visible:
		close_gear_store()
		get_viewport().set_input_as_handled()
		return

	if main_menu_screen.visible or death_screen.visible or stage_transition_active:
		return

	if pause_menu_screen.visible:
		resume_run()
	else:
		open_pause_menu()

	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()


#save/load
func get_default_meta_progression() -> Dictionary:
	return {
		"essence": 20,
		"weapon_unlocks": {
			"sword": true,
			"spear": false,
			"heavy": false,
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
			"heavy": {
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


func ensure_meta_progression_shape() -> void:
	var defaults: Dictionary = get_default_meta_progression()

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


func load_progress() -> void:
	meta_progression = get_default_meta_progression()
	current_run = {}

	var config := ConfigFile.new()
	if config.load(SAVE_FILE_PATH) != OK:
		ensure_meta_progression_shape()
		return

	meta_progression = config.get_value("meta", "progression", meta_progression)
	current_run = config.get_value("run", "snapshot", {})
	ensure_meta_progression_shape()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "progression", meta_progression)
	config.set_value("run", "snapshot", build_run_snapshot())
	config.save(SAVE_FILE_PATH)


func delete_save_file() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE_PATH))


func build_run_snapshot() -> Dictionary:
	if not run_active:
		return {"has_saved_run": false}

	return {
		"has_saved_run": true,
		"stage": current_stage,
		"room": current_room_number,
		"stage_rooms": current_stage_rooms,
		"gold": current_run.get("gold", 0),
		"weapon": current_run.get("weapon", "sword"),
		"player_health": health_component.current_health,
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
	main_menu_screen.visible = true
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	get_tree().paused = false
	continue_run_button.visible = has_saved_run()
	continue_run_button.disabled = not has_saved_run()
	main_menu_status_label.text = get_main_menu_status_text()
	set_run_ui_visible(false)
	update_gear_store_ui()


func get_main_menu_status_text() -> String:
	if has_saved_run():
		return "Saved run available.\nYou can continue your last run."
	return "Placeholder main menu.\nMeta progression saves automatically."


func has_saved_run() -> bool:
	return current_run.get("has_saved_run", false)


func open_gear_store() -> void:
	previous_menu_context = "main_menu"
	main_menu_screen.visible = false
	settings_screen.visible = false
	gear_store_screen.visible = true
	update_gear_store_ui()


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
	save_progress()
	get_tree().quit()


func reset_all_save_data() -> void:
	run_active = false
	current_stage = 1
	current_room_number = 0
	current_stage_rooms = []
	clear_active_room()
	get_tree().paused = false
	meta_progression = get_default_meta_progression()
	current_run = {}
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
	gear_store_essence_label.text = "Essence: " + str(meta_progression["essence"])
	gear_store_info_label.text = "Permanent meta progression.\nWeapon trees stay between runs."

	var unlock_spear_cost: int = 10
	if meta_progression["weapon_unlocks"]["spear"]:
		unlock_spear_button.text = "Unlock Spear (Unlocked)"
		unlock_spear_button.disabled = true
	else:
		unlock_spear_button.text = "Unlock Spear (%s Essence)" % str(unlock_spear_cost)
		unlock_spear_button.disabled = not can_afford_essence(unlock_spear_cost)

	var sword_base_level: int = meta_progression["weapon_trees"]["sword"]["base_damage"]
	var sword_base_cost: int = 5 + sword_base_level * 3
	sword_damage_button.text = "Sword Base Damage %s (%s Essence)" % [to_roman(sword_base_level + 1), str(sword_base_cost)]
	sword_damage_button.disabled = not can_afford_essence(sword_base_cost)

	var sword_special_level: int = meta_progression["weapon_trees"]["sword"]["special_damage"]
	var sword_special_cost: int = 6 + sword_special_level * 3
	sword_special_button.text = "Sword Special Damage %s (%s Essence)" % [to_roman(sword_special_level + 1), str(sword_special_cost)]
	sword_special_button.disabled = not can_afford_essence(sword_special_cost)

	var spear_unlocked: bool = meta_progression["weapon_unlocks"]["spear"]
	var spear_base_level: int = meta_progression["weapon_trees"]["spear"]["base_damage"]
	var spear_base_cost: int = 5 + spear_base_level * 3
	spear_damage_button.text = "Spear Base Damage %s (%s Essence)" % [to_roman(spear_base_level + 1), str(spear_base_cost)]
	spear_damage_button.disabled = (not spear_unlocked) or (not can_afford_essence(spear_base_cost))

	var spear_special_level: int = meta_progression["weapon_trees"]["spear"]["special_damage"]
	var spear_special_cost: int = 6 + spear_special_level * 3
	spear_special_button.text = "Spear Special Damage %s (%s Essence)" % [to_roman(spear_special_level + 1), str(spear_special_cost)]
	spear_special_button.disabled = (not spear_unlocked) or (not can_afford_essence(spear_special_cost))

	var starter_gold_level: int = meta_progression["gear"]["starter_gold"]
	var starter_gold_cost: int = 4 + starter_gold_level * 2
	starter_gold_button.text = "Starter Gold %s (%s Essence)" % [to_roman(starter_gold_level + 1), str(starter_gold_cost)]
	starter_gold_button.disabled = not can_afford_essence(starter_gold_cost)

	var rest_bonus_level: int = meta_progression["gear"]["rest_bonus"]
	var rest_bonus_cost: int = 4 + rest_bonus_level * 2
	rest_bonus_button.text = "Rest Heal Bonus %s (%s Essence)" % [to_roman(rest_bonus_level + 1), str(rest_bonus_cost)]
	rest_bonus_button.disabled = not can_afford_essence(rest_bonus_cost)

	var luck_level: int = meta_progression["gear"]["luck"]
	var luck_cost: int = 4 + luck_level * 2
	luck_button.text = "Lucky Charm %s (%s Essence)" % [to_roman(luck_level + 1), str(luck_cost)]
	luck_button.disabled = not can_afford_essence(luck_cost)


func to_roman(value: int) -> String:
	var numerals := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	if value <= 0:
		return "0"
	if value > numerals.size():
		return str(value)
	return numerals[value - 1]


func _on_unlock_spear_button_pressed() -> void:
	var cost: int = 10
	if not can_afford_essence(cost):
		return
	meta_progression["weapon_unlocks"]["spear"] = true
	spend_essence(cost)


func _on_sword_damage_button_pressed() -> void:
	var level: int = meta_progression["weapon_trees"]["sword"]["base_damage"]
	var cost: int = 5 + level * 3
	if not can_afford_essence(cost):
		return
	meta_progression["weapon_trees"]["sword"]["base_damage"] += 1
	spend_essence(cost)


func _on_sword_special_button_pressed() -> void:
	var level: int = meta_progression["weapon_trees"]["sword"]["special_damage"]
	var cost: int = 6 + level * 3
	if not can_afford_essence(cost):
		return
	meta_progression["weapon_trees"]["sword"]["special_damage"] += 1
	spend_essence(cost)


func _on_spear_damage_button_pressed() -> void:
	if not meta_progression["weapon_unlocks"]["spear"]:
		return
	var level: int = meta_progression["weapon_trees"]["spear"]["base_damage"]
	var cost: int = 5 + level * 3
	if not can_afford_essence(cost):
		return
	meta_progression["weapon_trees"]["spear"]["base_damage"] += 1
	spend_essence(cost)


func _on_spear_special_button_pressed() -> void:
	if not meta_progression["weapon_unlocks"]["spear"]:
		return
	var level: int = meta_progression["weapon_trees"]["spear"]["special_damage"]
	var cost: int = 6 + level * 3
	if not can_afford_essence(cost):
		return
	meta_progression["weapon_trees"]["spear"]["special_damage"] += 1
	spend_essence(cost)


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
	run_active = true
	stage_transition_active = false
	main_menu_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	player.visible = true
	player.set_physics_process(true)
	player.base_attack_damage = default_player_base_attack_damage
	player.move_speed = default_player_move_speed
	health_component.reset_health()
	clear_active_room()
	current_stage = 1
	current_room_number = 0
	current_stage_rooms = []
	current_run = {
		"has_saved_run": true,
		"gold": get_starting_gold(),
		"weapon": "sword",
	}
	apply_meta_progression_to_current_weapon()
	set_run_ui_visible(true)
	update_debug_ui()
	start_stage()


func continue_saved_run() -> void:
	if not has_saved_run():
		return

	get_tree().paused = false
	run_active = true
	stage_transition_active = false
	main_menu_screen.visible = false
	gear_store_screen.visible = false
	settings_screen.visible = false
	pause_menu_screen.visible = false
	death_screen.visible = false
	stage_transition_screen.visible = false
	player.visible = true
	player.set_physics_process(true)
	player.base_attack_damage = default_player_base_attack_damage
	player.move_speed = default_player_move_speed
	clear_active_room()

	current_stage = int(current_run.get("stage", 1))
	current_room_number = int(current_run.get("room", 1)) - 1
	current_stage_rooms = current_run.get("stage_rooms", [])
	if current_stage_rooms.is_empty():
		current_stage_rooms = build_stage_room_queue()
		current_room_number = 0

	health_component.reset_health()
	var saved_health: int = int(current_run.get("player_health", health_component.max_health))
	health_component.current_health = clampi(saved_health, 0, health_component.max_health)
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)

	apply_meta_progression_to_current_weapon()
	set_run_ui_visible(true)
	update_debug_ui()
	load_next_room()


func get_starting_gold() -> int:
	return meta_progression["gear"]["starter_gold"] * 3


func apply_meta_progression_to_current_weapon() -> void:
	var weapon_name: String = current_run.get("weapon", "sword")
	var weapon_damage_bonus: int = meta_progression["weapon_trees"][weapon_name]["base_damage"]
	player.base_attack_damage = default_player_base_attack_damage + weapon_damage_bonus


func add_run_gold(amount: int) -> void:
	current_run["gold"] = current_run.get("gold", 0) + amount
	update_debug_ui()


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
	weapon_label.text = "Weapon: " + str(current_run.get("weapon", "sword"))
	state_label.text = "State: " + get_player_state_text()
	multiplier_label.text = "Multiplier: " + str(player.get_damage_multiplier())
	damage_label.text = "Last Damage: " + str(player.last_damage_dealt)
	stage_label.text = "Stage: " + str(current_stage)
	room_label.text = "Room: " + str(current_room_number) + "/" + str(current_stage_rooms.size())
	room_type_label.text = "Room Type: " + get_current_room_type_text()
	stage_map_label.text = get_stage_map_text()

	if pause_menu_screen.visible:
		update_pause_menu_info()


func get_player_state_text() -> String:
	match player.movement_state:
		player.MovementState.DASHING:
			return "dashing"
		player.MovementState.WALKING:
			return "walking"
		_:
			return "stationary"


#stage flow
func start_stage() -> void:
	current_room_number = 0
	current_stage_rooms = build_stage_room_queue()
	load_next_room()


func build_stage_room_queue() -> Array[Dictionary]:
	var stage_rooms: Array[Dictionary] = []

	if available_room_scenes.is_empty():
		return stage_rooms

	for _room_index in base_combat_rooms_per_stage:
		stage_rooms.append(create_room_data(RoomType.COMBAT))

	for _reward_index in reward_rooms_per_stage:
		stage_rooms.append(create_room_data(RoomType.REWARD))

	for _rest_index in rest_rooms_per_stage:
		stage_rooms.append(create_room_data(RoomType.REST))

	stage_rooms.shuffle()
	return stage_rooms


func create_room_data(room_type: RoomType) -> Dictionary:
	return {
		"room_type": room_type,
		"room_scene": available_room_scenes.pick_random(),
		"visited": false,
		"completed": false,
	}


func load_next_room() -> void:
	if stage_transition_active or not run_active:
		return

	current_room_number += 1

	if current_room_number > current_stage_rooms.size():
		start_stage_transition()
		return

	clear_active_room()

	var room_data: Dictionary = get_current_room_data()
	room_data["visited"] = true
	current_stage_rooms[current_room_number - 1] = room_data

	current_room = room_data["room_scene"].instantiate() as StageRoom
	room_container.add_child(current_room)
	current_room.exit_requested.connect(_on_room_exit_requested)

	player.global_position = current_room.get_player_spawn_position()

	setup_current_room()
	update_debug_ui()


func clear_active_room() -> void:
	for enemy in enemy_container.get_children():
		enemy.queue_free()

	for room in room_container.get_children():
		room.queue_free()

	current_room = null
	remaining_room_enemies = 0


func setup_current_room() -> void:
	match get_current_room_type():
		RoomType.COMBAT:
			spawn_room_enemies()
		RoomType.REWARD:
			setup_placeholder_room("Reward Placeholder\nExit")
		RoomType.REST:
			setup_rest_room()
		RoomType.DEBUFF:
			setup_placeholder_room("Debuff Placeholder\nExit")


func setup_placeholder_room(exit_text: String) -> void:
	remaining_room_enemies = 0
	current_room.unlock_exit()
	current_room.set_exit_text(exit_text)
	mark_current_room_completed()


func setup_rest_room() -> void:
	remaining_room_enemies = 0

	var previous_health: int = health_component.current_health
	var heal_amount: int = rest_room_heal_amount + meta_progression["gear"]["rest_bonus"]
	health_component.heal(heal_amount)
	var healed_amount: int = health_component.current_health - previous_health

	current_room.unlock_exit()

	if healed_amount > 0:
		current_room.set_exit_text("Rested +" + str(healed_amount) + " HP\nExit")
	else:
		current_room.set_exit_text("Rest Room\nAlready Full HP\nExit")

	mark_current_room_completed()


func spawn_room_enemies() -> void:
	var enemy_spawn_positions: Array[Vector2] = current_room.get_enemy_spawn_positions()
	var enemy_count: int = get_enemy_count_for_room(enemy_spawn_positions.size())

	remaining_room_enemies = enemy_count

	if enemy_count == 0:
		current_room.unlock_exit()
		return

	current_room.lock_exit()

	for enemy_index in enemy_count:
		var enemy = enemy_scene.instantiate()
		enemy_container.add_child(enemy)
		enemy.global_position = enemy_spawn_positions[enemy_index]

		var enemy_health: HealthComponent = enemy.get_node("Health")
		enemy_health.died.connect(_on_room_enemy_died)


func get_enemy_count_for_room(max_spawn_count: int) -> int:
	if max_spawn_count <= 0:
		return 0

	var scaled_enemy_count: int = current_stage + current_room_number - 1
	return clampi(scaled_enemy_count, 1, max_spawn_count)


func get_current_room_data() -> Dictionary:
	if current_room_number <= 0 or current_room_number > current_stage_rooms.size():
		return {}

	return current_stage_rooms[current_room_number - 1]


func get_current_room_type() -> RoomType:
	var room_data: Dictionary = get_current_room_data()
	if room_data.is_empty():
		return RoomType.COMBAT

	return room_data["room_type"] as RoomType


func mark_current_room_completed() -> void:
	if current_room_number <= 0 or current_room_number > current_stage_rooms.size():
		return

	var room_data: Dictionary = get_current_room_data()
	room_data["completed"] = true
	current_stage_rooms[current_room_number - 1] = room_data
	update_debug_ui()


func get_current_room_type_text() -> String:
	match get_current_room_type():
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

	var stage_map_parts: Array[String] = []

	for room_index in current_stage_rooms.size():
		var room_data: Dictionary = current_stage_rooms[room_index]
		var room_text: String = get_room_type_short_text(room_data["room_type"] as RoomType)

		if room_index + 1 == current_room_number:
			room_text = "[" + room_text + "]"
		elif room_data["completed"]:
			room_text = "(" + room_text + ")"
		elif room_data["visited"]:
			room_text = "{" + room_text + "}"

		stage_map_parts.append(room_text)

	return "Map: " + " - ".join(stage_map_parts)


func get_room_type_short_text(room_type: RoomType) -> String:
	match room_type:
		RoomType.REWARD:
			return "R"
		RoomType.REST:
			return "H"
		RoomType.DEBUFF:
			return "D"
		_:
			return "C"


func start_stage_transition() -> void:
	stage_transition_active = true
	stage_transition_label.text = "Stage " + str(current_stage) + " Complete\nStage " + str(current_stage + 1) + " Starting..."
	stage_transition_screen.visible = true
	player.set_physics_process(false)
	call_deferred("finish_stage_transition")


func finish_stage_transition() -> void:
	await get_tree().create_timer(stage_transition_duration).timeout

	stage_transition_screen.visible = false
	current_stage += 1
	stage_transition_active = false
	player.set_physics_process(true)
	start_stage()


func _on_room_enemy_died() -> void:
	remaining_room_enemies = max(remaining_room_enemies - 1, 0)

	if remaining_room_enemies == 0 and current_room != null:
		on_combat_room_cleared()


func on_combat_room_cleared() -> void:
	mark_current_room_completed()
	current_room.unlock_exit()


func _on_room_exit_requested() -> void:
	call_deferred("load_next_room")


#player death
func _on_player_died() -> void:
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
