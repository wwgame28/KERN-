class_name LevelBuilder
## Сборка четырёх локаций. Работает как корутина: между объектами отдаёт кадр,
## чтобы экран загрузки показывал прогресс и iOS не считал приложение зависшим.

class Ctx:
	var gw: GameWorld
	var rng: RandomNumberGenerator
	var rects: Array[Rect2] = []
	var progress: Callable
	var done := 0
	var total := 1


static func build(gw: GameWorld, id: String, progress: Callable) -> Vector3:
	var ctx := Ctx.new()
	ctx.gw = gw
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = hash(id) + 1337
	ctx.progress = progress
	gw.location_id = id
	var spawn := Vector3(0, 0.6, 0)
	match id:
		"village":
			gw.init_systems(20.0)
			await _build_village(ctx)
			spawn = Vector3(0, 0.6, 6)
		"wasteland":
			gw.init_systems(20.0)
			await _build_wasteland(ctx)
		"space":
			gw.init_systems(7.0)
			await _build_space(ctx)
		_:
			gw.init_systems(20.0)
			await _build_city(ctx)
	progress.call(1.0)
	return spawn


static func _tick(ctx: Ctx) -> void:
	ctx.done += 1
	if ctx.done % 2 == 0:
		ctx.progress.call(clampf(float(ctx.done) / float(ctx.total), 0.0, 0.99))
		await ctx.gw.get_tree().process_frame


static func _rect_free(ctx: Ctx, rect: Rect2) -> bool:
	for r in ctx.rects:
		if r.intersects(rect):
			return false
	return true


static func _footprint(obj: VoxelObject, angle_steps: int) -> Vector2:
	var fx := obj.dims.x * obj.vs
	var fz := obj.dims.z * obj.vs
	return Vector2(fx, fz) if angle_steps % 2 == 0 else Vector2(fz, fx)


static func _commit(ctx: Ctx, obj: VoxelObject, center: Vector2, angle_steps: int, margin: float, check: bool) -> bool:
	var fp := _footprint(obj, angle_steps)
	var rect := Rect2(center.x - fp.x * 0.5 - margin, center.y - fp.y * 0.5 - margin, fp.x + margin * 2.0, fp.y + margin * 2.0)
	if check and not _rect_free(ctx, rect):
		obj.free()
		return false
	ctx.rects.append(rect)
	var angle := float(angle_steps) * PI * 0.5
	var b := Basis(Vector3.UP, angle)
	var local_center := Vector3(obj.dims.x * obj.vs * 0.5, 0.0, obj.dims.z * obj.vs * 0.5)
	var origin := Vector3(center.x, 0.0, center.y) - b * local_center
	ctx.gw.add_object(obj, origin, angle)
	return true


static func _try_place(ctx: Ctx, obj: VoxelObject, area: float, margin: float, rotate: bool, avoid_center: float) -> VoxelObject:
	for attempt in 30:
		var steps := (ctx.rng.randi() % 4) if rotate else 0
		var fp := _footprint(obj, steps)
		var lim_x := area - fp.x * 0.5
		var lim_z := area - fp.y * 0.5
		if lim_x <= 0.0 or lim_z <= 0.0:
			break
		var c := Vector2(ctx.rng.randf_range(-lim_x, lim_x), ctx.rng.randf_range(-lim_z, lim_z))
		if c.length() < avoid_center:
			continue
		var rect := Rect2(c.x - fp.x * 0.5 - margin, c.y - fp.y * 0.5 - margin, fp.x + margin * 2.0, fp.y + margin * 2.0)
		if not _rect_free(ctx, rect):
			continue
		_commit(ctx, obj, c, steps, margin, false)
		return obj
	obj.free()
	return null


# ------------------------------------------------------------------ ГОРОД

static func _build_city(ctx: Ctx) -> void:
	var gw := ctx.gw
	var rng := ctx.rng
	LevelEnv.make_environment(gw, {
		"top_color": Color(0.015, 0.02, 0.07), "horizon_color": Color(0.38, 0.12, 0.3),
		"bottom_color": Color(0.02, 0.02, 0.04), "sun_color": Color(0.7, 0.8, 1.0), "sun_size": 0.012,
		"star_amount": 0.7, "horizon_sharp": 0.25,
		"ambient": Color(0.22, 0.2, 0.38), "ambient_energy": 0.75,
		"sun_light": Color(0.55, 0.62, 1.0), "sun_energy": 0.55, "sun_elev": 38.0, "sun_yaw": 140.0,
		"fog_color": Color(0.16, 0.07, 0.2), "fog_density": 0.007, "glow": 1.0, "bloom": 0.12,
	})
	LevelEnv.make_ground(gw, {
		"base_color": Color(0.05, 0.055, 0.08), "dot_color": Color(0.35, 0.55, 1.0), "dot_scale": 2.0,
		"dot_glow": 0.35, "roughness_val": 0.22, "metallic_val": 0.35,
		"road_spacing": 36.0, "road_width": 10.0, "road_color": Color(0.02, 0.02, 0.035),
		"line_color": Color(1.0, 0.75, 0.3),
	})
	LevelEnv.make_bounds(gw, 64.0)
	LevelEnv.make_backdrop(gw, "skyline", rng, {
		"body_color": Color(0.03, 0.035, 0.07), "light_color": Color(1.0, 0.65, 0.35),
		"light_color2": Color(0.4, 0.75, 1.0), "window_mode": 1.0, "density": 0.3,
	})
	ctx.total = 16 + 10 + 14 + 8
	# кварталы между дорогами (дороги на x,z = 0, ±36)
	for bx in [-54.0, -18.0, 18.0, 54.0]:
		for bz in [-54.0, -18.0, 18.0, 54.0]:
			var outer := maxf(absf(bx), absf(bz)) > 40.0
			var w := rng.randi_range(13, 20)
			var d := rng.randi_range(13, 20)
			var h := rng.randi_range(44, 86) if outer else rng.randi_range(30, 64)
			var neon: int = VoxelMat.NEON_PINK if rng.randf() < 0.5 else VoxelMat.NEON_CYAN
			var b := VoxelShapes.skyscraper(rng, w, d, h, neon)
			var off := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			_commit(ctx, b, Vector2(bx, bz) + off, 0, 1.0, false)
			await _tick(ctx)
	# машины на дорогах
	for i in 10:
		var on_x := rng.randf() < 0.5
		var lane: float = [-36.0, 0.0, 36.0][rng.randi() % 3] + (2.6 if rng.randf() < 0.5 else -2.6)
		var along := rng.randf_range(-58.0, 58.0)
		var pos := Vector2(along, lane) if on_x else Vector2(lane, along)
		if pos.length() > 9.0:
			_commit(ctx, VoxelShapes.car(rng, false), pos, 0 if on_x else 1, 0.6, true)
		await _tick(ctx)
	# фонари вдоль дорог
	for i in 14:
		var road: float = [-36.0, 0.0, 36.0][i % 3]
		var side := 5.6 if i % 2 == 0 else -5.6
		var along2 := -54.0 + float(i) * 8.3
		var lamp := VoxelShapes.street_lamp(VoxelMat.NEON_CYAN if i % 3 == 0 else VoxelMat.NEON_PINK)
		var p2 := Vector2(road + side, along2) if i % 4 < 2 else Vector2(along2, road + side)
		_commit(ctx, lamp, p2, (i % 2) * 2 + (0 if i % 4 < 2 else 1), 0.2, true)
		await _tick(ctx)
	for i in 8:
		_try_place(ctx, VoxelShapes.barrel(), 60.0, 0.4, false, 8.0)
		await _tick(ctx)
	LevelEnv.ambient(gw, Color(1.0, 0.35, 0.8), 0.08, Vector3(0, 0.4, 0), Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ ДЕРЕВНЯ

static func _build_village(ctx: Ctx) -> void:
	var gw := ctx.gw
	var rng := ctx.rng
	LevelEnv.make_environment(gw, {
		"top_color": Color(0.13, 0.22, 0.5), "horizon_color": Color(1.0, 0.55, 0.3),
		"bottom_color": Color(0.12, 0.09, 0.09), "sun_color": Color(1.0, 0.75, 0.45), "sun_size": 0.035,
		"horizon_sharp": 0.45,
		"ambient": Color(0.55, 0.42, 0.45), "ambient_energy": 0.55,
		"sun_light": Color(1.0, 0.7, 0.45), "sun_energy": 1.35, "sun_elev": 13.0, "sun_yaw": -60.0,
		"fog_color": Color(0.85, 0.55, 0.42), "fog_density": 0.006, "glow": 0.8, "bloom": 0.1,
	})
	LevelEnv.make_ground(gw, {
		"base_color": Color(0.17, 0.24, 0.09), "dot_color": Color(1.0, 0.85, 0.45), "dot_scale": 2.6,
		"dot_glow": 0.18, "roughness_val": 0.9,
	})
	LevelEnv.make_bounds(gw, 64.0)
	LevelEnv.make_backdrop(gw, "mountains", rng, {
		"body_color": Color(0.17, 0.13, 0.24), "light_color": Color(1.0, 0.8, 0.6), "window_mode": 0.0,
	})
	ctx.total = 2 + 11 + 34 + 6 + 10 + 6 + 5
	# мост через реку и сама река
	var br := VoxelShapes.bridge(62, 10, 9)
	_commit(ctx, br, Vector2(22.0, 0.0), 0, 0.0, false)
	LevelEnv.make_water(gw, Vector3(22.0, 0.04, 0.0), Vector2(8.0, 140.0))
	ctx.rects.append(Rect2(17.0, -70.0, 10.0, 140.0))
	await _tick(ctx)
	_commit(ctx, VoxelShapes.church(rng), Vector2(-36.0, -36.0), 0, 2.0, false)
	await _tick(ctx)
	for i in 11:
		var hobj := VoxelShapes.house(rng, rng.randi_range(16, 22), rng.randi_range(12, 16), rng.randi_range(9, 12))
		var placed := _try_place(ctx, hobj, 58.0, 2.0, true, 9.0)
		if placed and placed.has_meta("chimney"):
			var smoke := LevelEnv.particles(14, 4.0, Vector3(0.2, 0.1, 0.2), Color(0.62, 0.6, 0.58), 0.35, Vector3(0, 1.4, 0), 12.0, Vector3(0.3, 0.1, 0.0))
			smoke.position = placed.get_meta("chimney")
			placed.add_child(smoke)
		await _tick(ctx)
	for i in 34:
		_try_place(ctx, VoxelShapes.tree(rng, "pine" if rng.randf() < 0.4 else "oak"), 62.0, 0.4, false, 7.0)
		await _tick(ctx)
	for i in 6:
		_try_place(ctx, VoxelShapes.fence(rng.randi_range(24, 40)), 55.0, 0.5, true, 8.0)
		await _tick(ctx)
	for i in 10:
		_try_place(ctx, VoxelShapes.hay_bale(), 55.0, 0.4, true, 6.0)
		await _tick(ctx)
	for i in 6:
		_try_place(ctx, VoxelShapes.crate(VoxelMat.WOOD), 55.0, 0.3, false, 6.0)
		await _tick(ctx)
	for i in 5:
		_try_place(ctx, VoxelShapes.barrel(), 55.0, 0.3, false, 8.0)
		await _tick(ctx)
	LevelEnv.ambient(gw, Color(1.0, 0.85, 0.4), 0.07, Vector3(0, 0.3, 0), Vector3(0, 0.02, 0))


# ------------------------------------------------------------------ ПУСТОШЬ

static func _build_wasteland(ctx: Ctx) -> void:
	var gw := ctx.gw
	var rng := ctx.rng
	LevelEnv.make_environment(gw, {
		"top_color": Color(0.32, 0.38, 0.55), "horizon_color": Color(0.95, 0.62, 0.38),
		"bottom_color": Color(0.4, 0.3, 0.2), "sun_color": Color(1.0, 0.85, 0.6), "sun_size": 0.04,
		"horizon_sharp": 0.5,
		"ambient": Color(0.6, 0.5, 0.42), "ambient_energy": 0.6,
		"sun_light": Color(1.0, 0.82, 0.62), "sun_energy": 1.5, "sun_elev": 28.0, "sun_yaw": 20.0,
		"fog_color": Color(0.82, 0.6, 0.42), "fog_density": 0.011, "fog_sky": 0.4, "glow": 0.7, "bloom": 0.06,
	})
	LevelEnv.make_ground(gw, {
		"base_color": Color(0.48, 0.34, 0.2), "dot_color": Color(1.0, 0.7, 0.4), "dot_scale": 2.2,
		"dot_glow": 0.12, "roughness_val": 0.95,
	})
	LevelEnv.make_bounds(gw, 64.0)
	LevelEnv.make_backdrop(gw, "mesas", rng, {
		"body_color": Color(0.42, 0.27, 0.17), "light_color": Color(1.0, 0.7, 0.4), "window_mode": 0.0,
	})
	ctx.total = 9 + 14 + 12 + 8 + 10 + 10
	for i in 9:
		_try_place(ctx, VoxelShapes.ruin(rng, rng.randi_range(12, 18), rng.randi_range(12, 18), rng.randi_range(24, 52)), 58.0, 3.0, false, 12.0)
		await _tick(ctx)
	for i in 14:
		_try_place(ctx, VoxelShapes.rock(rng, rng.randf_range(3.0, 6.5), VoxelMat.ROCK, VoxelMat.SAND), 60.0, 1.0, false, 8.0)
		await _tick(ctx)
	for i in 12:
		_try_place(ctx, VoxelShapes.crystal(rng), 60.0, 0.3, false, 6.0)
		await _tick(ctx)
	for i in 8:
		_try_place(ctx, VoxelShapes.car(rng, true), 58.0, 0.6, true, 8.0)
		await _tick(ctx)
	for i in 10:
		_try_place(ctx, VoxelShapes.tree(rng, "dead"), 60.0, 0.3, false, 6.0)
		await _tick(ctx)
	for i in 10:
		_try_place(ctx, VoxelShapes.barrel(), 58.0, 0.3, false, 8.0)
		await _tick(ctx)
	LevelEnv.ambient(gw, Color(0.95, 0.75, 0.5), 0.06, Vector3(2.0, 0.2, 0.6), Vector3(0.3, -0.02, 0.0))


# ------------------------------------------------------------------ КОСМОС

static func _build_space(ctx: Ctx) -> void:
	var gw := ctx.gw
	var rng := ctx.rng
	LevelEnv.make_environment(gw, {
		"top_color": Color(0.005, 0.005, 0.02), "horizon_color": Color(0.05, 0.03, 0.1),
		"bottom_color": Color(0.0, 0.0, 0.01), "sun_color": Color(1.0, 0.95, 0.9), "sun_size": 0.015,
		"star_amount": 1.0, "nebula": 0.9, "nebula_color": Color(0.7, 0.2, 0.9), "nebula_color2": Color(0.15, 0.5, 1.0),
		"horizon_sharp": 0.2,
		"ambient": Color(0.28, 0.22, 0.45), "ambient_energy": 0.7,
		"sun_light": Color(0.95, 0.95, 1.0), "sun_energy": 1.3, "sun_elev": 42.0, "sun_yaw": 70.0,
		"fog_density": 0.0, "glow": 1.0, "bloom": 0.12,
	})
	LevelEnv.make_ground(gw, {
		"base_color": Color(0.09, 0.1, 0.14), "dot_color": Color(0.3, 0.85, 1.0), "dot_scale": 1.5,
		"dot_glow": 0.45, "roughness_val": 0.3, "metallic_val": 0.6,
		"road_spacing": 12.0, "road_width": 0.5, "road_color": Color(0.03, 0.04, 0.06),
		"line_color": Color(0.3, 0.85, 1.0),
	}, 80.0)
	LevelEnv.make_bounds(gw, 55.0)
	LevelEnv.make_planet(gw)
	ctx.total = 4 + 8 + 4 + 10 + 6 + 14
	for i in 4:
		_try_place(ctx, VoxelShapes.dome(rng, rng.randi_range(10, 13)), 50.0, 2.0, true, 12.0)
		await _tick(ctx)
	for i in 8:
		_try_place(ctx, VoxelShapes.pylon(rng), 50.0, 1.5, false, 9.0)
		await _tick(ctx)
	for i in 4:
		_try_place(ctx, VoxelShapes.antenna_dish(rng), 50.0, 1.0, true, 9.0)
		await _tick(ctx)
	for i in 10:
		_try_place(ctx, VoxelShapes.crystal(rng), 52.0, 0.3, false, 6.0)
		await _tick(ctx)
	for i in 6:
		_try_place(ctx, VoxelShapes.crate(VoxelMat.METAL), 50.0, 0.3, false, 6.0)
		await _tick(ctx)
	# парящие астероиды (без опоры — не обрушаются, а рассыпаются)
	for i in 14:
		var a := VoxelShapes.asteroid(rng, rng.randf_range(3.0, 6.0))
		var pos := Vector3(rng.randf_range(-48.0, 48.0), rng.randf_range(6.0, 22.0), rng.randf_range(-48.0, 48.0))
		gw.add_object(a, pos - Vector3(a.dims) * a.vs * 0.5, rng.randf_range(0.0, TAU))
		await _tick(ctx)
	LevelEnv.ambient(gw, Color(0.5, 0.8, 1.0), 0.06, Vector3(0, 0.2, 0), Vector3(0, 0.01, 0))
