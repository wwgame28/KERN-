class_name TouchActionButton
extends Control
## Round on-screen button that holds an Input Action pressed while touched.
## Handles its own touch index, so it works together with the joystick (multi-touch).

@export var action: StringName = &"jump"
@export var label: String = "Прыжок"
@export var font_size: int = 22
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.16)
@export var pressed_color: Color = Color(0.55, 0.9, 1.0, 0.55)
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.95)

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func set_label(text: String) -> void:
	label = text
	queue_redraw()


func is_held() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and is_visible_in_tree() and _hit(touch.position):
				_touch_index = touch.index
				Input.action_press(action)
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	draw_circle(center, radius, pressed_color if is_held() else fill_color)
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, outline_color, 3.0, true)
	var font: Font = get_theme_default_font()
	if font == null or label.is_empty():
		return
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var text_position: Vector2 = Vector2(center.x - radius, baseline_y)
	draw_string_outline(font, text_position, label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, 4, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, text_color)


func _hit(point: Vector2) -> bool:
	var local_point: Vector2 = point - global_position
	var radius: float = minf(size.x, size.y) * 0.5
	return local_point.distance_to(size * 0.5) <= radius


func _release() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	Input.action_release(action)
	queue_redraw()
