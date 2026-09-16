extends Node
class_name PotionInventory

signal changed
const POTION_IDS := ["small_healing", "big_healing", "stamina"]
var quantities: Dictionary = {"small_healing": 0, "big_healing": 0, "stamina": 0}
var equipped_id: String = ""

func reset_for_run() -> void:
	quantities = {"small_healing": 0, "big_healing": 0, "stamina": 0}
	equipped_id = ""
	changed.emit()

func has(id: String) -> bool:
	return int(quantities.get(id, 0)) > 0

func add(id: String) -> bool:
	if not POTION_IDS.has(id) or has(id):
		return false
	quantities[id] = 1
	if equipped_id.is_empty():
		equipped_id = id
	changed.emit()
	return true

func remove(id: String) -> bool:
	if not has(id):
		return false
	quantities[id] = 0
	changed.emit()
	return true

func equip(id: String) -> bool:
	if not has(id):
		return false
	equipped_id = id
	changed.emit()
	return true

func get_snapshot() -> Dictionary:
	return {"quantities": quantities.duplicate(true), "equipped_id": equipped_id}

func set_snapshot(snapshot: Dictionary) -> void:
	quantities = {"small_healing": 0, "big_healing": 0, "stamina": 0}
	var saved: Dictionary = snapshot.get("quantities", {})
	for id in POTION_IDS:
		quantities[id] = clampi(int(saved.get(id, 0)), 0, 1)
	var requested := str(snapshot.get("equipped_id", ""))
	equipped_id = requested if POTION_IDS.has(requested) else ""
	changed.emit()
