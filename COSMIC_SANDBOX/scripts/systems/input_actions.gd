class_name InputActions
extends RefCounted
## Central list of Input Action names used by the game.
## Bindings live in project.godot (Project Settings -> Input Map) and can be remapped there.
## ensure_defaults() only adds actions that are completely missing,
## so it never overrides bindings changed by the user.

const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const CAMERA_LEFT: StringName = &"camera_left"
const CAMERA_RIGHT: StringName = &"camera_right"
const CAMERA_UP: StringName = &"camera_up"
const CAMERA_DOWN: StringName = &"camera_down"
const JUMP: StringName = &"jump"
const INTERACT: StringName = &"interact"
const TOGGLE_GRAVITY: StringName = &"toggle_gravity"
## Built-in Godot action (Escape). Releases the captured mouse on PC.
const RELEASE_MOUSE: StringName = &"ui_cancel"

const AXIS_DEADZONE: float = 0.2
const BUTTON_DEADZONE: float = 0.5


## Adds default bindings for any action missing from the Input Map.
## Returns the names of actions that had to be added (empty when project.godot is complete).
static func ensure_defaults() -> PackedStringArray:
	var added: PackedStringArray = PackedStringArray()
	if _ensure(MOVE_FORWARD, AXIS_DEADZONE, [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)]):
		added.append(MOVE_FORWARD)
	if _ensure(MOVE_BACK, AXIS_DEADZONE, [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)]):
		added.append(MOVE_BACK)
	if _ensure(MOVE_LEFT, AXIS_DEADZONE, [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)]):
		added.append(MOVE_LEFT)
	if _ensure(MOVE_RIGHT, AXIS_DEADZONE, [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)]):
		added.append(MOVE_RIGHT)
	if _ensure(CAMERA_LEFT, AXIS_DEADZONE, [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0)]):
		added.append(CAMERA_LEFT)
	if _ensure(CAMERA_RIGHT, AXIS_DEADZONE, [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0)]):
		added.append(CAMERA_RIGHT)
	if _ensure(CAMERA_UP, AXIS_DEADZONE, [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)]):
		added.append(CAMERA_UP)
	if _ensure(CAMERA_DOWN, AXIS_DEADZONE, [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)]):
		added.append(CAMERA_DOWN)
	if _ensure(JUMP, BUTTON_DEADZONE, [_key(KEY_SPACE), _button(JOY_BUTTON_A)]):
		added.append(JUMP)
	if _ensure(INTERACT, BUTTON_DEADZONE, [_key(KEY_E), _button(JOY_BUTTON_X)]):
		added.append(INTERACT)
	if _ensure(TOGGLE_GRAVITY, BUTTON_DEADZONE, [_key(KEY_G), _button(JOY_BUTTON_Y)]):
		added.append(TOGGLE_GRAVITY)
	if not added.is_empty():
		push_warning("InputActions: missing actions were added with default bindings: %s" % ", ".join(added))
	return added


static func _ensure(action: StringName, deadzone: float, events: Array) -> bool:
	if InputMap.has_action(action):
		return false
	InputMap.add_action(action, deadzone)
	for item in events:
		var input_event: InputEvent = item as InputEvent
		if input_event != null:
			InputMap.action_add_event(action, input_event)
	return true


static func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	return event
