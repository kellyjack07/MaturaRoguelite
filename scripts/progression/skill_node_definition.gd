extends Resource
class_name SkillNodeDefinition

@export var node_id: String = ""
@export var display_id: String = ""
@export var branch_id: String = ""
@export var order: int = 0
@export var title: String = ""
@export_multiline var description: String = ""
@export_range(0, 100000, 1) var cost: int = 0
@export var predecessor_id: String = ""
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var required_stage: int = 0
@export var automatic_with: String = ""
