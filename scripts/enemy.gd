extends CharacterBody2D

@export var move_speed: float = 50.0

@onready var health_component: HealthComponent = $Health

var player: Node2D = null

#start
func _ready() -> void:
	health_component.died.connect(on_died)


#updates
func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	move_toward_player()



#movement
func move_toward_player() -> void:
	var direction: Vector2 = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	move_and_slide()


#death
func on_died() -> void:
	print("enemy died")
	queue_free()
