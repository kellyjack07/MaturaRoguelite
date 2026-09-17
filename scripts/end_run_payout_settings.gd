extends Resource
class_name EndRunPayoutSettings

## Central, editable end-of-run payout rates. The UI only receives the
## calculated category totals; these formulas stay out of player-facing text.
@export var first_ever_level_essence: int = 10
@export var repeat_level_essence: int = 10
@export var level_overrides: Dictionary = {}
@export var complete_stage_essence: int = 30
@export var regular_kills_per_essence: int = 8
@export var regular_kill_essence: int = 1
@export var designated_boss_essence: int = 2
@export var gold_per_essence: int = 5
@export var gold_conversion_essence: int = 1

func calculate(accounting: Dictionary) -> Dictionary:
	var level_records: Array = accounting.get("completed_levels", [])
	var distinct_levels: Dictionary = {}
	for record: Variant in level_records:
		if record is Dictionary:
			var level_id := str(record.get("level_id", ""))
			if not level_id.is_empty():
				distinct_levels[level_id] = record

	var level_essence := 0
	for level_id: String in distinct_levels:
		var record: Dictionary = distinct_levels[level_id]
		var default_amount := first_ever_level_essence if bool(record.get("first_clear", false)) else repeat_level_essence
		level_essence += int(level_overrides.get(level_id, default_amount))

	var completed_stage_floors: Dictionary = {}
	for level_id: String in distinct_levels:
		var record: Dictionary = distinct_levels[level_id]
		var world := int(record.get("stage_world", 0))
		var floor := int(record.get("stage_floor", 0))
		if world > 0 and floor > 0:
			if not completed_stage_floors.has(world):
				completed_stage_floors[world] = {}
			completed_stage_floors[world][floor] = true
	var completed_stages := 0
	for world: Variant in completed_stage_floors:
		if completed_stage_floors[world].has(1) and completed_stage_floors[world].has(2) and completed_stage_floors[world].has(3):
			completed_stages += 1

	var regular_kills := maxi(int(accounting.get("regular_kills", 0)), 0)
	var boss_kills := maxi(int(accounting.get("boss_kills", 0)), 0)
	var leftover_gold := maxi(int(accounting.get("leftover_gold", 0)), 0)
	var debuff_essence := maxi(int(accounting.get("debuff_bonus_essence", 0)), 0)
	var regular_essence := (regular_kills / regular_kills_per_essence) * regular_kill_essence if regular_kills_per_essence > 0 else 0
	var boss_essence := boss_kills * designated_boss_essence
	var gold_essence := (leftover_gold / gold_per_essence) * gold_conversion_essence if gold_per_essence > 0 else 0
	var stage_essence := completed_stages * complete_stage_essence
	return {
		"completed_levels": distinct_levels.values(),
		"completed_level_count": distinct_levels.size(),
		"level_essence": level_essence,
		"completed_stage_count": completed_stages,
		"stage_essence": stage_essence,
		"regular_kills": regular_kills,
		"regular_essence": regular_essence,
		"boss_kills": boss_kills,
		"boss_essence": boss_essence,
		"leftover_gold": leftover_gold,
		"gold_essence": gold_essence,
		"debuff_essence": debuff_essence,
		"total_essence": level_essence + stage_essence + regular_essence + boss_essence + gold_essence + debuff_essence,
	}
