extends SceneTree

const PlayerScene := preload("res://scenes/player.tscn")
const MainScene := preload("res://scenes/main.tscn")
const HealthScript := preload("res://scripts/health_component.gd")
const HurtboxScript := preload("res://scripts/hurtbox_component.gd")
const WeaponRegistryScript := preload("res://scripts/weapons/weapon_registry.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TEST FAILED: " + message)


func run_tests() -> void:
	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	test_animation_contract(player)
	test_registry_and_cooldowns(player)
	await test_combat_queries(player)
	await test_death_and_reset(player)

	player.queue_free()
	await process_frame
	await test_main_run_integration()

	if failures.is_empty():
		print("PLAYER_WEAPONS_SMOKE_TEST: PASS")
		quit(0)
	else:
		print("PLAYER_WEAPONS_SMOKE_TEST: FAIL (%s failures)" % failures.size())
		for failure in failures:
			print(" - " + failure)
		quit(1)


func test_animation_contract(player: Node) -> void:
	var expected := {
		"idle_down_hammer": [0, 8],
		"idle_down_sword": [1, 9],
		"idle_down_spear": [2, 9],
		"idle_side": [3, 9],
		"idle_down": [4, 9],
		"idle_up": [5, 9],
		"attack_side_hammer": [6, 4],
		"special_hammer": [7, 8],
		"attack_down_hammer": [8, 4],
		"attack_up_hammer": [9, 4],
		"attack_down_sword": [10, 5],
		"special_sword": [11, 4],
		"attack_up_sword": [12, 4],
		"attack_down_spear": [13, 3],
		"attack_up_spear": [14, 3],
		"attack_side_spear": [15, 3],
		"special_side_spear": [16, 7],
		"special_down_spear": [17, 7],
		"special_up_spear": [18, 7],
		"walk_down": [20, 6],
		"walk_up": [21, 6],
		"walk_side": [22, 5],
		"dash_side": [23, 4],
		"dash_down": [24, 4],
		"dash_up": [25, 4],
		"hurt": [26, 4],
		"death": [27, 7],
	}
	var frames: SpriteFrames = player.animated_sprite.sprite_frames
	for animation_name in expected.keys():
		var row: int = expected[animation_name][0]
		var count: int = expected[animation_name][1]
		check(frames.has_animation(animation_name), "Missing animation %s" % animation_name)
		check(frames.get_frame_count(animation_name) == count, "%s frame count does not match Aseprite tag" % animation_name)
		check(is_equal_approx(frames.get_animation_speed(animation_name), 10.0), "%s does not preserve 100ms source timing" % animation_name)
		for frame_index in mini(frames.get_frame_count(animation_name), count):
			var texture := frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
			check(texture != null, "%s frame %s is not an AtlasTexture" % [animation_name, frame_index])
			if texture != null:
				var expected_region := Rect2(frame_index * 192, row * 208, 192, 208)
				check(texture.region == expected_region, "%s frame %s has region %s; expected %s" % [animation_name, frame_index, texture.region, expected_region])
	for looping_animation in ["idle_down_hammer", "idle_down_sword", "idle_down_spear", "idle_side", "idle_down", "idle_up", "walk_down", "walk_up", "walk_side"]:
		check(frames.get_animation_loop(looping_animation), "%s should loop" % looping_animation)
	for one_shot_animation in ["attack_side_hammer", "special_hammer", "attack_down_hammer", "attack_up_hammer", "attack_down_sword", "special_sword", "attack_up_sword", "attack_down_spear", "attack_up_spear", "attack_side_spear", "special_side_spear", "special_down_spear", "special_up_spear", "dash_side", "dash_down", "dash_up", "hurt", "death"]:
		check(not frames.get_animation_loop(one_shot_animation), "%s should not loop" % one_shot_animation)

	check(player.animated_sprite.position == Vector2(0, -10), "Player sprite anchor offset changed")
	check(player.animated_sprite.scale == Vector2(0.7, 0.7), "Player sprite scale changed")
	for weapon_id in WeaponRegistryScript.get_weapon_ids():
		var definition: Resource = WeaponRegistryScript.get_definition(str(weapon_id))
		for action_name in ["idle", "walk", "dash", "basic", "special"]:
			for direction_name in ["down", "side", "up"]:
				var mapped: StringName = definition.get_animation(action_name, direction_name)
				check(not mapped.is_empty(), "%s lacks %s_%s fallback" % [weapon_id, action_name, direction_name])
				check(frames.get_frame_count(mapped) > 0, "%s maps %s_%s to empty animation %s" % [weapon_id, action_name, direction_name, mapped])


func test_registry_and_cooldowns(player: Node) -> void:
	check(player.equip_weapon("not-a-weapon") == "sword", "Invalid weapon ID did not fall back to sword")
	check(player.equip_weapon("heavy") == "hammer", "Legacy heavy weapon ID did not migrate to hammer")
	player.equip_weapon("sword")
	player.start_special_attack()
	var sword_cooldown: float = player.get_special_cooldown_left()
	check(is_equal_approx(sword_cooldown, 1.5), "Sword special cooldown did not start")
	player.equip_weapon("spear")
	player.equip_weapon("sword")
	check(is_equal_approx(player.get_special_cooldown_left(), sword_cooldown), "A-B-A switching reset sword cooldown")
	player.cancel_transient_actions()


func make_target(target_position: Vector2, max_health: int = 100, invulnerability_duration: float = 0.01) -> Node2D:
	var target := Node2D.new()
	target.position = target_position
	var health := HealthScript.new()
	health.name = "Health"
	health.max_health = max_health
	target.add_child(health)
	var hurtbox := HurtboxScript.new()
	hurtbox.name = "Hurtbox"
	hurtbox.health_path = NodePath("../Health")
	hurtbox.invulnerability_duration = invulnerability_duration
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	shape_node.shape = shape
	hurtbox.add_child(shape_node)
	target.add_child(hurtbox)
	root.add_child(target)
	return target


func test_combat_queries(player: Node) -> void:
	player.reset_for_run(true)
	player.set_physics_process(false)
	player.position = Vector2.ZERO
	player.move_direction = Vector2.DOWN
	player.input_direction = Vector2.ZERO
	player.movement_state = player.MovementState.STATIONARY
	player.equip_weapon("sword")
	player.set_effective_attack_damage(5, 8)

	var targets: Array[Node2D] = []
	for target_position in [Vector2(0, 10), Vector2(2, 15), Vector2(-2, 20), Vector2(0, 25)]:
		targets.append(make_target(target_position))
	await physics_frame
	for target in targets:
		check(target.get_node("Health").current_health == 100, "Idle overlap dealt weapon damage")

	player.start_attack()
	await physics_frame
	player.update_action(0.21)
	var damaged_targets := 0
	for target in targets:
		if target.get_node("Health").current_health < 100:
			damaged_targets += 1
	check(damaged_targets == 3, "Sword basic did not respect its full-attack target cap of 3")
	player.cancel_transient_actions()
	await create_timer(0.05).timeout
	for target in targets:
		target.queue_free()
	await process_frame

	var spear_target := make_target(Vector2(0, 36), 100, 0.5)
	await physics_frame
	player.equip_weapon("spear")
	player.set_effective_attack_damage(4, 7)
	player.start_special_attack()
	await physics_frame
	player.update_action(0.55)
	check(spear_target.get_node("Health").current_health == 93, "Spear special ignored target invulnerability between pulses")
	player.cancel_transient_actions()
	await create_timer(0.55).timeout
	spear_target.queue_free()
	await process_frame

	var stale_target := make_target(Vector2(0, 20))
	await physics_frame
	player.equip_weapon("hammer")
	player.start_attack()
	player.equip_weapon("spear")
	player.update_action(0.5)
	check(stale_target.get_node("Health").current_health == 100, "Weapon switch allowed a stale hammer hit")
	check(not player.attack_area.hitbox_active and not player.is_attacking, "Weapon switch left the attack active")
	stale_target.queue_free()
	await process_frame


func test_death_and_reset(player: Node) -> void:
	player.equip_weapon("sword")
	player.health_component.reset_health()
	player.health_component.take_damage(player.health_component.max_health)
	check(player.action_state == player.ActionState.DEAD, "Lethal damage did not enter death state")
	check(not player.hurtbox.enabled, "Player hurtbox stayed enabled during death")
	await create_timer(0.8).timeout
	check(player.death_emitted, "Death animation did not finish and emit death")
	check(not player.animated_sprite.visible, "Player sprite stayed visible after death animation")
	player.reset_for_run(true)
	player.set_physics_process(false)
	check(player.action_state == player.ActionState.NORMAL, "Run reset did not clear death state")
	check(player.hurtbox.enabled and player.animated_sprite.visible, "Run reset did not restore hurtbox and visibility")


func test_main_run_integration() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.start_new_run()
	await process_frame

	main.meta_progression["weapon_trees"]["sword"]["base_damage"] = 2
	main.meta_progression["weapon_trees"]["sword"]["special_damage"] = 3
	main.current_run["debuff_state"]["attack_penalty"] = 1
	main.current_run["weapon"] = "sword"
	main.apply_run_modifiers()
	check(main.player.effective_basic_damage == 6, "Sword basic modifiers were not applied exactly once")
	check(main.player.effective_special_damage == 10, "Sword special modifiers were not applied")
	main.current_run["weapon"] = "spear"
	main.apply_run_modifiers()
	main.current_run["weapon"] = "sword"
	main.apply_run_modifiers()
	check(main.player.effective_basic_damage == 6 and main.player.effective_special_damage == 10, "A-B-A switching accumulated or lost modifiers")

	var hammer_unlocked_before: bool = main.meta_progression["weapon_unlocks"]["hammer"]
	main.open_developer_weapon_screen()
	check(main.dev_weapon_screen.visible and paused, "Developer weapon screen did not pause a live run")
	main.equip_developer_weapon("hammer")
	check(main.current_run["weapon"] == "hammer" and main.player.equipped_weapon_id == "hammer", "Developer selection did not update run and player together")
	check(main.meta_progression["weapon_unlocks"]["hammer"] == hammer_unlocked_before, "Developer selection changed permanent unlocks")
	var snapshot: Dictionary = main.build_run_snapshot()
	check(snapshot["weapon"] == "hammer" and snapshot.has("weapon_cooldowns"), "Run snapshot did not persist weapon state")
	main.close_developer_weapon_screen()
	check(not paused and not main.dev_weapon_screen.visible, "Developer screen did not restore the prior pause state")

	main.queue_free()
	await process_frame
	await create_timer(0.6).timeout
