class_name PlayerCameraRig
extends Node3D
## Third-person orbit camera.
## Uses top_level so it follows the target smoothly instead of inheriting its rotation.
## The SpringArm3D pulls the camera closer when level geometry is in the way.

@export var follow_height: float = 1.5
@export var follow_smoothing: float = 14.0
@export var min_pitch_degrees: float = -65.0
@export var max_pitch_degrees: float = 30.0
@export var start_pitch_degrees: float = -18.0

var _target: Node3D = null
var _input: PlayerInput = null
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	_pitch = deg_to_rad(start_pitch_degrees)
	_apply_rotation()


func setup(target: Node3D, player_input: PlayerInput, excluded_body: CollisionObject3D) -> void:
	_target = target
	_input = player_input
	if excluded_body != null:
		_spring_arm.add_excluded_object(excluded_body.get_rid())
	_camera.make_current()
	snap_to_target()


## Instantly moves the rig to the target (after spawn/respawn).
func snap_to_target() -> void:
	if _target == null:
		return
	global_position = _get_follow_point()


## Horizontal camera orientation, used for camera-relative movement.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


func _process(delta: float) -> void:
	if _target == null:
		return
	if _input != null:
		var look: Vector2 = _input.consume_look_delta()
		_yaw = wrapf(_yaw - look.x, -PI, PI)
		_pitch = clampf(_pitch - look.y, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_apply_rotation()
	var weight: float = 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(_get_follow_point(), weight)


func _apply_rotation() -> void:
	_yaw_pivot.rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_pivot.rotation = Vector3(_pitch, 0.0, 0.0)


func _get_follow_point() -> Vector3:
	return _target.global_position + Vector3.UP * follow_height
