class_name FxSystem
extends Node3D
## Пулы визуальных эффектов: вспышки, ударные кольца, лучи, молнии, свет взрывов.
## Ничего не создаётся во время боя — только переиспользование.

const FLASH_POOL := 24
const RING_POOL := 10
const BEAM_POOL := 24
const LIGHT_POOL := 3

class FxItem:
	var node: MeshInstance3D
	var mat: StandardMaterial3D
	var t := 0.0
	var life := 0.0
	var s0 := 1.0
	var s1 := 1.0
	var color := Color.WHITE
	var active := false
	var beam := false
	var width := 0.1
	var basis_dir := Basis()
	var length := 1.0

var _flashes: Array[FxItem] = []
var _rings: Array[FxItem] = []
var _beams: Array[FxItem] = []
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []
var _light_life: Array[float] = []
var _light_energy: Array[float] = []
var _fi := 0
var _ri := 0
var _bi := 0
var _li := 0


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for i in FLASH_POOL:
		_flashes.append(_make_item(sphere))
	for i in RING_POOL:
		_rings.append(_make_item(torus))
	for i in BEAM_POOL:
		var it := _make_item(box)
		it.beam = true
		_beams.append(it)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		l.omni_attenuation = 1.5
		add_child(l)
		_lights.append(l)
		_light_t.append(0.0)
		_light_life.append(1.0)
		_light_energy.append(0.0)


func _make_item(mesh: Mesh) -> FxItem:
	var it := FxItem.new()
	it.mat = StandardMaterial3D.new()
	it.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	it.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	it.mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	it.mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	it.mat.no_depth_test = false
	it.node = MeshInstance3D.new()
	it.node.mesh = mesh
	it.node.material_override = it.mat
	it.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	it.node.visible = false
	add_child(it.node)
	return it


func flash(pos: Vector3, radius: float, color: Color, life: float = 0.25) -> void:
	var it := _flashes[_fi]
	_fi = (_fi + 1) % _flashes.size()
	_start(it, pos, radius * 0.35, radius, color, life)


func ring(pos: Vector3, radius: float, color: Color, life: float = 0.45) -> void:
	var it := _rings[_ri]
	_ri = (_ri + 1) % _rings.size()
	_start(it, pos + Vector3(0, 0.15, 0), radius * 0.2, radius * 1.3, color, life)


func beam(a: Vector3, b: Vector3, color: Color, width: float = 0.08, life: float = 0.12) -> void:
	var dir := b - a
	var dist := dir.length()
	if dist < 0.01:
		return
	var it := _beams[_bi]
	_bi = (_bi + 1) % _beams.size()
	var up := Vector3.UP if absf(dir.y / dist) < 0.98 else Vector3.RIGHT
	it.basis_dir = Basis.looking_at(dir / dist, up)
	it.length = dist
	it.width = width
	_start(it, (a + b) * 0.5, 1.0, 1.0, color, life)


func lightning(a: Vector3, b: Vector3, color: Color) -> void:
	var segs := 4
	var prev := a
	for s in range(1, segs + 1):
		var p := a.lerp(b, float(s) / segs)
		if s < segs:
			p += Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		beam(prev, p, color, 0.06, 0.15)
		prev = p


func light(pos: Vector3, color: Color, energy: float, range_m: float, life: float = 0.3) -> void:
	var i := _li
	_li = (_li + 1) % _lights.size()
	var l := _lights[i]
	l.global_position = pos
	l.light_color = color
	l.omni_range = range_m
	l.light_energy = energy
	l.visible = true
	_light_t[i] = 0.0
	_light_life[i] = life
	_light_energy[i] = energy


func muzzle(pos: Vector3, color: Color) -> void:
	flash(pos, 0.35, color, 0.08)


func explosion(pos: Vector3, radius: float, color: Color) -> void:
	flash(pos, radius * 0.9, Color(1.0, 0.85, 0.6), 0.18)
	flash(pos, radius * 1.3, color, 0.4)
	ring(pos, radius * 1.6, color, 0.5)
	light(pos, color, 6.0, radius * 4.0, 0.35)
	var gw := GameWorld.current
	if gw:
		gw.debris.burst(pos, int(clampf(radius * 45.0, 30.0, 220.0)), Color(1.0, 0.6, 0.2), radius * 4.0, 0.06, true, 3.0)


func _start(it: FxItem, pos: Vector3, s0: float, s1: float, color: Color, life: float) -> void:
	it.node.global_position = pos
	it.s0 = s0
	it.s1 = s1
	it.color = color
	it.t = 0.0
	it.life = maxf(life, 0.01)
	it.active = true
	it.node.visible = true
	_apply(it, 0.0)


func _apply(it: FxItem, k: float) -> void:
	var fade := 1.0 - k
	if it.beam:
		var w := it.width * (1.0 - k * 0.7)
		it.node.basis = it.basis_dir * Basis.from_scale(Vector3(w, w, it.length))
	else:
		var s := lerpf(it.s0, it.s1, 1.0 - pow(1.0 - k, 3.0))
		it.node.scale = Vector3.ONE * maxf(s, 0.001)
	it.mat.albedo_color = Color(it.color.r, it.color.g, it.color.b, fade * fade)


func _update_pool(pool: Array[FxItem], delta: float) -> void:
	for it in pool:
		if not it.active:
			continue
		it.t += delta
		var k := it.t / it.life
		if k >= 1.0:
			it.active = false
			it.node.visible = false
		else:
			_apply(it, k)


func _process(delta: float) -> void:
	_update_pool(_flashes, delta)
	_update_pool(_rings, delta)
	_update_pool(_beams, delta)
	for i in _lights.size():
		var l := _lights[i]
		if not l.visible:
			continue
		_light_t[i] += delta
		var k := _light_t[i] / _light_life[i]
		if k >= 1.0:
			l.visible = false
		else:
			l.light_energy = _light_energy[i] * (1.0 - k)
