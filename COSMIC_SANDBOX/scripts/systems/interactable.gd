class_name Interactable
extends Area3D
## Base class for anything the player can interact with.
## Put the area on physics layer 3 ("interactable") so PlayerInteractor can detect it.

signal interacted(by: Node3D)
signal focus_changed(focused: bool)

## Short text shown in the HUD when the player is close enough.
@export var prompt_text: String = "Взаимодействовать"
@export var enabled: bool = true

var is_focused: bool = false


func interact(by: Node3D) -> void:
	if not enabled:
		return
	_on_interact(by)
	interacted.emit(by)


func set_focused(value: bool) -> void:
	if is_focused == value:
		return
	is_focused = value
	_on_focus_changed(value)
	focus_changed.emit(value)


## Override in subclasses.
func _on_interact(_by: Node3D) -> void:
	pass


## Override in subclasses.
func _on_focus_changed(_value: bool) -> void:
	pass
