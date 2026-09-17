extends SceneTree

const CATALOGUE := preload("res://data/encounters/encounter_catalogue.tres")
const ARCHER_BLUE := preload("res://data/enemy_frames_orc_archer_blue.tres")
const BARBARE_RED := preload("res://data/enemy_frames_orc_barbare_red.tres")
var failures: Array[String] = []

func _init() -> void:
	var first_final := CATALOGUE.get_final_waves(1, false)
	check(first_final.size() == 3, "1-1 first-run finale should have three waves")
	check(_ids(first_final[0]) == ["training_dummy_2", "training_dummy_2"], "1-1 first wave mismatch")
	check(_ids(first_final[1]) == ["training_dummy_2", "goblin_barrel"], "1-1 second wave mismatch")
	check(_ids(first_final[2]) == ["training_dummy_2", "training_dummy_2", "goblin_barrel", "goblin_barrel", "goblin_barrel"], "1-1 third wave mismatch")
	var replay_final := CATALOGUE.get_final_waves(1, true)
	check(_ids(replay_final[0]) == ["training_dummy_2", "goblin_barrel", "goblin_barrel"], "1-1 replay first wave mismatch")
	var second_final := CATALOGUE.get_final_waves(2, false)
	check(_ids(second_final[2]) == ["orc_barbare", "blue_orc_archer"], "1-2 final wave mismatch")
	check(ARCHER_BLUE.get_frame_count(&"attack") == 7, "Blue archer authored frame count changed")
	check(is_equal_approx(ARCHER_BLUE.get_animation_speed(&"attack"), 7.0), "Blue archer authored FPS changed")
	check(BARBARE_RED.get_frame_count(&"prepare") == 7, "Red Barbare authored frame count changed")
	print("ENCOUNTER_CATALOGUE_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)


func _ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in entries:
		result.append(str(entry.get("enemy_id", "")))
	return result


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
