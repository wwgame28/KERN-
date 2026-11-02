class_name GravitySettings
extends Resource
## Central gravity configuration.
## All gravity values used by the game come from one .tres file
## (res://resources/planets/test_planet_gravity.tres) - edit it in the Inspector.
## The values below are only the defaults of a brand-new resource.

@export var normal_strength: float = 9.8
@export var low_strength: float = 3.2
@export var direction: Vector3 = Vector3.DOWN
@export var normal_label: String = "Нормальная"
@export var low_label: String = "Низкая"
