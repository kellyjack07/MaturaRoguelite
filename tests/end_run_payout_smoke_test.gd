extends SceneTree

const SETTINGS := preload("res://data/progression/end_run_payout_settings.tres")
var failures: Array[String] = []

func _init() -> void:
	var no_kills := SETTINGS.calculate({"completed_levels": [], "regular_kills": 0, "boss_kills": 0, "leftover_gold": 0})
	check(no_kills.total_essence == 0, "Empty run paid essence")
	var boundaries := SETTINGS.calculate({"completed_levels": [], "regular_kills": 8, "boss_kills": 1, "leftover_gold": 5})
	check(boundaries.total_essence == 14, "Boundary payout should be 14 essence")
	var floors: Array = [
		{"level_id": "1-1", "stage_world": 1, "stage_floor": 1, "first_clear": true},
		{"level_id": "1-2", "stage_world": 1, "stage_floor": 2, "first_clear": false},
		{"level_id": "1-3", "stage_world": 1, "stage_floor": 3, "first_clear": true},
		{"level_id": "1-3", "stage_world": 1, "stage_floor": 3, "first_clear": true},
	]
	var complete_stage := SETTINGS.calculate({"completed_levels": floors, "regular_kills": 15, "boss_kills": 0, "leftover_gold": 9})
	check(complete_stage.completed_level_count == 3, "Duplicate level was counted")
	check(complete_stage.completed_stage_count == 1 and complete_stage.stage_essence == 30, "Stage bonus was not paid once")
	check(complete_stage.regular_essence == 1 and complete_stage.gold_essence == 1, "Rounding boundaries are wrong")
	print("END_RUN_PAYOUT_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
