extends CharacterBody2D

@onready var health_component: HealthComponent = $Health

#start
func _ready() -> void:
	health_component.died.connect(on_died)


#death
func on_died() -> void:
	print("enemy died")
	queue_free()
