class_name ProjectileSystem
extends Node3D
## Все снаряды игрока и врагов. Столкновения — лучом между позициями кадра
## (без пропусков на высокой скорости). Визуал — пул светящихся сфер.

const MAX_PROJ := 160

class Proj:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var life := 0.0
	var kind := "bolt"
	var team := 0
	var damage := 0.0
	var radius := 0.5
	var element := 0
	var color := Color.WHITE
	var node: MeshInstance3D
	var eaten := 0
	var gravity := 0.0
	var trail_t := 0.0
	var size := 0.12
	var stretch := 4.0
	var hit_ids := {}

var _active: Array[Proj] = []
var _pool: Array[MeshInstance3D] = []
var _sphere: SphereMesh
var _mats := {}


func _ready() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 10
	_sphere.rings = 5


func _material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * 1.8, c.g * 1.8, c.b * 1.8)
	_mats[key] = m
	return m


func _acquire_node(c: Color) -> MeshInstance3D:
	var n: MeshInstance3D
	if _pool.is_empty():
		n = MeshInstance3D.new()
		n.mesh = _sphere
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
	else:
		n = _pool.pop_back()
	n.material_override = _material(c)
	n.visible = true
	return n


func _release(i: int) -> void:
	var p := _active[i]
	p.node.visible = false
	_pool.append(p.node)
	_active[i] = _active[_active.size() - 1]
	_active.pop_back()


func spawn(kind: String, team: int, pos: Vector3, vel: Vector3, damage: float, radius: float, element: int, color: Color) -> Proj:
	if _active.size() >= MAX_PROJ:
		_release(0)
	var p := Proj.new()
	p.kind = kind
	p.team = team
	p.pos = pos
	p.vel = vel
	p.damage = damage
	p.radius = radius
	p.element = element
	p.color = color
	p.life = 3.0
	match kind:
		"rocket":
			p.size = 0.2
			p.stretch = 3.0
			p.life = 4.0
		"plasma":
			p.size = 0.55
			p.stretch = 1.0
			p.life = 3.2
		"frag":
			p.size = 0.1
			p.stretch = 2.5
			p.gravity = 18.0
			p.life = 1.4
		"enemy_orb":
			p.size = 0.28
			p.stretch = 1.3
			p.life = 5.0
		"spit":
			p.size = 0.32
			p.stretch = 1.6
			p.life = 4.0
		"big_spit":
			p.size = 0.95
			p.stretch = 1.35
			p.life = 5.0
		_:
			p.size = 0.09 if element != WeaponData.Element.ICE else 0.12
			p.stretch = 6.0
	p.node = _acquire_node(color)
	_place(p)
	_active.append(p)
	return p


func _place(p: Proj) -> void:
	var sp := p.vel.length()
	if sp > 0.1 and p.stretch > 1.01:
		var d := p.vel / sp
		var up := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
		p.node.global_transform = Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(p.size, p.size, p.size * p.stretch)), p.pos)
	else:
		p.node.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * p.size), p.pos)


func clear_all() -> void:
	for i in range(_active.size() - 1, -1, -1):
		_release(i)


func _physics_process(delta: float) -> void:
	var gw := GameWorld.current
	if gw == null:
		return
	for i in range(_active.size() - 1, -1, -1):
		var p := _active[i]
		p.life -= delta
		p.vel.y -= p.gravity * delta
		var next := p.pos + p.vel * delta
		var done := false
		if p.kind == "plasma":
			done = _update_plasma(gw, p, next)
		else:
			var mask := GameWorld.L_WORLD | GameWorld.L_DESTRUCT
			mask |= GameWorld.L_ENEMY if p.team == 0 else GameWorld.L_PLAYER
			var hit := gw.raycast(p.pos, next, mask)
			if p.team == 0 and hit.get("enemy") == null:
				# неконтактный взрыватель / «толстый» луч: прощает промах на сенсорном экране
				var seg_end: Vector3 = next if hit.is_empty() else hit["position"]
				var near := _proximity_enemy(gw, p.pos, seg_end, _proximity(p))
				if near:
					hit = {"position": near.center() - p.vel.normalized() * near.hit_radius * 0.5, "enemy": near, "normal": -p.vel.normalized(), "object": null}
			elif p.team == 1 and hit.is_empty() and gw.player and gw.player.is_alive():
				# снаряды врагов чуть «толще» — от плевков надо уворачиваться, а не проскальзывать
				var pc := gw.player.global_position + Vector3.UP * 0.9
				var ab := next - p.pos
				var tt := clampf((pc - p.pos).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var pr := 0.85 if p.kind == "big_spit" else 0.4
				if pc.distance_to(p.pos + ab * tt) < 0.4 + pr:
					hit = {"position": p.pos + ab * tt, "player": true, "normal": -p.vel.normalized(), "object": null}
			if not hit.is_empty():
				_impact(gw, p, hit)
				done = true
		if not done:
			p.pos = next
			if p.life <= 0.0:
				if p.kind == "rocket" or p.kind == "frag":
					gw.explode(p.pos, p.radius, p.damage, WeaponData.Element.EXPLOSIVE, p.team)
				done = true
		if done:
			_release(i)
			continue
		_place(p)
		if p.kind == "rocket":
			p.vel *= 1.0 + delta * 0.8
			p.trail_t += delta
			if p.trail_t > 0.02:
				p.trail_t = 0.0
				gw.debris.spawn(p.pos - p.vel.normalized() * 0.4, Vector3(randf_range(-1, 1), randf_range(0, 1.5), randf_range(-1, 1)), Color(1.0, 0.5, 0.2), 0.021, true)
		elif p.kind == "spit" or p.kind == "big_spit":
			# капли слюны срываются с летящего плевка; размер «дрожит»
			p.trail_t += delta
			if p.trail_t > (0.03 if p.kind == "big_spit" else 0.07):
				p.trail_t = 0.0
				gw.debris.spawn(p.pos, p.vel * 0.15 + Vector3(randf_range(-0.6, 0.6), -1.0, randf_range(-0.6, 0.6)), p.color, 0.02 if p.kind == "spit" else 0.035, false)
			p.node.scale *= 1.0 + 0.12 * sin(p.life * 40.0)


func _proximity(p: Proj) -> float:
	match p.kind:
		"rocket":
			return 1.1
		"frag":
			return 0.5
	return 0.3


func _proximity_enemy(gw: GameWorld, a: Vector3, b: Vector3, extra: float) -> Enemy:
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	var best: Enemy = null
	var best_t := 2.0
	for e: Enemy in gw.enemies:
		if not e.is_alive():
			continue
		var c := e.center()
		var t := clampf((c - a).dot(ab) / l2, 0.0, 1.0)
		var r := e.hit_radius + extra
		if c.distance_squared_to(a + ab * t) < r * r and t < best_t:
			best_t = t
			best = e
	return best


func _update_plasma(gw: GameWorld, p: Proj, next: Vector3) -> bool:
	# плазма проедает частицы на всём пути и не останавливается
	if p.eaten < 1400:
		for obj: VoxelObject in gw.objects_near(next, p.radius):
			p.eaten += obj.damage_sphere(next, p.radius, 1.0, WeaponData.Element.PLASMA, 3.0)
	for e: Enemy in gw.enemies.duplicate():
		if not e.is_alive():
			continue
		var id := e.get_instance_id()
		if p.hit_ids.has(id):
			continue
		if e.center().distance_to(next) < p.radius + e.hit_radius:
			p.hit_ids[id] = true
			e.take_damage(p.damage, WeaponData.Element.PLASMA, p.vel.normalized(), next)
	if next.y < 0.25 or p.life <= 0.0:
		gw.explode(next, p.radius * 1.8, p.damage, WeaponData.Element.PLASMA, p.team)
		return true
	p.pos = next
	if randf() < 0.5:
		gw.debris.spawn(next, Vector3(randf_range(-2, 2), randf_range(-1, 2), randf_range(-2, 2)), p.color, 0.017, false)
	return false


func _impact(gw: GameWorld, p: Proj, hit: Dictionary) -> void:
	var hp: Vector3 = hit["position"]
	var dir := p.vel.normalized()
	var enemy: Enemy = hit.get("enemy")
	var obj: VoxelObject = hit.get("object")
	match p.kind:
		"rocket":
			gw.explode(hp, p.radius, p.damage, WeaponData.Element.EXPLOSIVE, p.team)
			var n: Vector3 = hit.get("normal", Vector3.UP)
			for k in 6:
				var d := (n + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))).normalized()
				spawn("frag", p.team, hp + n * 0.4, d * randf_range(12, 20), p.damage * 0.22, 1.1, WeaponData.Element.EXPLOSIVE, Color(1.0, 0.6, 0.2))
		"frag":
			gw.explode(hp, p.radius, p.damage, WeaponData.Element.EXPLOSIVE, p.team)
		"enemy_orb":
			if bool(hit.get("player", false)):
				gw.player.take_damage(p.damage, p.pos)
			elif obj:
				obj.damage_sphere(hp, 0.7, 0.3, WeaponData.Element.NONE, 4.0)
			gw.fx.flash(hp, 0.6, p.color, 0.15)
		"spit":
			var on_player := bool(hit.get("player", false))
			if on_player:
				gw.player.take_damage(p.damage, p.pos)
				gw.player.apply_slime(1.8)
			elif obj:
				obj.damage_sphere(hp, 0.35, 0.5, WeaponData.Element.NONE, 2.0)
			gw.splat(hp, 1.0, on_player)
		"big_spit":
			gw.big_splat(hp, p.damage)
		_:
			if p.element == WeaponData.Element.EXPLOSIVE:
				gw.explode(hp, p.radius, p.damage, WeaponData.Element.EXPLOSIVE, p.team, false)
				return
			if enemy:
				enemy.take_damage(p.damage, p.element, dir, hp)
				if p.element == WeaponData.Element.ENERGY and randf() < 0.3:
					_chain(gw, enemy, p.damage * 0.7, p.color)
			elif obj:
				obj.damage_sphere(hp, p.radius, clampf(p.damage / 60.0, 0.2, 1.0), p.element, 6.0)
			gw.fx.flash(hp, 0.35 + p.radius * 0.25, p.color, 0.1)
			gw.debris.burst(hp, 20, p.color, 5.0, 0.016, false, 1.0)


func _chain(gw: GameWorld, from_enemy: Enemy, dmg: float, color: Color) -> void:
	## Цепная молния: перескакивает на ближайшего врага.
	var best: Enemy = null
	var best_d := 8.0
	for e: Enemy in gw.enemies.duplicate():
		if e == from_enemy or not e.is_alive():
			continue
		var d := e.center().distance_to(from_enemy.center())
		if d < best_d:
			best_d = d
			best = e
	if best:
		gw.fx.lightning(from_enemy.center(), best.center(), Color(0.6, 0.85, 1.0))
		best.take_damage(dmg, WeaponData.Element.ENERGY, (best.center() - from_enemy.center()).normalized(), best.center())


func fire_laser(from: Vector3, dir: Vector3, damage: float, radius: float, pierce_m: float, color: Color) -> Vector3:
	var gw := GameWorld.current
	var to := from + dir * 260.0
	var end := to
	var hit := gw.raycast(from, to, GameWorld.L_WORLD | GameWorld.L_DESTRUCT)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		var obj: VoxelObject = hit.get("object")
		if obj:
			var pierce_len := pierce_m
			end = hp + dir * pierce_len
			obj.carve_segment(hp - dir * 0.2, end, radius)
			# пробитие: следующий объект за первым
			var hit2 := gw.raycast(end, end + dir * 40.0, GameWorld.L_DESTRUCT)
			if not hit2.is_empty():
				var obj2: VoxelObject = hit2.get("object")
				if obj2 and obj2 != obj:
					var hp2: Vector3 = hit2["position"]
					obj2.carve_segment(hp2 - dir * 0.2, hp2 + dir * pierce_len * 0.5, radius * 0.8)
		else:
			end = hp
		gw.fx.flash(hp, 0.9, color, 0.2)
		gw.debris.burst(hp, 72, color, 7.0, 0.017, true, 1.5)
	for e: Enemy in gw.enemies.duplicate():
		if not e.is_alive():
			continue
		var c := e.center()
		var seg := end - from
		var t := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if c.distance_to(from + seg * t) < e.hit_radius + 0.3:
			e.take_damage(damage, WeaponData.Element.LASER, dir, c)
	gw.fx.beam(from, end, color, 0.16, 0.22)
	gw.fx.beam(from, end, Color(1, 1, 1), 0.05, 0.12)
	return end
