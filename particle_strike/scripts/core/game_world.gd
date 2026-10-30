class_name GameWorld
extends Node3D
## Корень игрового мира: системы частиц, объекты, враги, взрывы, комбо,
## замедление времени, гравивихрь, постройка стен, награды.

signal combo_changed(combo: int, mult: float)
signal notify(text: String, color: Color)
signal player_died
signal hit_marker(kill: bool)

const L_WORLD := 1
const L_DESTRUCT := 2
const L_PLAYER := 4
const L_ENEMY := 8
const L_CHUNK := 16
const L_BOUNDS := 32

const WALL_COST := 40
const MAX_WALLS := 3
const MAX_CHUNKS := 6

static var current: GameWorld = null

var location_id := "city"
var gravity := 20.0
var bounds := 60.0
var round_bounds := false
var debris: DebrisSystem
var shards: ShardSystem
var fx: FxSystem
var projectiles: ProjectileSystem
var player: Player
var director: WaveDirector
var env: WorldEnvironment
var sun: DirectionalLight3D
var objects: Array[VoxelObject] = []
var enemies: Array[Enemy] = []
var walls: Array[VoxelObject] = []

var combo := 0
var combo_timer := 0.0
var vortex_charge := 0.0
var stats := {"voxels": 0, "kills": 0, "particles": 0}
var shake := 0.0
var game_over := false

var _collapse_queue: Array[VoxelObject] = []
var _pending_explosions: Array = []
var _slowmo_left := 0.0
var _chunks := 0
var _vortex_active := false
var _vortex_pos := Vector3.ZERO
var _vortex_t := 0.0
var _vortex_tick := 0.0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null
	Engine.time_scale = 1.0


func init_systems(g: float) -> void:
	gravity = g
	debris = DebrisSystem.new()
	debris.name = "Debris"
	add_child(debris)
	debris.setup(int(Perf.get_value("debris")), g, 0.0)
	shards = ShardSystem.new()
	shards.name = "Shards"
	add_child(shards)
	shards.setup(400, g)
	fx = FxSystem.new()
	fx.name = "Fx"
	add_child(fx)
	projectiles = ProjectileSystem.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)


# ---------------------------------------------------------------- объекты

func add_object(obj: VoxelObject, pos: Vector3, rot_y: float = 0.0) -> VoxelObject:
	obj.position = pos
	obj.rotation.y = rot_y
	add_child(obj)
	obj.finalize()
	objects.append(obj)
	return obj


func unregister_object(obj: VoxelObject) -> void:
	objects.erase(obj)
	walls.erase(obj)
	_collapse_queue.erase(obj)


func objects_near(pos: Vector3, radius: float) -> Array[VoxelObject]:
	var out: Array[VoxelObject] = []
	for o: VoxelObject in objects:
		if is_instance_valid(o) and o.world_aabb.grow(radius).has_point(pos):
			out.append(o)
	return out


func point_blocked(pos: Vector3, margin: float = 0.5) -> bool:
	for o: VoxelObject in objects:
		if o.world_aabb.grow(margin).has_point(pos):
			return true
	return false


func request_collapse(obj: VoxelObject) -> void:
	if not _collapse_queue.has(obj):
		_collapse_queue.append(obj)


func spawn_falling_chunk(points: PackedVector3Array, cols: PackedColorArray, vs: float, value: float, explosive: bool) -> void:
	if _chunks >= MAX_CHUNKS:
		# слишком много падающих кусков — сразу рассыпаем в частицы
		var stride := maxi(1, points.size() / int(Perf.get_value("per_event")))
		for k in range(0, points.size(), stride):
			debris.spawn(points[k], Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), cols[k], vs * 0.9, false)
		on_voxels_destroyed(points.size(), value, points[0], false)
		return
	var ch := FallingChunk.new()
	ch.setup(points, cols, vs, value, explosive)
	add_child(ch)
	ch.start(gravity / 20.0)
	_chunks += 1
	ch.tree_exited.connect(_on_chunk_gone)
	if points.size() > 600:
		Sfx.play_at("crumble", ch.global_position, 4.0)


func _on_chunk_gone() -> void:
	_chunks = maxi(_chunks - 1, 0)


func on_chunk_impact(pos: Vector3, n: int, explosive: bool) -> void:
	var r := clampf(sqrt(float(n)) * 0.12, 1.2, 4.5)
	add_shake(clampf(float(n) / 1200.0, 0.15, 0.8) * _shake_falloff(pos))
	fx.ring(pos, r * 1.4, Color(0.8, 0.7, 0.6), 0.6)
	Sfx.play_at("crumble", pos, 2.0)
	if n > 60:
		# каскад: упавший кусок крушит всё, что под ним
		for obj: VoxelObject in objects_near(pos, r):
			obj.damage_sphere(pos, r, 0.8, WeaponData.Element.NONE, 5.0)
		for e: Enemy in enemies.duplicate():
			if e.is_alive() and e.center().distance_to(pos) < r + 1.0:
				e.take_damage(40.0 + n * 0.05, WeaponData.Element.NONE, Vector3.UP, pos)
		if player and player.global_position.distance_to(pos) < r:
			player.take_damage(15.0, pos)
	if explosive:
		schedule_explosion(pos, 5.0, 0.05)
	if n > 450:
		slowmo(0.5, 0.35)


# ---------------------------------------------------------------- лучи

func raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var dir := to - from
	var total := dir.length()
	if total < 0.0001:
		return {}
	dir /= total
	for attempt in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			return {}
		var col: Object = r["collider"]
		if col != null and col.has_meta("vobj"):
			var vo: VoxelObject = col.get_meta("vobj")
			var hp: Vector3 = r["position"]
			var start := hp - dir * 0.05
			var remaining := total - from.distance_to(start)
			var vh := vo.ray_voxel(start, dir, remaining)
			if not vh.is_empty():
				vh["collider"] = col
				return vh
			exclude.append(r["rid"])
			continue
		var out := {"position": r["position"], "normal": r["normal"], "collider": col, "object": null}
		if col is Enemy:
			out["enemy"] = col
		elif col is Player:
			out["player"] = true
		return out
	return {}


# ---------------------------------------------------------------- взрывы

func element_color(element: int) -> Color:
	match element:
		WeaponData.Element.ICE:
			return Color(0.5, 0.9, 1.0)
		WeaponData.Element.PLASMA:
			return Color(0.35, 1.0, 0.45)
		WeaponData.Element.ENERGY:
			return Color(0.35, 0.6, 1.0)
	return Color(1.0, 0.45, 0.15)


func explode(pos: Vector3, radius: float, damage: float, element: int, team: int, big_fx: bool = true) -> void:
	for obj: VoxelObject in objects_near(pos, radius):
		obj.damage_sphere(pos, radius, 1.0, element, 9.0 + radius)
	for e: Enemy in enemies.duplicate():
		if not e.is_alive():
			continue
		var d := e.center().distance_to(pos)
		if d < radius + e.hit_radius:
			var fall := 1.0 - clampf(d / (radius + e.hit_radius), 0.0, 1.0) * 0.6
			var dir := (e.center() - pos).normalized()
			e.take_damage(damage * fall, element, dir, pos)
			e.knockback(dir * 9.0 * fall + Vector3.UP * 4.0 * fall)
	if player and player.is_alive():
		var pd := player.global_position.distance_to(pos)
		if pd < radius + 0.6:
			var fall2 := 1.0 - clampf(pd / (radius + 0.6), 0.0, 1.0)
			var away := (player.global_position + Vector3.UP - pos).normalized()
			if team == 1:
				player.take_damage(damage * 0.45 * fall2, pos)
			elif team == 2:
				player.take_damage(damage * 0.2 * fall2, pos)
			# свои взрывы не ранят, но подбрасывают (ракетный прыжок)
			player.apply_impulse(away * 12.0 * fall2)
	var col := element_color(element)
	if big_fx:
		fx.explosion(pos, radius, col)
		Sfx.play_at("explosion", pos, -2.0 + radius)
	else:
		fx.flash(pos, radius * 0.9, col, 0.18)
		debris.burst(pos, 8, col, radius * 4.0, 0.14, true, 2.0)
		Sfx.play_at("hit", pos)
	add_shake(clampf(radius * 0.1, 0.05, 0.6) * _shake_falloff(pos))


func schedule_explosion(pos: Vector3, radius: float, delay: float) -> void:
	_pending_explosions.append([delay, pos, radius])


func _shake_falloff(pos: Vector3) -> float:
	if player == null:
		return 0.0
	return clampf(1.0 - player.global_position.distance_to(pos) / 45.0, 0.0, 1.0)


# ---------------------------------------------------------------- награды и комбо

func combo_mult() -> float:
	return 1.0 + minf(float(combo) / 150.0, 8.0) * 0.25


func on_voxels_destroyed(count: int, value: float, pos: Vector3, is_wall: bool) -> void:
	if is_wall or game_over:
		return
	stats["voxels"] = int(stats["voxels"]) + count
	combo += count
	combo_timer = 2.5
	combo_changed.emit(combo, combo_mult())
	add_vortex_charge(float(count) * 0.0011)
	var total := int(value * 0.22 * combo_mult())
	if total > 0:
		shards.spray(pos, total, clampi(total / 4, 1, 14))
	if count > 350:
		slowmo(0.4, 0.4)


func on_enemy_killed(e: Enemy) -> void:
	stats["kills"] = int(stats["kills"]) + 1
	combo += 40
	combo_timer = 2.5
	combo_changed.emit(combo, combo_mult())
	add_vortex_charge(0.05)
	shards.spray(e.center(), int(e.reward * combo_mult()), 6)
	if randf() < 0.3:
		shards.spawn(e.center(), Vector3(randf_range(-2, 2), 6, randf_range(-2, 2)), 15, ShardSystem.Kind.HEALTH)
	hit_marker.emit(true)
	if director:
		director.on_enemy_killed(e)


func add_vortex_charge(v: float) -> void:
	vortex_charge = minf(vortex_charge + v * (1.0 + 0.2 * GameState.upgrade_level("vortex")), 1.0)


func _collect(kind: int, amount: int) -> void:
	match kind:
		ShardSystem.Kind.ENERGY:
			GameState.add_particles(amount)
			stats["particles"] = int(stats["particles"]) + amount
			Sfx.play("pickup", -8.0, 0.15)
		ShardSystem.Kind.HEALTH:
			if player:
				player.heal(float(amount))
			Sfx.play("pickup", -4.0, 0.0)
		ShardSystem.Kind.CORE:
			add_vortex_charge(0.1)


# ---------------------------------------------------------------- время, тряска

func slowmo(duration: float, scale: float) -> void:
	if not bool(GameState.get_setting("slowmo", true)):
		return
	Engine.time_scale = minf(Engine.time_scale, scale)
	_slowmo_left = maxf(_slowmo_left, duration)


func add_shake(amount: float) -> void:
	shake = minf(shake + amount * float(GameState.get_setting("shake", 1.0)), 1.0)


# ---------------------------------------------------------------- способности

func build_wall(pos: Vector3, yaw: float) -> bool:
	if not GameState.spend(WALL_COST):
		notify.emit("Нужно %d частиц" % WALL_COST, Color(1, 0.4, 0.3))
		return false
	if walls.size() >= MAX_WALLS:
		crumble(walls[0])
	var w := VoxelObject.new()
	w.setup(Vector3i(11, 8, 2), 0.4)
	w.fill_box(Vector3i(0, 0, 0), Vector3i(10, 7, 1), VoxelMat.BUILD)
	w.is_player_wall = true
	w.casts_shadow = false
	var wb := Basis(Vector3.UP, yaw)
	var origin := Vector3(pos.x, 0.0, pos.z) - wb * Vector3(2.2, 0.0, 0.4)
	add_object(w, origin, yaw)
	walls.append(w)
	w.play_build_anim(0.45)
	fx.ring(Vector3(pos.x, 0.1, pos.z), 3.0, Color(0.3, 0.95, 1.0), 0.4)
	Sfx.play("build")
	return true


func crumble(obj: VoxelObject) -> void:
	if not is_instance_valid(obj):
		return
	var list := PackedInt32Array()
	for i in obj.grid.size():
		if obj.grid[i] != 0:
			list.push_back(i)
	obj._remove_list(list, obj.center_world(), 3.0, true, false)


func use_vortex(pos: Vector3) -> bool:
	if vortex_charge < 1.0 or _vortex_active:
		return false
	vortex_charge = 0.0
	_vortex_active = true
	_vortex_pos = pos + Vector3.UP * 1.2
	_vortex_t = 0.0
	Sfx.play("vortex")
	notify.emit("ГРАВИВИХРЬ!", Color(0.7, 0.4, 1.0))
	return true


func _update_vortex(delta: float) -> void:
	_vortex_t += delta
	_vortex_tick += delta
	var r := lerpf(1.5, 4.5, clampf(_vortex_t / 2.0, 0.0, 1.0))
	if _vortex_tick >= 0.1:
		_vortex_tick = 0.0
		# частицы и обломки затягиваются внутрь (отрицательный импульс)
		for obj: VoxelObject in objects_near(_vortex_pos, r):
			obj.damage_sphere(_vortex_pos, r, 1.0, WeaponData.Element.NONE, -10.0)
		for e: Enemy in enemies.duplicate():
			if e.is_alive():
				var to := _vortex_pos - e.center()
				var d := to.length()
				if d < 14.0:
					e.knockback(to.normalized() * clampf(16.0 - d, 2.0, 12.0))
					e.take_damage(4.0, WeaponData.Element.PLASMA, to.normalized(), _vortex_pos)
		for k in 10:
			var a := randf() * TAU
			var off := Vector3(cos(a), randf_range(-0.4, 0.8), sin(a)) * randf_range(3.0, 7.0)
			var tang := Vector3(-sin(a), 0, cos(a)) * 6.0
			debris.spawn(_vortex_pos + off, -off * 1.3 + tang + Vector3.UP * 4.0, Color(0.7, 0.4, 1.0), 0.2, true)
		fx.flash(_vortex_pos, r * 0.6, Color(0.55, 0.25, 1.0), 0.15)
	if _vortex_t >= 2.2:
		_vortex_active = false
		explode(_vortex_pos, 6.0, 180.0, WeaponData.Element.PLASMA, 0)
		fx.ring(_vortex_pos, 9.0, Color(0.7, 0.4, 1.0), 0.7)
		slowmo(0.6, 0.3)


# ---------------------------------------------------------------- цикл

func _process(delta: float) -> void:
	# замедление времени считается по реальному времени
	if _slowmo_left > 0.0:
		var real := delta / maxf(Engine.time_scale, 0.05)
		_slowmo_left -= real
		if _slowmo_left <= 0.0:
			Engine.time_scale = 1.0
		else:
			Engine.time_scale = lerpf(Engine.time_scale, 1.0, real * 0.5)
	var n := 0
	while n < 2 and not _collapse_queue.is_empty():
		var obj: VoxelObject = _collapse_queue.pop_front()
		if is_instance_valid(obj):
			obj.check_collapse()
		n += 1
	if not _pending_explosions.is_empty():
		for i in range(_pending_explosions.size() - 1, -1, -1):
			var pe: Array = _pending_explosions[i]
			pe[0] = float(pe[0]) - delta
			if float(pe[0]) <= 0.0:
				_pending_explosions.remove_at(i)
				explode(pe[1], pe[2], 140.0, WeaponData.Element.EXPLOSIVE, 2)
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(0, 1.0)
	if _vortex_active:
		_update_vortex(delta)
	if player:
		shards.update(delta, player.global_position, player.magnet_radius(), _collect)
	shake = maxf(shake - delta * 1.6, 0.0)


func on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if director:
		GameState.report_wave(location_id, director.wave)
	GameState.save_game()
	player_died.emit()
