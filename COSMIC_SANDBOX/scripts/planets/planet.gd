class_name Planet
extends Node3D
## Root of a planet scene.
## Stage 1 has a single test planet. Data-driven PlanetDefinition resources
## and planet switching are planned for stage 3.

@export var display_name: String = "Тестовая планета «Эхо-1»"
## Falling below this height returns the player to the spawn point.
@export var kill_height: float = -25.0

@onready var _spawn: Marker3D = $PlayerSpawn


func get_spawn_position() -> Vector3:
	return _spawn.global_position
