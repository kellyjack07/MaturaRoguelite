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
	var shop_id := -1
	for room in main.current_stage_rooms:
		if room.room_type == main.RoomType.REWARD:
			shop_id = room.id
	var shop = main.get_room_node(shop_id)
	main.player.global_position = shop.get_player_spawn_position()
	main._on_generated_room_entered(shop)
	main._on_reward_interaction_requested(shop)
	var ui = main.rest_shop
	check(ui.visible and ui.is_shop and paused, "Shared Shop UI did not open/ pause")
	check(not main.room_event_screen.visible, "Legacy event screen still shown")
	check(not ui.cards.instant.visible and ui.cards.stamina.visible, "Wrong shop offers")
	main.current_run.gold = 1
	ui.refresh()
	check(ui.buttons.small.disabled, "Unaffordable offer enabled")
	check(not main.select_shop_potion(shop_id, "small_healing").success, "Unaffordable purchase succeeded")
	main.current_run.gold = 20
	main.fail_test_save = true
	check(not main.select_shop_potion(shop_id, "small_healing").success, "Failed save accepted")
	check(main.current_run.gold == 20 and not main.potion_inventory.has("small_healing"), "Failed save lost gold or granted item")
	check(main.get_room_data_by_id(shop_id).shop_stock.small_healing, "Failed save consumed stock")
	main.fail_test_save = false
	ui._choose("small")
	check(main.current_run.gold == 17 and main.potion_inventory.has("small_healing"), "Small purchase failed")
	check(ui.visible and not main.get_room_data_by_id(shop_id).completed, "Partial purchase closed/consumed whole shop")
	check(not main.select_shop_potion(shop_id, "small_healing").success, "Duplicate purchase accepted")
	ui.close_shop()
	check(shop.rest_chest.animation == &"open", "Partially bought chest closed")
	check(not main.select_shop_potion(shop_id, "big_healing").success, "Purchase outside shop accepted")
	main.current_run = main.test_saved.duplicate(true)
	main.continue_saved_run()
	await process_frame
	shop = main.get_room_node(shop_id)
	check(shop.rest_chest.animation == &"open", "Partial chest state lost on continue")
	check(not main.get_shop_potion_offer(shop_id, "small_healing").available and main.get_shop_potion_offer(shop_id, "big_healing").available, "Partial stock lost on continue")
	main._on_reward_interaction_requested(shop)
	ui._choose("big")
	ui._choose("stamina")
	check(main.current_run.gold == 7, "Incorrect total cost")
	check(main.get_room_data_by_id(shop_id).completed, "Sold-out shop not completed")
	check(main.test_saved.stage_rooms[shop_id].completed, "Sold-out completion not saved")
	main.potion_inventory.remove("small_healing")
	var inventory: Dictionary = main.player.get_potion_inventory_snapshot()
	main.player.set_potion_inventory_snapshot(inventory)
	check(main.potion_inventory.equipped_id == "small_healing", "Empty equipped type lost on load")
	ui.close_shop()
	var snapshot: Dictionary = main.build_run_snapshot().duplicate(true)
	main.current_run = snapshot
	main.continue_saved_run()
	await process_frame
	check(main.get_room_data_by_id(shop_id).completed, "Sold-out state lost on continue")
	check(not main.get_shop_potion_offer(shop_id, "stamina").available, "Sold-out shop replenished")
	var legacy: Dictionary = main.ensure_stage_room_shape({"completed": true})
	check(not legacy.shop_stock.values().has(true), "Legacy completed shop restocked")
	# Capture populated icons and the same shared panel used by the real interaction path.
	main.potion_inventory.equip("stamina")
	var data: Dictionary = main.get_room_data_by_id(shop_id)
	data.completed = false
	data.shop_stock.big_healing = true
	main._on_reward_interaction_requested(main.get_room_node(shop_id))
	await process_frame
	await process_frame
	check(main.hud.equipped_potion_icon.texture != null, "Equipped HUD icon absent")
	check(main.hud.health_panel.size.x < 300, "Potion label stretches health panel")
	check(main.hud.equipped_potion_icon.size.x > 0, "HUD potion icon has zero size")
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/shop-ui-preview.png")
	ui.close_shop()
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/shop-hud-preview.png")
	main.queue_free()
	paused = false
	await process_frame
	print("SHOP_UI_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
