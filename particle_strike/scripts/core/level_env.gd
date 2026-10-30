class_name LevelEnv
## Общие кирпичики локаций: небо, свет, туман, земля, границы, дальний фон, частицы атмосферы.


static func make_environment(gw: GameWorld, cfg: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skymat := ShaderMaterial.new()
	skymat.shader = load("res://shaders/sky.gdshader")
	for key in ["top_color", "horizon_color", "bottom_color", "sun_color", "sun_size", "star_amount", "nebula", "nebula_color", "nebula_color2", "horizon_sharp"]:
		if cfg.has(key):
			skymat.set_shader_parameter(key, cfg[key])
	sky.sky_material = skymat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cfg.get("ambient", Color(0.3, 0.3, 0.4))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.6))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(cfg.get("exposure", 1.0))
	env.glow_enabled = bool(Perf.get_value("glow"))
	env.glow_intensity = float(cfg.get("glow", 0.9))
	env.glow_strength = 1.0
	env.glow_bloom = float(cfg.get("bloom", 0.08))
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)
	env.set_glow_level(5, 0.0)
	env.set_glow_level(6, 0.0)
	env.fog_enabled = float(cfg.get("fog_density", 0.0)) > 0.0
	env.fog_light_color = cfg.get("fog_color", Color(0.5, 0.5, 0.6))
	env.fog_density = float(cfg.get("fog_density", 0.0))
	env.fog_sky_affect = float(cfg.get("fog_sky", 0.25))
	env.adjustment_enabled = true
	env.adjustment_saturation = float(cfg.get("saturation", 1.15))
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	gw.add_child(we)
	gw.env = we

	var sun := DirectionalLight3D.new()
	sun.light_color = cfg.get("sun_light", Color(1, 0.9, 0.8))
	sun.light_energy = float(cfg.get("sun_energy", 1.0))
	sun.rotation_degrees = Vector3(-float(cfg.get("sun_elev", 35.0)), float(cfg.get("sun_yaw", 30.0)), 0)
	sun.shadow_enabled = bool(Perf.get_value("shadows"))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = float(Perf.get_value("shadow_dist"))
	sun.shadow_blur = 1.0
	gw.add_child(sun)
	gw.sun = sun


static func make_ground(gw: GameWorld, cfg: Dictionary, disc_radius: float = 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	for key in ["base_color", "dot_color", "dot_scale", "dot_glow", "roughness_val", "metallic_val", "road_spacing", "road_width", "road_color", "line_color"]:
		if cfg.has(key):
			mat.set_shader_parameter(key, cfg[key])
	var mi := MeshInstance3D.new()
	if disc_radius > 0.0:
		var cyl := CylinderMesh.new()
		cyl.top_radius = disc_radius
		cyl.bottom_radius = disc_radius * 0.92
		cyl.height = 3.0
		cyl.radial_segments = 64
		cyl.rings = 1
		cyl.material = mat
		mi.mesh = cyl
		mi.position.y = -1.5
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(700, 700)
		plane.material = mat
		mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gw.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = GameWorld.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000, 2, 1000)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	gw.add_child(body)


static func make_bounds(gw: GameWorld, half: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameWorld.L_BOUNDS
	body.collision_mask = 0
	for k in 4:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var along_x := k < 2
		box.size = Vector3(half * 2.0 + 4.0, 80, 2) if along_x else Vector3(2, 80, half * 2.0 + 4.0)
		cs.shape = box
		var s := 1.0 if k % 2 == 0 else -1.0
		cs.position = Vector3(0, 40, (half + 1.0) * s) if along_x else Vector3((half + 1.0) * s, 40, 0)
		body.add_child(cs)
	gw.add_child(body)
	gw.bounds = half


static func make_water(gw: GameWorld, center: Vector3, size: Vector2) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 8
	plane.subdivide_depth = 32
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gw.add_child(mi)


# ------------------------------------------------------------------ дальний фон

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3) -> void:
	_tri(st, a, b, c, center)
	_tri(st, a, c, d, center)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		n = -n
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


static func _box_into(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	_quad(st, p[0], p[1], p[2], p[3], c)
	_quad(st, p[5], p[4], p[7], p[6], c)
	_quad(st, p[4], p[0], p[3], p[7], c)
	_quad(st, p[1], p[5], p[6], p[2], c)
	_quad(st, p[3], p[2], p[6], p[7], c)


static func _cone_into(st: SurfaceTool, base: Vector3, r: float, h: float, segs: int, rng: RandomNumberGenerator) -> void:
	var top := base + Vector3(rng.randf_range(-r, r) * 0.2, h, rng.randf_range(-r, r) * 0.2)
	var center := base + Vector3(0, h * 0.3, 0)
	var pts: Array[Vector3] = []
	for i in segs:
		var a := TAU * float(i) / float(segs) + rng.randf_range(-0.2, 0.2)
		var rr := r * rng.randf_range(0.75, 1.1)
		pts.append(base + Vector3(cos(a) * rr, 0, sin(a) * rr))
	for i in segs:
		_tri(st, pts[i], pts[(i + 1) % segs], top, center)


static func make_backdrop(gw: GameWorld, kind: String, rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"skyline":
			for i in 90:
				var a := TAU * float(i) / 90.0 + rng.randf_range(-0.03, 0.03)
				var dist := rng.randf_range(115.0, 190.0)
				var w := rng.randf_range(8.0, 22.0)
				var h := rng.randf_range(25.0, 110.0)
				_box_into(st, Vector3(cos(a) * dist, h * 0.5, sin(a) * dist), Vector3(w, h, w * rng.randf_range(0.7, 1.3)))
		"mountains", "mesas":
			for i in 34:
				var a := TAU * float(i) / 34.0 + rng.randf_range(-0.05, 0.05)
				var dist := rng.randf_range(150.0, 230.0)
				if kind == "mesas":
					var w := rng.randf_range(25.0, 60.0)
					var h := rng.randf_range(15.0, 45.0)
					_box_into(st, Vector3(cos(a) * dist, h * 0.5, sin(a) * dist), Vector3(w, h, w * 0.7))
				else:
					_cone_into(st, Vector3(cos(a) * dist, -2.0, sin(a) * dist), rng.randf_range(35.0, 70.0), rng.randf_range(30.0, 80.0), 7, rng)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop.gdshader")
	for key in ["body_color", "light_color", "light_color2", "window_mode", "density"]:
		if cfg.has(key):
			mat.set_shader_parameter(key, cfg[key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gw.add_child(mi)


static func make_planet(gw: GameWorld) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 260.0
	sphere.height = 520.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.05, 0.25)
	mat.rim_enabled = true
	mat.rim = 0.8
	mat.rim_tint = 0.2
	sphere.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = Vector3(-520, 160, -900)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gw.add_child(mi)
	var torus := TorusMesh.new()
	torus.inner_radius = 330.0
	torus.outer_radius = 430.0
	torus.rings = 64
	torus.ring_segments = 4
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.7, 0.55, 1.0, 0.35)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	torus.material = rmat
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.position = mi.position
	ring.rotation_degrees = Vector3(18, 0, 12)
	ring.scale = Vector3(1, 0.02, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gw.add_child(ring)


# ------------------------------------------------------------------ частицы атмосферы

static func particles(amount: int, lifetime: float, extents: Vector3, color: Color, size: float, velocity: Vector3, spread: float, gravity: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.preprocess = lifetime
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	var sp := velocity.length()
	pm.direction = velocity / sp if sp > 0.001 else Vector3.UP
	pm.initial_velocity_min = sp * 0.5
	pm.initial_velocity_max = sp
	pm.spread = spread
	pm.gravity = gravity
	pm.scale_min = size * 0.5
	pm.scale_max = size
	pm.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.draw_pass_1 = mesh
	var grow := extents + Vector3(20, 30, 20)
	p.visibility_aabb = AABB(-grow, grow * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func ambient(gw: GameWorld, color: Color, size: float, velocity: Vector3, gravity: Vector3) -> void:
	var p := particles(int(Perf.get_value("ambient")), 9.0, Vector3(gw.bounds, 10, gw.bounds), color, size, velocity, 180.0, gravity)
	p.position = Vector3(0, 10, 0)
	gw.add_child(p)
