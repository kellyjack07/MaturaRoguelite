extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/hud_test_main.gd"))
	root.add_child(main)
	await process_frame
	check(not main.hud.visible, "HUD visible in main menu")
	check(not main.run_background.visible, "Run atmosphere visible in main menu")
	main.start_new_run()
	await process_frame
	main.player.set_physics_process(false)
	var hud = main.hud
	check(hud.visible, "HUD not visible in run")
	check(main.run_background.visible and main.run_background.layer < 0, "Atmosphere not behind run")
	main.health_component.take_damage(3)
	check(hud.health_fill.value == main.health_component.current_health, "Damage did not update health fill")
	main.health_component.heal(2)
	check(hud.health_fill.value == main.health_component.current_health, "Healing did not update health fill")
	hud.set_health(0, 0)
	check(hud.health_fill.value == 0, "Zero maximum produced a nonempty health bar")
	main.update_debug_ui()
	main.add_run_gold(7)
	check(hud.gold_text.text == "Gold: %d" % main.current_run.gold, "Gold out of sync")
	main.save_progress()
	var saved: Dictionary = main.test_saved.duplicate(true)
	main.show_main_menu()
	main.current_run = saved
	main.continue_saved_run()
	await process_frame
	main.player.set_physics_process(false)
	check(hud.visible and hud.health_fill.value == saved.player_health, "Continue did not restore HUD health")
	check(hud.gold_text.text == "Gold: %d" % saved.gold, "Continue did not restore HUD gold")
	main.player.developer_combat_bypass = true
	main.player.special_cooldowns[main.player.equipped_weapon_id] = 2.0
	hud._refresh_special()
	check(hud.special_text.text.contains("2.0s"), "Cooldown not displayed")
	paused = true
	var atmosphere_time: float = main.run_background.drift_time
	await create_timer(0.2, true).timeout
	check(main.run_background.drift_time == atmosphere_time, "Paused atmosphere kept advancing")
	check(main.player.get_special_cooldown_left() == 2.0, "Pause changed cooldown")
	paused = false
	main.player.special_cooldowns[main.player.equipped_weapon_id] = 0.0
	hud._refresh_special()
	check(hud.special_text.text.contains("Ready"), "Ready state missing")
	main.player.developer_combat_bypass = false
	hud._refresh_special()
	check(hud.special_text.text.contains("Locked"), "Locked state missing")
	var test_rooms: Array[Dictionary] = [
		{"id": 0, "grid_x": 0, "grid_y": 0, "room_type": 0, "neighbors": [1], "visited": true},
		{"id": 1, "grid_x": 1, "grid_y": 0, "room_type": 1, "neighbors": [0, 2], "revealed": true},
		{"id": 2, "grid_x": 2, "grid_y": 0, "room_type": 2, "neighbors": [1]},
	]
	main.current_stage_rooms = test_rooms
	main.current_room_id = 0
	main.refresh_hud_map()
	check(hud.minimap.rooms.size() == 2, "Undiscovered room leaked")
	check(hud.minimap.rooms[1].label != "?", "Adjacent room type hidden")
	main.current_stage_rooms[0].neighbors = []
	main.refresh_hud_map()
	check(hud.minimap.rooms[1].label == "?", "Previously revealed type leaked after leaving adjacency")
	var snapshot: Dictionary = main.build_run_snapshot().duplicate(true)
	main.current_stage_rooms = snapshot.stage_rooms
	main.refresh_hud_map()
	check(hud.minimap.rooms.size() == 2, "Restored map lost discovery")
	main.current_stage = 4
	main.update_debug_ui()
	check(hud.stage_text.text == "Stage: 2-1", "Stage display incorrect")
	hud.size = Vector2(640, 360)
	hud._arrange()
	await process_frame
	check(not hud.health_panel.get_rect().intersects(hud.map_panel.get_rect()), "HUD panels overlap")
	var previous_size: int = hud.theme.get_font_size("font_size", "HUDText")
	hud.theme.set_font_size("font_size", "HUDText", 16)
	hud.layout.health_width = 200
	hud.layout.gap = 8
	await process_frame
	await process_frame
	hud._arrange()
	check(not hud.health_panel.get_rect().intersects(hud.stage_panel.get_rect()), "Larger font overlaps stage")
	check(hud.weapon_panel.position.y + hud.weapon_panel.size.y <= hud.size.y, "Larger weapon panel clipped")
	hud.theme.set_font_size("font_size", "HUDText", previous_size)
	hud.layout.health_width = 180
	hud.layout.gap = 6
	main.open_pause_menu()
	check(hud.visible, "Pause incorrectly hid HUD")
	main.resume_run()
	main._on_player_death_started()
	check(not hud.visible, "Death did not hide HUD")
	main.set_run_ui_visible(true)
	check_mouse(hud)
	main.show_main_menu()
	check(not hud.visible, "HUD remained visible in main menu")
	check(not main.run_background.visible, "Atmosphere remained visible in main menu")
	if OS.get_cmdline_user_args().has("--capture"):
		main.main_menu_screen.hide()
		main.run_background.show()
		hud.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud-preview.png")
	main.queue_free()
	await process_frame
	print("HUD tests: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func check_mouse(node: Node) -> void:
	if node is Control:
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD captures mouse: " + str(node.name))
	for child in node.get_children():
		check_mouse(child)
