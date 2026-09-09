extends Node
class_name SkillTreeService

signal changed

const TREE_DEFINITION: SkillTreeDefinition = preload("res://data/skill_tree/skill_tree.tres")
const CURRENT_VERSION := 1
const WEAPON_IDS := [&"sword", &"spear", &"hammer"]

var definition: SkillTreeDefinition = TREE_DEFINITION
var progression: Dictionary = {}
var persist_callback: Callable
var apply_callback: Callable
var nodes_by_id: Dictionary = {}


func setup(
	meta_progression: Dictionary,
	save_callable: Callable = Callable(),
	apply_callable: Callable = Callable(),
	migrate_legacy: bool = false
) -> void:
	progression = meta_progression
	persist_callback = save_callable
	apply_callback = apply_callable
	_index_and_validate_definition()
	var was_changed := _ensure_progression_shape()
	if migrate_legacy:
		was_changed = _migrate_legacy_progression() or was_changed
	if was_changed:
		_persist()


func _index_and_validate_definition() -> void:
	nodes_by_id.clear()
	for node: SkillNodeDefinition in definition.nodes:
		if node == null or node.node_id.is_empty():
			push_error("Skill tree contains a node without an ID.")
			continue
		if nodes_by_id.has(node.node_id):
			push_error("Duplicate skill-tree node ID: %s" % node.node_id)
			continue
		nodes_by_id[node.node_id] = node
	for node: SkillNodeDefinition in definition.nodes:
		if not node.predecessor_id.is_empty() and not nodes_by_id.has(node.predecessor_id):
			push_error("Skill-tree node %s has unknown predecessor %s." % [node.node_id, node.predecessor_id])


func _ensure_progression_shape() -> bool:
	var was_changed := false
	if not progression.has("skill_tree_version"):
		progression["skill_tree_version"] = CURRENT_VERSION
		was_changed = true
	if not progression.has("purchased_skill_nodes"):
		progression["purchased_skill_nodes"] = []
		was_changed = true
	if not progression.has("tutorial_reward") or not progression["tutorial_reward"] is Dictionary:
		progression["tutorial_reward"] = {"claimed": false, "essence_granted": 0}
		was_changed = true
	else:
		var reward: Dictionary = progression["tutorial_reward"]
		if not reward.has("claimed"):
			reward["claimed"] = false
			was_changed = true
		if not reward.has("essence_granted"):
			reward["essence_granted"] = 0
			was_changed = true
	if not progression.has("pending_unlock_eligibility"):
		progression["pending_unlock_eligibility"] = []
		was_changed = true
	if not progression.has("committed_unlock_eligibility"):
		progression["committed_unlock_eligibility"] = []
		was_changed = true
	if not progression.has("legacy_skill_tree_bonuses"):
		progression["legacy_skill_tree_bonuses"] = _empty_legacy_bonuses()
		was_changed = true
	if not progression.has("weapon_unlocks"):
		progression["weapon_unlocks"] = {"sword": true, "spear": false, "hammer": false}
		was_changed = true
	return was_changed


func _empty_legacy_bonuses() -> Dictionary:
	return {
		"sword": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
		"spear": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
		"hammer": {"basic_damage_flat": 0.0, "special_damage_flat": 0.0},
	}


func _migrate_legacy_progression() -> bool:
	var purchased: Array = progression.get("purchased_skill_nodes", [])
	var unlocks: Dictionary = progression.get("weapon_unlocks", {})
	if bool(unlocks.get("spear", false)) and not purchased.has("spear"):
		purchased.append("spear")
	if bool(unlocks.get("hammer", unlocks.get("heavy", false))) and not purchased.has("hammer"):
		purchased.append("hammer")
	progression["purchased_skill_nodes"] = purchased

	var migrated_bonuses := _empty_legacy_bonuses()
	var old_trees: Dictionary = progression.get("weapon_trees", {})
	for weapon_id: StringName in WEAPON_IDS:
		var legacy_key := "heavy" if weapon_id == &"hammer" and not old_trees.has("hammer") else str(weapon_id)
		var old_tree: Dictionary = old_trees.get(legacy_key, {})
		migrated_bonuses[str(weapon_id)] = {
			"basic_damage_flat": float(old_tree.get("base_damage", 0)),
			"special_damage_flat": float(old_tree.get("special_damage", 0)),
		}
	progression["legacy_skill_tree_bonuses"] = migrated_bonuses

	var highest_stage := int(progression.get("highest_stage_completed", 0))
	var committed: Array = progression.get("committed_unlock_eligibility", [])
	for required_stage in _get_required_stages():
		if highest_stage >= required_stage and not committed.has(required_stage):
			committed.append(required_stage)
	progression["committed_unlock_eligibility"] = committed

	# The former save schema had no tutorial grant. Catch up an existing qualifying save once.
	var reward: Dictionary = progression["tutorial_reward"]
	if highest_stage >= definition.tutorial_reward_stage and not bool(reward.get("claimed", false)):
		reward["claimed"] = true
		reward["essence_granted"] = definition.tutorial_reward_essence
		progression["essence"] = int(progression.get("essence", 0)) + definition.tutorial_reward_essence
	progression["tutorial_reward"] = reward
	progression["skill_tree_version"] = CURRENT_VERSION
	return true


func _get_required_stages() -> Array[int]:
	var stages: Array[int] = []
	for node: SkillNodeDefinition in definition.nodes:
		if node.required_stage > 0 and not stages.has(node.required_stage):
			stages.append(node.required_stage)
	stages.sort()
	return stages


func get_essence_balance() -> int:
	return int(progression.get("essence", 0))


func get_ordered_branches() -> Array[Dictionary]:
	var branches: Array[Dictionary] = []
	for branch_name: String in definition.branch_order:
		var node_views: Array[Dictionary] = []
		for node: SkillNodeDefinition in definition.nodes:
			if node.branch_id == branch_name:
				node_views.append(get_node_view(node.node_id))
		node_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
		branches.append({
			"branch_id": branch_name,
			"display_id": str(definition.branch_display_ids.get(branch_name, branch_name)),
			"title": str(definition.branch_titles.get(branch_name, branch_name.capitalize())),
			"nodes": node_views,
		})
	return branches


func get_node_view(node_id: String) -> Dictionary:
	var node := nodes_by_id.get(node_id) as SkillNodeDefinition
	if node == null:
		return {
			"node_id": node_id,
			"state": "locked",
			"blocking_reason": "Unknown skill-tree node: %s" % node_id,
		}
	var validation := validate_purchase(node_id)
	var state := "purchased" if is_node_purchased(node_id) else ("available" if bool(validation.success) else "locked")
	return {
		"node_id": node.node_id,
		"display_id": node.display_id,
		"branch_id": node.branch_id,
		"order": node.order,
		"title": node.title,
		"description": node.description,
		"cost": node.cost,
		"predecessor_id": node.predecessor_id,
		"effect_type": node.effect_type,
		"state": state,
		"blocking_reason": "" if state == "available" else str(validation.reason),
	}


func validate_purchase(node_id: String) -> Dictionary:
	var node := nodes_by_id.get(node_id) as SkillNodeDefinition
	if node == null:
		return _result(false, node_id, "unknown_node", "Unknown skill-tree node: %s" % node_id)
	if is_node_purchased(node_id):
		return _result(false, node_id, "already_purchased", "%s is already purchased." % node.display_id)
	if not node.automatic_with.is_empty():
		return _result(false, node_id, "automatic_node", "%s is purchased automatically with %s." % [node.display_id, nodes_by_id[node.automatic_with].display_id])
	if not node.predecessor_id.is_empty() and not is_node_purchased(node.predecessor_id):
		var predecessor: SkillNodeDefinition = nodes_by_id[node.predecessor_id]
		return _result(false, node_id, "missing_prerequisite", "Purchase %s first." % predecessor.display_id)
	if node.required_stage > 0 and not _has_committed_stage(node.required_stage):
		var pending: Array = progression.get("pending_unlock_eligibility", [])
		var stage_text := _stage_display(node.required_stage)
		if pending.has(node.required_stage):
			return _result(false, node_id, "eligibility_pending", "Clear %s is pending until death, run completion, or save-and-quit." % stage_text)
		return _result(false, node_id, "stage_locked", "Clear %s first." % stage_text)
	if get_essence_balance() < node.cost:
		return _result(false, node_id, "insufficient_essence", "Need %d more essence." % (node.cost - get_essence_balance()))
	return _result(true, node_id, "", "")


func purchase(node_id: String) -> Dictionary:
	var validation := validate_purchase(node_id)
	if not bool(validation.success):
		return validation
	var node: SkillNodeDefinition = nodes_by_id[node_id]
	var old_essence := get_essence_balance()
	var old_purchased: Array = progression.get("purchased_skill_nodes", []).duplicate()
	var old_unlocks: Dictionary = progression.get("weapon_unlocks", {}).duplicate(true)
	var purchased: Array = old_purchased.duplicate()
	purchased.append(node_id)
	if node_id == "root" and not purchased.has("sword"):
		purchased.append("sword")
	progression["purchased_skill_nodes"] = purchased
	progression["essence"] = old_essence - node.cost
	var unlocks: Dictionary = progression.get("weapon_unlocks", {})
	if node_id == "root":
		unlocks["sword"] = true
	elif node_id in ["spear", "hammer"]:
		unlocks[node_id] = true
	progression["weapon_unlocks"] = unlocks

	var save_error := _persist()
	if save_error != OK:
		progression["essence"] = old_essence
		progression["purchased_skill_nodes"] = old_purchased
		progression["weapon_unlocks"] = old_unlocks
		return _result(false, node_id, "save_failed", "Purchase could not be saved (error %d)." % save_error)
	if apply_callback.is_valid():
		apply_callback.call()
	changed.emit()
	return _result(true, node_id, "", "Purchased %s." % node.display_id)


func record_stage_clear(stage: int) -> Dictionary:
	var changed_progression := false
	var reward_granted := 0
	var reward: Dictionary = progression["tutorial_reward"]
	if stage == definition.tutorial_reward_stage and not bool(reward.get("claimed", false)):
		reward_granted = definition.tutorial_reward_essence
		reward["claimed"] = true
		reward["essence_granted"] = reward_granted
		progression["tutorial_reward"] = reward
		progression["essence"] = get_essence_balance() + reward_granted
		changed_progression = true

	var pending: Array = progression.get("pending_unlock_eligibility", [])
	var committed: Array = progression.get("committed_unlock_eligibility", [])
	for required_stage in _get_required_stages():
		if stage >= required_stage and not pending.has(required_stage) and not committed.has(required_stage):
			pending.append(required_stage)
			changed_progression = true
	progression["pending_unlock_eligibility"] = pending
	if changed_progression:
		_persist()
		changed.emit()
	return {"changed": changed_progression, "tutorial_essence_granted": reward_granted}


func commit_pending_eligibility() -> bool:
	var pending: Array = progression.get("pending_unlock_eligibility", [])
	if pending.is_empty():
		return false
	var committed: Array = progression.get("committed_unlock_eligibility", []).duplicate()
	for stage in pending:
		if not committed.has(int(stage)):
			committed.append(int(stage))
	committed.sort()
	progression["committed_unlock_eligibility"] = committed
	progression["pending_unlock_eligibility"] = []
	_persist()
	changed.emit()
	return true


func is_node_purchased(node_id: String) -> bool:
	return progression.get("purchased_skill_nodes", []).has(node_id)


func is_weapon_owned(weapon_id: String) -> bool:
	if weapon_id == "sword":
		return true
	return weapon_id in ["spear", "hammer"] and is_node_purchased(weapon_id)


func is_special_unlocked(weapon_id: String) -> bool:
	return is_node_purchased("%s_07" % weapon_id)


func get_stat_profile(weapon_id: String) -> Dictionary:
	var normalized_id := weapon_id if weapon_id in ["sword", "spear", "hammer"] else "sword"
	var profile := {
		"character_damage_bonus": 0.0,
		"character_move_speed_bonus": 0.0,
		"character_max_health_bonus": 0.0,
		"basic_damage_bonus": 0.0,
		"basic_reach_bonus": 0.0,
		"basic_width_bonus": 0.0,
		"basic_area_bonus": 0.0,
		"basic_target_limit_add": 0,
		"special_damage_bonus": 0.0,
		"special_cooldown_bonus": 0.0,
		"special_unlocked": is_special_unlocked(normalized_id),
		"legacy_basic_damage_flat": 0.0,
		"legacy_special_damage_flat": 0.0,
	}
	for node: SkillNodeDefinition in definition.nodes:
		if not is_node_purchased(node.node_id) or node.effect_type.is_empty():
			continue
		if node.effect_type.begins_with("character_"):
			var strength := 1.0 if node.branch_id == normalized_id else definition.off_weapon_character_strength
			profile["%s_bonus" % node.effect_type] += node.effect_value * strength
		elif node.branch_id == normalized_id:
			match node.effect_type:
				"basic_target_limit":
					profile.basic_target_limit_add += roundi(node.effect_value)
				"special_unlock":
					profile.special_unlocked = true
				_:
					profile["%s_bonus" % node.effect_type] += node.effect_value
	var legacy: Dictionary = progression.get("legacy_skill_tree_bonuses", {}).get(normalized_id, {})
	profile.legacy_basic_damage_flat = float(legacy.get("basic_damage_flat", 0.0))
	profile.legacy_special_damage_flat = float(legacy.get("special_damage_flat", 0.0))
	return profile


func _has_committed_stage(stage: int) -> bool:
	return progression.get("committed_unlock_eligibility", []).has(stage)


func _stage_display(stage: int) -> String:
	return "%d-%d" % [int((stage - 1) / 3) + 1, int((stage - 1) % 3) + 1]


func _result(success: bool, node_id: String, code: String, reason: String) -> Dictionary:
	return {
		"success": success,
		"node_id": node_id,
		"code": code,
		"reason": reason,
		"essence": get_essence_balance(),
	}


func _persist() -> Error:
	if not persist_callback.is_valid():
		return OK
	var result: Variant = persist_callback.call()
	return int(result) as Error if result != null else OK
