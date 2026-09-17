extends Resource
class_name DebuffCatalogue

@export var definitions: Array[DebuffDefinition] = []
@export var tier_essence: Dictionary = {1: 1, 2: 2, 3: 3}

func get_definition(debuff_id: String) -> DebuffDefinition:
	for definition in definitions:
		if definition != null and definition.id == debuff_id:
			return definition
	return null

func eligible(stage: int, encounter_entries: Array[Dictionary]) -> Array[DebuffDefinition]:
	# Capability gate: only effects with authoritative room/enemy hooks are
	# offered. Definitions for later hooks remain editable but cannot be selected.
	var supported := ["enemy_health", "more_enemies", "slowness", "damage_reduction", "enemy_haste"]
	var has_projectile := false
	var has_melee := false
	for entry in encounter_entries:
		var enemy_id := str(entry.get("enemy_id", ""))
		has_projectile = has_projectile or enemy_id.contains("archer")
		has_melee = has_melee or not enemy_id.is_empty()
	var result: Array[DebuffDefinition] = []
	for definition in definitions:
		if definition == null or not supported.has(definition.id) or not definition.enabled or definition.selection_weight <= 0.0:
			continue
		if stage < definition.min_stage or stage > definition.max_stage:
			continue
		if definition.requires_projectile and not has_projectile:
			continue
		if definition.requires_melee and not has_melee:
			continue
		result.append(definition)
	return result
