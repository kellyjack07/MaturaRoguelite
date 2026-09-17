extends "res://scripts/new_melee_enemy.gd"
class_name OrcBarbare

@export var skin_variant: int = 1

func on_enemy_ready() -> void:
	uses_dash = false
	super()
