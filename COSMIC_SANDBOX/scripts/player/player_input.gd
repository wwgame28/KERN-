class_name PlayerInput
extends Node
## Collects player intent from Input Actions, mouse and touch.
## Keyboard, gamepad and the on-screen touch controls all drive the same Input Actions;
## this node only translates them into movement/look/intent values.

signal interact_requested
signal gravity_toggle_requested

## Godot marks mouse events emulated from a touchscreen with device id -1.
const EMULATED_DEVICE_ID: int = -1

## Radians per pixel of mouse movement (PC, captured mouse).
@export var mouse_sensitivity: float = 0.0025
## Radians per pixel of finger drag in the touch look area.
@export var touch_look_sensitivity: float = 0.006
## Radians per second at full camera stick / arrow keys.
@export var stick_look_speed: float = 2.6
@export var invert_look_y: bool = false

## When false the player ignores gameplay input (e.g. while a dialog is open).
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_look_delta = Vector2.ZERO

## PC only: capture the mouse on left click for camera control.
var mouse_capture_enabled: bool = true

## Accumulated look input in radians: x > 0 turns right, y > 0 looks down.
var _look_delta: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	if not enabled:
		return
	var stick: Vector2 = Input.get_vector(
		InputActions.CAMERA_LEFT, InputActions.CAMERA_RIGHT,
		InputActions.CAMERA_UP, InputActions.CAMERA_DOWN)
	if stick != Vector2.ZERO:
		_add_look(stick * stick_look_speed * delta)
	if Input.is_action_just_pressed(InputActions.INTERACT):
		interact_requested.emit()
	if Input.is_action_just_pressed(InputActions.TOGGLE_GRAVITY):
		gravity_toggle_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Mouse events emulated from touches (device id -1) must not drive the camera:
	# on phones the touch UI handles look input itself.
	if (event is InputEventMouse) and event.device == EMULATED_DEVICE_ID:
		return
	if event is InputEventMouseMotion:
		if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			_add_look(motion.relative * mouse_sensitivity)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if (button.pressed and button.button_index == MOUSE_BUTTON_LEFT
				and enabled and mouse_capture_enabled
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(InputActions.RELEASE_MOUSE):
		release_mouse()


## Movement intent: x = right, y = back (Godot forward is -Z). Length is 0..1.
func get_move_vector() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK)


func is_jump_just_pressed() -> bool:
	return enabled and Input.is_action_just_pressed(InputActions.JUMP)


## Called by the touch look area with the finger drag in pixels.
func add_touch_look(screen_delta: Vector2) -> void:
	if enabled:
		_add_look(screen_delta * touch_look_sensitivity)


## Returns the look input gathered since the last call and resets it.
func consume_look_delta() -> Vector2:
	var result: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return result


func release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add_look(delta_radians: Vector2) -> void:
	_look_delta.x += delta_radians.x
	if invert_look_y:
		_look_delta.y -= delta_radians.y
	else:
		_look_delta.y += delta_radians.y
