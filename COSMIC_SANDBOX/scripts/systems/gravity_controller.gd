class_name GravityController
extends Node
## Holds the active gravity mode for the current planet.
## Stage 1: two strength presets with one fixed direction.
## Arbitrary gravity fields (spherical planets, zones) are intentionally not implemented yet.
## All numbers come from the GravitySettings resource - nothing is hard-coded here.

signal gravity_changed(mode: int, strength: float)

enum Mode { NORMAL, LOW }

## Central gravity configuration (res://resources/planets/test_planet_gravity.tres).
@export var settings: GravitySettings
@export var start_mode: Mode = Mode.NORMAL
## Also write the gravity into the default physics space,
## so future RigidBody3D props follow the same rules as the player.
@export var apply_to_physics_space: bool = true

var mode: Mode = Mode.NORMAL


func _ready() -> void:
	if settings == null:
		push_warning("GravityController: 'settings' is not assigned, using GravitySettings defaults.")
		settings = GravitySettings.new()
	set_mode(start_mode, true)


func toggle_mode() -> void:
	if mode == Mode.NORMAL:
		set_mode(Mode.LOW)
	else:
		set_mode(Mode.NORMAL)


func set_mode(new_mode: Mode, force: bool = false) -> void:
	if new_mode == mode and not force:
		return
	mode = new_mode
	if apply_to_physics_space:
		_apply_to_physics_space()
	gravity_changed.emit(mode, get_strength())


func get_strength() -> float:
	if mode == Mode.LOW:
		return settings.low_strength
	return settings.normal_strength


func get_direction() -> Vector3:
	if settings.direction.is_zero_approx():
		return Vector3.DOWN
	return settings.direction.normalized()


func get_gravity_vector() -> Vector3:
	return get_direction() * get_strength()


func get_mode_name() -> String:
	if mode == Mode.LOW:
		return settings.low_label
	return settings.normal_label


func _apply_to_physics_space() -> void:
	if not is_inside_tree():
		return
	var world: World3D = get_viewport().find_world_3d()
	if world == null:
		return
	PhysicsServer3D.area_set_param(world.space, PhysicsServer3D.AREA_PARAM_GRAVITY, get_strength())
	PhysicsServer3D.area_set_param(world.space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, get_direction())
