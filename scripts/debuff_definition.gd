extends Resource
class_name DebuffDefinition

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export_range(1, 3, 1) var tier: int = 1
@export_range(1, 9, 1) var min_stage: int = 1
@export_range(1, 9, 1) var max_stage: int = 3
@export var selection_weight: float = 1.0
@export var enabled: bool = true
@export var requires_projectile: bool = false
@export var requires_melee: bool = false
@export var effect_value: float = 0.0
@export var effect_seconds: float = 3.0
@export var vision_radius: float = 135.0
@export var reinforcement_warning: float = 1.0

