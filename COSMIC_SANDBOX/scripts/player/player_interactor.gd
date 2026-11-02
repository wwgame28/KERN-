class_name PlayerInteractor
extends Area3D
## Detects nearby Interactable areas (physics layer 3) and forwards
## the interact action to the closest enabled one.

signal focus_changed(interactable: Interactable)

var focused: Interactable = null
var _candidates: Array[Interactable] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
	var best: Interactable = _find_closest()
	if best == focused:
		return
	if focused != null and is_instance_valid(focused):
		focused.set_focused(false)
	focused = best
	if focused != null:
		focused.set_focused(true)
	focus_changed.emit(focused)


func try_interact(by: Node3D) -> bool:
	if focused == null or not is_instance_valid(focused) or not focused.enabled:
		return false
	focused.interact(by)
	return true


func _find_closest() -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.enabled:
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _on_area_entered(area: Area3D) -> void:
	var interactable: Interactable = area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_area_exited(area: Area3D) -> void:
	var interactable: Interactable = area as Interactable
	if interactable != null:
		_candidates.erase(interactable)
