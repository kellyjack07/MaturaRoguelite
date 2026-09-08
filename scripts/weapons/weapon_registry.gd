extends RefCounted
class_name WeaponRegistry

const SWORD_DEFINITION := preload("res://data/weapons/sword.tres")
const SPEAR_DEFINITION := preload("res://data/weapons/spear.tres")
const HAMMER_DEFINITION := preload("res://data/weapons/hammer.tres")

const WEAPON_IDS := [&"sword", &"spear", &"hammer"]


static func get_weapon_ids() -> Array:
	return WEAPON_IDS.duplicate()


static func has_weapon(weapon_id: String) -> bool:
	return StringName(weapon_id) in WEAPON_IDS


static func get_definition(weapon_id: String) -> Resource:
	match weapon_id:
		"spear":
			return SPEAR_DEFINITION
		"hammer", "heavy":
			return HAMMER_DEFINITION
		_:
			return SWORD_DEFINITION


static func normalize_weapon_id(weapon_id: String) -> String:
	if weapon_id == "heavy":
		return "hammer"
	if not has_weapon(weapon_id):
		return "sword"
	return weapon_id
