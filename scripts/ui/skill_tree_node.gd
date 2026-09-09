extends Button
class_name SkillTreeNode

signal inspected(node_id: String)

const HEALTH_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_health.png")
const HEALTH_LOCKED_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_health_locked.png")
const STRENGTH_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_strength.png")
const STRENGTH_LOCKED_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_strength_locked.png")
const STAT_BOOST_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_stat_boost.png")
const STAT_BOOST_LOCKED_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_stat_boost_locked.png")
const INVENTORY_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_inventory.png")
const INVENTORY_LOCKED_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_icons/skill_inventory_locked.png")
const GENERIC_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/tier_icons/icon_plus.png")
const GENERIC_LOCKED_ICON := preload("res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/tier_icons/icon_plus_locked.png")
const AVAILABLE_ICON_MODULATE := Color(0.72, 0.72, 0.72, 1.0)

var node_view: Dictionary = {}
var selected: bool = false
var selection_texture: Texture2D
var artwork_scale := 1


func set_node_view(view: Dictionary, is_selected: bool, selected_texture: Texture2D = null, scale_factor: int = 1) -> void:
	node_view = view
	selected = is_selected
	selection_texture = selected_texture
	artwork_scale = maxi(1, scale_factor)
	text = ""
	$DisplayIdLabel.text = str(view.get("display_id", view.get("node_id", "?")))
	tooltip_text = "%s\n%s" % [str(view.get("title", "")), str(view.get("description", ""))]
	var state := str(view.get("state", "locked"))
	theme_type_variation = "SkillNode%s" % state.capitalize()
	$SkillIcon.texture = _get_icon_texture(str(view.get("effect_type", "")), state == "locked")
	$SkillIcon.modulate = AVAILABLE_ICON_MODULATE if state == "available" else Color.WHITE
	$SelectionOverlay.texture = selection_texture
	if selection_texture != null:
		var overlay_size := selection_texture.get_size() * artwork_scale
		var icon_center: Vector2 = $SkillIcon.position + $SkillIcon.size * 0.5
		$SelectionOverlay.position = icon_center - overlay_size * 0.5
		$SelectionOverlay.size = overlay_size
	$SelectionOverlay.visible = selected and selection_texture != null


func _get_icon_texture(effect_type: String, locked: bool) -> Texture2D:
	match effect_type:
		"character_max_health":
			return HEALTH_LOCKED_ICON if locked else HEALTH_ICON
		"character_damage", "basic_damage", "special_damage":
			return STRENGTH_LOCKED_ICON if locked else STRENGTH_ICON
		"basic_target_limit":
			return INVENTORY_LOCKED_ICON if locked else INVENTORY_ICON
		"character_move_speed", "basic_reach", "basic_width", "basic_area", "special_cooldown":
			return STAT_BOOST_LOCKED_ICON if locked else STAT_BOOST_ICON
		_:
			return GENERIC_LOCKED_ICON if locked else GENERIC_ICON


func get_node_id() -> String:
	return str(node_view.get("node_id", ""))


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_force_pass_scroll_events = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	inspected.emit(get_node_id())
