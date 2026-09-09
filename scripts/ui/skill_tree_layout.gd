@tool
extends Resource
class_name SkillTreeLayout

## Presentation-only settings for the skill-tree screen.
## Progression data, costs and prerequisites remain in skill_tree.tres.

@export var node_size: Vector2 = Vector2(64.0, 42.0)
@export_range(1, 4, 1) var artwork_scale: int = 1
@export var vertical_node_gap: float = 18.0
@export var branch_gap: float = 18.0
@export var canvas_padding: Vector4 = Vector4(20.0, 20.0, 20.0, 20.0)
@export var header_spacing: float = 6.0
@export var footer_spacing: float = 6.0
@export var outer_margin: Vector4 = Vector4(12.0, 8.0, 12.0, 8.0)
@export var details_width: float = 190.0
@export var details_min_height: float = 112.0
@export var responsive_breakpoint: float = 560.0
@export var background_color: Color = Color(0.72, 0.76, 0.82, 1.0)
@export var connector_purchased_color: Color = Color(0.74, 0.86, 0.72, 1.0)
@export var connector_available_color: Color = Color(0.72, 0.78, 0.9, 1.0)
@export var connector_locked_color: Color = Color(0.28, 0.32, 0.42, 1.0)
@export var path_tileset: Texture2D = preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_tree_path_tileset.png")
@export var selection_texture: Texture2D = preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_selected.png")
@export var optional_icon_paths: Dictionary = {}
