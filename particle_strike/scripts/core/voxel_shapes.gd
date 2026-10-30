class_name VoxelShapes
## Процедурные генераторы разрушаемых построек из частиц.
## Все возвращают VoxelObject с заполненной сеткой (finalize вызывает GameWorld.add_object).

static func _hash(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) % 1000


# ------------------------------------------------------------------ город

static func skyscraper(rng: RandomNumberGenerator, w: int, d: int, h: int, neon_mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(w, h + 7, d), 0.5)
	var seed_v := rng.randi() % 1000
	var floor_h := 4
	var neon_every := rng.randi_range(10, 16)
	for y in h:
		var fy := y % floor_h
		var is_neon := y > 3 and y % neon_every == 0
		for z in d:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == d - 1
				if not (ex or ez):
					continue
				var m: int = VoxelMat.CONCRETE
				if is_neon:
					m = neon_mat
				elif not (ex and ez) and fy != 0:
					var along := x if ez else z
					if along % 3 != 0 and fy <= 2:
						var win := _hash(along / 3 + seed_v, y / floor_h, 1 if ex else 2)
						m = VoxelMat.WINDOW_DARK if win < 330 else VoxelMat.GLASS
				o.set_v(x, y, z, m)
		# перекрытия внутри — здание не пустая коробка
		if y > 0 and y % (floor_h * 3) == 0:
			o.fill_box(Vector3i(1, y, 1), Vector3i(w - 2, y, d - 2), VoxelMat.CONCRETE)
	o.fill_box(Vector3i(0, h, 0), Vector3i(w - 1, h, d - 1), VoxelMat.CONCRETE)
	# парапет и неоновая окантовка крыши
	for x in w:
		o.set_v(x, h + 1, 0, neon_mat)
		o.set_v(x, h + 1, d - 1, neon_mat)
	for z in d:
		o.set_v(0, h + 1, z, neon_mat)
		o.set_v(w - 1, h + 1, z, neon_mat)
	# антенна
	var ax := w / 2
	var az := d / 2
	o.fill_box(Vector3i(ax - 1, h + 1, az - 1), Vector3i(ax, h + 2, az), VoxelMat.METAL)
	o.fill_box(Vector3i(ax, h + 3, az), Vector3i(ax, h + 5, az), VoxelMat.METAL)
	o.set_v(ax, h + 6, az, VoxelMat.NEON_PINK)
	return o


static func street_lamp(color_mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(5, 18, 2), 0.25)
	o.fill_box(Vector3i(0, 0, 0), Vector3i(1, 15, 1), VoxelMat.METAL)
	o.fill_box(Vector3i(0, 15, 0), Vector3i(4, 16, 1), VoxelMat.METAL)
	o.fill_box(Vector3i(3, 14, 0), Vector3i(4, 14, 1), color_mat)
	o.casts_shadow = false
	return o


static func car(rng: RandomNumberGenerator, wreck: bool) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(11, 5, 6), 0.4)
	var body: int = VoxelMat.RUST if wreck else [VoxelMat.METAL, VoxelMat.NEON_PINK, VoxelMat.CONCRETE][rng.randi() % 3]
	if body == VoxelMat.NEON_PINK:
		body = VoxelMat.METAL
	o.fill_box(Vector3i(0, 1, 0), Vector3i(10, 2, 5), body)
	o.fill_box(Vector3i(2, 3, 0), Vector3i(8, 4, 5), VoxelMat.WINDOW_DARK if wreck else VoxelMat.GLASS)
	o.fill_box(Vector3i(3, 4, 1), Vector3i(7, 4, 4), body)
	for wx in [1, 9]:
		for wz in [0, 5]:
			o.set_v(wx, 0, wz, VoxelMat.ASTEROID)
			o.set_v(wx + 1, 0, wz, VoxelMat.ASTEROID)
	# бензобак — красные взрывные частицы
	o.fill_box(Vector3i(4, 1, 2), Vector3i(6, 2, 3), VoxelMat.EXPLOSIVE)
	if not wreck:
		o.set_v(0, 2, 1, VoxelMat.NEON_CYAN)
		o.set_v(0, 2, 4, VoxelMat.NEON_CYAN)
		o.set_v(10, 2, 1, VoxelMat.EXPLOSIVE)
		o.set_v(10, 2, 4, VoxelMat.EXPLOSIVE)
	o.explode_on_break = true
	o.explode_radius = 5.0
	o.value_mult = 1.5
	o.casts_shadow = false
	return o


static func barrel() -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(4, 6, 4), 0.25)
	for y in 6:
		for z in 4:
			for x in 4:
				var corner := (x == 0 or x == 3) and (z == 0 or z == 3)
				if corner:
					continue
				o.set_v(x, y, z, VoxelMat.METAL if y == 0 or y == 5 or y == 3 else VoxelMat.EXPLOSIVE)
	o.explode_on_break = true
	o.explode_radius = 4.5
	o.value_mult = 2.0
	o.casts_shadow = false
	return o


# ------------------------------------------------------------------ деревня

static func house(rng: RandomNumberGenerator, w: int, d: int, wall_h: int) -> VoxelObject:
	var o := VoxelObject.new()
	var roof_h := d / 2 + 2
	o.setup(Vector3i(w + 2, wall_h + roof_h + 4, d + 2), 0.35)
	var wall: int = VoxelMat.PLASTER if rng.randf() < 0.6 else VoxelMat.WOOD
	var seed_v := rng.randi() % 1000
	# стены (смещение +1 под свес крыши)
	for y in wall_h:
		for z in d:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == d - 1
				if not (ex or ez):
					continue
				var m := wall
				if ex and ez:
					m = VoxelMat.TRUNK
				elif y == 0:
					m = VoxelMat.STONE
				else:
					var along := x if ez else z
					var span := w if ez else d
					var wy := y % 6
					if along > 1 and along < span - 2 and along % 5 >= 2 and along % 5 <= 3 and wy >= 2 and wy <= 3:
						m = VoxelMat.GLASS if _hash(along / 5 + seed_v, y / 6, 3) < 750 else VoxelMat.WINDOW_DARK
					if ez and z == 0 and absi(x - w / 2) <= 1 and y >= 1 and y <= 4:
						m = VoxelMat.TRUNK
				o.set_v(x + 1, y, z + 1, m)
	# пол чердака
	o.fill_box(Vector3i(2, wall_h - 1, 2), Vector3i(w - 1, wall_h - 1, d - 1), VoxelMat.WOOD)
	# двускатная крыша (конёк вдоль X) + фронтоны
	for k in roof_h:
		var y := wall_h + k
		var z0 := k
		var z1 := d + 1 - k
		if z0 > z1:
			break
		for x in w + 2:
			o.set_v(x, y, z0, VoxelMat.ROOF)
			o.set_v(x, y, z1, VoxelMat.ROOF)
			if z1 - z0 <= 1:
				continue
		for z in range(z0 + 1, z1):
			o.set_v(1, y, z, wall)
			o.set_v(w, y, z, wall)
		if z1 - z0 <= 1:
			for x in w + 2:
				for z in range(z0, z1 + 1):
					o.set_v(x, y, z, VoxelMat.ROOF)
	# труба
	var cx := 3 + rng.randi() % maxi(w - 5, 1)
	o.fill_box(Vector3i(cx, wall_h, d / 2 - 2), Vector3i(cx + 1, wall_h + roof_h + 2, d / 2 - 1), VoxelMat.STONE)
	o.set_meta("chimney", Vector3(cx + 1, wall_h + roof_h + 3, d / 2 - 1) * 0.35)
	return o


static func church(rng: RandomNumberGenerator) -> VoxelObject:
	var o := VoxelObject.new()
	var w := 26
	var d := 16
	var wall_h := 16
	var tw := 8
	var tower_h := 38
	o.setup(Vector3i(w + tw, tower_h + 12, d), 0.4)
	# неф
	for y in wall_h:
		for z in d:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == d - 1
				if not (ex or ez):
					continue
				var m: int = VoxelMat.STONE
				if ez and x % 5 == 2 and y >= 5 and y <= 11:
					m = VoxelMat.GLASS
				o.set_v(x + tw, y, z, m)
	var roof_h := d / 2
	for k in roof_h:
		for x in range(tw, tw + w):
			o.set_v(x, wall_h + k, k, VoxelMat.ROOF)
			o.set_v(x, wall_h + k, d - 1 - k, VoxelMat.ROOF)
		for z in range(k + 1, d - 1 - k):
			o.set_v(tw + w - 1, wall_h + k, z, VoxelMat.STONE)
	# колокольня
	var oz := (d - tw) / 2
	for y in tower_h:
		for z in tw:
			for x in tw:
				if x == 0 or x == tw - 1 or z == 0 or z == tw - 1:
					var m: int = VoxelMat.STONE
					if y > tower_h - 9 and y < tower_h - 3 and (x == tw / 2 or z == tw / 2):
						m = VoxelMat.GLASS
					o.set_v(x, y, z + oz, m)
	# шпиль
	for k in tw / 2 + 6:
		var inset := mini(k / 2, tw / 2 - 1)
		for z in range(inset, tw - inset):
			for x in range(inset, tw - inset):
				if x == inset or x == tw - 1 - inset or z == inset or z == tw - 1 - inset:
					o.set_v(x, tower_h + k, z + oz, VoxelMat.ROOF)
	var top := tower_h + tw / 2 + 6
	o.fill_box(Vector3i(tw / 2 - 1, top, oz + tw / 2 - 1), Vector3i(tw / 2 - 1, top + 3, oz + tw / 2 - 1), VoxelMat.GOLD)
	o.fill_box(Vector3i(tw / 2 - 2, top + 2, oz + tw / 2 - 1), Vector3i(tw / 2, top + 2, oz + tw / 2 - 1), VoxelMat.GOLD)
	o.value_mult = 1.3
	return o


static func tree(rng: RandomNumberGenerator, kind: String) -> VoxelObject:
	var o := VoxelObject.new()
	var vs := 0.3
	match kind:
		"pine":
			var h := rng.randi_range(14, 20)
			o.setup(Vector3i(11, h + 3, 11), vs)
			o.fill_box(Vector3i(5, 0, 5), Vector3i(5, h - 2, 5), VoxelMat.TRUNK)
			for y in range(3, h + 2):
				var r := (float(h + 2 - y) / float(h)) * 5.2
				for z in 11:
					for x in 11:
						var dd := Vector2(x - 5, z - 5).length()
						if dd <= r and dd > r - 1.6 and (y % 2 == 0 or dd > r - 1.0):
							o.set_v(x, y, z, VoxelMat.PINE)
		"dead":
			var h2 := rng.randi_range(9, 14)
			o.setup(Vector3i(9, h2 + 1, 9), vs)
			o.fill_box(Vector3i(4, 0, 4), Vector3i(4, h2, 4), VoxelMat.TRUNK)
			for b in 3:
				var by := rng.randi_range(4, h2 - 1)
				var dx := rng.randi_range(-1, 1)
				var dz := 1 if dx == 0 else rng.randi_range(-1, 1)
				for k in range(1, 4):
					o.set_v(4 + dx * k, by + k / 2, 4 + dz * k, VoxelMat.TRUNK)
		_:
			var th := rng.randi_range(6, 9)
			var r2 := rng.randf_range(3.6, 4.8)
			var size := int(ceil(r2 * 2.0)) + 3
			var c := size / 2
			o.setup(Vector3i(size, th + int(r2 * 2.0) + 2, size), vs)
			o.fill_box(Vector3i(c - 1, 0, c - 1), Vector3i(c, th + 2, c), VoxelMat.TRUNK)
			var center := Vector3(c, th + r2 * 0.8, c)
			var nz := FastNoiseLite.new()
			nz.seed = rng.randi()
			nz.frequency = 0.05
			o.fill_sphere(center, r2, VoxelMat.LEAVES, nz, 1.0)
			o.fill_sphere(center, r2 - 1.7, 0)
			o.fill_box(Vector3i(c - 1, th, c - 1), Vector3i(c, th + 3, c), VoxelMat.TRUNK)
	o.casts_shadow = true
	return o


static func bridge(length: int, width: int, arch: int) -> VoxelObject:
	## Деревянный арочный мост вдоль X. Держится за оба берега (Anchor.ENDS_X).
	var o := VoxelObject.new()
	o.setup(Vector3i(length, arch + 6, width), 0.3)
	o.anchor = VoxelObject.Anchor.ENDS_X
	for x in length:
		var t := float(x) / float(length - 1)
		var y := int(round(sin(t * PI) * arch))
		for z in width:
			o.set_v(x, y, z, VoxelMat.WOOD)
			o.set_v(x, y + 1, z, VoxelMat.WOOD if (x % 3 != 0) else VoxelMat.TRUNK)
		# перила
		if x % 4 == 0:
			o.fill_box(Vector3i(x, y + 2, 0), Vector3i(x, y + 4, 0), VoxelMat.TRUNK)
			o.fill_box(Vector3i(x, y + 2, width - 1), Vector3i(x, y + 4, width - 1), VoxelMat.TRUNK)
		o.set_v(x, y + 4, 0, VoxelMat.WOOD)
		o.set_v(x, y + 4, width - 1, VoxelMat.WOOD)
		# фонарики
		if x % 12 == 6:
			o.set_v(x, y + 5, 0, VoxelMat.GLASS)
			o.set_v(x, y + 5, width - 1, VoxelMat.GLASS)
	return o


static func fence(length: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(length, 5, 1), 0.25)
	for x in length:
		if x % 4 == 0:
			o.fill_box(Vector3i(x, 0, 0), Vector3i(x, 4, 0), VoxelMat.TRUNK)
		o.set_v(x, 2, 0, VoxelMat.WOOD)
		o.set_v(x, 4, 0, VoxelMat.WOOD)
	o.casts_shadow = false
	return o


static func hay_bale() -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(5, 4, 4), 0.3)
	o.fill_box(Vector3i(0, 0, 0), Vector3i(4, 3, 3), VoxelMat.HAY)
	o.casts_shadow = false
	return o


static func crate(mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(4, 4, 4), 0.3)
	o.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), mat)
	o.casts_shadow = false
	return o


# ------------------------------------------------------------------ пустошь

static func ruin(rng: RandomNumberGenerator, w: int, d: int, h: int) -> VoxelObject:
	var o := skyscraper(rng, w, d, h, VoxelMat.RUST)
	# заменяем материалы на пыльные и выгрызаем «раны»
	var g := o.grid
	for i in g.size():
		var m := g[i]
		if m == VoxelMat.CONCRETE:
			g[i] = VoxelMat.SAND if (i * 7919) % 5 == 0 else VoxelMat.CONCRETE
		elif m == VoxelMat.GLASS or m == VoxelMat.NEON_PINK:
			g[i] = VoxelMat.WINDOW_DARK
	o.grid = g
	for k in rng.randi_range(3, 6):
		var c := Vector3(rng.randf_range(0, w), rng.randf_range(h * 0.4, h + 6), rng.randf_range(0, d))
		o.carve_sphere(c, rng.randf_range(3.0, 7.0))
	o.carve_sphere(Vector3(rng.randf_range(0, w), h + 6, rng.randf_range(0, d)), 9.0)
	o.prune_floating()
	return o


static func rock(rng: RandomNumberGenerator, r: float, mat: int, alt_mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	var size := int(ceil(r * 2.0)) + 4
	o.setup(Vector3i(size, int(r * 1.6) + 2, size), 0.5)
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.04
	var c := Vector3(size * 0.5, 0.0, size * 0.5)
	for z in size:
		for y in o.dims.y:
			for x in size:
				var p := Vector3(x + 0.5, (y + 0.5) * 1.25, z + 0.5)
				var n := nz.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0)
				if p.distance_to(c) < r + n * 2.2:
					var m := alt_mat if nz.get_noise_3d(p.x * 9.0, p.y * 9.0, 50.0) > 0.25 else mat
					o.set_v(x, y, z, m)
	return o


static func crystal(rng: RandomNumberGenerator) -> VoxelObject:
	var o := VoxelObject.new()
	var h := rng.randi_range(10, 18)
	o.setup(Vector3i(7, h, 7), 0.3)
	for y in h:
		var r := 3.2 * (1.0 - float(y) / float(h)) + 0.6
		for z in 7:
			for x in 7:
				if Vector2(x - 3, z - 3).length() <= r:
					o.set_v(x, y, z, VoxelMat.CRYSTAL)
	o.value_mult = 2.5
	o.casts_shadow = false
	return o


# ------------------------------------------------------------------ космос

static func asteroid(rng: RandomNumberGenerator, r: float) -> VoxelObject:
	var o := VoxelObject.new()
	var size := int(ceil(r * 2.0)) + 4
	o.setup(Vector3i(size, size, size), 0.5)
	o.anchor = VoxelObject.Anchor.NONE
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.05
	var c := Vector3(size, size, size) * 0.5
	for z in size:
		for y in size:
			for x in size:
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var n := nz.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0)
				var dd := p.distance_to(c)
				if dd < r + n * 2.0 and dd > r - 2.4 + n:
					var m: int = VoxelMat.ASTEROID
					if nz.get_noise_3d(p.x * 10.0, p.y * 10.0, p.z * 10.0) > 0.42:
						m = VoxelMat.CRYSTAL
					o.set_v(x, y, z, m)
	o.value_mult = 1.4
	return o


static func pylon(rng: RandomNumberGenerator) -> VoxelObject:
	var o := VoxelObject.new()
	var h := rng.randi_range(22, 34)
	o.setup(Vector3i(6, h + 3, 6), 0.4)
	for y in h:
		for z in 6:
			for x in 6:
				var edge := (x == 0 or x == 5) and (z == 0 or z == 5)
				var ring := y % 6 == 0 and (x == 0 or x == 5 or z == 0 or z == 5)
				if edge or ring:
					o.set_v(x, y, z, VoxelMat.METAL if not ring else VoxelMat.NEON_CYAN)
	o.fill_box(Vector3i(2, h - 6, 2), Vector3i(3, h - 3, 3), VoxelMat.EXPLOSIVE)
	o.fill_box(Vector3i(1, h, 1), Vector3i(4, h + 2, 4), VoxelMat.CRYSTAL)
	o.explode_on_break = true
	o.explode_radius = 6.0
	o.value_mult = 1.6
	return o


static func dome(rng: RandomNumberGenerator, r: int) -> VoxelObject:
	var o := VoxelObject.new()
	var size := r * 2 + 1
	o.setup(Vector3i(size, r + 1, size), 0.4)
	var c := Vector3(r + 0.5, 0.0, r + 0.5)
	for z in size:
		for y in r + 1:
			for x in size:
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var dd := p.distance_to(c)
				if dd <= r + 0.5 and dd > r - 0.7:
					var rib := (x % 4 == 0) or (y % 4 == 0)
					o.set_v(x, y, z, VoxelMat.METAL if rib else VoxelMat.GLASS)
	# вход
	o.fill_box(Vector3i(r - 1, 0, 0), Vector3i(r + 1, 3, 2), 0)
	o.fill_box(Vector3i(r - 2, 0, 0), Vector3i(r - 2, 4, 1), VoxelMat.NEON_CYAN)
	o.fill_box(Vector3i(r + 2, 0, 0), Vector3i(r + 2, 4, 1), VoxelMat.NEON_CYAN)
	o.value_mult = 1.4
	return o


static func antenna_dish(rng: RandomNumberGenerator) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(11, 16, 11), 0.35)
	o.fill_box(Vector3i(4, 0, 4), Vector3i(6, 8, 6), VoxelMat.METAL)
	var c := Vector3(5.5, 14.0, 5.5)
	for z in 11:
		for y in range(8, 16):
			for x in 11:
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var dd := p.distance_to(c)
				if dd > 5.0 and dd <= 6.0:
					o.set_v(x, y, z, VoxelMat.METAL if (x + z) % 3 != 0 else VoxelMat.NEON_PINK)
	o.fill_box(Vector3i(5, 9, 5), Vector3i(5, 13, 5), VoxelMat.NEON_CYAN)
	return o
