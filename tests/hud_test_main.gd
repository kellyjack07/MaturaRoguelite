extends "res://scripts/main.gd"

# In-memory persistence: this harness never reads or writes the user's save.
var test_saved: Dictionary = {}

func load_progress() -> void:
	meta_progression = get_default_meta_progression()
	current_run = {}
	ensure_meta_progression_shape()

func save_progress() -> Error:
	test_saved = build_run_snapshot().duplicate(true)
	return OK

func delete_save_file() -> void:
	test_saved.clear()
