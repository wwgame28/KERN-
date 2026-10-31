class_name LevelBuilder
## Сборка локации «Город». Работает как корутина: между объектами отдаёт кадр,
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
	gw.init_systems(20.0)
	await _build_city(ctx)
	progress.call(1.0)
	return Vector3(0, 0.6, 0)


static func _tick(ctx: Ctx) -> void:
	ctx.done += 1
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


static func _try_place_in(ctx: Ctx, obj: VoxelObject, area: Rect2, margin: float, rotate: bool, avoid_center: float) -> VoxelObject:
	for attempt in 30:
		var steps := (ctx.rng.randi() % 4) if rotate else 0
		var fp := _footprint(obj, steps)
		var lo := area.position + fp * 0.5
		var hi := area.end - fp * 0.5
		if hi.x <= lo.x or hi.y <= lo.y:
			break
		var c := Vector2(ctx.rng.randf_range(lo.x, hi.x), ctx.rng.randf_range(lo.y, hi.y))
		if c.length() < avoid_center:
			continue
		var rect := Rect2(c.x - fp.x * 0.5 - margin, c.y - fp.y * 0.5 - margin, fp.x + margin * 2.0, fp.y + margin * 2.0)
		if not _rect_free(ctx, rect):
			continue
		_commit(ctx, obj, c, steps, margin, false)
		return obj
	obj.free()
	return null


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
	# земля из частиц по 5 см + дороги
	LevelEnv.make_ground(gw, {
		"base_color": Color(0.05, 0.055, 0.08), "dot_color": Color(0.35, 0.55, 1.0), "dot_scale": 20.0,
		"dot_glow": 0.4, "dot_size": 0.3, "contrast": 0.55, "roughness_val": 0.22, "metallic_val": 0.35,
		"road_spacing": 36.0, "road_width": 10.0, "road_color": Color(0.02, 0.02, 0.035),
		"line_color": Color(1.0, 0.75, 0.3),
	})
	LevelEnv.make_bounds(gw, 64.0)
	LevelEnv.make_backdrop(gw, "skyline", rng, {
		"body_color": Color(0.03, 0.035, 0.07), "light_color": Color(1.0, 0.65, 0.35),
		"light_color2": Color(0.4, 0.75, 1.0), "window_mode": 1.0, "density": 0.3,
	})
	var blocks: Array[Vector2] = []
	for bx in [-54.0, -18.0, 18.0, 54.0]:
		for bz in [-54.0, -18.0, 18.0, 54.0]:
			if absf(bx) > 40.0 and absf(bz) > 40.0:
				continue
			blocks.append(Vector2(bx, bz))
	ctx.total = blocks.size() + 6 + 10 + 14 + 8 + 6
	# кварталы между дорогами (дороги на x,z = 0, ±36)
	for bc in blocks:
		var outer := maxf(absf(bc.x), absf(bc.y)) > 40.0
		var w := rng.randf_range(6.5, 9.0)
		var d := rng.randf_range(6.5, 9.0)
		var h := rng.randf_range(22.0, 34.0) if outer else rng.randf_range(14.0, 26.0)
		var neon: int = VoxelMat.NEON_PINK if rng.randf() < 0.5 else VoxelMat.NEON_CYAN
		var b := VoxelShapes.skyscraper(rng, w, d, h, neon)
		var off := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
		_commit(ctx, b, bc + off, 0, 1.0, false)
		await _tick(ctx)
	# сквер: деревья в ближних кварталах
	for i in 6:
		var bc2: Vector2 = blocks[rng.randi() % blocks.size()]
		if maxf(absf(bc2.x), absf(bc2.y)) > 40.0:
			bc2 = Vector2(18.0 if i % 2 == 0 else -18.0, 18.0 if i % 4 < 2 else -18.0)
		_try_place_in(ctx, VoxelShapes.tree(rng), Rect2(bc2 - Vector2(12.5, 12.5), Vector2(25, 25)), 0.4, false, 7.0)
		await _tick(ctx)
	# машины на дорогах
	for i in 10:
		var on_x := rng.randf() < 0.5
		var lane: float = [-36.0, 0.0, 36.0][rng.randi() % 3] + (2.6 if rng.randf() < 0.5 else -2.6)
		var along := rng.randf_range(-58.0, 58.0)
		var pos := Vector2(along, lane) if on_x else Vector2(lane, along)
		if pos.length() > 9.0:
			_commit(ctx, VoxelShapes.car(rng), pos, 0 if on_x else 1, 0.6, true)
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
	var world_rect := Rect2(-60, -60, 120, 120)
	for i in 8:
		_try_place_in(ctx, VoxelShapes.barrel(), world_rect, 0.4, false, 8.0)
		await _tick(ctx)
	for i in 6:
		_try_place_in(ctx, VoxelShapes.crate(VoxelMat.METAL if i % 2 == 0 else VoxelMat.WOOD), world_rect, 0.3, false, 6.0)
		await _tick(ctx)
	LevelEnv.ambient(gw, Color(1.0, 0.35, 0.8), 0.04, Vector3(0, 0.4, 0), Vector3(0, 0.05, 0))
