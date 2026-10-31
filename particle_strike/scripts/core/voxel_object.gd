class_name VoxelObject
extends Node3D
## Разрушаемый объект из частиц-вокселей.
## * Логическая ячейка (обычно 25 см) рисуется шейдером как сетка частиц по 5 см.
## * Рендер: один MultiMesh на объект (1 draw call), удалённая ячейка = нулевой масштаб.
## * При разрушении ячейка рассыпается на несколько мелких частиц-обломков (GPU).
## * Коллизии: ячейки 4×4×4 вокселя -> BoxShape без отдельных нод; пустая ячейка отключается.
## * Обрушение: после повреждения ищутся частицы, не связанные с опорой, —
##   они отваливаются целым куском (FallingChunk) или осыпаются.
## * Горение: огонь распространяется по горючим частицам (дерево, листва, сено).

enum Anchor { GROUND, ENDS_X, ENDS_Z, NONE }

const CELL_SHIFT := 2
const ZERO_T := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
const MAX_BURNING := 600
## Размер видимой частицы (м): шейдер дробит каждую ячейку на частицы этого размера.
const PARTICLE := 0.05
## Ячейка 0.5 м — эталон, под который считаются награды и комбо.
const REF_VS := 0.5

static var _cube: ArrayMesh = null
static var _material: ShaderMaterial = null

var dims := Vector3i.ONE
var vs := 0.5
var grid := PackedByteArray()
var inst_of := PackedInt32Array()
var anchor: int = Anchor.GROUND
var solid_count := 0
var initial_count := 0
var value_mult := 1.0
var explode_on_break := false
var explode_radius := 4.5
var exploded := false
var is_player_wall := false
var casts_shadow := true

var mm: MultiMesh
var mmi: MultiMeshInstance3D
## Копия буфера MultiMesh в памяти: крупные разрушения (обрушение) обновляют
## его целиком одной загрузкой вместо тысяч отдельных вызовов.
var cpu_buf := PackedFloat32Array()
var body: StaticBody3D
var cdims := Vector3i.ONE
var cell_counts := PackedInt32Array()
var cell_owner := PackedInt32Array()
var world_aabb := AABB()
var collapse_pending := false
## Проверка опор не чаще раза в 0.25 с на объект — при непрерывной стрельбе
## повреждения копятся, а обрушение выглядит как короткий «скрип» перед обвалом.
var collapse_ready_ms := 0
var _flood_count := 0
var burning := {}
var _burn_tick := 0.0
var _dead := false


static func cube_mesh() -> ArrayMesh:
	if _cube == null:
		_cube = make_cube_mesh()
		_cube.surface_set_material(0, shared_material())
	return _cube


static func make_cube_mesh() -> ArrayMesh:
	## Куб из 8 общих вершин (нормали считает шейдер) — втрое меньше работы
	## вершинного шейдера, чем у стандартного BoxMesh (24 вершины).
	var v := PackedVector3Array()
	for i in 8:
		v.append(Vector3(0.5 if (i & 1) != 0 else -0.5, 0.5 if (i & 2) != 0 else -0.5, 0.5 if (i & 4) != 0 else -0.5))
	var faces := [[0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5]]
	var idx := PackedInt32Array()
	for f in faces:
		var q: Array = f
		var center := (v[q[0]] + v[q[1]] + v[q[2]] + v[q[3]]) * 0.25
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var a: int = tri[0]
			var b: int = tri[1]
			var c: int = tri[2]
			# Godot: лицевые грани — по часовой стрелке, если смотреть снаружи
			if (v[b] - v[a]).cross(v[c] - v[a]).dot(center) > 0.0:
				var t := b
				b = c
				c = t
			idx.append(a)
			idx.append(b)
			idx.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func sub_for(voxel_size: float) -> float:
	return maxf(1.0, roundf(voxel_size / PARTICLE))


func area_scale() -> float:
	## Сколько «эталонных» ячеек 0.5 м составляет одна наша (по площади поверхности).
	return (vs / REF_VS) * (vs / REF_VS)


static func shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/voxel.gdshader")
	return _material


# ---------------------------------------------------------------- построение

func setup(size: Vector3i, voxel_size: float) -> void:
	dims = Vector3i(maxi(size.x, 1), maxi(size.y, 1), maxi(size.z, 1))
	vs = voxel_size
	grid = PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	grid.fill(0)


func idx(x: int, y: int, z: int) -> int:
	return x + dims.x * (y + dims.y * z)


func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < dims.x and y < dims.y and z < dims.z


func set_v(x: int, y: int, z: int, m: int) -> void:
	if in_bounds(x, y, z):
		grid[x + dims.x * (y + dims.y * z)] = m


func get_v(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return 0
	return grid[x + dims.x * (y + dims.y * z)]


func fill_box(a: Vector3i, b: Vector3i, m: int) -> void:
	for z in range(maxi(a.z, 0), mini(b.z, dims.z - 1) + 1):
		for y in range(maxi(a.y, 0), mini(b.y, dims.y - 1) + 1):
			for x in range(maxi(a.x, 0), mini(b.x, dims.x - 1) + 1):
				grid[x + dims.x * (y + dims.y * z)] = m


func fill_sphere(c: Vector3, r: float, m: int, noise: FastNoiseLite = null, amp: float = 0.0) -> void:
	var r_max := r + amp
	for z in range(maxi(floori(c.z - r_max), 0), mini(ceili(c.z + r_max), dims.z - 1) + 1):
		for y in range(maxi(floori(c.y - r_max), 0), mini(ceili(c.y + r_max), dims.y - 1) + 1):
			for x in range(maxi(floori(c.x - r_max), 0), mini(ceili(c.x + r_max), dims.x - 1) + 1):
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var rr := r
				if noise:
					rr += noise.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0) * amp
				if p.distance_to(c) <= rr:
					grid[x + dims.x * (y + dims.y * z)] = m


func carve_sphere(c: Vector3, r: float) -> void:
	fill_sphere(c, r, 0)


func upsample(factor: int) -> void:
	## Дробит каждую ячейку на factor³ более мелких (до finalize).
	if factor <= 1:
		return
	var nd := dims * factor
	var ng := PackedByteArray()
	ng.resize(nd.x * nd.y * nd.z)
	ng.fill(0)
	for z in nd.z:
		for y in nd.y:
			for x in nd.x:
				ng[x + nd.x * (y + nd.y * z)] = grid[(x / factor) + dims.x * ((y / factor) + dims.y * (z / factor))]
	dims = nd
	grid = ng
	vs /= float(factor)


func finalize() -> void:
	var n := grid.size()
	inst_of.resize(n)
	inst_of.fill(-1)
	var count := 0
	for i in n:
		if grid[i] != 0:
			count += 1
	solid_count = count
	initial_count = count
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube_mesh()
	mm.instance_count = count
	if count > 0:
		var buf := PackedFloat32Array()
		buf.resize(count * 16)
		buf.fill(0.0)
		# ячейки стоят вплотную: зазоры рисует шейдер между частицами 5 см
		var s := vs
		var k := 0
		# снизу вверх — порядок нужен для анимации «сборки»
		for y in dims.y:
			for z in dims.z:
				for x in dims.x:
					var i := x + dims.x * (y + dims.y * z)
					var m := grid[i]
					if m == 0:
						continue
					inst_of[i] = k
					var o := k * 16
					var c := VoxelMat.vary(m, i)
					buf[o] = s
					buf[o + 3] = (x + 0.5) * vs
					buf[o + 5] = s
					buf[o + 7] = (y + 0.5) * vs
					buf[o + 10] = s
					buf[o + 11] = (z + 0.5) * vs
					buf[o + 12] = c.r
					buf[o + 13] = c.g
					buf[o + 14] = c.b
					buf[o + 15] = c.a
					k += 1
		cpu_buf = buf
		mm.buffer = cpu_buf
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.set_instance_shader_parameter("sub", sub_for(vs))
	var shadows_on := bool(Perf.get_value("shadows"))
	if not shadows_on or not casts_shadow or count < 250:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if count < 400:
		mmi.visibility_range_end = float(Perf.get_value("view")) * 0.75
	add_child(mmi)
	_build_collision()
	world_aabb = global_transform * AABB(Vector3.ZERO, Vector3(dims) * vs)


func _cell_index(x: int, y: int, z: int) -> int:
	return (x >> CELL_SHIFT) + cdims.x * ((y >> CELL_SHIFT) + cdims.y * (z >> CELL_SHIFT))


func _build_collision() -> void:
	var cell := 1 << CELL_SHIFT
	cdims = Vector3i(ceili(dims.x / float(cell)), ceili(dims.y / float(cell)), ceili(dims.z / float(cell)))
	var cn := cdims.x * cdims.y * cdims.z
	cell_counts.resize(cn)
	cell_counts.fill(0)
	cell_owner.resize(cn)
	cell_owner.fill(-1)
	var bmin := PackedInt32Array()
	bmin.resize(cn * 3)
	bmin.fill(1 << 20)
	var bmax := PackedInt32Array()
	bmax.resize(cn * 3)
	bmax.fill(-1)
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				if grid[x + dims.x * (y + dims.y * z)] == 0:
					continue
				var ci := _cell_index(x, y, z)
				cell_counts[ci] += 1
				var b := ci * 3
				bmin[b] = mini(bmin[b], x)
				bmin[b + 1] = mini(bmin[b + 1], y)
				bmin[b + 2] = mini(bmin[b + 2], z)
				bmax[b] = maxi(bmax[b], x)
				bmax[b + 1] = maxi(bmax[b + 1], y)
				bmax[b + 2] = maxi(bmax[b + 2], z)
	body = StaticBody3D.new()
	body.collision_layer = GameWorld.L_DESTRUCT
	body.collision_mask = 0
	body.set_meta("vobj", self)
	add_child(body)
	for ci in cn:
		if cell_counts[ci] == 0:
			continue
		var b := ci * 3
		var mn := Vector3(bmin[b], bmin[b + 1], bmin[b + 2])
		var mx := Vector3(bmax[b], bmax[b + 1], bmax[b + 2])
		var box := BoxShape3D.new()
		box.size = (mx - mn + Vector3.ONE) * vs
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, box)
		body.shape_owner_set_transform(owner_id, Transform3D(Basis(), (mn + mx + Vector3.ONE) * 0.5 * vs))
		cell_owner[ci] = owner_id


func play_build_anim(duration: float) -> void:
	## Анимация «сборки из частиц»: частицы появляются снизу вверх.
	if mm == null or initial_count == 0:
		return
	mm.visible_instance_count = 0
	var total := initial_count
	var setter := func(v: float) -> void:
		if mm:
			mm.visible_instance_count = mini(int(v), total)
	var finish := func() -> void:
		if mm:
			mm.visible_instance_count = -1
	var tw := create_tween()
	tw.tween_method(setter, 0.0, float(total), duration)
	tw.tween_callback(finish)


func voxel_world_pos(i: int) -> Vector3:
	var x := i % dims.x
	var yz := i / dims.x
	var y := yz % dims.y
	var z := yz / dims.y
	return global_transform * (Vector3(x + 0.5, y + 0.5, z + 0.5) * vs)


func center_world() -> Vector3:
	return global_transform * (Vector3(dims) * vs * 0.5)


# ---------------------------------------------------------------- лучи

func ray_voxel(origin_w: Vector3, dir_w: Vector3, max_dist: float) -> Dictionary:
	## DDA-трассировка луча по сетке (Amanatides–Woo).
	var inv := global_transform.affine_inverse()
	var o: Vector3 = (inv * origin_w) / vs
	var d: Vector3 = (inv.basis * dir_w).normalized()
	var t0 := 0.0
	var t1 := max_dist / vs
	var entry_axis := -1
	for a in 3:
		var oa: float = o[a]
		var da: float = d[a]
		var hi := float(dims[a])
		if absf(da) < 1e-8:
			if oa < 0.0 or oa > hi:
				return {}
		else:
			var ta := (0.0 - oa) / da
			var tb := (hi - oa) / da
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			if ta > t0:
				t0 = ta
				entry_axis = a
			t1 = minf(t1, tb)
			if t0 > t1:
				return {}
	var p := o + d * (t0 + 0.0001)
	var x := clampi(floori(p.x), 0, dims.x - 1)
	var y := clampi(floori(p.y), 0, dims.y - 1)
	var z := clampi(floori(p.z), 0, dims.z - 1)
	var sx := 1 if d.x > 0.0 else -1
	var sy := 1 if d.y > 0.0 else -1
	var sz := 1 if d.z > 0.0 else -1
	var tdx := INF if absf(d.x) < 1e-8 else absf(1.0 / d.x)
	var tdy := INF if absf(d.y) < 1e-8 else absf(1.0 / d.y)
	var tdz := INF if absf(d.z) < 1e-8 else absf(1.0 / d.z)
	var tmx := INF
	var tmy := INF
	var tmz := INF
	if absf(d.x) >= 1e-8:
		tmx = t0 + ((float(x + 1) - p.x) / d.x if d.x > 0.0 else (p.x - float(x)) / -d.x)
	if absf(d.y) >= 1e-8:
		tmy = t0 + ((float(y + 1) - p.y) / d.y if d.y > 0.0 else (p.y - float(y)) / -d.y)
	if absf(d.z) >= 1e-8:
		tmz = t0 + ((float(z + 1) - p.z) / d.z if d.z > 0.0 else (p.z - float(z)) / -d.z)
	var nrm := Vector3.ZERO
	if entry_axis == 0:
		nrm = Vector3(-sx, 0, 0)
	elif entry_axis == 1:
		nrm = Vector3(0, -sy, 0)
	elif entry_axis == 2:
		nrm = Vector3(0, 0, -sz)
	var t := t0
	var guard := 0
	while t <= t1 and guard < 4096:
		guard += 1
		var i := x + dims.x * (y + dims.y * z)
		if grid[i] != 0:
			var hit_local := (o + d * t) * vs
			return {
				"idx": i, "dist": t * vs, "object": self,
				"position": global_transform * hit_local,
				"normal": (global_transform.basis * nrm).normalized() if nrm != Vector3.ZERO else -dir_w,
			}
		if tmx < tmy and tmx < tmz:
			x += sx
			t = tmx
			tmx += tdx
			nrm = Vector3(-sx, 0, 0)
			if x < 0 or x >= dims.x:
				break
		elif tmy < tmz:
			y += sy
			t = tmy
			tmy += tdy
			nrm = Vector3(0, -sy, 0)
			if y < 0 or y >= dims.y:
				break
		else:
			z += sz
			t = tmz
			tmz += tdz
			nrm = Vector3(0, 0, -sz)
			if z < 0 or z >= dims.z:
				break
	return {}


# ---------------------------------------------------------------- урон

func damage_sphere(center_w: Vector3, radius: float, power: float, element: int, impulse: float = 8.0) -> int:
	if solid_count <= 0 or _dead:
		return 0
	var lc: Vector3 = to_local(center_w) / vs
	var r := radius / vs
	if r <= 0.0:
		return 0
	var ext := r * 1.6
	var x0 := maxi(floori(lc.x - ext), 0)
	var x1 := mini(floori(lc.x + ext), dims.x - 1)
	var y0 := maxi(floori(lc.y - ext), 0)
	var y1 := mini(floori(lc.y + ext), dims.y - 1)
	var z0 := maxi(floori(lc.z - ext), 0)
	var z1 := mini(floori(lc.z + ext), dims.z - 1)
	if x0 > x1 or y0 > y1 or z0 > z1:
		return 0
	var to_ice := element == WeaponData.Element.ICE
	var ignite := element == WeaponData.Element.EXPLOSIVE or element == WeaponData.Element.FIRE
	var pw := clampf(power, 0.0, 1.0)
	var removed := PackedInt32Array()
	var core2 := (r * 0.45) * (r * 0.45)
	for z in range(z0, z1 + 1):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := x + dims.x * (y + dims.y * z)
				var m := grid[i]
				if m == 0:
					continue
				var dx := float(x) + 0.5 - lc.x
				var dy := float(y) + 0.5 - lc.y
				var dz := float(z) + 0.5 - lc.z
				var d2 := dx * dx + dy * dy + dz * dz
				var eff := r * (1.0 - VoxelMat.hardness(m) * (1.0 - pw) * 0.7)
				if m == VoxelMat.ICE and not to_ice:
					eff = r * 1.6
				elif VoxelMat.has_flag(m, VoxelMat.FLAG_BRITTLE):
					eff = r * 1.3
				if d2 > eff * eff:
					if ignite and d2 < eff * eff * 2.4 and VoxelMat.has_flag(m, VoxelMat.FLAG_FLAMMABLE):
						ignite_voxel(i)
					continue
				if to_ice and m != VoxelMat.ICE and m != VoxelMat.EXPLOSIVE and d2 > core2:
					_set_material(i, VoxelMat.ICE)
					continue
				removed.push_back(i)
	if removed.is_empty():
		return 0
	_remove_list(removed, center_w, impulse, true, true)
	return removed.size()


func carve_segment(a_w: Vector3, b_w: Vector3, radius: float) -> int:
	## Тоннель вдоль отрезка (лазер снайпера).
	if solid_count <= 0 or _dead:
		return 0
	var a: Vector3 = to_local(a_w) / vs
	var b: Vector3 = to_local(b_w) / vs
	var r := radius / vs
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * r
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3.ONE * r
	var x0 := maxi(floori(lo.x), 0)
	var x1 := mini(floori(hi.x), dims.x - 1)
	var y0 := maxi(floori(lo.y), 0)
	var y1 := mini(floori(hi.y), dims.y - 1)
	var z0 := maxi(floori(lo.z), 0)
	var z1 := mini(floori(hi.z), dims.z - 1)
	if x0 > x1 or y0 > y1 or z0 > z1:
		return 0
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	var removed := PackedInt32Array()
	var r2 := r * r
	for z in range(z0, z1 + 1):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := x + dims.x * (y + dims.y * z)
				if grid[i] == 0:
					continue
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				if p.distance_squared_to(a + ab * t) <= r2:
					removed.push_back(i)
	if removed.is_empty():
		return 0
	_remove_list(removed, b_w, 5.0, true, true)
	return removed.size()


func ignite_voxel(i: int) -> void:
	if burning.has(i) or burning.size() >= MAX_BURNING or grid[i] == 0:
		return
	burning[i] = randf_range(1.4, 2.8)
	var inst := inst_of[i]
	if inst >= 0:
		_set_color(inst, Color(1.0, 0.45, 0.1, 1.0))
	set_process(true)


func _set_material(i: int, m: int) -> void:
	grid[i] = m
	var inst := inst_of[i]
	if inst >= 0:
		_set_color(inst, VoxelMat.vary(m, i))


func _set_color(inst: int, c: Color) -> void:
	mm.set_instance_color(inst, c)
	var o := inst * 16 + 12
	cpu_buf[o] = c.r
	cpu_buf[o + 1] = c.g
	cpu_buf[o + 2] = c.b
	cpu_buf[o + 3] = c.a


func _remove_list(list: PackedInt32Array, center_w: Vector3, impulse: float, fx: bool, award: bool) -> void:
	var gw := GameWorld.current
	var n := list.size()
	# бюджет мелких частиц-обломков на событие: мало ячеек — по несколько частиц
	# на каждую, много ячеек — берём каждую k-ю
	var budget: int = maxi(int(Perf.get_value("per_event")), 1)
	var per := clampi(budget / maxi(n, 1), 1, 6)
	var stride := maxi(1, ceili(float(n) / float(budget)))
	var jitter := vs * 0.4
	var bulk := n > 250
	var value := 0.0
	var trigger := false
	var xf := global_transform
	var removed_count := 0
	for j in n:
		var i := list[j]
		var m := grid[i]
		if m == 0:
			continue
		removed_count += 1
		value += float(VoxelMat.VALUE[m])
		if m == VoxelMat.EXPLOSIVE:
			trigger = true
		var x := i % dims.x
		var yz := i / dims.x
		var y := yz % dims.y
		var z := yz / dims.y
		grid[i] = 0
		solid_count -= 1
		if not burning.is_empty():
			burning.erase(i)
		var inst := inst_of[i]
		if inst >= 0:
			if not bulk:
				mm.set_instance_transform(inst, ZERO_T)
			var ob := inst * 16
			cpu_buf[ob] = 0.0
			cpu_buf[ob + 5] = 0.0
			cpu_buf[ob + 10] = 0.0
			inst_of[i] = -1
		var ci := _cell_index(x, y, z)
		cell_counts[ci] -= 1
		if cell_counts[ci] <= 0 and cell_owner[ci] >= 0:
			body.shape_owner_set_disabled(cell_owner[ci], true)
			cell_owner[ci] = -1
		if fx and gw and j % stride == 0:
			var wp := xf * (Vector3(x + 0.5, y + 0.5, z + 0.5) * vs)
			var dir := wp - center_w
			var dl := dir.length()
			dir = dir / dl if dl > 0.001 else Vector3.UP
			var col := VoxelMat.vary(m, i)
			for q in per:
				var off := Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), randf_range(-jitter, jitter))
				var vel := dir * impulse * randf_range(0.4, 1.25) + Vector3(randf_range(-1.8, 1.8), randf_range(1.5, 5.5), randf_range(-1.8, 1.8))
				gw.debris.spawn(wp + off, vel, col, PARTICLE * randf_range(0.8, 1.7), (j + q) % 3 == 0)
	if bulk and removed_count > 0:
		mm.buffer = cpu_buf
	if gw and award and removed_count > 0:
		var w := area_scale()
		gw.on_voxels_destroyed(removed_count, value * value_mult * w, center_w, is_player_wall, w)
	if gw and (trigger or (explode_on_break and solid_count < int(initial_count * 0.55))) and not exploded:
		exploded = true
		gw.schedule_explosion(center_world() if explode_on_break else center_w, explode_radius, 0.12)
	if solid_count <= 0:
		_die()
	elif not collapse_pending and anchor != Anchor.NONE and gw:
		collapse_pending = true
		collapse_ready_ms = Time.get_ticks_msec() + 250
		gw.request_collapse(self)


func _die() -> void:
	if _dead:
		return
	_dead = true
	var gw := GameWorld.current
	if gw:
		gw.unregister_object(self)
	queue_free()


# ---------------------------------------------------------------- горение

func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if burning.is_empty():
		set_process(false)
		return
	_burn_tick += delta
	if _burn_tick < 0.25:
		return
	var step := _burn_tick
	_burn_tick = 0.0
	var done := PackedInt32Array()
	var spread := PackedInt32Array()
	var flick := randf() < 0.5
	for key in burning.keys():
		var i: int = key
		var left: float = float(burning[i]) - step
		burning[i] = left
		var inst := inst_of[i]
		if inst >= 0:
			_set_color(inst, Color(1.0, 0.55, 0.12, 1.0) if flick else Color(1.0, 0.3, 0.05, 1.0))
		if left <= 0.0:
			done.push_back(i)
		elif randf() < 0.22:
			spread.push_back(i)
	for i in spread:
		var x := i % dims.x
		var yz := i / dims.x
		var y := yz % dims.y
		var z := yz / dims.y
		var nx := x + randi_range(-1, 1)
		var ny := y + randi_range(0, 1)
		var nz := z + randi_range(-1, 1)
		if in_bounds(nx, ny, nz):
			var j := idx(nx, ny, nz)
			if grid[j] != 0 and VoxelMat.has_flag(grid[j], VoxelMat.FLAG_FLAMMABLE):
				ignite_voxel(j)
	if not done.is_empty():
		var gw := GameWorld.current
		if gw:
			for k in mini(done.size(), 6):
				var wp := voxel_world_pos(done[k])
				gw.debris.spawn(wp, Vector3(randf_range(-1, 1), randf_range(2, 5), randf_range(-1, 1)), Color(1.0, 0.5, 0.1), PARTICLE * 1.4, true)
		_remove_list(done, center_world(), 1.0, false, true)


# ---------------------------------------------------------------- обрушение

func check_collapse() -> void:
	collapse_pending = false
	if _dead or anchor == Anchor.NONE or solid_count <= 0:
		return
	var n := grid.size()
	var visited := _flood()
	# быстрые выходы без сканирования всей сетки
	if _flood_count >= solid_count:
		return
	var gw0 := GameWorld.current
	if gw0 and _flood_count <= int(float(solid_count) * 0.15) and float(solid_count) * area_scale() > 120.0:
		gw0.spawn_whole_chunk(self, float(solid_count) * value_mult * area_scale())
		_die()
		return
	var loose := PackedInt32Array()
	for i in n:
		if grid[i] != 0 and visited[i] == 0:
			loose.push_back(i)
	if loose.is_empty():
		return
	var gw := GameWorld.current
	if gw == null:
		return
	if loose.size() >= int(float(solid_count) * 0.85) and float(loose.size()) * area_scale() > 120.0:
		# падает почти всё здание — оно целиком превращается в падающее тело
		gw.spawn_whole_chunk(self, float(solid_count) * value_mult * area_scale())
		_die()
		return
	if float(loose.size()) * area_scale() < 24.0:
		_remove_list(loose, voxel_world_pos(loose[0]), 2.0, true, true)
		return
	var positions := PackedVector3Array()
	var cols := PackedColorArray()
	var value := 0.0
	var has_explosive := false
	positions.resize(loose.size())
	cols.resize(loose.size())
	var xf := global_transform
	for k in loose.size():
		var i := loose[k]
		var m := grid[i]
		# позиция и цвет берутся прямо из копии буфера MultiMesh — без пересчёта
		var o := inst_of[i] * 16
		positions[k] = xf * Vector3(cpu_buf[o + 3], cpu_buf[o + 7], cpu_buf[o + 11])
		cols[k] = Color(cpu_buf[o + 12], cpu_buf[o + 13], cpu_buf[o + 14], cpu_buf[o + 15])
		value += float(VoxelMat.VALUE[m])
		if m == VoxelMat.EXPLOSIVE:
			has_explosive = true
	_remove_silent(loose)
	# сам кусок создаётся в следующем кадре — работа делится на два кадра
	gw.queue_chunk(positions, cols, vs, value * value_mult * area_scale(), has_explosive)


func _remove_silent(list: PackedInt32Array) -> void:
	## Быстрое удаление большого набора ячеек без эффектов и наград
	## (они уже переданы падающему куску). Буфер MultiMesh загружается одним вызовом.
	var dx := dims.x
	var dxy := dims.x * dims.y
	for i in list:
		if grid[i] == 0:
			continue
		grid[i] = 0
		var inst := inst_of[i]
		if inst >= 0:
			var ob := inst * 16
			cpu_buf[ob] = 0.0
			cpu_buf[ob + 5] = 0.0
			cpu_buf[ob + 10] = 0.0
			inst_of[i] = -1
		var z := i / dxy
		var r := i - z * dxy
		var y := r / dx
		var x := r - y * dx
		var ci := (x >> CELL_SHIFT) + cdims.x * ((y >> CELL_SHIFT) + cdims.y * (z >> CELL_SHIFT))
		cell_counts[ci] -= 1
		if cell_counts[ci] <= 0 and cell_owner[ci] >= 0:
			body.shape_owner_set_disabled(cell_owner[ci], true)
			cell_owner[ci] = -1
	solid_count -= list.size()
	if not burning.is_empty():
		for i in list:
			burning.erase(i)
	mm.buffer = cpu_buf
	if solid_count <= 0:
		_die()


func _flood() -> PackedByteArray:
	## Заливка от опорных частиц: 1 — частица держится, 0 — висит в воздухе.
	var n := grid.size()
	var visited := PackedByteArray()
	visited.resize(n)
	visited.fill(0)
	var stack := PackedInt32Array()
	_flood_count = 0
	match anchor:
		Anchor.GROUND:
			for z in dims.z:
				for x in dims.x:
					var i := x + dims.x * dims.y * z
					if grid[i] != 0:
						visited[i] = 1
						stack.push_back(i)
						_flood_count += 1
		Anchor.ENDS_X:
			for z in dims.z:
				for y in dims.y:
					for x in [0, dims.x - 1]:
						var i := idx(x, y, z)
						if grid[i] != 0 and visited[i] == 0:
							visited[i] = 1
							stack.push_back(i)
							_flood_count += 1
		Anchor.ENDS_Z:
			for y in dims.y:
				for x in dims.x:
					for z in [0, dims.z - 1]:
						var i := idx(x, y, z)
						if grid[i] != 0 and visited[i] == 0:
							visited[i] = 1
							stack.push_back(i)
							_flood_count += 1
	var sx := 1
	var sy := dims.x
	var sz := dims.x * dims.y
	while stack.size() > 0:
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % dims.x
		var yz := i / dims.x
		var y := yz % dims.y
		var z := yz / dims.y
		if x > 0:
			var ja := i - sx
			if grid[ja] != 0 and visited[ja] == 0:
				visited[ja] = 1
				stack.push_back(ja)
				_flood_count += 1
		if x < dims.x - 1:
			var jb := i + sx
			if grid[jb] != 0 and visited[jb] == 0:
				visited[jb] = 1
				stack.push_back(jb)
				_flood_count += 1
		if y > 0:
			var jc := i - sy
			if grid[jc] != 0 and visited[jc] == 0:
				visited[jc] = 1
				stack.push_back(jc)
				_flood_count += 1
		if y < dims.y - 1:
			var jd := i + sy
			if grid[jd] != 0 and visited[jd] == 0:
				visited[jd] = 1
				stack.push_back(jd)
				_flood_count += 1
		if z > 0:
			var je := i - sz
			if grid[je] != 0 and visited[je] == 0:
				visited[je] = 1
				stack.push_back(je)
				_flood_count += 1
		if z < dims.z - 1:
			var jf := i + sz
			if grid[jf] != 0 and visited[jf] == 0:
				visited[jf] = 1
				stack.push_back(jf)
				_flood_count += 1
	return visited


func prune_floating() -> void:
	## До finalize: убрать «висящие» частицы (руины после процедурных разрушений).
	if anchor == Anchor.NONE:
		return
	var visited := _flood()
	for i in grid.size():
		if grid[i] != 0 and visited[i] == 0:
			grid[i] = 0


func get_aabb_world() -> AABB:
	return world_aabb
