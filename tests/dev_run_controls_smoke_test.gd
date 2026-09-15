extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/rest_shop_test_main.gd"))
	root.add_child(main)
	await process_frame
	main.start_new_run()
	await process_frame
	main.open_developer_weapon_screen()
	var panel = main.dev_weapon_screen
	check(panel.visible and paused, "Developer panel must pause gameplay")
	panel.dev_fields.gold.value = 75
	panel.dev_fields.essence.value = 123
	panel._apply_currency()
	check(main.current_run.gold == 75, "Gold not applied")
	check(main.skill_tree.get_essence_balance() == 123, "Skill tree essence not updated")
	check(main.test_saved.gold == 75, "Gold not saved")
	main.fail_test_save = true
	panel.dev_fields.gold.value = 80
	panel.dev_fields.essence.value = 130
	panel._apply_currency()
	check(main.current_run.gold == 75 and main.meta_progression.essence == 123, "Failed save did not roll back")
	main.fail_test_save = false
	var hp: int = main.health_component.current_health
	var weapon: String = main.current_run.weapon
	var cleared: int = main.meta_progression.highest_stage_completed
	panel.dev_fields.stage.value = 2
	panel.dev_fields.floor.value = 2
	panel._request_floor_change()
	for i in 8:
		await process_frame
	check(main.current_stage == 5, "2-2 did not map to floor index 5")
	check(not main.current_stage_rooms.is_empty(), "Jump did not generate rooms")
	check(main.health_component.current_health == hp and main.current_run.weapon == weapon, "Jump changed HP or weapon")
	check(main.current_run.gold == 75 and main.meta_progression.essence == 123, "Jump changed currency")
	check(main.meta_progression.highest_stage_completed == cleared, "Jump granted stage-clear credit")
	check(main.test_saved.stage_world == 2 and main.test_saved.stage_floor == 2, "Jump not saved")
	check(paused and panel.visible, "Jump changed developer pause state")
	main.close_developer_weapon_screen()
	check(not paused, "Closing developer panel did not resume")
	main.current_run = main.test_saved.duplicate(true)
	main.continue_saved_run()
	await process_frame
	check(main.current_stage == 5 and main.current_run.gold == 75, "Continue lost developer changes")
	main.queue_free()
	await process_frame
	print("DEV_RUN_CONTROLS_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
