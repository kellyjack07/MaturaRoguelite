extends VBoxContainer
class_name BossHealthBar

signal boss_died

@onready var name_label: Label = $Name
@onready var health_bar: EnemyHealthBar = $EnemyHealthBar

var bound_health: HealthComponent


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(boss_name: String, health: HealthComponent, width: float) -> void:
	name_label.text = boss_name
	# Keep the reusable world-space bar inside this UI row; world-space bars
	# normally use an offset to center themselves over an enemy.
	health_bar.always_visible = true
	health_bar.setup(health, Vector2(width * 0.5, 0.0), width)
	bound_health = health
	if bound_health != null:
		bound_health.died.connect(_on_died)


func _on_died() -> void:
	boss_died.emit()


func _exit_tree() -> void:
	if bound_health != null and bound_health.died.is_connected(_on_died):
		bound_health.died.disconnect(_on_died)
