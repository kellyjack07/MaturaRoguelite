extends "res://tests/hud_test_main.gd"

func get_room_scene_for_room(_room_data: Dictionary) -> PackedScene:
	return preload("res://rooms/premade/stage_1/combat/east_west/combat_east_west_a.tscn")
