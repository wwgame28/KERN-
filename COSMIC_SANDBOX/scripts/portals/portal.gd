class_name Portal
extends Interactable
## Stage 1 portal: a safe interactive stub.
## It glows when the player is near and, on interaction, asks the HUD to show
## a status message. Real travel between planets is planned for stage 3.

signal portal_activated(portal: Portal)

const GROUP: StringName = &"portals"

@export var portal_name: String = "Врата Эхо-1"
## Main message shown when the player interacts with the portal.
@export var status_headline: String = "Портал пока не активирован"
@export_multiline var status_text: String = "Древние символы мерцают, но сеть порталов не отвечает.\n\n[Прототип] Переход между планетами появится на этапе 3, вместе с загрузкой планет и сохранением состояния."
@export var idle_glow: float = 0.6
@export var focus_glow: float = 2.2
@export var idle_spin_speed: float = 0.5

var _core_material: StandardMaterial3D = null
var _glow: float = 0.0
var _pulse: float = 0.0

@onready var _core: MeshInstance3D = $Visual/Core
@onready var _orbiter: Node3D = $Visual/Orbiter
@onready var _light: OmniLight3D = $Visual/Light


func _ready() -> void:
	add_to_group(GROUP)
	_glow = idle_glow
	var material: StandardMaterial3D = _core.get_active_material(0) as StandardMaterial3D
	if material != null:
		# Own copy, so several portals can glow independently.
		_core_material = material.duplicate() as StandardMaterial3D
		_core.material_override = _core_material


func _process(delta: float) -> void:
	var target_glow: float = focus_glow if is_focused else idle_glow
	_glow = lerpf(_glow, target_glow, 1.0 - exp(-6.0 * delta))
	_pulse = maxf(_pulse - delta * 1.5, 0.0)
	var shimmer: float = sin(Time.get_ticks_msec() * 0.003) * 0.15
	var energy: float = _glow + _pulse * 4.0 + shimmer
	if _core_material != null:
		_core_material.emission_energy_multiplier = energy
	_light.light_energy = 0.4 + energy * 0.5
	_orbiter.rotate_z(delta * (idle_spin_speed + _glow * 0.5 + _pulse * 4.0))


func _on_interact(_by: Node3D) -> void:
	_pulse = 1.0
	portal_activated.emit(self)
