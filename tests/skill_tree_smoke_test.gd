extends SceneTree

const SkillTreeServiceScript := preload("res://scripts/progression/skill_tree_service.gd")

var failures: Array[String] = []
var change_count := 0


func _initialize() -> void:
	test_definition_and_purchases()
	test_rewards_and_eligibility()
	test_stat_profiles_and_special_gate()
	test_legacy_migration()
	test_failed_save_rolls_back_purchase()
	if failures.is_empty():
		print("SKILL_TREE_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SKILL_TREE_SMOKE_TEST: FAIL (%d)" % failures.size())
		quit(1)


func fresh_meta(essence: int = 1000) -> Dictionary:
	return {
		"essence": essence,
		"skill_tree_version": 1,
		"purchased_skill_nodes": [],
		"tutorial_reward": {"claimed": false, "essence_granted": 0},
		"pending_unlock_eligibility": [],
		"committed_unlock_eligibility": [],
		"legacy_skill_tree_bonuses": {
			"sword": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
			"spear": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
			"hammer": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
		},
		"weapon_unlocks": {"sword": true, "spear": false, "hammer": false},
	}


func make_service(meta: Dictionary, save_callable: Callable = Callable()) -> SkillTreeService:
	var service: SkillTreeService = SkillTreeServiceScript.new()
	root.add_child(service)
	service.setup(meta, save_callable)
	return service


func test_definition_and_purchases() -> void:
	var meta := fresh_meta(100)
	var service := make_service(meta)
	change_count = 0
	service.changed.connect(count_change)
	var branches := service.get_ordered_branches()
	check(branches.size() == 4, "Skill tree does not expose four ordered branches")
	check(branches[0].display_id == "0" and branches[1].display_id == "1", "Root/Sword display IDs are incorrect")
	check(branches[1].nodes.size() == 11, "Sword branch does not expose branch node plus ten upgrades")
	check(branches[1].nodes[1].display_id == "1-01" and branches[3].nodes[10].display_id == "3-10", "Upgrade display IDs are incorrect")
	var expected_costs := [5, 8, 12, 17, 23, 30, 38, 47, 57, 68]
	var expected_effects := {
		"sword": ["character_damage", "basic_damage", "basic_width", "character_max_health", "basic_target_limit", "basic_reach", "special_unlock", "character_move_speed", "special_damage", "special_cooldown"],
		"spear": ["character_move_speed", "basic_reach", "basic_damage", "character_damage", "basic_target_limit", "basic_width", "special_unlock", "character_max_health", "special_damage", "special_cooldown"],
		"hammer": ["character_max_health", "basic_damage", "basic_area", "character_move_speed", "basic_target_limit", "basic_reach", "special_unlock", "character_damage", "special_damage", "special_cooldown"],
	}
	var expected_values := {
		"sword": [0.1, 0.12, 0.15, 0.1, 1.0, 0.12, 1.0, 0.1, 0.15, -0.15],
		"spear": [0.1, 0.15, 0.12, 0.1, 1.0, 0.15, 1.0, 0.1, 0.15, -0.15],
		"hammer": [0.2, 0.15, 0.15, 0.1, 1.0, 0.12, 1.0, 0.1, 0.15, -0.15],
	}
	for branch_id in ["sword", "spear", "hammer"]:
		for index in 10:
			var node: SkillNodeDefinition = service.nodes_by_id["%s_%02d" % [branch_id, index + 1]]
			check(node.cost == expected_costs[index], "%s_%02d has the wrong cost" % [branch_id, index + 1])
			check(node.effect_type == expected_effects[branch_id][index], "%s_%02d has the wrong effect" % [branch_id, index + 1])
			check(is_equal_approx(node.effect_value, expected_values[branch_id][index]), "%s_%02d has the wrong effect value" % [branch_id, index + 1])
	check(service.nodes_by_id.root.cost == 10 and service.nodes_by_id.spear.cost == 30 and service.nodes_by_id.hammer.cost == 50, "Root or weapon unlock costs are incorrect")
	check(service.nodes_by_id.spear.required_stage == 4 and service.nodes_by_id.hammer.required_stage == 7, "Weapon clear requirements are incorrect")

	var blocked := service.purchase("sword_02")
	check(not blocked.success and blocked.code == "missing_prerequisite", "Purchase bypassed a predecessor")
	var root_result := service.purchase("root")
	check(root_result.success and service.is_node_purchased("sword"), "Root purchase did not automatically unlock the Sword branch")
	check(change_count == 1, "Successful purchase did not emit exactly one change signal")
	check(service.get_essence_balance() == 90, "Root did not deduct exactly 10 essence")
	var duplicate := service.purchase("root")
	check(not duplicate.success and service.get_essence_balance() == 90, "Duplicate root callback deducted essence")
	check(service.purchase("sword_01").success, "First Sword upgrade was not purchasable after root")


func test_rewards_and_eligibility() -> void:
	var reward_meta := fresh_meta(0)
	var reward_service := make_service(reward_meta)
	var first_reward := reward_service.record_stage_clear(1)
	var second_reward := reward_service.record_stage_clear(1)
	check(first_reward.tutorial_essence_granted == 10, "Tutorial 1-1 did not grant exactly 10 essence")
	check(second_reward.tutorial_essence_granted == 0 and reward_service.get_essence_balance() == 10, "Repeated tutorial callback duplicated essence")
	check(reward_meta.tutorial_reward.claimed and reward_meta.tutorial_reward.essence_granted == 10, "Tutorial claimed flag and amount were not persisted together")
	var reloaded_service := make_service(reward_meta)
	reloaded_service.record_stage_clear(1)
	check(reloaded_service.get_essence_balance() == 10, "Reloading duplicated the tutorial reward")

	var meta := fresh_meta(100)
	var service := make_service(meta)
	service.purchase("root")
	check(service.validate_purchase("spear").code == "stage_locked", "Spear was not locked behind 2-1")
	service.record_stage_clear(4)
	check(service.validate_purchase("spear").code == "eligibility_pending", "2-1 eligibility became active before a commit boundary")
	check(meta.pending_unlock_eligibility.has(4) and not meta.committed_unlock_eligibility.has(4), "Qualifying clear was not recorded as pending")
	service.commit_pending_eligibility()
	check(meta.pending_unlock_eligibility.is_empty() and meta.committed_unlock_eligibility.has(4), "Pending eligibility did not commit")
	check(service.purchase("spear").success and service.is_weapon_owned("spear"), "Eligible Spear purchase failed")


func test_stat_profiles_and_special_gate() -> void:
	var meta := fresh_meta()
	meta.purchased_skill_nodes = ["root", "sword", "sword_01"]
	var service := make_service(meta)
	var sword_profile := service.get_stat_profile("sword")
	var spear_profile := service.get_stat_profile("spear")
	check(is_equal_approx(sword_profile.character_damage_bonus, 0.1), "Associated character bonus was not full strength")
	check(is_equal_approx(spear_profile.character_damage_bonus, 0.03), "Off-weapon character bonus was not 30% strength")
	check(not service.is_special_unlocked("sword"), "Special unlocked before node 07")
	for position in range(2, 11):
		var node_id := "sword_%02d" % position
		var result := service.purchase(node_id)
		check(result.success, "%s failed in the linear Sword purchase chain" % node_id)
	check(service.is_special_unlocked("sword"), "Sword node 07 did not unlock its special")
	var upgraded := service.get_stat_profile("sword")
	check(is_equal_approx(upgraded.basic_damage_bonus, 0.12), "Basic damage percentage was not exposed")
	check(upgraded.basic_target_limit_add == 1, "Finite Sword target limit did not receive +1")
	check(is_equal_approx(upgraded.special_damage_bonus, 0.15), "Special damage percentage was not exposed")
	check(is_equal_approx(upgraded.special_cooldown_bonus, -0.15), "Special cooldown percentage was not exposed")


func test_legacy_migration() -> void:
	var legacy := {
		"essence": 20,
		"highest_stage_completed": 4,
		"weapon_unlocks": {"sword": true, "spear": true, "heavy": true},
		"weapon_trees": {
			"sword": {"base_damage": 2, "special_damage": 3},
			"spear": {"base_damage": 1, "special_damage": 0},
			"heavy": {"base_damage": 4, "special_damage": 2},
		},
	}
	var service: SkillTreeService = SkillTreeServiceScript.new()
	root.add_child(service)
	service.setup(legacy, Callable(), Callable(), true)
	check(service.is_weapon_owned("spear") and service.is_weapon_owned("hammer"), "Legacy weapon ownership was not preserved")
	var sword_profile := service.get_stat_profile("sword")
	check(sword_profile.legacy_basic_damage_flat == 2.0 and sword_profile.legacy_special_damage_flat == 3.0, "Legacy damage value was not preserved")
	check(legacy.essence == 30 and legacy.tutorial_reward.claimed, "Legacy qualifying save did not receive the one-time tutorial catch-up")
	check(legacy.committed_unlock_eligibility.has(4), "Legacy 2-1 clear was not committed")
	service.setup(legacy, Callable(), Callable(), false)
	check(legacy.essence == 30, "Reloading migrated progression duplicated tutorial essence")


func test_failed_save_rolls_back_purchase() -> void:
	var meta := fresh_meta(10)
	var service := make_service(meta, Callable(self, "fail_save"))
	var result := service.purchase("root")
	check(not result.success and result.code == "save_failed", "A failed save reported purchase success")
	check(meta.essence == 10 and not service.is_node_purchased("root") and not service.is_node_purchased("sword"), "Failed purchase save did not roll back atomically")


func fail_save() -> Error:
	return ERR_CANT_CREATE


func count_change() -> void:
	change_count += 1


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
