extends Node3D
## Entry point of the stage-1 vertical slice.
## Wires planet, gravity, player, portals and HUD together (dependency injection,
## no global singletons yet).

@onready var _gravity: GravityController = $GravityController
@onready var _planet: Planet = $TestPlanet
@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	InputActions.ensure_defaults()

	_player.kill_height = _planet.kill_height
	_player.setup(_gravity, _planet.get_spawn_position())
	_player.input.gravity_toggle_requested.connect(_gravity.toggle_mode)

	_hud.setup(_player, _gravity, _planet)

	for node in get_tree().get_nodes_in_group(Portal.GROUP):
		var portal: Portal = node as Portal
		if portal != null:
			portal.portal_activated.connect(_hud.show_portal_dialog)
