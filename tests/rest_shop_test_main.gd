extends "res://tests/hud_test_main.gd"
var fail_test_save: bool = false

func save_progress() -> Error:
	if fail_test_save:
		return ERR_CANT_CREATE
	return super.save_progress()
