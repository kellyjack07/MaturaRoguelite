extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_gear_store()
	await process_frame
	await process_frame

	var screen: SkillTreeScreen = main.gear_store_screen
	var viewport_rect := Rect2(Vector2.ZERO, screen.size)
	check(viewport_rect.encloses(screen.outer_margin.get_global_rect()), "Skill-tree margins overflow the viewport")
	check(viewport_rect.encloses(screen.main_vbox.get_global_rect()), "Skill-tree content overflows the viewport")
	var back_button: Button = screen.get_node("OuterMargin/MainVBox/Footer/BackRow/BackButton")
	check(viewport_rect.encloses(back_button.get_global_rect()), "Back button is outside the skill-tree viewport")
	check(back_button.is_visible_in_tree() and back_button.size.y >= 30.0, "Back button is not visibly allocated")

	var tree_scroll: ScrollContainer = screen.tree_scroll
	var scroll_bar := tree_scroll.get_v_scroll_bar()
	check(scroll_bar.max_value > scroll_bar.page, "Tree content does not expose a vertical scroll range")
	tree_scroll.scroll_vertical = 0
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	wheel_down.position = tree_scroll.get_global_rect().get_center()
	wheel_down.global_position = wheel_down.position
	Input.warp_mouse(wheel_down.position)
	await process_frame
	root.push_input(wheel_down, true)
	await process_frame
	check(tree_scroll.scroll_vertical > 0, "Mouse wheel did not change the tree scroll position")

	var icon_test_node: SkillTreeNode = screen.graph.node_controls["sword_10"]
	var skill_icon: TextureRect = icon_test_node.get_node("SkillIcon")
	var display_id_label: Label = icon_test_node.get_node("DisplayIdLabel")
	icon_test_node.set_node_view(_icon_test_view("character_max_health", "locked"), false)
	check(skill_icon.texture.resource_path.ends_with("skill_health_locked.png"), "Locked health effect does not use the locked health icon")
	icon_test_node.set_node_view(_icon_test_view("basic_damage", "available"), false)
	check(skill_icon.texture.resource_path.ends_with("skill_strength.png"), "Available damage effect does not use the unlocked strength icon")
	check(skill_icon.modulate == SkillTreeNode.AVAILABLE_ICON_MODULATE, "Available icon is not darkened")
	icon_test_node.set_node_view(_icon_test_view("basic_target_limit", "purchased"), false)
	check(skill_icon.texture.resource_path.ends_with("skill_inventory.png"), "Target-limit effect does not use the inventory icon")
	check(skill_icon.modulate == Color.WHITE, "Purchased icon is not displayed at full brightness")
	icon_test_node.set_node_view(_icon_test_view("basic_reach", "purchased"), false)
	check(skill_icon.texture.resource_path.ends_with("skill_stat_boost.png"), "Stat effect does not use the stat-boost icon")
	icon_test_node.set_node_view(_icon_test_view("special_unlock", "locked"), false)
	check(skill_icon.texture.resource_path.ends_with("icon_plus_locked.png"), "Unmapped effect does not use the generic locked icon")
	check(display_id_label.text == "test", "Display ID is not shown beside the icon")
	screen.refresh_ui()
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture_path := ProjectSettings.globalize_path("res://.godot/skill_tree_icon_ui.png")
		var capture_error := root.get_texture().get_image().save_png(capture_path)
		check(capture_error == OK, "Could not save the optional skill-tree UI capture")

	screen._on_graph_node_selected("hammer")
	await process_frame
	var details_content: VBoxContainer = screen.get_node("OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsScroll/DetailsContent")
	check(details_content.size.x <= screen.details_scroll.size.x + 1.0, "Details text is wider than its scroll viewport")
	check(not screen.details_description_label.text.is_empty(), "Selected node description was not displayed")

	back_button.pressed.emit()
	await process_frame
	check(not screen.visible and main.main_menu_screen.visible, "Back button did not return to the main menu")

	main.open_gear_store()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not screen.visible and main.main_menu_screen.visible, "Escape did not return to the main menu")

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("SKILL_TREE_UI_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SKILL_TREE_UI_SMOKE_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _icon_test_view(effect_type: String, state: String) -> Dictionary:
	return {
		"node_id": "test",
		"display_id": "test",
		"title": "Icon test",
		"description": "Icon mapping test.",
		"effect_type": effect_type,
		"state": state,
	}
