extends Node
class_name StaminaComponent

const DEFAULT_SETTINGS := preload("res://data/player/stamina_settings.tres")

signal stamina_changed(current: float, maximum: float)
signal boost_changed(seconds_left: float)

@export var settings: StaminaSettings = DEFAULT_SETTINGS

var current_stamina: float = 0.0
var regen_delay_left: float = 0.0
var boost_time_left: float = 0.0


func _ready() -> void:
	reset_for_run()


func tick(delta: float, is_dashing: bool, is_alive: bool = true) -> void:
	if delta <= 0.0 or not is_alive:
		return
	regen_delay_left = maxf(regen_delay_left - delta, 0.0)
	var previous_boost := boost_time_left
	boost_time_left = maxf(boost_time_left - delta, 0.0)
	if not is_equal_approx(previous_boost, boost_time_left):
		boost_changed.emit(boost_time_left)

	if is_dashing:
		return
	var regen_rate := settings.boost_regen_per_second if boost_time_left > 0.0 else settings.regen_per_second
	if boost_time_left <= 0.0 and regen_delay_left > 0.0:
		return
	if regen_rate <= 0.0 or current_stamina >= get_max_stamina():
		return
	var previous_stamina := current_stamina
	current_stamina = minf(current_stamina + regen_rate * delta, get_max_stamina())
	if not is_equal_approx(previous_stamina, current_stamina):
		stamina_changed.emit(current_stamina, get_max_stamina())


func get_max_stamina() -> float:
	return maxf(settings.max_stamina, 0.0)


func get_dash_cost() -> float:
	return maxf(settings.dash_cost, 0.0)


func can_spend(amount: float) -> bool:
	return amount >= 0.0 and current_stamina >= amount


func spend(amount: float) -> bool:
	var cost := maxf(amount, 0.0)
	if not can_spend(cost):
		return false
	current_stamina = maxf(current_stamina - cost, 0.0)
	regen_delay_left = maxf(settings.regen_delay, 0.0)
	stamina_changed.emit(current_stamina, get_max_stamina())
	return true


func can_start_boost() -> bool:
	return boost_time_left <= 0.0


func start_boost() -> bool:
	if not can_start_boost():
		return false
	boost_time_left = maxf(settings.boost_duration, 0.0)
	boost_changed.emit(boost_time_left)
	return true


func reset_for_run() -> void:
	current_stamina = get_max_stamina()
	regen_delay_left = 0.0
	boost_time_left = 0.0
	stamina_changed.emit(current_stamina, get_max_stamina())
	boost_changed.emit(0.0)


func get_snapshot() -> Dictionary:
	return {
		"current_stamina": current_stamina,
		"regen_delay_left": regen_delay_left,
		"boost_time_left": boost_time_left,
	}


func set_snapshot(snapshot: Dictionary) -> void:
	current_stamina = clampf(float(snapshot.get("current_stamina", get_max_stamina())), 0.0, get_max_stamina())
	regen_delay_left = maxf(float(snapshot.get("regen_delay_left", 0.0)), 0.0)
	boost_time_left = maxf(float(snapshot.get("boost_time_left", 0.0)), 0.0)
	stamina_changed.emit(current_stamina, get_max_stamina())
	boost_changed.emit(boost_time_left)
