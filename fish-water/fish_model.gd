extends MeshInstance3D

const FISH_SHADER := preload("res://fish.gdshader")
const L_SEGS := 48
const R_SEGS := 24
const WX := 0.55
const WY := 1.0

const ORANGE := Color(1.0, 0.42, 0.06)
const BELLY := Color(1.0, 0.68, 0.38)
const WHITE := Color(0.97, 0.97, 0.95)
const BLACK := Color(0.05, 0.04, 0.04)

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var idx := PackedInt32Array()


func _ready() -> void:
	_body()
	_eye(1.0)
	_eye(-1.0)
	_caudal_fin()
	_dorsal_fins()
	_pectoral_fin(1.0)
	_pectoral_fin(-1.0)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m

	var mat := ShaderMaterial.new()
	mat.shader = FISH_SHADER
	material_override = mat


func radius(t: float) -> float:
	var tt := pow(clampf(t, 0.0, 1.0), 0.8)
	return 0.2 * pow(sin(PI * (tt * 0.93 + 0.02)), 0.75)


func surface(t: float, a: float) -> Vector3:
	var r := radius(t)
	return Vector3(r * WX * cos(a), r * WY * sin(a), t - 0.5)


func surface_normal(t: float, a: float) -> Vector3:
	var dr := (radius(t + 0.001) - radius(t - 0.001)) / 0.002
	return Vector3(cos(a) / WX, sin(a) / WY, -dr).normalized()


func _v(p: Vector3, n: Vector3, c: Color, part: float, flex: float, uv2 := Vector2.ZERO) -> int:
	verts.append(p)
	norms.append(n.normalized())
	cols.append(c)
	uvs.append(Vector2(part, flex))
	uv2s.append(uv2)
	return verts.size() - 1


# Godot treats clockwise triangles as front faces; orient each one to match its stored normals.
func _tri(a: int, b: int, c: int) -> void:
	var front := (verts[c] - verts[a]).cross(verts[b] - verts[a])
	if front.dot(norms[a] + norms[b] + norms[c]) < 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


func _body_color(t: float, a: float) -> Color:
	var c := ORANGE.lerp(BELLY, clampf((-sin(a) - 0.1) / 0.6, 0.0, 1.0))
	for band in [Vector2(0.17, 0.25), Vector2(0.5, 0.58), Vector2(0.88, 0.93)]:
		if t > band.x - 0.02 and t < band.y + 0.02:
			c = WHITE if t > band.x and t < band.y else BLACK
	return c


func _body() -> void:
	var base := verts.size()
	for i in L_SEGS + 1:
		var t := float(i) / L_SEGS
		for j in R_SEGS + 1:
			var a := TAU * j / R_SEGS
			_v(surface(t, a), surface_normal(t, a), _body_color(t, a), 0.0, 0.0, Vector2(float(j) / R_SEGS, t))
	for i in L_SEGS:
		for j in R_SEGS:
			var v00 := base + i * (R_SEGS + 1) + j
			var v10 := v00 + R_SEGS + 1
			_tri(v00, v10, v10 + 1)
			_tri(v00, v10 + 1, v00 + 1)
	var nose := _v(Vector3(0, 0, -0.515), Vector3.FORWARD, ORANGE, 0.0, 0.0)
	var tail := _v(Vector3(0, 0, 0.5), Vector3.BACK, BLACK, 0.0, 0.0, Vector2(0, 1))
	var last := base + L_SEGS * (R_SEGS + 1)
	for j in R_SEGS:
		_tri(nose, base + j, base + j + 1)
		_tri(tail, last + j, last + j + 1)


func _sphere(center: Vector3, rad: float, c: Color) -> void:
	var base := verts.size()
	var lat := 8
	var lon := 12
	for i in lat + 1:
		var phi := PI * i / lat
		for j in lon + 1:
			var th := TAU * j / lon
			var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			_v(center + n * rad, n, c, 4.0, 0.0)
	for i in lat:
		for j in lon:
			var v00 := base + i * (lon + 1) + j
			var v10 := v00 + lon + 1
			_tri(v00, v10, v10 + 1)
			_tri(v00, v10 + 1, v00 + 1)


func _eye(side: float) -> void:
	var a := 0.45 if side > 0.0 else PI - 0.45
	var p := surface(0.12, a)
	var n := surface_normal(0.12, a)
	_sphere(p - n * 0.012, 0.042, WHITE)
	_sphere(p + n * 0.018, 0.026, BLACK)


func _fin(base_pts: Array, edge_pts: Array, normal: Vector3, part: float, rows: int) -> void:
	var start := verts.size()
	var n := base_pts.size()
	for r in rows + 1:
		var f := float(r) / rows
		var c := ORANGE.lerp(BLACK, smoothstep(0.6, 1.0, f))
		for k in n:
			_v(base_pts[k].lerp(edge_pts[k], f), normal, c, part, f)
	for r in rows:
		for k in n - 1:
			var v00 := start + r * n + k
			var v10 := v00 + n
			_tri(v00, v10, v10 + 1)
			_tri(v00, v10 + 1, v00 + 1)


func _caudal_fin() -> void:
	var base_pts := []
	var edge_pts := []
	var n := 14
	for k in n:
		var u := float(k) / (n - 1)
		base_pts.append(Vector3(0, lerpf(0.05, -0.05, u), 0.46))
		edge_pts.append(Vector3(0, lerpf(0.3, -0.3, u), 0.74 + 0.17 * pow(absf(2.0 * u - 1.0), 0.7)))
	_fin(base_pts, edge_pts, Vector3.RIGHT, 1.0, 5)


func _dorsal_fins() -> void:
	var base_pts := []
	var edge_pts := []
	var n := 14
	for k in n:
		var s := float(k) / (n - 1)
		var t := lerpf(0.28, 0.8, s)
		var b := Vector3(0, radius(t) * WY * 0.95, t - 0.5)
		base_pts.append(b)
		edge_pts.append(b + Vector3(0, 0.17 * pow(sin(PI * s), 0.7) + 0.01, 0.07))
	_fin(base_pts, edge_pts, Vector3.RIGHT, 2.0, 4)

	base_pts = []
	edge_pts = []
	for k in 8:
		var s := float(k) / 7
		var t := lerpf(0.62, 0.86, s)
		var b := Vector3(0, -radius(t) * WY * 0.95, t - 0.5)
		base_pts.append(b)
		edge_pts.append(b + Vector3(0, -0.1 * pow(sin(PI * s), 0.7) - 0.01, 0.05))
	_fin(base_pts, edge_pts, Vector3.RIGHT, 2.0, 3)


func _pectoral_fin(side: float) -> void:
	var a := -0.35 if side > 0.0 else PI + 0.35
	var base_pts := []
	var edge_pts := []
	var n := 8
	for k in n:
		var s := float(k) / (n - 1)
		var b := surface(lerpf(0.26, 0.34, s), a) * Vector3(0.97, 1, 1)
		base_pts.append(b)
		edge_pts.append(b + Vector3(side * 0.13, -0.05, 0.12) * (0.6 + 0.4 * sin(PI * s)))
	var normal: Vector3 = (edge_pts[0] - base_pts[0]).cross(base_pts[n - 1] - base_pts[0])
	_fin(base_pts, edge_pts, normal, 3.0, 3)
