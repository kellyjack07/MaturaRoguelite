extends Resource
class_name AttackDefinition

enum ShapeKind {
	RECTANGLE,
	CAPSULE,
	CIRCLE,
}

@export var base_damage: int = 5
@export_range(0.0, 5.0, 0.01) var startup: float = 0.1
@export_range(0.0, 5.0, 0.01) var active_duration: float = 0.1
@export_range(0.0, 5.0, 0.01) var recovery: float = 0.2
@export_range(0.0, 30.0, 0.05) var cooldown: float = 0.0
@export var shape_kind: ShapeKind = ShapeKind.RECTANGLE
@export var shape_size: Vector2 = Vector2(32.0, 18.0)
@export_range(1.0, 128.0, 1.0) var shape_radius: float = 16.0
@export_range(0.0, 128.0, 1.0) var reach: float = 16.0
@export_range(0, 64, 1) var max_targets: int = 2
@export var pulse_times: PackedFloat32Array = PackedFloat32Array([0.1])
@export var allow_repeat_hits_between_pulses: bool = false


func get_action_duration() -> float:
	return startup + active_duration + recovery
