class_name VoxelRig
extends Node3D
## Модель персонажа из частиц: набор частей (голова, торс, руки, ноги, оружие),
## каждая — отдельный MultiMesh. Анимации процедурные: бег, прыжок, рывок,
## отдача, приземление, вспышка попадания, распад на частицы при смерти.

class Part:
	var pivot: Node3D
	var mmi: MultiMeshInstance3D
	var points := PackedVector3Array()
	var cols := PackedColorArray()

var parts := {}
var vsize := 0.1
var _flash := 0.0
var _tint := Color(0, 0, 0, 0)


static func _fill_points(boxes: Array, vs: float, hollow: bool) -> Array:
	## boxes: [[from: Vector3, to: Vector3, color: Color], ...] в метрах.
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for b in boxes:
		var a: Vector3 = b[0]
		var z: Vector3 = b[1]
		var c: Color = b[2]
		var n := Vector3i(maxi(roundi((z.x - a.x) / vs), 1), maxi(roundi((z.y - a.y) / vs), 1), maxi(roundi((z.z - a.z) / vs), 1))
		for iz in n.z:
			for iy in n.y:
				for ix in n.x:
					if hollow and ix > 0 and iy > 0 and iz > 0 and ix < n.x - 1 and iy < n.y - 1 and iz < n.z - 1:
						continue
					pts.append(a + Vector3(ix + 0.5, iy + 0.5, iz + 0.5) * vs)
					var f := 0.88 + 0.24 * float((ix * 7 + iy * 13 + iz * 5) % 10) / 10.0
					cols.append(Color(c.r * f, c.g * f, c.b * f, c.a))
	return [pts, cols]


func add_part(part_name: String, parent_name: String, pivot_pos: Vector3, boxes: Array, hollow: bool = true) -> Part:
	var p := Part.new()
	p.pivot = Node3D.new()
	p.pivot.name = part_name
	p.pivot.position = pivot_pos
	var parent: Node3D = self
	if parts.has(parent_name):
		parent = (parts[parent_name] as Part).pivot
	parent.add_child(p.pivot)
	var res := _fill_points(boxes, vsize, hollow)
	p.points = res[0]
	p.cols = res[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = VoxelObject.cube_mesh()
	mm.instance_count = p.points.size()
	var buf := PackedFloat32Array()
	buf.resize(p.points.size() * 16)
	buf.fill(0.0)
	var s := vsize * 0.9
	for k in p.points.size():
		var o := k * 16
		var pt := p.points[k]
		var c := p.cols[k]
		buf[o] = s
		buf[o + 3] = pt.x
		buf[o + 5] = s
		buf[o + 7] = pt.y
		buf[o + 10] = s
		buf[o + 11] = pt.z
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	if p.points.size() > 0:
		mm.buffer = buf
	p.mmi = MultiMeshInstance3D.new()
	p.mmi.multimesh = mm
	p.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.pivot.add_child(p.mmi)
	parts[part_name] = p
	return p


func part(part_name: String) -> Node3D:
	if parts.has(part_name):
		return (parts[part_name] as Part).pivot
	return null


func set_flash(v: float) -> void:
	if absf(v - _flash) < 0.01:
		return
	_flash = v
	for p in parts.values():
		(p as Part).mmi.set_instance_shader_parameter("flash", v)


func set_tint(c: Color) -> void:
	if c == _tint:
		return
	_tint = c
	for p in parts.values():
		(p as Part).mmi.set_instance_shader_parameter("tint", c)


func shatter(debris: DebrisSystem, impulse: float, max_points: int = 220) -> void:
	## Распад модели на частицы-обломки.
	var total := 0
	for p in parts.values():
		total += (p as Part).points.size()
	var stride := maxi(1, total / maxi(max_points, 1))
	var center := global_position + Vector3.UP
	var k := 0
	for p in parts.values():
		var pp := p as Part
		if not pp.pivot.is_visible_in_tree():
			continue
		var xf := pp.pivot.global_transform
		for i in pp.points.size():
			k += 1
			if k % stride != 0:
				continue
			var wp := xf * pp.points[i]
			var dir := (wp - center).normalized()
			debris.spawn(wp, dir * impulse * randf_range(0.4, 1.0) + Vector3.UP * randf_range(2.0, 6.0), pp.cols[i], vsize * 1.3, i % 3 == 0)
	visible = false


# ------------------------------------------------------------------ сборка моделей

static func build_humanoid(body: Color, accent: Color, glow: Color, scale_m: float, vs: float) -> VoxelRig:
	var r := VoxelRig.new()
	r.vsize = vs
	var s := scale_m
	var gl := Color(glow.r, glow.g, glow.b, 0.9)
	var bd := Color(body.r, body.g, body.b, 0.15)
	var ac := Color(accent.r, accent.g, accent.b, 0.35)
	r.add_part("hips", "", Vector3(0, 0.95 * s, 0), [
		[Vector3(-0.22, -0.1, -0.13) * s, Vector3(0.22, 0.1, 0.13) * s, ac],
	])
	r.add_part("torso", "hips", Vector3(0, 0.08 * s, 0), [
		[Vector3(-0.26, 0.0, -0.15) * s, Vector3(0.26, 0.55, 0.15) * s, bd],
		[Vector3(-0.1, 0.2, 0.15) * s, Vector3(0.1, 0.4, 0.2) * s, gl],
		[Vector3(-0.2, 0.15, -0.25) * s, Vector3(0.2, 0.5, -0.15) * s, ac],
	])
	r.add_part("head", "torso", Vector3(0, 0.6 * s, 0), [
		[Vector3(-0.16, 0.0, -0.16) * s, Vector3(0.16, 0.32, 0.16) * s, bd],
		[Vector3(-0.13, 0.12, 0.15) * s, Vector3(0.13, 0.2, 0.2) * s, gl],
	])
	r.add_part("arm_l", "torso", Vector3(-0.34 * s, 0.5 * s, 0), [
		[Vector3(-0.08, -0.6, -0.08) * s, Vector3(0.08, 0.05, 0.08) * s, bd],
		[Vector3(-0.09, -0.65, -0.09) * s, Vector3(0.09, -0.5, 0.09) * s, ac],
	])
	r.add_part("arm_r", "torso", Vector3(0.34 * s, 0.5 * s, 0), [
		[Vector3(-0.08, -0.6, -0.08) * s, Vector3(0.08, 0.05, 0.08) * s, bd],
		[Vector3(-0.09, -0.65, -0.09) * s, Vector3(0.09, -0.5, 0.09) * s, ac],
	])
	r.add_part("leg_l", "hips", Vector3(-0.12 * s, -0.08 * s, 0), [
		[Vector3(-0.09, -0.85, -0.09) * s, Vector3(0.09, 0.0, 0.09) * s, bd],
		[Vector3(-0.1, -0.88, -0.1) * s, Vector3(0.1, -0.78, 0.16) * s, gl],
	])
	r.add_part("leg_r", "hips", Vector3(0.12 * s, -0.08 * s, 0), [
		[Vector3(-0.09, -0.85, -0.09) * s, Vector3(0.09, 0.0, 0.09) * s, bd],
		[Vector3(-0.1, -0.88, -0.1) * s, Vector3(0.1, -0.78, 0.16) * s, gl],
	])
	return r


static func build_gun(rig: VoxelRig, parent_name: String, color: Color, kind: String, hand_y: float = -0.58) -> Part:
	var c := Color(color.r, color.g, color.b, 1.0)
	var dark := Color(0.12, 0.13, 0.18, 0.1)
	var l := 0.45
	match kind:
		"shotgun":
			l = 0.6
		"sniper":
			l = 0.85
		"rocket":
			l = 0.75
		"plasma":
			l = 0.6
	var boxes := [
		[Vector3(-0.05, -0.06, -0.05), Vector3(0.05, 0.06, l), dark],
		[Vector3(-0.035, 0.06, 0.05), Vector3(0.035, 0.1, l * 0.8), c],
		[Vector3(-0.04, -0.2, -0.02), Vector3(0.04, -0.06, 0.08), dark],
		[Vector3(-0.03, -0.03, l), Vector3(0.03, 0.03, l + 0.06), c],
	]
	if kind == "rocket":
		boxes.append([Vector3(-0.09, -0.09, 0.1), Vector3(0.09, 0.09, l), Color(c.r, c.g, c.b, 0.4)])
	if kind == "sniper":
		boxes.append([Vector3(-0.03, 0.1, 0.2), Vector3(0.03, 0.16, 0.45), c])
	if kind == "plasma" or kind == "ice":
		boxes.append([Vector3(-0.07, -0.07, l * 0.4), Vector3(0.07, 0.07, l * 0.7), c])
	var g := rig.add_part("gun", parent_name, Vector3(0, hand_y, 0), boxes, false)
	# ствол вдоль руки: когда рука поднята вперёд — оружие смотрит в прицел
	g.pivot.rotation.x = PI * 0.5
	g.pivot.set_meta("hand_y", hand_y)
	g.pivot.set_meta("muzzle", Vector3(0, 0, l + 0.08))
	return g


static func build_crawler(color: Color, glow: Color, vs: float) -> VoxelRig:
	var r := VoxelRig.new()
	r.vsize = vs
	var bd := Color(color.r, color.g, color.b, 0.25)
	var gl := Color(glow.r, glow.g, glow.b, 1.0)
	r.add_part("hips", "", Vector3(0, 0.45, 0), [
		[Vector3(-0.3, -0.15, -0.4), Vector3(0.3, 0.2, 0.4), bd],
		[Vector3(-0.2, 0.0, 0.38), Vector3(0.2, 0.12, 0.48), gl],
	])
	for side in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var nm := "leg_%d_%d" % [int(side), int(row)]
			r.add_part(nm, "hips", Vector3(0.3 * side, 0.0, 0.25 * row), [
				[Vector3(minf(0.0, 0.45 * side), -0.45, -0.05), Vector3(maxf(0.0, 0.45 * side), 0.05, 0.05), bd],
			])
	return r


static func build_drone(color: Color, glow: Color, vs: float) -> VoxelRig:
	var r := VoxelRig.new()
	r.vsize = vs
	var bd := Color(color.r, color.g, color.b, 0.3)
	var gl := Color(glow.r, glow.g, glow.b, 1.0)
	r.add_part("hips", "", Vector3(0, 0, 0), [
		[Vector3(-0.3, -0.3, -0.3), Vector3(0.3, 0.3, 0.3), bd],
		[Vector3(-0.12, -0.12, 0.28), Vector3(0.12, 0.12, 0.38), gl],
	])
	r.add_part("ring_a", "hips", Vector3.ZERO, _ring_boxes(0.62, Color(gl.r, gl.g, gl.b, 0.8)), false)
	r.add_part("ring_b", "hips", Vector3.ZERO, _ring_boxes(0.5, Color(bd.r, bd.g, bd.b, 0.5)), false)
	return r


static func _ring_boxes(radius: float, c: Color) -> Array:
	var out := []
	for i in 14:
		var a := TAU * float(i) / 14.0
		var p := Vector3(cos(a), 0.0, sin(a)) * radius
		out.append([p - Vector3(0.05, 0.05, 0.05), p + Vector3(0.05, 0.05, 0.05), c])
	return out


# ------------------------------------------------------------------ анимации

func animate_humanoid(t: float, move: float, airborne: bool, aim_pitch: float, aiming: bool, recoil: float, dash: float, land: float) -> void:
	## move 0..1 — скорость бега, t — фаза, recoil 0..1, dash 0..1, land 0..1 (сжатие при приземлении).
	var swing := sin(t) * 0.7 * move
	var leg_l := part("leg_l")
	var leg_r := part("leg_r")
	var arm_l := part("arm_l")
	var arm_r := part("arm_r")
	var torso := part("torso")
	var hips := part("hips")
	var head := part("head")
	if airborne:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.7, 0.2)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.35, 0.2)
	else:
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
	var breathe := sin(t * 0.35) * 0.015
	torso.scale = Vector3(1.0, 1.0 + breathe, 1.0)
	torso.rotation.x = 0.12 * move + dash * 0.5
	hips.position.y = 0.95 * (1.0 - land * 0.18) + absf(sin(t)) * 0.05 * move
	hips.scale = Vector3(1.0 + land * 0.1, 1.0 - land * 0.12, 1.0 + land * 0.1)
	scale = Vector3(1.0, 1.0, 1.0 + dash * 0.5)
	# правая рука держит оружие и смотрит в точку прицела
	arm_r.rotation.x = lerpf(arm_r.rotation.x, -PI * 0.5 - aim_pitch + recoil * 0.35, 0.35)
	arm_r.rotation.z = 0.0
	if aiming:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -PI * 0.45 - aim_pitch, 0.3)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.45, 0.3)
	else:
		arm_l.rotation.x = -swing * 0.8
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.0, 0.3)
	head.rotation.x = -aim_pitch * 0.5
	var gun := part("gun")
	if gun:
		gun.position.y = float(gun.get_meta("hand_y", -0.58)) + recoil * 0.12


func animate_crawler(t: float, move: float) -> void:
	var k := 0
	for side in [-1, 1]:
		for row in [-1, 1]:
			var leg := part("leg_%d_%d" % [side, row])
			if leg:
				var ph := t * 2.0 + (0.0 if (k % 2 == 0) else PI)
				leg.rotation.z = sin(ph) * 0.5 * move * float(side)
				leg.rotation.x = cos(ph) * 0.35 * move
			k += 1
	var hips := part("hips")
	hips.position.y = 0.45 + absf(sin(t * 2.0)) * 0.08 * move


func animate_drone(t: float) -> void:
	var a := part("ring_a")
	var b := part("ring_b")
	if a:
		a.rotation = Vector3(t * 1.7, t * 2.3, 0.4)
	if b:
		b.rotation = Vector3(-t * 1.1, 0.0, t * 2.9)
	part("hips").position.y = sin(t * 1.5) * 0.15
