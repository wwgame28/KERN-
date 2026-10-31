extends Camera3D

@export var water_level := 0.0
@export var fog_color := Color(0.06, 0.32, 0.4)
@export var fog_density := 0.07
@export var world_env: WorldEnvironment
@export var overlay: ColorRect

var blend := 0.0
var time := 0.0


func _process(delta: float) -> void:
	time += delta
	var under := global_position.y < water_level
	blend = move_toward(blend, 1.0 if under else 0.0, delta * 6.0)

	var env := world_env.environment
	env.fog_enabled = blend > 0.001
	env.fog_light_color = fog_color
	env.fog_density = fog_density * blend
	overlay.visible = blend > 0.001
	(overlay.material as ShaderMaterial).set_shader_parameter("strength", blend)

	rotation.z = sin(time * 0.7) * 0.012 * blend
