extends Node3D

@export var speed := 2.5
@export var boost := 2.0
@export var turn_speed := 5.0
@export var mouse_sensitivity := 0.003
@export var bounds_min := Vector3(-11.3, -6.8, -6.3)
@export var bounds_max := Vector3(11.3, -0.35, 6.3)

@onready var pivot: Node3D = $"../CameraPivot"
@onready var arm: SpringArm3D = $"../CameraPivot/SpringArm3D"
@onready var touch: TouchUI = $"../TouchLayer/TouchUI"
@onready var model_mat: ShaderMaterial = $Model.material_override

var yaw := 0.0
var pitch := -0.3
var velocity := Vector3.ZERO
var swim_phase := 0.0
var fin_phase := 0.0


func _ready() -> void:
	pivot.global_position = global_position
	if DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		touch.hide()


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
	dir += basis_cam.x * touch.move.x + basis_cam.z * touch.move.y
	if touch.up: dir += Vector3.UP
	if touch.down: dir += Vector3.DOWN
	var look: Vector2 = touch.consume_look()
	yaw -= look.x
	pitch = clamp(pitch - look.y, -1.4, 1.4)
	dir = dir.normalized()

	var target_speed := speed * (boost if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	velocity = velocity.lerp(dir * target_speed, 1.0 - exp(-3.0 * delta))
	position += velocity * delta
	var clamped := position.clamp(bounds_min, bounds_max)
	if clamped != position:
		velocity *= Vector3(float(clamped.x == position.x), float(clamped.y == position.y), float(clamped.z == position.z))
		position = clamped

	var effort := clampf(velocity.length() / speed, 0.0, 2.0)
	swim_phase += delta * (4.0 + effort * 7.0)
	fin_phase += delta * (3.0 + effort * 4.0)
	model_mat.set_shader_parameter("swim_phase", swim_phase)
	model_mat.set_shader_parameter("fin_phase", fin_phase)
	model_mat.set_shader_parameter("swim_amount", 0.02 + effort * 0.035)

	if velocity.length() > 0.1:
		var target := Basis.looking_at(velocity.normalized(), Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)
		basis = basis.orthonormalized().slerp(target, 1.0 - exp(-turn_speed * delta))


func _process(delta: float) -> void:
	pivot.global_position = pivot.global_position.lerp(global_position, 1.0 - exp(-6.0 * delta))
	pivot.rotation = Vector3(pitch, yaw, 0.0)
