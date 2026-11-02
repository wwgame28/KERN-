class_name TouchLookArea
extends Control
## Drag a finger inside this area to rotate the camera.
## Touches that start on a registered blocker (e.g. on-screen buttons) are ignored,
## so the area can lie underneath the buttons.

signal look_dragged(relative: Vector2)

var _blockers: Array[Control] = []
var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_blocker(control: Control) -> void:
	if control != null and not _blockers.has(control):
		_blockers.append(control)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_touch_index = -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if (_touch_index == -1 and is_visible_in_tree()
					and get_global_rect().has_point(touch.position)
					and not _is_blocked(touch.position)):
				_touch_index = touch.index
		elif touch.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			look_dragged.emit(drag.relative)
			get_viewport().set_input_as_handled()


func _is_blocked(point: Vector2) -> bool:
	for blocker in _blockers:
		if is_instance_valid(blocker) and blocker.is_visible_in_tree() and blocker.get_global_rect().has_point(point):
			return true
	return false
