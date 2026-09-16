extends Control
class_name EnemyHealthBar

const DEFAULT_STYLE := preload("res://data/ui/enemy_health_bar_style.tres")

@export var style: EnemyHealthBarStyle = DEFAULT_STYLE
@export var always_visible: bool = false

@onready var background: Panel = $Background
@onready var fill: ColorRect = $Fill

var health_component: HealthComponent
var bar_width: float = 0.0
var bar_height: float = 0.0
var bar_offset := Vector2.ZERO
var has_taken_damage := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()


func setup(health: HealthComponent, offset_override: Vector2 = Vector2.INF, width_override: float = 0.0) -> void:
	unbind_health()
	health_component = health
	has_taken_damage = false
	if health_component == null:
		visible = false
		return

	bar_width = width_override if width_override > 0.0 else style.width
	bar_height = style.height
	bar_offset = style.offset if offset_override == Vector2.INF else offset_override
	has_taken_damage = health_component.current_health < health_component.max_health
	_apply_style()
	_health_changed(health_component.current_health, health_component.max_health)
	health_component.health_changed.connect(_health_changed)
	health_component.damaged.connect(_damaged)
	health_component.died.connect(_died)


func unbind_health() -> void:
	if health_component == null:
		return
	if health_component.health_changed.is_connected(_health_changed):
		health_component.health_changed.disconnect(_health_changed)
	if health_component.damaged.is_connected(_damaged):
		health_component.damaged.disconnect(_damaged)
	if health_component.died.is_connected(_died):
		health_component.died.disconnect(_died)
	health_component = null


func _apply_style() -> void:
	if not is_instance_valid(background) or not is_instance_valid(fill):
		return
	var width := bar_width if bar_width > 0.0 else style.width
	var height := bar_height if bar_height > 0.0 else style.height
	var border := maxi(style.border_width, 0)
	size = Vector2(width, height)
	position = bar_offset + Vector2(-width * 0.5, 0.0)
	custom_minimum_size = size
	var box := StyleBoxFlat.new()
	box.bg_color = style.background_color
	box.border_color = style.border_color
	box.set_border_width_all(border)
	background.add_theme_stylebox_override("panel", box)
	background.position = Vector2.ZERO
	background.size = size
	fill.color = style.fill_color
	fill.position = Vector2(border, border)
	fill.size = Vector2(maxf(width - border * 2.0, 0.0), maxf(height - border * 2.0, 0.0))


func _health_changed(current: int, maximum: int) -> void:
	var safe_maximum := maxi(maximum, 0)
	var safe_current := clampi(current, 0, safe_maximum)
	var ratio := float(safe_current) / float(safe_maximum) if safe_maximum > 0 else 0.0
	var border := maxi(style.border_width, 0)
	fill.size.x = maxf(size.x - border * 2.0, 0.0) * ratio
	visible = (always_visible and safe_current > 0 and safe_maximum > 0) or (has_taken_damage and safe_current > 0)


func _damaged(_amount: int) -> void:
	has_taken_damage = true
	if health_component != null and not health_component.is_dead():
		visible = true


func _died() -> void:
	visible = false


func _exit_tree() -> void:
	unbind_health()
