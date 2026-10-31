class_name DebrisSystem
extends MultiMeshInstance3D
## Кольцевой буфер обломков-микрочастиц. Физика целиком в шейдере (debris.gdshader),
## поэтому десятки тысяч частиц стоят ~0 мс CPU. Новые частицы пишутся в копию буфера
## в памяти, а на видеокарту уходит одна загрузка за кадр (а не 3 вызова на частицу).

var capacity := 4000
var cursor := 0
var clock := 0.0
var mat: ShaderMaterial
var buf := PackedFloat32Array()
var _dirty := false


func setup(cap: int, gravity: float, ground_y: float) -> void:
	capacity = maxi(cap, 64)
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.use_custom_data = true
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/debris.gdshader")
	mat.set_shader_parameter("gravity", gravity)
	mat.set_shader_parameter("ground_y", ground_y)
	m.mesh = VoxelObject.make_cube_mesh()
	material_override = mat
	m.instance_count = capacity
	# 12 (transform) + 4 (color) + 4 (custom) float на экземпляр
	buf = PackedFloat32Array()
	buf.resize(capacity * 20)
	buf.fill(0.0)
	for i in capacity:
		var o := i * 20
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
		buf[o + 19] = -1000.0
	m.buffer = buf
	multimesh = m
	custom_aabb = AABB(Vector3(-500, -60, -500), Vector3(1000, 400, 1000))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	clock += delta
	mat.set_shader_parameter("u_time", clock)
	if _dirty:
		_dirty = false
		multimesh.buffer = buf


func spawn(pos: Vector3, vel: Vector3, col: Color, size: float, hot: bool = false) -> void:
	# базис у всех экземпляров единичный и не меняется — пишем только позицию, цвет и данные
	var o := cursor * 20
	cursor = (cursor + 1) % capacity
	var a := clampf(size, 0.004, 0.98) * 0.5
	if hot:
		a += 0.5
	buf[o + 3] = pos.x
	buf[o + 7] = pos.y
	buf[o + 11] = pos.z
	buf[o + 12] = col.r
	buf[o + 13] = col.g
	buf[o + 14] = col.b
	buf[o + 15] = a
	buf[o + 16] = vel.x
	buf[o + 17] = vel.y
	buf[o + 18] = vel.z
	buf[o + 19] = clock
	_dirty = true


func burst(pos: Vector3, count: int, col: Color, speed: float, size: float, hot: bool = true, up_bias: float = 2.0) -> void:
	## Искры/брызги без привязки к вокселям (взрывы, вспышки, следы ракет).
	for k in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var v := dir * speed * randf_range(0.4, 1.0) + Vector3.UP * up_bias
		spawn(pos, v, col, size * randf_range(0.6, 1.2), hot)


func set_gravity(g: float) -> void:
	mat.set_shader_parameter("gravity", g)
