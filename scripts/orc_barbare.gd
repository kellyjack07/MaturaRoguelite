extends "res://scripts/new_melee_enemy.gd"
class_name OrcBarbare

@export var skin_variant: int = 1

func on_enemy_ready() -> void:
	uses_dash = false
	sprite_folder = "Orc_Barbare_%02d (Green Skinned)" % skin_variant
	sprite_prefix = "Orc_Barbare_%02d" % skin_variant
	sprite_frame_size = Vector2(57, 58)
	move_frame_count = 5
	prepare_frame_count = 7
	attack_frame_count = 12
	if skin_variant == 2: sprite_folder = "Orc_Barbare_02 (Blue Skinned)"
	if skin_variant == 3: sprite_folder = "Orc_Barbare_03 (Red Skinned)"
	super()
