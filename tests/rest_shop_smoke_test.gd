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
	main.set_script(load("res://tests/rest_shop_test_main.gd"))
	root.add_child(main)
	await process_frame
	main.start_new_run()
	await process_frame
	var room_data: Dictionary
	for room in main.current_stage_rooms:
		if room.room_type == main.RoomType.REST:
			room_data = room
			break
	var id: int = room_data.id
	var room = main.get_room_node(id)
	main.health_component.current_health = 1
	main.health_component.max_health = 26
	room_data.initialized = true
	main._on_generated_room_entered(room)
	check(main.health_component.current_health == 1, "Rest entry healed automatically")
	main._on_reward_interaction_requested(room)
	check(main.rest_shop.visible and paused, "Shop did not pause")
	check(main.get_rest_shop_offer(id, "small").heal == 6, "Small rounding incorrect")
	check(main.get_rest_shop_offer(id, "big").heal == 13, "Big healing incorrect")
	main.current_run.gold = 0
	check(not main.select_rest_shop_offer(id, "big").success, "Unaffordable purchase allowed")
	main.rest_shop.close_shop()
	check(not paused and not room_data.completed, "Close consumed choice or left game paused")
	check(room.rest_chest.animation == &"closed", "Unconsumed chest not closed")
	main._on_reward_interaction_requested(room)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	main.rest_shop._input(cancel)
	check(not main.rest_shop.visible and not paused, "Escape did not restore gameplay")
	main._on_reward_interaction_requested(room)
	main.current_run.gold = 10
	main.fail_test_save = true
	check(not main.select_rest_shop_offer(id, "big").success, "Failed save reported success")
	check(main.current_run.gold == 10 and main.health_component.current_health == 1 and not room_data.completed, "Failed save did not roll back")
	main.fail_test_save = false
	main.rest_shop._choose("big")
	check(main.current_run.gold == 5 and main.health_component.current_health == 14, "Big selection values incorrect")
	check(room_data.completed and room.rest_chest.animation == &"open", "Consumed chest not open")
	check(not main.select_rest_shop_offer(id, "small").success, "Repeated selection succeeded")
	var snapshot: Dictionary = main.test_saved.duplicate(true)
	main.show_main_menu()
	main.current_run = snapshot
	main.continue_saved_run()
	await process_frame
	room = main.get_room_node(id)
	check(room.rest_chest.animation == &"open", "Consumed chest state lost after restore")
	check(not main.get_rest_shop_offer(id, "small").available, "Restored reward became available")
	room_data = main.get_room_data_by_id(id)
	room_data.completed = false
	room.configure_rest_chest(false)
	main.health_component.current_health = main.health_component.max_health
	check(not main.get_rest_shop_offer(id, "small").available, "Full-health potion allowed")
	main.health_component.current_health -= 1
	check(main.get_rest_shop_offer(id, "big").heal == 1, "Healing exceeds missing HP")
	main.meta_progression.gear.rest_bonus = 2
	main.current_run.debuff_state.rest_penalty = 100
	check(not main.get_rest_shop_offer(id, "small").available, "Zero healing consumed reward")
	main.current_run.debuff_state.rest_penalty = 1
	main.health_component.current_health = 1
	check(main.get_rest_shop_offer(id, "small").heal == ceili(main.health_component.max_health * 0.2) + 1, "Rest modifiers incorrect")
	main._on_reward_interaction_requested(room)
	var original_font_size: int = main.rest_shop.theme.get_font_size("font_size", "RestShopText")
	main.rest_shop.theme.set_font_size("font_size", "RestShopText", 18)
	await process_frame
	check(main.rest_shop.close_button.is_visible_in_tree(), "Close inaccessible with larger font")
	main.rest_shop.theme.set_font_size("font_size", "RestShopText", original_font_size)
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(0.7, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/rest-shop-preview.png")
	main.rest_shop._choose("small")
	check(room_data.completed and main.current_run.gold == 5, "Free choice failed or charged gold")
	main.queue_free()
	paused = false
	await process_frame
	print("REST_SHOP_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
