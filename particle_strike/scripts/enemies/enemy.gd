class_name Enemy
extends CharacterBody3D
## Враги из частиц. Типы: Рой (ближний бой), Стрелок (держит дистанцию),
## Громила (проламывает стены, удар-волна), Дрон (летает, стреляет сверху),
## Колосс (босс каждые 5 волн), Света Салеева (босс-плевальщица).
## Статусы: заморозка, горение, отбрасывание.

signal died(e: Enemy)

const TYPES := {
	"swarmer": {"name": "Рой", "hp": 34.0, "speed": 8.0, "damage": 7.0, "reward": 8,
		"color": Color(0.45, 0.15, 0.75), "glow": Color(1.0, 0.3, 0.9), "radius": 0.5, "height": 0.9, "scale": 1.0},
	"shooter": {"name": "Стрелок", "hp": 70.0, "speed": 4.8, "damage": 10.0, "reward": 14,
		"color": Color(0.55, 0.1, 0.14), "glow": Color(1.0, 0.35, 0.25), "radius": 0.45, "height": 1.8, "scale": 1.0},
	"brute": {"name": "Громила", "hp": 290.0, "speed": 3.6, "damage": 26.0, "reward": 40,
		"color": Color(0.45, 0.25, 0.1), "glow": Color(1.0, 0.6, 0.15), "radius": 0.85, "height": 2.9, "scale": 1.6},
	"drone": {"name": "Дрон", "hp": 45.0, "speed": 7.5, "damage": 8.0, "reward": 16,
		"color": Color(0.12, 0.3, 0.45), "glow": Color(0.3, 0.95, 1.0), "radius": 0.6, "height": 1.2, "scale": 1.0},
	"boss": {"name": "Колосс", "hp": 1900.0, "speed": 3.2, "damage": 40.0, "reward": 450,
		"color": Color(0.3, 0.08, 0.3), "glow": Color(1.0, 0.2, 0.5), "radius": 1.4, "height": 4.6, "scale": 2.5},
	"sveta": {"name": "Света Салеева", "hp": 4000.0, "speed": 2.9, "damage": 30.0, "reward": 300,
		"color": Color(0.85, 0.3, 0.6), "glow": Color(0.5, 1.0, 0.85), "radius": 1.6, "height": 5.8, "scale": 3.2,
		"boss": true},
}

var gw: GameWorld
var type := "swarmer"
var def: Dictionary
var hp := 10.0
var max_hp := 10.0
var hit_radius := 0.6
var height := 1.8
var reward := 10
var body_root: Node3D
var rig: VoxelRig
var state := "spawn"
var spawn_t := 0.0
var attack_cd := 1.5
var windup := 0.0
var freeze := 0.0
var frozen_t := 0.0
var burn_t := 0.0
var knock := Vector3.ZERO
var flash := 0.0
var anim_t := 0.0
var recoil := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var stuck_t := 0.0
var avoid_t := 0.0
var avoid_dir := Vector3.ZERO
var smash_t := 0.0
var orbit_a := 0.0
var flying := false
var is_boss := false
# Света Салеева: очереди плевков, заряженный плевок, «слюнявый дождь», ярость
var spit_left := 0
var spit_t := 0.0
var spit_mode := ""
var spit_windup := 0.0
var mouth_open := 0.0
var phase2 := false
var rain_targets: Array[Vector3] = []
const SPIT_COLOR := Color(0.55, 1.0, 0.85)
const SPIT_WINDUP := 0.7


func setup(world: GameWorld, enemy_type: String, hp_mult: float) -> void:
	gw = world
	type = enemy_type
	def = TYPES[type]
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	hit_radius = float(def["radius"])
	height = float(def["height"])
	reward = int(def["reward"])
	flying = type == "drone"
	is_boss = type == "boss" or bool(def.get("boss", false))
	collision_layer = GameWorld.L_ENEMY
	collision_mask = GameWorld.L_WORLD | GameWorld.L_DESTRUCT | GameWorld.L_BOUNDS | GameWorld.L_ENEMY | GameWorld.L_PLAYER
	if flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	if type == "swarmer" or flying:
		var sph := SphereShape3D.new()
		sph.radius = hit_radius
		cs.shape = sph
		cs.position.y = 0.0 if flying else hit_radius
	else:
		var cap := CapsuleShape3D.new()
		cap.radius = hit_radius
		cap.height = maxf(height, hit_radius * 2.0 + 0.1)
		cs.shape = cap
		cs.position.y = height * 0.5
	add_child(cs)

	body_root = Node3D.new()
	add_child(body_root)
	var col: Color = def["color"]
	var glow: Color = def["glow"]
	match type:
		"swarmer":
			rig = VoxelRig.build_crawler(col, glow, 0.1)
		"drone":
			rig = VoxelRig.build_drone(col, glow, 0.1)
		"sveta":
			rig = _build_sveta(col, float(def["scale"]))
		_:
			var sc := float(def["scale"])
			rig = VoxelRig.build_humanoid(col, col.lightened(0.25), glow, sc, 0.09 * sc)
			if type == "shooter" or type == "boss":
				VoxelRig.build_gun(rig, "arm_r", glow, "plasma", -0.58 * sc)
	body_root.add_child(rig)
	body_root.scale = Vector3.ONE * 0.05
	if is_boss:
		var label := Label3D.new()
		label.text = String(def["name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 40
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.outline_size = 10
		label.modulate = Color(1.0, 0.65, 0.85)
		label.position = Vector3(0, height + 0.9, 0)
		add_child(label)
	orbit_a = randf() * TAU
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	attack_cd = randf_range(1.0, 2.0)


func _build_sveta(col: Color, s: float) -> VoxelRig:
	## Модель Светы: длинные светлые волосы, платье, светящийся «слюнявый» рот.
	var r := VoxelRig.build_humanoid(col, Color(0.98, 0.78, 0.82), Color(0.4, 0.85, 1.0), s, 0.09 * s)
	var hair := Color(0.92, 0.74, 0.4, 0.12)
	r.add_part("hair", "head", Vector3.ZERO, [
		[Vector3(-0.19, 0.24, -0.2) * s, Vector3(0.19, 0.38, 0.17) * s, hair],
		[Vector3(-0.21, -0.02, -0.21) * s, Vector3(-0.15, 0.3, 0.12) * s, hair],
		[Vector3(0.15, -0.02, -0.21) * s, Vector3(0.21, 0.3, 0.12) * s, hair],
		[Vector3(-0.19, -0.6, -0.25) * s, Vector3(0.19, 0.26, -0.15) * s, hair],
	])
	r.add_part("mouth", "head", Vector3(0, 0.07 * s, 0.17 * s), [
		[Vector3(-0.07, -0.03, -0.01) * s, Vector3(0.07, 0.03, 0.04) * s, Color(SPIT_COLOR.r, SPIT_COLOR.g, SPIT_COLOR.b, 1.0)],
	], false)
	r.add_part("dress", "hips", Vector3.ZERO, [
		[Vector3(-0.32, -0.55, -0.25) * s, Vector3(0.32, 0.12, 0.25) * s, Color(col.r, col.g, col.b, 0.3)],
		[Vector3(-0.34, -0.6, -0.27) * s, Vector3(0.34, -0.5, 0.27) * s, Color(1.0, 0.7, 0.9, 0.8)],
	])
	return r


func _mouth_pos() -> Vector3:
	var m := rig.part("mouth")
	if m:
		return m.global_position + body_root.global_transform.basis.z.normalized() * 0.5
	return center() + Vector3.UP * height * 0.4


func _spit_at(target: Vector3, kind: String, flight_t: float, dmg: float) -> void:
	## Баллистический плевок: подбираем скорость, чтобы попасть в точку с учётом гравитации.
	var from := _mouth_pos()
	var g := 14.0
	var d := target - from
	var t := flight_t if flight_t > 0.0 else clampf(Vector2(d.x, d.z).length() / 20.0, 0.45, 1.6)
	var v := d / t + Vector3(0.0, 0.5 * g * t, 0.0)
	# снаряд темнее капель: иначе слюна светится, как плазма
	var p := gw.projectiles.spawn(kind, 1, from, v, dmg, 1.0 if kind == "spit" else 3.2, WeaponData.Element.NONE, Color(0.33, 0.62, 0.52))
	p.gravity = g
	mouth_open = 1.6
	Sfx.play_at("spit", from, -3.0)


func _sveta_ai(delta: float, pl: Player, dist: float, dir_flat: Vector3) -> Vector3:
	var speed := float(def["speed"]) * (1.3 if phase2 else 1.0)
	if not phase2 and hp < max_hp * 0.5:
		phase2 = true
		rig.set_tint(Color(1.0, 0.25, 0.45, 0.22))
		gw.notify.emit("СВЕТА САЛЕЕВА В ЯРОСТИ!", Color(1.0, 0.45, 0.65))
		gw.slowmo(0.5, 0.4)
		Sfx.play_at("vortex", center())
		attack_cd = 0.6
	var cd_mult := 0.65 if phase2 else 1.0
	mouth_open = maxf(mouth_open - delta * 3.0, 0.0)
	# очередь плевков / дождь
	if spit_left > 0:
		spit_t -= delta
		if spit_t <= 0.0:
			spit_t = 0.09 if phase2 else 0.13
			spit_left -= 1
			if spit_mode == "rain" and not rain_targets.is_empty():
				_spit_at(rain_targets.pop_back(), "spit", 1.25, float(def["damage"]) * 0.3)
			else:
				var lead := pl.global_position + Vector3.UP + pl.velocity * 0.45
				lead += Vector3(randf_range(-1.2, 1.2), randf_range(-0.3, 0.6), randf_range(-1.2, 1.2))
				_spit_at(lead, "spit", -1.0, float(def["damage"]) * 0.35)
		return Vector3.ZERO
	# заряженный плевок: голова назад, рот раскрывается
	if spit_windup > 0.0:
		spit_windup -= delta
		mouth_open = 1.0 + (SPIT_WINDUP - spit_windup) * 1.5
		if spit_windup <= 0.0:
			_spit_at(pl.global_position + Vector3.UP * 0.4 + pl.velocity * 0.5, "big_spit", -1.0, float(def["damage"]))
		return Vector3.ZERO
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_slam()
		return Vector3.ZERO
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(2.0, 3.5)
		strafe_dir = -strafe_dir
	var side := dir_flat.cross(Vector3.UP) * strafe_dir
	var want := side * speed * 0.6
	if dist > 18.0:
		want = dir_flat * speed
	elif dist < 8.0:
		want = -dir_flat * speed * 0.6 + side * speed * 0.5
	if attack_cd <= 0.0 and dist < 55.0:
		if dist < 5.0:
			windup = 0.65
			attack_cd = 2.0 * cd_mult
		else:
			var r := randf()
			if r < 0.55:
				spit_mode = "volley"
				spit_left = 8 if phase2 else 6
				spit_t = 0.0
				attack_cd = 2.4 * cd_mult
			elif r < 0.8:
				spit_windup = SPIT_WINDUP
				attack_cd = 3.0 * cd_mult
				Sfx.play_at("hurt", center(), 2.0)
			else:
				spit_mode = "rain"
				spit_left = 12 if phase2 else 9
				spit_t = 0.25
				attack_cd = 3.4 * cd_mult
				rain_targets.clear()
				for k in spit_left:
					var a := randf() * TAU
					var rr := randf_range(0.5, 7.0)
					var tp := Vector3(pl.global_position.x + cos(a) * rr, 0.1, pl.global_position.z + sin(a) * rr)
					rain_targets.append(tp)
					gw.fx.ring(tp, 1.1, SPIT_COLOR, 1.4)
				gw.notify.emit("СЛЮНЯВЫЙ ДОЖДЬ!", SPIT_COLOR)
	return want


func center() -> Vector3:
	if flying:
		return global_position
	return global_position + Vector3.UP * height * 0.5


func is_alive() -> bool:
	return state != "dead"


func knockback(v: Vector3) -> void:
	if state == "dead":
		return
	knock += v * (0.25 if is_boss else (0.5 if type == "brute" else 1.0))


func take_damage(amount: float, element: int, dir: Vector3, _pos: Vector3) -> void:
	if state == "dead":
		return
	var a := amount
	if frozen_t > 0.0:
		a *= 1.8
	match element:
		WeaponData.Element.ICE:
			var resist := 1.4 if is_boss else (0.7 if type == "brute" else 0.35)
			freeze += amount / (max_hp * resist)
			if freeze >= 1.0 and frozen_t <= 0.0:
				frozen_t = 1.5 if is_boss else 2.6
				freeze = 0.0
				rig.set_tint(Color(0.6, 0.92, 1.0, 0.75))
				Sfx.play_at("freeze", center())
		WeaponData.Element.EXPLOSIVE, WeaponData.Element.FIRE:
			burn_t = 1.5 if is_boss else 3.0
	hp -= a
	flash = 1.0
	if not is_boss:
		knock += dir * clampf(a / max_hp * 14.0, 0.4, 5.0)
	gw.hit_marker.emit(false)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if state == "dead":
		return
	state = "dead"
	collision_layer = 0
	collision_mask = 0
	var glow: Color = def["glow"]
	rig.set_tint(Color(0, 0, 0, 0))
	rig.shatter(gw.debris, 16.0 if is_boss else 10.0, 1400 if is_boss else 240)
	gw.fx.flash(center(), hit_radius * 2.5, glow, 0.3)
	gw.debris.burst(center(), 80, glow, 7.0, 0.017, true, 2.0)
	if is_boss or type == "brute":
		gw.fx.ring(global_position + Vector3.UP * 0.2, hit_radius * 4.0, glow, 0.6)
		gw.add_shake(0.35 if is_boss else 0.15)
	if is_boss:
		gw.fx.explosion(center(), 4.0, glow)
		gw.slowmo(0.8, 0.3)
	Sfx.play_at("death", center())
	gw.on_enemy_killed(self)
	gw.enemies.erase(self)
	died.emit(self)
	queue_free()


# ---------------------------------------------------------------- атаки

func _line_of_sight(target: Vector3) -> bool:
	var hit := gw.raycast(center(), target, GameWorld.L_WORLD | GameWorld.L_DESTRUCT)
	return hit.is_empty()


func _shoot_orb(target: Vector3, speed: float, dmg: float) -> void:
	var from := center() + (target - center()).normalized() * (hit_radius + 0.4)
	var g := rig.part("gun")
	if g:
		from = g.global_transform * (g.get_meta("muzzle", Vector3(0, 0, 0.5)) as Vector3)
	var dir := (target - from).normalized()
	var col: Color = def["glow"]
	gw.projectiles.spawn("enemy_orb", 1, from, dir * speed, dmg, 0.7, WeaponData.Element.NONE, col)
	recoil = 1.0
	Sfx.play_at("enemy_shot", from)


func _slam() -> void:
	var p := global_position + Vector3.UP * 0.3
	var r := 4.5 if is_boss else 3.6
	for obj: VoxelObject in gw.objects_near(p, r):
		obj.damage_sphere(p, r * 0.7, 0.9, WeaponData.Element.NONE, 10.0)
	var pl := gw.player
	if pl and pl.is_alive() and pl.global_position.distance_to(global_position) < r + 0.5:
		pl.take_damage(float(def["damage"]), global_position)
		pl.apply_impulse((pl.global_position - global_position).normalized() * 9.0 + Vector3.UP * 6.0)
	var glow: Color = def["glow"]
	gw.fx.ring(p, r * 1.4, glow, 0.5)
	gw.fx.flash(p, r * 0.6, glow, 0.2)
	gw.debris.burst(p, 140, Color(0.7, 0.6, 0.5), 8.0, 0.021, false, 4.0)
	gw.add_shake(0.3 * gw._shake_falloff(p) + 0.1)
	Sfx.play_at("explosion", p, -4.0)


# ---------------------------------------------------------------- ИИ

func _physics_process(delta: float) -> void:
	if state == "dead":
		return
	anim_t += delta
	attack_cd -= delta
	recoil = maxf(recoil - delta * 4.0, 0.0)
	flash = maxf(flash - delta * 6.0, 0.0)
	rig.set_flash(flash * 0.9 + (0.0 if state != "spawn" else 0.6))

	if state == "spawn":
		spawn_t += delta
		var k := clampf(spawn_t / 0.7, 0.0, 1.0)
		body_root.scale = Vector3.ONE * maxf(k * k * (3.0 - 2.0 * k), 0.05)
		if k >= 1.0:
			state = "active"

	if burn_t > 0.0:
		burn_t -= delta
		hp -= (22.0 if is_boss else 9.0) * delta
		if randf() < 0.35:
			gw.debris.spawn(center() + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.5), randf_range(-0.4, 0.4)), Vector3(0, 3, 0), Color(1.0, 0.5, 0.1), 0.017, true)
		if hp <= 0.0:
			_die()
			return

	var pl := gw.player
	var to := Vector3.ZERO
	var dist := 999.0
	if pl and pl.is_alive():
		to = pl.global_position - global_position
		dist = to.length()
	var to_flat := Vector3(to.x, 0, to.z)
	var dir_flat := to_flat.normalized() if to_flat.length() > 0.01 else Vector3.FORWARD
	var want := Vector3.ZERO
	var speed := float(def["speed"])

	if frozen_t > 0.0:
		frozen_t -= delta
		if frozen_t <= 0.0:
			rig.set_tint(Color(0, 0, 0, 0))
	elif state == "active" and pl and pl.is_alive():
		match type:
			"swarmer":
				want = dir_flat * speed
				if dist < 1.8 and attack_cd <= 0.0:
					attack_cd = 1.1
					pl.take_damage(float(def["damage"]), global_position)
					knock -= dir_flat * 4.0
			"shooter":
				strafe_t -= delta
				if strafe_t <= 0.0:
					strafe_t = randf_range(1.5, 3.0)
					strafe_dir = -strafe_dir
				var side := dir_flat.cross(Vector3.UP) * strafe_dir
				if dist > 17.0:
					want = dir_flat * speed
				elif dist < 9.0:
					want = -dir_flat * speed * 0.8 + side * speed * 0.5
				else:
					want = side * speed * 0.7
				if attack_cd <= 0.0 and dist < 38.0:
					attack_cd = randf_range(1.5, 2.2)
					var target := pl.global_position + Vector3.UP * 1.0 + pl.velocity * clampf(dist / 22.0, 0.0, 1.0) * 0.6
					if _line_of_sight(pl.global_position + Vector3.UP):
						_shoot_orb(target, 22.0, float(def["damage"]))
					else:
						want = dir_flat * speed
			"brute", "boss":
				if windup > 0.0:
					windup -= delta
					if windup <= 0.0:
						_slam()
				else:
					want = dir_flat * speed
					if dist < (4.2 if type == "boss" else 3.4) and attack_cd <= 0.0:
						windup = 0.65
						attack_cd = 2.4
					if type == "boss" and attack_cd <= 0.0 and dist > 8.0 and dist < 45.0:
						attack_cd = 3.5
						for k in 7:
							var off := dir_flat.rotated(Vector3.UP, (float(k) - 3.0) * 0.12)
							_shoot_orb(global_position + off * dist + Vector3.UP * 1.0, 18.0, 14.0)
			"sveta":
				want = _sveta_ai(delta, pl, dist, dir_flat)
			"drone":
				orbit_a += delta * 0.6
				var goal := pl.global_position + Vector3(cos(orbit_a), 0, sin(orbit_a)) * 11.0 + Vector3.UP * 7.5
				var d := goal - global_position
				want = d.limit_length(speed)
				if attack_cd <= 0.0 and dist < 40.0:
					attack_cd = randf_range(1.1, 1.6)
					if _line_of_sight(pl.global_position + Vector3.UP):
						_shoot_orb(pl.global_position + Vector3.UP * 0.9, 26.0, float(def["damage"]))

	# обход препятствий для наземных
	if not flying and want.length() > 0.1:
		if is_on_wall():
			stuck_t += delta
			if type == "brute" or is_boss:
				# громилы и боссы проламывают стены
				smash_t -= delta
				if smash_t <= 0.0:
					smash_t = 0.45
					var front := center() + dir_flat * (hit_radius + 0.8)
					for obj: VoxelObject in gw.objects_near(front, 1.8):
						obj.damage_sphere(front, 1.9 if type == "brute" else 2.8, 0.85, WeaponData.Element.NONE, 7.0)
					gw.add_shake(0.08 * gw._shake_falloff(front))
			elif is_on_floor() and stuck_t > 0.15:
				velocity.y = 8.0
			if stuck_t > 0.5 and avoid_t <= 0.0 and type != "brute" and not is_boss:
				avoid_t = 0.9
				avoid_dir = dir_flat.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		else:
			stuck_t = 0.0
		if avoid_t > 0.0:
			avoid_t -= delta
			want = (want.normalized() * 0.3 + avoid_dir).normalized() * speed

	if windup > 0.0 or frozen_t > 0.0 or spit_windup > 0.0:
		want = Vector3.ZERO

	var blend := 1.0 - exp(-8.0 * delta)
	if flying:
		velocity = velocity.lerp(want, blend) + knock
	else:
		velocity.x = lerpf(velocity.x, want.x, blend) + knock.x
		velocity.z = lerpf(velocity.z, want.z, blend) + knock.z
		velocity.y += knock.y
		velocity.y -= gw.gravity * delta
	knock = Vector3.ZERO
	move_and_slide()
	if global_position.y < -20.0:
		_die()
		return

	# поворот и анимация
	if to_flat.length() > 0.1:
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(dir_flat.x, dir_flat.z), clampf(delta * 8.0, 0.0, 1.0))
	var hv := Vector2(velocity.x, velocity.z).length()
	var move := clampf(hv / maxf(speed, 0.1), 0.0, 1.2)
	match type:
		"swarmer":
			rig.animate_crawler(anim_t * 6.0, move)
		"drone":
			rig.animate_drone(anim_t)
		_:
			var aim_p := 0.0
			if to.length() > 0.1:
				aim_p = asin(clampf((to.y + 0.5) / maxf(to.length(), 0.1), -1.0, 1.0))
			rig.animate_humanoid(anim_t * (3.0 + hv * 1.2), move, not is_on_floor(), aim_p, type == "shooter", recoil, 0.0, 0.0)
			if windup > 0.0:
				var k2 := 1.0 - windup / 0.65
				rig.part("arm_l").rotation.x = -PI * 0.95 * k2
				rig.part("arm_r").rotation.x = -PI * 0.95 * k2
				rig.part("torso").rotation.x = -0.3 * k2
			if type == "sveta":
				var mth := rig.part("mouth")
				if mth:
					mth.scale = Vector3(1.0 + mouth_open * 0.35, 1.0 + mouth_open * 1.8, 1.0)
				if spit_windup > 0.0:
					var k3 := 1.0 - spit_windup / SPIT_WINDUP
					rig.part("head").rotation.x = -0.55 * k3
					rig.part("torso").rotation.x = -0.25 * k3
				elif mouth_open > 1.2:
					rig.part("head").rotation.x = 0.25
