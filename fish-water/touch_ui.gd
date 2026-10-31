class_name TouchUI
extends Control

@export var stick_radius := 90.0
@export var button_radius := 55.0
@export var look_sensitivity := 0.006

var move := Vector2.ZERO
var up := false
var down := false
var look_delta := Vector2.ZERO

var _stick_index := -1
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_index := -1
var _button_touches := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _up_center() -> Vector2:
	return Vector2(size.x - 90.0, size.y - 230.0)


func _down_center() -> Vector2:
	return Vector2(size.x - 90.0, size.y - 100.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(_up_center()) < button_radius:
				_button_touches[event.index] = "up"
			elif event.position.distance_to(_down_center()) < button_radius:
				_button_touches[event.index] = "down"
			elif event.position.x < size.x * 0.5 and _stick_index == -1:
				_stick_index = event.index
				_stick_center = event.position
				_stick_pos = event.position
			elif _look_index == -1:
				_look_index = event.index
		else:
			_button_touches.erase(event.index)
			if event.index == _stick_index:
				_stick_index = -1
				move = Vector2.ZERO
			elif event.index == _look_index:
				_look_index = -1
		up = _button_touches.values().has("up")
		down = _button_touches.values().has("down")
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			var offset: Vector2 = (event.position - _stick_center).limit_length(stick_radius)
			_stick_pos = _stick_center + offset
			move = offset / stick_radius
			queue_redraw()
		elif event.index == _look_index:
			look_delta += event.relative * look_sensitivity


func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


func _draw() -> void:
	if _stick_index != -1:
		draw_circle(_stick_center, stick_radius, Color(1, 1, 1, 0.15))
		draw_circle(_stick_pos, 35.0, Color(1, 1, 1, 0.4))
	draw_circle(_up_center(), button_radius, Color(1, 1, 1, 0.4 if up else 0.2))
	draw_circle(_down_center(), button_radius, Color(1, 1, 1, 0.4 if down else 0.2))
	var font := get_theme_default_font()
	draw_string(font, _up_center() + Vector2(-10, 12), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	draw_string(font, _down_center() + Vector2(-10, 12), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
