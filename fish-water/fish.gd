extends Node3D

@export var speed := 4.0
@export var boost := 2.0
@export var turn_speed := 6.0
@export var mouse_sensitivity := 0.003
@export var surface_y := -0.25
@export var bottom_y := -9.5

@onready var pivot: Node3D = $"../CameraPivot"
@onready var arm: SpringArm3D = $"../CameraPivot/SpringArm3D"

var yaw := 0.0
var pitch := -0.3
var velocity := Vector3.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = max(1.5, arm.spring_length - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = min(15.0, arm.spring_length + 0.5)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var basis_cam := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir -= basis_cam.z
	if Input.is_physical_key_pressed(KEY_S): dir += basis_cam.z
	if Input.is_physical_key_pressed(KEY_A): dir -= basis_cam.x
	if Input.is_physical_key_pressed(KEY_D): dir += basis_cam.x
	if Input.is_physical_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C): dir += Vector3.DOWN
	dir = dir.normalized()

	var target_speed := speed * (boost if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	velocity = velocity.lerp(dir * target_speed, 1.0 - exp(-3.0 * delta))
	position += velocity * delta
	position.y = clamp(position.y, bottom_y, surface_y)

	if velocity.length() > 0.1:
		var target := Basis.looking_at(velocity.normalized(), Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)
		basis = basis.orthonormalized().slerp(target, 1.0 - exp(-turn_speed * delta))

	pivot.global_position = global_position
	pivot.rotation = Vector3(pitch, yaw, 0.0)
