extends Node2D
class_name StageRoom

signal exit_requested

@onready var enemy_door_blocker: StaticBody2D = $EnemyDoorBlocker
@onready var enemy_door_blocker_shape: CollisionShape2D = $EnemyDoorBlocker/CollisionShape2D
@onready var player_spawn: Marker2D = $Markers/PlayerSpawn
@onready var exit_point: Marker2D = $Markers/ExitPoint
@onready var enemy_spawns_root: Node2D = $Markers/EnemySpawns
@onready var exit_area: Area2D = $ExitArea
@onready var exit_label: Label = $ExitArea/ExitLabel


#setup
func _ready() -> void:
	validate_room_layout()
	lock_exit()


#spawns
func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position


func get_enemy_spawn_positions() -> Array[Vector2]:
	var spawn_positions: Array[Vector2] = []

	for child in enemy_spawns_root.get_children():
		if child is Marker2D:
			spawn_positions.append(child.global_position)

	return spawn_positions


func get_exit_position() -> Vector2:
	return exit_point.global_position


#exit
func lock_exit() -> void:
	enemy_door_blocker_shape.disabled = false
	exit_area.monitoring = false
	exit_area.monitorable = false
	exit_label.visible = false


func unlock_exit() -> void:
	enemy_door_blocker_shape.disabled = true
	exit_area.monitoring = true
	exit_area.monitorable = true
	exit_label.visible = true


func set_exit_text(new_text: String) -> void:
	exit_label.text = new_text


func validate_room_layout() -> void:
	var spawn_distance: float = player_spawn.global_position.distance_to(get_exit_position())
	if spawn_distance < 32.0:
		push_warning("Player spawn and exit are too close together in room: " + name)


func _on_exit_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not exit_area.monitoring:
		return

	exit_requested.emit()
