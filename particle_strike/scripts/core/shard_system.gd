class_name ShardSystem
extends MultiMeshInstance3D
## Собираемые частицы-ресурсы (и зелёные частицы лечения).
## Лежат на земле, покачиваются, а в радиусе магнита летят к игроку.

enum Kind { ENERGY, HEALTH, CORE }

const KIND_COLORS := [Color(0.45, 0.85, 1.0, 1.0), Color(0.3, 1.0, 0.45, 1.0), Color(1.0, 0.8, 0.25, 1.0)]

var capacity := 400
var count := 0
var pos := PackedVector3Array()
var vel := PackedVector3Array()
var age := PackedFloat32Array()
var value := PackedInt32Array()
var kind := PackedByteArray()
var magnet := PackedByteArray()
var gravity := 20.0


func setup(cap: int, g: float) -> void:
	capacity = cap
	gravity = g
	pos.resize(cap)
	vel.resize(cap)
	age.resize(cap)
	value.resize(cap)
	kind.resize(cap)
	magnet.resize(cap)
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.mesh = VoxelObject.cube_mesh()
	m.instance_count = cap
	m.visible_instance_count = 0
	multimesh = m
	set_instance_shader_parameter("sub", 2.0)
	custom_aabb = AABB(Vector3(-500, -60, -500), Vector3(1000, 400, 1000))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func spawn(p: Vector3, v: Vector3, amount: int, k: int = Kind.ENERGY) -> void:
	if amount <= 0:
		return
	var i := count
	if count >= capacity:
		# переполнение — добавляем ценность к случайной существующей частице
		var j := randi() % capacity
		value[j] += amount
		return
	count += 1
	pos[i] = p
	vel[i] = v
	age[i] = 0.0
	value[i] = amount
	kind[i] = k
	magnet[i] = 0
	multimesh.set_instance_color(i, KIND_COLORS[k])


func spray(center: Vector3, total: int, pieces: int, k: int = Kind.ENERGY) -> void:
	if total <= 0:
		return
	pieces = clampi(pieces, 1, total)
	var each := total / pieces
	var rest := total - each * pieces
	for n in pieces:
		var v := Vector3(randf_range(-4, 4), randf_range(4, 9), randf_range(-4, 4))
		spawn(center + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6)), v, each + (rest if n == 0 else 0), k)


func _remove(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		age[i] = age[last]
		value[i] = value[last]
		kind[i] = kind[last]
		magnet[i] = magnet[last]
		multimesh.set_instance_color(i, KIND_COLORS[kind[i]])
	count -= 1


func update(delta: float, player_pos: Vector3, magnet_radius: float, collect_cb: Callable) -> void:
	var target := player_pos + Vector3(0, 1.0, 0)
	var mr2 := magnet_radius * magnet_radius
	var i := 0
	while i < count:
		var p := pos[i]
		var v := vel[i]
		var a := age[i] + delta
		age[i] = a
		var to := target - p
		var d2 := to.length_squared()
		if magnet[i] == 0 and d2 < mr2 and a > 0.35:
			magnet[i] = 1
		if magnet[i] == 1:
			var spd := 14.0 + a * 10.0
			v = v.lerp(to.normalized() * spd, minf(delta * 8.0, 1.0))
			p += v * delta
			if d2 < 0.8:
				collect_cb.call(int(kind[i]), value[i])
				_remove(i)
				continue
		else:
			v.y -= gravity * delta
			p += v * delta
			if p.y < 0.35:
				p.y = 0.35
				v.y = absf(v.y) * 0.3
				v.x *= 0.7
				v.z *= 0.7
			if a > 30.0:
				_remove(i)
				continue
		pos[i] = p
		vel[i] = v
		var bob := sin(a * 3.0 + float(i)) * 0.12
		var b := Basis(Vector3.UP, a * 2.5).rotated(Vector3.RIGHT, 0.6).scaled(Vector3(0.16, 0.16, 0.16))
		multimesh.set_instance_transform(i, Transform3D(b, p + Vector3(0, bob, 0)))
		i += 1
	multimesh.visible_instance_count = count
