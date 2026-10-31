class_name VoxelShapes
## Процедурные генераторы разрушаемых объектов города.
## Размеры задаются в метрах; логическая ячейка — 25 см и мельче,
## шейдер дробит её на видимые частицы по 5 см.
## Все функции возвращают VoxelObject с заполненной сеткой (finalize вызывает GameWorld.add_object).

const BUILDING_VS := 0.25


static func _hash(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) % 1000


static func skyscraper(rng: RandomNumberGenerator, w_m: float, d_m: float, h_m: float, neon_mat: int) -> VoxelObject:
	var vs := BUILDING_VS
	var w := int(round(w_m / vs))
	var d := int(round(d_m / vs))
	var h := int(round(h_m / vs))
	var floor_h := int(round(3.0 / vs))      # этаж 3 м
	var pitch := int(round(1.5 / vs))        # шаг окон 1.5 м
	var win := int(round(1.0 / vs))          # ширина окна 1 м
	var o := VoxelObject.new()
	o.setup(Vector3i(w, h + int(round(4.0 / vs)), d), vs)
	var seed_v := rng.randi() % 1000
	var neon_every := rng.randi_range(3, 5)
	for y in h:
		var fy := y % floor_h
		var level := y / floor_h
		var is_neon := level > 0 and level % neon_every == 0 and fy == 0
		for z in d:
			for x in w:
				var ex := x == 0 or x == w - 1
				var ez := z == 0 or z == d - 1
				if not (ex or ez):
					continue
				var m: int = VoxelMat.CONCRETE
				if is_neon:
					m = neon_mat
				elif not (ex and ez) and fy >= 3 and fy <= 8:
					var along := x if ez else z
					var span := w if ez else d
					var col := along % pitch
					if along > 1 and along < span - 2 and col >= 1 and col <= win:
						var cell := _hash(along / pitch + seed_v, level, 1 if ex else 2)
						m = VoxelMat.WINDOW_DARK if cell < 330 else VoxelMat.GLASS
				o.set_v(x, y, z, m)
		# перекрытия каждые 3 этажа — здание не пустая коробка и красиво рушится
		if y > 0 and y % (floor_h * 3) == 0:
			o.fill_box(Vector3i(1, y, 1), Vector3i(w - 2, y, d - 2), VoxelMat.CONCRETE)
	o.fill_box(Vector3i(0, h, 0), Vector3i(w - 1, h, d - 1), VoxelMat.CONCRETE)
	# неоновый парапет
	for x in w:
		o.set_v(x, h + 1, 0, neon_mat)
		o.set_v(x, h + 1, d - 1, neon_mat)
	for z in d:
		o.set_v(0, h + 1, z, neon_mat)
		o.set_v(w - 1, h + 1, z, neon_mat)
	# антенна
	var ax := w / 2
	var az := d / 2
	var top := o.dims.y - 1
	o.fill_box(Vector3i(ax - 2, h + 1, az - 2), Vector3i(ax + 1, h + 3, az + 1), VoxelMat.METAL)
	o.fill_box(Vector3i(ax, h + 4, az), Vector3i(ax, top - 1, az), VoxelMat.METAL)
	o.set_v(ax, top, az, VoxelMat.NEON_PINK)
	return o


static func street_lamp(color_mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(5, 18, 2), 0.25)
	o.fill_box(Vector3i(0, 0, 0), Vector3i(1, 15, 1), VoxelMat.METAL)
	o.fill_box(Vector3i(0, 15, 0), Vector3i(4, 16, 1), VoxelMat.METAL)
	o.fill_box(Vector3i(3, 14, 0), Vector3i(4, 14, 1), color_mat)
	o.upsample(2)
	o.casts_shadow = false
	return o


static func car(rng: RandomNumberGenerator) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(11, 5, 6), 0.4)
	var body: int = [VoxelMat.METAL, VoxelMat.CONCRETE, VoxelMat.RUST][rng.randi() % 3]
	o.fill_box(Vector3i(0, 1, 0), Vector3i(10, 2, 5), body)
	o.fill_box(Vector3i(2, 3, 0), Vector3i(8, 4, 5), VoxelMat.GLASS)
	o.fill_box(Vector3i(3, 4, 1), Vector3i(7, 4, 4), body)
	for wx in [1, 9]:
		for wz in [0, 5]:
			o.set_v(wx, 0, wz, VoxelMat.ASTEROID)
			o.set_v(wx + 1, 0, wz, VoxelMat.ASTEROID)
	# бензобак — взрывоопасные частицы
	o.fill_box(Vector3i(4, 1, 2), Vector3i(6, 2, 3), VoxelMat.EXPLOSIVE)
	o.set_v(0, 2, 1, VoxelMat.NEON_CYAN)
	o.set_v(0, 2, 4, VoxelMat.NEON_CYAN)
	o.set_v(10, 2, 1, VoxelMat.EXPLOSIVE)
	o.set_v(10, 2, 4, VoxelMat.EXPLOSIVE)
	o.upsample(2)
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
	o.upsample(2)
	o.explode_on_break = true
	o.explode_radius = 4.5
	o.value_mult = 2.0
	o.casts_shadow = false
	return o


static func crate(mat: int) -> VoxelObject:
	var o := VoxelObject.new()
	o.setup(Vector3i(4, 4, 4), 0.3)
	o.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), mat)
	o.upsample(2)
	o.casts_shadow = false
	return o


static func tree(rng: RandomNumberGenerator) -> VoxelObject:
	## Дерево в сквере: ствол + крона-оболочка (горит!).
	var o := VoxelObject.new()
	var th := rng.randi_range(6, 9)
	var r := rng.randf_range(3.6, 4.6)
	var size := int(ceil(r * 2.0)) + 3
	var c := size / 2
	o.setup(Vector3i(size, th + int(r * 2.0) + 2, size), 0.3)
	o.fill_box(Vector3i(c - 1, 0, c - 1), Vector3i(c, th + 2, c), VoxelMat.TRUNK)
	var center := Vector3(c, th + r * 0.8, c)
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.05
	o.fill_sphere(center, r, VoxelMat.LEAVES, nz, 1.0)
	o.fill_sphere(center, r - 1.7, 0)
	o.fill_box(Vector3i(c - 1, th, c - 1), Vector3i(c, th + 3, c), VoxelMat.TRUNK)
	o.upsample(2)
	return o
