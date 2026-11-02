class_name Rotator
extends Node3D
## Decorative rotation without physics. Used for placeholder sky bodies and beacons.

@export var axis: Vector3 = Vector3.UP
@export var degrees_per_second: float = 10.0


func _process(delta: float) -> void:
	if axis.is_zero_approx():
		return
	rotate_object_local(axis.normalized(), deg_to_rad(degrees_per_second) * delta)
