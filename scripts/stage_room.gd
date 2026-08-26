extends Node2D
class_name StageRoom

signal room_entered(room: StageRoom)
signal reward_interaction_requested(room: StageRoom)
signal stage_exit_requested(room: StageRoom)

const ROOM_ACTIVATION_SETTINGS := preload("res://data/room_activation_settings.tres")

const ROOM_COLORS := {
	"start": Color(0.19, 0.25, 0.36, 1.0),
	"combat": Color(0.32, 0.18, 0.18, 1.0),
	"boss": Color(0.43, 0.12, 0.12, 1.0),
	"reward": Color(0.36, 0.29, 0.14, 1.0),
	"rest": Color(0.16, 0.31, 0.23, 1.0),
	"debuff": Color(0.30, 0.15, 0.32, 1.0),
}

@onready var floor_polygon: Polygon2D = $Floor
@onready var room_label: Label = $RoomLabel
@onready var player_spawn: Marker2D = $Markers/PlayerSpawn
@onready var north_door: Marker2D = $Markers/NorthDoor
@onready var south_door: Marker2D = $Markers/SouthDoor
@onready var west_door: Marker2D = $Markers/WestDoor
@onready var east_door: Marker2D = $Markers/EastDoor
@onready var enemy_spawns_root: Node2D = $Markers/EnemySpawns
@onready var activation_zone: Area2D = $ActivationZone
@onready var activation_zone_shape: CollisionShape2D = $ActivationZone/CollisionShape2D
@onready var reward_interactable: Area2D = $RewardInteractable
@onready var reward_interactable_shape: CollisionShape2D = $RewardInteractable/CollisionShape2D
@onready var reward_prompt_label: Label = $RewardInteractable/PromptLabel
@onready var reward_display: Polygon2D = $RewardInteractable/RewardDisplay
@onready var stage_exit_interactable: Area2D = $StageExitInteractable
@onready var stage_exit_interactable_shape: CollisionShape2D = $StageExitInteractable/CollisionShape2D
@onready var stage_exit_prompt_label: Label = $StageExitInteractable/PromptLabel
@onready var stage_exit_display: Polygon2D = $StageExitInteractable/ExitDisplay
@onready var north_connection: Polygon2D = $ConnectionIndicators/NorthConnection
@onready var south_connection: Polygon2D = $ConnectionIndicators/SouthConnection
@onready var west_connection: Polygon2D = $ConnectionIndicators/WestConnection
@onready var east_connection: Polygon2D = $ConnectionIndicators/EastConnection
@onready var door_root: Node = get_node_or_null("Door")

var room_id: int = -1
var room_type_name: String = "combat"
var connection_directions: Array[String] = []
var player_in_reward_range: bool = false
var player_in_stage_exit_range: bool = false


#setup
func _ready() -> void:
	apply_global_activation_zone_settings()
	hide_reward_interactable()
	hide_stage_exit()
	update_connection_indicators()


func configure(new_room_id: int, new_room_type_name: String, new_connection_directions: Array[String]) -> void:
	room_id = new_room_id
	room_type_name = new_room_type_name
	connection_directions = new_connection_directions.duplicate()
	update_room_visuals()
	update_connection_indicators()
	set_connected_doors_locked(false)


func update_room_visuals() -> void:
	floor_polygon.color = ROOM_COLORS.get(room_type_name, ROOM_COLORS["combat"])
	room_label.text = room_type_name.capitalize()


func update_connection_indicators() -> void:
	if not is_node_ready():
		return

	north_connection.visible = connection_directions.has("north")
	south_connection.visible = connection_directions.has("south")
	west_connection.visible = connection_directions.has("west")
	east_connection.visible = connection_directions.has("east")


#spawns
func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position


func get_enemy_spawn_positions() -> Array[Vector2]:
	var spawn_positions: Array[Vector2] = []

	for child in enemy_spawns_root.get_children():
		if child is Marker2D:
			spawn_positions.append(child.global_position)

	return spawn_positions


func apply_global_activation_zone_settings() -> void:
	if activation_zone_shape == null:
		return

	activation_zone.position = ROOM_ACTIVATION_SETTINGS.activation_zone_offset
	var rectangle_shape := activation_zone_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		activation_zone_shape.shape = rectangle_shape

	rectangle_shape.size = ROOM_ACTIVATION_SETTINGS.activation_zone_size


func get_door_world_position(direction: String) -> Vector2:
	match direction:
		"north":
			return north_door.global_position
		"south":
			return south_door.global_position
		"west":
			return west_door.global_position
		"east":
			return east_door.global_position
		_:
			return global_position


func set_connected_doors_locked(locked: bool) -> void:
	for direction in connection_directions:
		set_direction_door_locked(str(direction), locked)


func set_direction_door_locked(direction: String, locked: bool) -> void:
	var direction_name: String = direction.capitalize()
	var direction_door_nodes: Array[Node] = get_direction_door_nodes(direction_name)
	if direction_door_nodes.is_empty():
		return

	for door_node in direction_door_nodes:
		var blocker_shape: CollisionShape2D = get_door_blocker_shape(door_node, direction_name)
		if blocker_shape != null:
			blocker_shape.set_deferred("disabled", not locked)

		play_matching_door_animations(door_node, direction_name, locked)


func get_direction_door_nodes(direction_name: String) -> Array[Node]:
	var nodes: Array[Node] = []
	var direct_door_node: Node = get_node_or_null("%sDoor" % direction_name)
	if direct_door_node != null:
		nodes.append(direct_door_node)

	if door_root != null:
		nodes.append(door_root)

	return nodes


func get_door_blocker_shape(door_node: Node, direction_name: String) -> CollisionShape2D:
	var named_blocker_shape := get_node_or_null("%s/%sDoorBlocker/CollisionShape2D" % [door_node.get_path(), direction_name]) as CollisionShape2D
	if named_blocker_shape != null:
		return named_blocker_shape

	var blocker_nodes: Array[Node] = door_node.find_children("*DoorBlocker", "StaticBody2D", true, false)
	for blocker_node in blocker_nodes:
		var blocker_shape := get_node_or_null("%s/CollisionShape2D" % blocker_node.get_path()) as CollisionShape2D
		if blocker_shape != null:
			return blocker_shape

	return null


func play_matching_door_animations(door_node: Node, direction_name: String, locked: bool) -> void:
	var animation_suffix: String = "Close" if locked else "Open"
	var animated_sprites: Array[Node] = door_node.find_children("*", "AnimatedSprite2D", true, false)

	for animated_node in animated_sprites:
		var sprite := animated_node as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null:
			continue

		var chosen_animation_name: String = ""
		for animation_name in sprite.sprite_frames.get_animation_names():
			var animation_name_string: String = str(animation_name)
			if animation_name_string.begins_with("%sDoor" % direction_name) and animation_name_string.ends_with(animation_suffix):
				chosen_animation_name = animation_name_string
				break

		if chosen_animation_name.is_empty():
			for animation_name in sprite.sprite_frames.get_animation_names():
				var animation_name_string: String = str(animation_name)
				if animation_name_string.ends_with(animation_suffix):
					chosen_animation_name = animation_name_string
					break

		if chosen_animation_name.is_empty():
			continue

		sprite.play(chosen_animation_name)


#ui helpers
func set_room_label(new_text: String) -> void:
	room_label.text = new_text


func set_room_state(is_current_room: bool, is_visited: bool, is_revealed: bool) -> void:
	if is_current_room:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif is_visited:
		modulate = Color(0.9, 0.9, 0.9, 0.9)
	elif is_revealed:
		modulate = Color(0.72, 0.72, 0.72, 0.72)
	else:
		modulate = Color(0.45, 0.45, 0.45, 0.6)


func show_reward_interactable(prompt_text: String = "Press E\nReward") -> void:
	reward_interactable.set_deferred("monitoring", true)
	reward_interactable.set_deferred("monitorable", true)
	reward_interactable_shape.set_deferred("disabled", false)
	reward_display.visible = true
	reward_prompt_label.text = prompt_text
	reward_prompt_label.visible = player_in_reward_range


func hide_reward_interactable() -> void:
	reward_interactable.set_deferred("monitoring", false)
	reward_interactable.set_deferred("monitorable", false)
	reward_interactable_shape.set_deferred("disabled", true)
	reward_display.visible = false
	reward_prompt_label.visible = false
	player_in_reward_range = false


func show_stage_exit(prompt_text: String = "Press E\nEnter Portal") -> void:
	stage_exit_interactable.set_deferred("monitoring", true)
	stage_exit_interactable.set_deferred("monitorable", true)
	stage_exit_interactable_shape.set_deferred("disabled", false)
	stage_exit_display.visible = true
	stage_exit_prompt_label.text = prompt_text
	stage_exit_prompt_label.visible = player_in_stage_exit_range


func hide_stage_exit() -> void:
	stage_exit_interactable.set_deferred("monitoring", false)
	stage_exit_interactable.set_deferred("monitorable", false)
	stage_exit_interactable_shape.set_deferred("disabled", true)
	stage_exit_display.visible = false
	stage_exit_prompt_label.visible = false
	player_in_stage_exit_range = false


#input
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if player_in_stage_exit_range and stage_exit_interactable.monitoring:
		get_viewport().set_input_as_handled()
		stage_exit_requested.emit(self)
		return

	if player_in_reward_range and reward_interactable.monitoring:
		get_viewport().set_input_as_handled()
		reward_interaction_requested.emit(self)


#signals
func _on_activation_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		call_deferred("_emit_room_entered")


func _emit_room_entered() -> void:
	room_entered.emit(self)


func _on_reward_interactable_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_reward_range = true
	reward_prompt_label.visible = reward_interactable.monitoring


func _on_reward_interactable_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_reward_range = false
	reward_prompt_label.visible = false


func _on_stage_exit_interactable_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_stage_exit_range = true
	stage_exit_prompt_label.visible = stage_exit_interactable.monitoring


func _on_stage_exit_interactable_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_stage_exit_range = false
	stage_exit_prompt_label.visible = false
