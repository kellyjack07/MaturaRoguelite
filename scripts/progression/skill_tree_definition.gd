extends Resource
class_name SkillTreeDefinition

@export var branch_order: PackedStringArray = PackedStringArray(["root", "sword", "spear", "hammer"])
@export var branch_display_ids: Dictionary = {
	"root": "0",
	"sword": "1",
	"spear": "2",
	"hammer": "3",
}
@export var branch_titles: Dictionary = {
	"root": "Root",
	"sword": "Sword",
	"spear": "Spear",
	"hammer": "Hammer",
}
@export_range(0.0, 1.0, 0.01) var off_weapon_character_strength: float = 0.3
@export var tutorial_reward_stage: int = 1
@export_range(0, 100000, 1) var tutorial_reward_essence: int = 10
@export var nodes: Array[SkillNodeDefinition] = []
