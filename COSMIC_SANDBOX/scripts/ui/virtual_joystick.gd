class_name VirtualJoystick
extends Control
## Multi-touch virtual stick. The control's rect is the touch zone; the stick appears
## where the finger lands. It feeds analog strength into Input Actions, so movement
## code reads exactly the same actions as keyboard and gamepad.

@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_forward"
@export var action_down: StringName = &"move_back"
@export var base_radius: float = 100.0
@export var knob_radius: float = 42.0
## Extra dead zone on top of the Input Map dead zone (0 = rely on the action dead zone).
@export var dead_zone: float = 0.0
## Distance from the zone's bottom-left corner to the stick when idle.
@export var rest_margin: float = 24.0
## When true, the stick center jumps to where the finger first touches.
@export var follow_touch: bool = true
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.14)
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var active_color: Color = Color(0.55, 0.9, 1.0, 0.8)

var output: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset_center)
	_reset_center()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and is_visible_in_tree() and get_global_rect().has_point(touch.position):
				_touch_index = touch.index
				if follow_touch:
					_center = _clamp_center(touch.position - global_position)
				_update_knob(touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var active: bool = _touch_index != -1
	draw_circle(_center, base_radius, base_color)
	draw_arc(_center, base_radius, 0.0, TAU, 48, ring_color, 3.0, true)
	draw_circle(_center + _knob, knob_radius, active_color if active else knob_color)


func _update_knob(screen_position: Vector2) -> void:
	var offset: Vector2 = (screen_position - global_position) - _center
	_knob = offset.limit_length(base_radius)
	var value: Vector2 = _knob / base_radius
	var strength: float = value.length()
	if strength <= dead_zone:
		value = Vector2.ZERO
	elif dead_zone > 0.0:
		value = value.normalized() * inverse_lerp(dead_zone, 1.0, strength)
	_set_output(value)
	queue_redraw()


func _release() -> void:
	var was_active: bool = _touch_index != -1 or output != Vector2.ZERO
	_touch_index = -1
	_knob = Vector2.ZERO
	_reset_center()
	if was_active:
		_set_output(Vector2.ZERO)


func _reset_center() -> void:
	_center = _clamp_center(Vector2(rest_margin + base_radius, size.y - rest_margin - base_radius))
	queue_redraw()


func _clamp_center(point: Vector2) -> Vector2:
	var max_x: float = maxf(size.x - base_radius, base_radius)
	var max_y: float = maxf(size.y - base_radius, base_radius)
	return Vector2(clampf(point.x, base_radius, max_x), clampf(point.y, base_radius, max_y))


func _set_output(value: Vector2) -> void:
	output = value
	_apply_action(action_left, maxf(-value.x, 0.0))
	_apply_action(action_right, maxf(value.x, 0.0))
	_apply_action(action_up, maxf(-value.y, 0.0))
	_apply_action(action_down, maxf(value.y, 0.0))


func _apply_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
