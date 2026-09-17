extends Resource
class_name EncounterCatalogue

## Editable encounter catalogue. A missing scene is intentional: it marks a
## planned enemy as pending while the main scene provides an explicit MVP
## fallback. This resource contains no combat behavior or balancing rules.

@export_range(0.0, 1.0, 0.01) var previous_floor_carryover_fraction: float = 0.2
@export var stage_settings: Dictionary = {}


func get_stage_settings(stage: int) -> Dictionary:
	var value: Variant = stage_settings.get(str(stage), {})
	return value as Dictionary if value is Dictionary else {}


func get_regular_roster(stage: int, replay_first_stage: bool = false) -> Array[Dictionary]:
	var settings := get_stage_settings(stage)
	var key := "replay_regular_roster" if replay_first_stage else "regular_roster"
	var value: Variant = settings.get(key, settings.get("regular_roster", []))
	return _copy_entries(value)


func get_final_roster(stage: int) -> Array[Dictionary]:
	return _copy_entries(get_stage_settings(stage).get("final_roster", []))


func get_final_waves(stage: int, replay_first_stage: bool = false) -> Array[Array]:
	var settings := get_stage_settings(stage)
	var key := "replay_final_waves" if replay_first_stage else "final_waves"
	var value: Variant = settings.get(key, [])
	var waves: Array[Array] = []
	if not value is Array:
		return waves
	for wave: Variant in value:
		if wave is Array:
			waves.append(_copy_entries(wave))
	return waves


func get_boss_roster(stage: int) -> Array[Dictionary]:
	return _copy_entries(get_stage_settings(stage).get("boss_roster", []))


func get_boss_support_policy(stage: int) -> Dictionary:
	var value: Variant = get_stage_settings(stage).get("boss_support", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func get_encounter_id(stage: int, kind: String) -> String:
	var settings := get_stage_settings(stage)
	return str(settings.get("%s_encounter_id" % kind, "%s_stage_%d" % [kind, stage]))


func _copy_entries(value: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not value is Array:
		return entries
	for entry: Variant in value:
		if entry is Dictionary:
			entries.append((entry as Dictionary).duplicate(true))
	return entries
