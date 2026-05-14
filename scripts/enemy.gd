extends CharacterBody2D

@onready var health_component: HealthComponent = $Health

#start
func _ready() -> void:
	health_component.died.connect(on_died)


#death
func on_died() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		health_component.take_damage(1)
