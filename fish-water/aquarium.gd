extends Node3D

const HALF_X := 12.0
const HALF_Z := 7.0
const FLOOR_Y := -8.0
const TOP_Y := 3.0
const GROUND_SHADER := preload("res://ground.gdshader")
const PLANT_SHADER := preload("res://plant.gdshader")

var detail_tex: NoiseTexture2D
var caustic_tex: NoiseTexture2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 12345
	detail_tex = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02)
	caustic_tex = _noise_tex(FastNoiseLite.TYPE_CELLULAR, 0.04)
	(caustic_tex.noise as FastNoiseLite).cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB

	_build_ground()
	_build_rocks()
	_build_plants()
	_build_glass()
	_build_frame()
	_build_backdrop()
	_build_colliders()
	_build_bubbles()
	_build_dust()


func _noise_tex(type: FastNoiseLite.NoiseType, freq: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = type
	noise.frequency = freq
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex


func _ground_mat(color: Color, displace: bool, lump: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("detail", detail_tex)
	mat.set_shader_parameter("caustic_tex", caustic_tex)
	mat.set_shader_parameter("displace", displace)
	mat.set_shader_parameter("lump", lump)
	mat.set_shader_parameter("half_depth", HALF_Z)
	return mat


func _ground_y(_x: float, z: float) -> float:
	return FLOOR_Y - z / HALF_Z * 0.6


func _add_mesh(mesh: Mesh, xform: Transform3D, mat: Material = null, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if mat:
		mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_X * 2.0, HALF_Z * 2.0)
	plane.subdivide_width = 60
	plane.subdivide_depth = 35
	_add_mesh(plane, Transform3D(Basis(), Vector3(0, FLOOR_Y, 0)), _ground_mat(Color(0.82, 0.72, 0.52), true, 0.0))


func _build_rocks() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	var mat := _ground_mat(Color(0.42, 0.4, 0.38), false, 0.35)
	var spots := [Vector2(-8, -5), Vector2(-6.5, -4.2), Vector2(4, -5.5), Vector2(9, -1), Vector2(-10, 3), Vector2(1, -3), Vector2(7, 4)]
	for s in spots:
		var size := Vector3(rng.randf_range(1.0, 2.0), rng.randf_range(0.6, 1.3), rng.randf_range(0.9, 1.7))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(size)
		_add_mesh(sphere, Transform3D(b, Vector3(s.x, _ground_y(s.x, s.y) + size.y * 0.3, s.y)), mat)


func _blade_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := 8
	for i in segs + 1:
		var h := float(i) / segs
		var w := 0.16 * pow(1.0 - h, 0.7) + 0.01
		for side in [-1.0, 1.0]:
			verts.append(Vector3(side * w * 0.5, h, 0.1 * h * h))
			norms.append(Vector3.BACK)
			uvs.append(Vector2(side * 0.5 + 0.5, h))
	for i in segs:
		var a := i * 2
		# Clockwise when viewed from +Z, which is the side the normals face.
		idx.append_array([a, a + 2, a + 1, a + 2, a + 3, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _build_plants() -> void:
	var clusters := [
		[Vector2(-9.5, -5.5), Color(1, 1, 1)], [Vector2(-5, -6), Color(0.8, 1.1, 0.8)],
		[Vector2(1.5, -6), Color(1, 1, 1)], [Vector2(6, -5.8), Color(1.6, 0.6, 0.5)],
		[Vector2(10.5, -4), Color(1, 1, 1)], [Vector2(10.5, 2.5), Color(0.9, 1.2, 0.9)],
		[Vector2(-10.5, 0), Color(1.5, 0.7, 0.5)], [Vector2(-3, -2.5), Color(1, 1, 1)],
	]
	var per_cluster := 22
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	mm.instance_count = clusters.size() * per_cluster
	var i := 0
	for cl in clusters:
		var center: Vector2 = cl[0]
		for k in per_cluster:
			var p: Vector2 = center + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.0, 1.0))
			var height := rng.randf_range(2.0, 5.5)
			var width := rng.randf_range(0.8, 1.4)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
			mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, _ground_y(p.x, p.y) - 0.35, p.y)))
			mm.set_instance_color(i, (cl[1] as Color) * rng.randf_range(0.8, 1.15))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = PLANT_SHADER
	mmi.material_override = mat
	add_child(mmi)


func _build_glass() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.9, 0.95, 0.06)
	mat.roughness = 0.02
	mat.metallic_specular = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var height := TOP_Y - FLOOR_Y + 0.6
	var cy := (TOP_Y + FLOOR_Y - 0.6) * 0.5
	var t := 0.06
	for z in [-1.0, 1.0]:
		var box := BoxMesh.new()
		box.size = Vector3(HALF_X * 2.0, height, t)
		_add_mesh(box, Transform3D(Basis(), Vector3(0, cy, z * (HALF_Z + t * 0.5))), mat, false)
	for x in [-1.0, 1.0]:
		var box := BoxMesh.new()
		box.size = Vector3(t, height, HALF_Z * 2.0)
		_add_mesh(box, Transform3D(Basis(), Vector3(x * (HALF_X + t * 0.5), cy, 0)), mat, false)


func _build_frame() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.035)
	mat.roughness = 0.4
	var w := HALF_X * 2.0 + 0.6
	var d := HALF_Z * 2.0 + 0.6
	var bar := 0.3
	for y in [FLOOR_Y - 0.6 - bar * 0.5, TOP_Y + bar * 0.5]:
		for z in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(w, bar, bar)
			_add_mesh(box, Transform3D(Basis(), Vector3(0, y, z * (HALF_Z + bar * 0.5))), mat, false)
		for x in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(bar, bar, d)
			_add_mesh(box, Transform3D(Basis(), Vector3(x * (HALF_X + bar * 0.5), y, 0)), mat, false)
	var post := BoxMesh.new()
	post.size = Vector3(bar, TOP_Y - FLOOR_Y + 0.6, bar)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_add_mesh(post, Transform3D(Basis(), Vector3(x * (HALF_X + bar * 0.5), (TOP_Y + FLOOR_Y - 0.6) * 0.5, z * (HALF_Z + bar * 0.5))), mat, false)

	# Sand bed underside, lid with lamp and the stand.
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.6, d)
	_add_mesh(slab, Transform3D(Basis(), Vector3(0, FLOOR_Y - 0.3, 0)), mat, false)
	var lid := BoxMesh.new()
	lid.size = Vector3(w, 0.4, d)
	_add_mesh(lid, Transform3D(Basis(), Vector3(0, TOP_Y + 0.5, 0)), mat, false)
	var stand := BoxMesh.new()
	stand.size = Vector3(w + 1.0, 8.0, d + 1.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.18, 0.11, 0.07)
	wood.roughness = 0.7
	_add_mesh(stand, Transform3D(Basis(), Vector3(0, FLOOR_Y - 0.6 - 0.3 - 4.0, 0)), wood, false)

	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(0.85, 0.95, 1.0)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(HALF_X * 1.7, 0.05, 0.8)
	_add_mesh(lamp, Transform3D(Basis(), Vector3(0, TOP_Y + 0.28, 0)), lamp_mat, false)


func _build_backdrop() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
void fragment() {
	float y = 1.0 - UV.y;
	vec3 c = mix(vec3(0.0, 0.05, 0.12), vec3(0.05, 0.35, 0.5), y);
	float hills = texture(noise, vec2(UV.x * 0.6, 0.3)).r * 0.45 + 0.05;
	float hills2 = texture(noise, vec2(UV.x * 1.3 + 0.4, 0.7)).r * 0.3;
	c = mix(c, c * 0.45, step(y, hills));
	c = mix(c, c * 0.6, step(y, hills2));
	ALBEDO = c;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise", detail_tex)
	var quad := QuadMesh.new()
	quad.size = Vector2(HALF_X * 2.0, TOP_Y - FLOOR_Y + 0.6)
	_add_mesh(quad, Transform3D(Basis(), Vector3(0, (TOP_Y + FLOOR_Y - 0.6) * 0.5, -HALF_Z - 0.2)), mat, false)


func _build_colliders() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var t := 1.0
	var boxes := [
		[Vector3(HALF_X * 2.0, t, HALF_Z * 2.0), Vector3(0, FLOOR_Y - t * 0.5, 0)],
		[Vector3(HALF_X * 2.0, t, HALF_Z * 2.0), Vector3(0, TOP_Y + t * 0.5, 0)],
		[Vector3(HALF_X * 2.0, 20.0, t), Vector3(0, 0, -HALF_Z - t * 0.5)],
		[Vector3(HALF_X * 2.0, 20.0, t), Vector3(0, 0, HALF_Z + t * 0.5)],
		[Vector3(t, 20.0, HALF_Z * 2.0), Vector3(-HALF_X - t * 0.5, 0, 0)],
		[Vector3(t, 20.0, HALF_Z * 2.0), Vector3(HALF_X + t * 0.5, 0, 0)],
	]
	for b in boxes:
		var shape := BoxShape3D.new()
		shape.size = b[0]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = b[1]
		body.add_child(cs)


func _build_bubbles() -> void:
	var pos := Vector3(10.0, _ground_y(10.0, -5.5) + 0.2, -5.5)
	var stone := CylinderMesh.new()
	stone.top_radius = 0.25
	stone.bottom_radius = 0.3
	stone.height = 0.3
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.1, 0.1, 0.12)
	_add_mesh(stone, Transform3D(Basis(), pos), stone_mat)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.97, 1.0, 0.35)
	mat.roughness = 0.0
	mat.rim_enabled = true
	mat.rim = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = mat

	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = 40
	p.lifetime = 2.7
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 1.6, 0)
	p.tangential_accel_min = -0.5
	p.tangential_accel_max = 0.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.position = pos + Vector3(0, 0.2, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


func _build_dust() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.9, 1.0, 0.95, 0.45)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	quad.material = mat

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.5, Color(1, 1, 1, 1))

	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = 250
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(HALF_X - 0.3, 3.8, HALF_Z - 0.3)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.gravity = Vector3(0, -0.01, 0)
	p.color_ramp = ramp
	p.position = Vector3(0, FLOOR_Y * 0.5, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
