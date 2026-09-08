extends Resource
class_name WeaponDefinition

@export var weapon_id: String = "sword"
@export var display_name: String = "Sword"
@export var animations: Dictionary = {}
@export var basic_attack: Resource
@export var special_attack: Resource


func get_animation(action_name: String, direction_name: String = "") -> StringName:
	var directional_key := action_name
	if not direction_name.is_empty():
		directional_key += "_" + direction_name

	if animations.has(directional_key):
		return StringName(animations[directional_key])
	if animations.has(action_name):
		return StringName(animations[action_name])
	return StringName()
