extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	for direction in ["east", "west"]:
		var start_room = load("res://rooms/premade/stage_1/start/%s/start_%s_a.tscn" % [direction, direction]).instantiate()
		root.add_child(start_room)
		var directions: Array[String] = [direction]
		start_room.configure(0, "start", directions)
		await process_frame
		check(start_room.get_node("Door/EastDoorBlocker/CollisionShape2D").disabled, "Start door blocked: " + direction)
		check(str(start_room.get_node("Door/EastDoorTop").animation).ends_with("Open"), "Start animation not opening: " + direction)
		start_room.queue_free()
		await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/door_test_main.gd"))
	root.add_child(main)
	await process_frame
	var positions: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	main.current_stage_rooms = main.build_stage_rooms_from_positions(positions)
	main.current_stage_rooms[0].room_type = main.RoomType.START
	main.current_stage_rooms[1].completed = true
	main.current_stage_rooms[1].initialized = true
	main.current_room_id = 1
	main.start_room_id = 0
	main.boss_room_id = 1
	main.run_active = true
	main.current_run = {"weapon": "sword", "gold": 0}
	var snapshot: Dictionary = main.build_run_snapshot().duplicate(true)
	main.current_run = snapshot
	main.continue_saved_run()
	for i in 5:
		await process_frame
	main.player.set_physics_process(false)
	var room = main.get_room_node(1)
	var blocker: CollisionShape2D = room.get_node("WestDoor/WestDoorBlocker/CollisionShape2D")
	check(blocker.disabled, "Completed saved room remained locked")
	check(main.enemy_container.get_child_count() == 0, "Cleared room respawned enemies")
	for i in 3:
		main._on_generated_room_entered(room)
		main.player.global_position = room.get_door_world_position("west")
		main.sync_room_doors(main.get_room_data_by_id(1))
		await process_frame
		check(blocker.disabled, "Completed room relocked near door")
	# A saved unfinished encounter must restore remaining enemies, not trust initialized.
	snapshot.stage_rooms[1].completed = false
	snapshot.stage_rooms[1].combat_cleared = false
	snapshot.stage_rooms[1].enemies_remaining = 1
	snapshot.stage_rooms[1].initialized = true
	main.current_run = snapshot.duplicate(true)
	main.continue_saved_run()
	for i in 5:
		await process_frame
	main.player.set_physics_process(false)
	room = main.get_room_node(1)
	blocker = room.get_node("WestDoor/WestDoorBlocker/CollisionShape2D")
	check(main.enemy_container.get_child_count() == 1, "Remaining enemy not restored")
	check(not blocker.disabled, "Active restored encounter is not locked")
	main._on_generated_room_entered(room)
	await process_frame
	check(main.enemy_container.get_child_count() == 1, "Repeated activation duplicated enemies")
	main._on_room_enemy_died(1)
	await process_frame
	check(blocker.disabled, "Final kill did not unlock doors")
	check(main.get_room_data_by_id(1).combat_cleared, "Clear flag not recorded")
	# Legacy save taken at the collect screen: recover the pending reward, no respawn.
	snapshot.stage_rooms[1].erase("combat_cleared")
	snapshot.stage_rooms[1].enemies_remaining = 0
	main.current_run = snapshot.duplicate(true)
	main.hide_room_event()
	main.continue_saved_run()
	for i in 5:
		await process_frame
	room = main.get_room_node(1)
	check(room.get_node("WestDoor/WestDoorBlocker/CollisionShape2D").disabled, "Legacy clear did not unlock")
	check(main.enemy_container.get_child_count() == 0, "Legacy clear respawned enemies")
	check(main.current_room_event_type == main.RoomEventType.COMBAT_REWARD, "Pending reward was lost on restore")
	main.queue_free()
	await process_frame
	print("DOOR_RESTORE_TEST: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
