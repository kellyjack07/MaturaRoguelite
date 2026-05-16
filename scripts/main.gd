extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var death_screen: Control = $UI/DeathScreen
@onready var health_label: Label = $UI/HealthLabel
@onready var health_component: HealthComponent = $Player/Health

#start
func _ready() -> void:
	health_component.health_changed.connect(_on_player_health_changed)
	death_screen.visible = false
	_on_player_health_changed(health_component.current_health, health_component.max_health)


#player death
func _on_player_died() -> void:
	call_deferred("show_death_screen")


func show_death_screen() -> void:
	death_screen.visible = true
	get_tree().paused = true


#health ui
func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "HP: " + str(current_health) + "/" + str(max_health)

#restart
func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	call_deferred("restart_scene")


func restart_scene() -> void:
	get_tree().reload_current_scene()
