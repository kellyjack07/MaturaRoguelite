extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_tests")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func run_tests() -> void:
	var stamina := StaminaComponent.new()
	root.add_child(stamina)
	await process_frame
	check(is_equal_approx(stamina.current_stamina, 100.0), "Stamina did not start full")
	check(stamina.spend(40.0), "Dash stamina spend was rejected")
	check(is_equal_approx(stamina.current_stamina, 60.0), "Dash did not spend exactly 40 stamina")
	check(not stamina.spend(61.0), "Insufficient stamina was spent")
	stamina.tick(1.0, false)
	check(is_equal_approx(stamina.current_stamina, 60.0), "Regen ignored the full delay")
	stamina.tick(0.5, false)
	check(is_equal_approx(stamina.current_stamina, 70.0), "Normal regen rate was incorrect")
	check(stamina.start_boost(), "Stamina boost did not start")
	check(not stamina.start_boost(), "Active stamina boost stacked")
	var before_boost := stamina.current_stamina
	stamina.tick(1.0, false)
	check(is_equal_approx(stamina.current_stamina, before_boost + 40.0), "Bottle boost regen was incorrect")
	var snapshot: Dictionary = stamina.get_snapshot()
	stamina.reset_for_run()
	stamina.set_snapshot(snapshot)
	check(stamina.boost_time_left > 0.0, "Stamina snapshot did not restore boost state")
	stamina.queue_free()
	await process_frame
	print("Stamina tests: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
