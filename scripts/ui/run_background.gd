extends CanvasLayer

var drift_time: float = 0.0

func _ready() -> void:
	$Atmosphere.material = $Atmosphere.material.duplicate()

func _process(delta: float) -> void:
	if not visible:
		return
	# Gameplay time pauses naturally with the scene tree; no wall-clock shader TIME.
	drift_time += delta
	$Atmosphere.material.set_shader_parameter("drift_time", drift_time)
