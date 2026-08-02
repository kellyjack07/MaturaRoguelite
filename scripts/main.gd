extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var death_screen: Control = $UI/DeathScreen
@onready var health_label: Label = $UI/HealthLabel
@onready var health_component: HealthComponent = $Player/Health
@onready var state_label: Label = $UI/StateLabel
@onready var multiplier_label: Label = $UI/MultiplierLabel
@onready var damage_label: Label = $UI/DamageLabel

var hit_stop_active: bool = false
var hit_stop_duration: float = 0.01
var hit_stop_scale: float = 0.05

#start
func _ready() -> void:
	health_component.health_changed.connect(_on_player_health_changed)
	death_screen.visible = false
	_on_player_health_changed(health_component.current_health, health_component.max_health)
	update_debug_ui()

#debug ui
func update_debug_ui() -> void:
	state_label.text = "State: " + player.movement_state
	multiplier_label.text = "Multiplier: " + str(player.get_damage_multiplier())
	damage_label.text = "Last Damage: " + str(player.last_damage_dealt)

func _process(_delta: float) -> void:
	update_debug_ui()

#player death
func _on_player_died() -> void:
	call_deferred("show_death_screen")

func show_death_screen() -> void:
	death_screen.visible = true
	get_tree().paused = true

func trigger_hit_stop() -> void:
	if hit_stop_active:
		return
	
	hit_stop_active = true
	Engine.time_scale = hit_stop_scale
	
	await get_tree().create_timer(hit_stop_duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
	hit_stop_active = false

#health ui
func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "HP: " + str(current_health) + "/" + str(max_health)

#restart
func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	call_deferred("restart_scene")


func restart_scene() -> void:
	get_tree().reload_current_scene()
