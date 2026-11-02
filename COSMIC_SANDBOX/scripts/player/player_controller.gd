class_name PlayerController
extends CharacterBody3D
## Player movement on the planet surface: camera-relative walking, jumping
## (with coyote time and jump buffer), gravity from GravityController and respawn.
## Input lives in PlayerInput, the camera in PlayerCameraRig, interaction in PlayerInteractor.

signal respawned

@export_group("Movement")
@export var move_speed: float = 6.0
@export var ground_acceleration: float = 45.0
@export var air_acceleration: float = 12.0
@export var jump_velocity: float = 5.2
@export var max_fall_speed: float = 40.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15
@export var turn_speed: float = 12.0

@export_group("Safety")
## Falling below this height returns the player to the spawn point.
@export var kill_height: float = -25.0
## Used only if no GravityController was provided.
@export var fallback_gravity: float = 9.8

var _gravity_controller: GravityController = null
var _spawn_position: Vector3 = Vector3.ZERO
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var input: PlayerInput = $PlayerInput
@onready var interactor: PlayerInteractor = $Interactor
@onready var camera_rig: PlayerCameraRig = $CameraRig
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_spawn_position = global_position
	camera_rig.setup(self, input, self)
	input.interact_requested.connect(_on_interact_requested)


func setup(gravity_controller: GravityController, spawn_position: Vector3) -> void:
	_gravity_controller = gravity_controller
	_spawn_position = spawn_position
	respawn()


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	camera_rig.snap_to_target()
	respawned.emit()


func get_gravity_vector() -> Vector3:
	if _gravity_controller != null:
		return _gravity_controller.get_gravity_vector()
	return Vector3.DOWN * fallback_gravity


func _physics_process(delta: float) -> void:
	var gravity: Vector3 = get_gravity_vector()
	var up: Vector3 = Vector3.UP
	if not gravity.is_zero_approx():
		up = -gravity.normalized()
	up_direction = up

	var on_floor: bool = is_on_floor()
	var vertical_speed: float = velocity.dot(up)
	var horizontal: Vector3 = velocity - up * vertical_speed

	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if input.is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	var desired: Vector3 = _camera_relative_direction(input.get_move_vector(), up) * move_speed
	var acceleration: float = ground_acceleration if on_floor else air_acceleration
	horizontal = horizontal.move_toward(desired, acceleration * delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		vertical_speed = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif not on_floor:
		vertical_speed = maxf(vertical_speed - gravity.length() * delta, -max_fall_speed)

	velocity = horizontal + up * vertical_speed
	move_and_slide()

	_update_visual(delta, horizontal)

	if global_position.y < kill_height:
		respawn()


func _camera_relative_direction(move_input: Vector2, up: Vector3) -> Vector3:
	if move_input == Vector2.ZERO:
		return Vector3.ZERO
	var yaw_basis: Basis = camera_rig.get_yaw_basis()
	var direction: Vector3 = yaw_basis * Vector3(move_input.x, 0.0, move_input.y)
	direction = direction.slide(up)
	if direction.is_zero_approx():
		return Vector3.ZERO
	return direction.normalized() * minf(move_input.length(), 1.0)


func _update_visual(delta: float, horizontal: Vector3) -> void:
	if horizontal.length_squared() < 0.04:
		return
	# The placeholder model faces -Z, so yaw = atan2(-x, -z) turns it toward the motion.
	var target_yaw: float = atan2(-horizontal.x, -horizontal.z)
	var weight: float = 1.0 - exp(-turn_speed * delta)
	_visual.rotation = Vector3(0.0, lerp_angle(_visual.rotation.y, target_yaw, weight), 0.0)


func _on_interact_requested() -> void:
	interactor.try_interact(self)
