extends Node
class_name HealthComponent

@export var max_health: int = 3
var current_health: int

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

#start
func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


#damage
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	if current_health <= 0:
		return
	
	current_health = max(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	
	if current_health == 0:
		died.emit()


#heal
func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	if current_health <= 0:
		return
	
	current_health = min(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


#reset
func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


#check
func is_dead() -> bool:
	return current_health <= 0
