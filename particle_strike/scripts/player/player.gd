class_name Player
extends CharacterBody3D
## Игрок из частиц. Вид от первого лица, бег, двойной прыжок, рывок с неуязвимостью,
## 6 видов оружия с перегревом, автоприцел для сенсорного управления, стены и гравивихрь.

signal health_changed(hp: float, max_hp: float, shield: float, max_shield: float)
signal weapon_changed(id: String)
signal damaged(from_pos: Vector3)
signal slimed(duration: float)

const BASE_SPEED := 6.8
const JUMP_V := 8.2
const DASH_SPEED := 26.0
const DASH_TIME := 0.18
const LOOK_SENS := 0.0042

var gw: GameWorld
var controls: TouchControls

var max_hp := 100.0
var hp := 100.0
var max_shield := 50.0
var shield := 50.0
var shield_delay := 0.0
var invuln := 0.0
var alive := true

var yaw := 0.0
var pitch := -0.1
var cam_yaw: Node3D
var cam_pitch: Node3D
var camera: Camera3D
var first_person := true
var aiming := false

var rig: VoxelRig
var viewmodel: VoxelRig
var weapon_id := "pistol"
var heat := {}
var overheated := {}
var fire_cd := 0.0
var recoil := 0.0
var anim_t := 0.0
var land_squash := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var jumps_left := 1
var coyote := 0.0
var jump_buffer := 0.0
var external_impulse := Vector3.ZERO
var was_on_floor := true
var last_vy := 0.0
var hit_flash := 0.0
var trail_t := 0.0
var _keys := {}
var _shake_t := 0.0
var _sway := Vector2.ZERO
## Облит слюной босса: замедление и потёки на экране.
var slime_t := 0.0


func setup(world: GameWorld, touch: TouchControls) -> void:
	gw = world
	controls = touch
	collision_layer = GameWorld.L_PLAYER
	collision_mask = GameWorld.L_WORLD | GameWorld.L_DESTRUCT | GameWorld.L_BOUNDS | GameWorld.L_ENEMY
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	rig = VoxelRig.build_humanoid(Color(0.1, 0.13, 0.28), Color(0.2, 0.5, 1.0), Color(0.35, 0.85, 1.0), 1.0, 0.075)
	add_child(rig)

	cam_yaw = Node3D.new()
	cam_yaw.position.y = 1.55
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	camera = Camera3D.new()
	camera.fov = 74.0
	camera.near = 0.05
	camera.far = 1500.0
	camera.position = Vector3(0, 0.1, 0)
	cam_pitch.add_child(camera)
	camera.current = true

	viewmodel = VoxelRig.new()
	viewmodel.vsize = 0.022
	viewmodel.position = Vector3(0.2, -0.17, -0.36)
	viewmodel.rotation_degrees = Vector3(-2.0, 183.0, 0.0)
	viewmodel.scale = Vector3.ONE * 0.5
	camera.add_child(viewmodel)

	for id in WeaponData.ORDER:
		heat[id] = 0.0
		overheated[id] = false
	apply_upgrades()
	# модель тела нужна только для распада на частицы при смерти
	rig.visible = false
	equip("pistol")


func apply_upgrades() -> void:
	max_hp = 100.0 + 20.0 * GameState.upgrade_level("hp")
	max_shield = 50.0 + 15.0 * GameState.upgrade_level("shield")
	hp = minf(hp, max_hp)
	shield = minf(shield, max_shield)
	health_changed.emit(hp, max_hp, shield, max_shield)


func magnet_radius() -> float:
	return 3.5 + 1.5 * GameState.upgrade_level("magnet")


func is_alive() -> bool:
	return alive


# ---------------------------------------------------------------- оружие

func equip(id: String) -> void:
	if not GameState.is_weapon_unlocked(id):
		return
	weapon_id = id
	var col := WeaponData.color(id)
	var kind := id
	for r in [rig, viewmodel]:
		var vr := r as VoxelRig
		if vr.parts.has("gun"):
			var old: VoxelRig.Part = vr.parts["gun"]
			old.pivot.queue_free()
			vr.parts.erase("gun")
	VoxelRig.build_gun(rig, "arm_r", col, kind)
	var vg := VoxelRig.build_gun(viewmodel, "", col, kind)
	vg.pivot.rotation = Vector3.ZERO
	vg.pivot.position = Vector3.ZERO
	fire_cd = 0.15
	weapon_changed.emit(id)
	Sfx.play("ui")


func cycle_weapon() -> void:
	var i := WeaponData.ORDER.find(weapon_id)
	for k in range(1, WeaponData.ORDER.size() + 1):
		var id: String = WeaponData.ORDER[(i + k) % WeaponData.ORDER.size()]
		if GameState.is_weapon_unlocked(id):
			equip(id)
			return


func muzzle_position() -> Vector3:
	var g := viewmodel.part("gun")
	if g == null:
		return camera.global_position
	return g.global_transform * (g.get_meta("muzzle", Vector3(0, 0, 0.5)) as Vector3)


func _aim_assist_target(origin: Vector3, fwd: Vector3) -> Enemy:
	if not bool(GameState.get_setting("aim_assist", true)):
		return null
	var best: Enemy = null
	var best_cos := cos(deg_to_rad(4.5 if aiming else 7.0))
	for e: Enemy in gw.enemies:
		if not e.is_alive():
			continue
		var to := e.center() - origin
		var d := to.length()
		if d > 90.0 or d < 1.0:
			continue
		var c := fwd.dot(to / d)
		if c > best_cos:
			best_cos = c
			best = e
	return best


func _fire() -> void:
	var def: Dictionary = WeaponData.DEFS[weapon_id]
	var cam_xf := camera.global_transform
	var origin := cam_xf.origin
	var fwd := -cam_xf.basis.z
	var target_point := origin + fwd * 200.0
	var tgt := _aim_assist_target(origin, fwd)
	if tgt:
		target_point = tgt.center()
	else:
		var hit := gw.raycast(origin + fwd * 0.5, origin + fwd * 200.0, GameWorld.L_WORLD | GameWorld.L_DESTRUCT | GameWorld.L_ENEMY)
		if not hit.is_empty():
			target_point = hit["position"]
	var muzzle := muzzle_position()
	var dir := (target_point - muzzle).normalized()
	if dir.dot(fwd) < 0.2:
		dir = fwd
	var col: Color = def["color"]
	var dmg := WeaponData.stat(weapon_id, "damage")
	var rad := WeaponData.stat(weapon_id, "radius")
	var elem: int = def["element"]
	match String(def["kind"]):
		"laser":
			gw.projectiles.fire_laser(muzzle, dir, dmg, rad, float(def.get("pierce", 6.0)), col)
			gw.add_shake(0.12)
		"rocket":
			gw.projectiles.spawn("rocket", 0, muzzle, dir * float(def["speed"]), dmg, rad, elem, col)
			gw.add_shake(0.15)
			external_impulse -= dir * 1.5
		"plasma":
			gw.projectiles.spawn("plasma", 0, muzzle, dir * float(def["speed"]), dmg, rad, elem, col)
			gw.add_shake(0.08)
		_:
			var pellets := int(def["pellets"])
			var spread := deg_to_rad(float(def["spread"]))
			var right := dir.cross(Vector3.UP).normalized()
			if right.length() < 0.5:
				right = Vector3.RIGHT
			var up := right.cross(dir).normalized()
			for k in pellets:
				var sd := (dir + right * randf_range(-spread, spread) + up * randf_range(-spread, spread)).normalized()
				gw.projectiles.spawn("bolt", 0, muzzle, sd * float(def["speed"]), dmg, rad, elem, col)
			if pellets > 1:
				gw.add_shake(0.12)
	gw.fx.muzzle(muzzle, col)
	recoil = 1.0
	pitch += 0.004 * (3.0 if weapon_id == "sniper" or weapon_id == "rocket" else 1.0)
	Sfx.play("laser" if weapon_id == "sniper" else weapon_id, -4.0)


func _update_weapons(delta: float) -> void:
	for id in WeaponData.ORDER:
		var h: float = heat[id]
		if h > 0.0:
			h = maxf(h - WeaponData.stat(id, "cool") * delta, 0.0)
			heat[id] = h
			if overheated[id] and h <= 0.25:
				overheated[id] = false
	fire_cd -= delta
	recoil = maxf(recoil - delta * 6.0, 0.0)
	var firing := controls != null and controls.fire_held
	firing = firing or bool(_keys.get("fire", false))
	if not firing or overheated[weapon_id] or fire_cd > 0.0:
		return
	fire_cd = WeaponData.stat(weapon_id, "interval")
	var def: Dictionary = WeaponData.DEFS[weapon_id]
	heat[weapon_id] = float(heat[weapon_id]) + float(def["heat"])
	if float(heat[weapon_id]) >= 1.0:
		heat[weapon_id] = 1.0
		overheated[weapon_id] = true
		Sfx.play("overheat")
		gw.notify.emit("ПЕРЕГРЕВ", Color(1.0, 0.45, 0.2))
	_fire()


# ---------------------------------------------------------------- урон

func take_damage(amount: float, from_pos: Vector3) -> void:
	if not alive or invuln > 0.0 or amount <= 0.0:
		return
	var a := amount
	if shield > 0.0:
		var absorbed := minf(shield, a)
		shield -= absorbed
		a -= absorbed
	hp -= a
	shield_delay = 4.0
	hit_flash = 1.0
	gw.add_shake(0.22)
	Sfx.play("hurt", -2.0)
	Sfx.vibrate(35)
	damaged.emit(from_pos)
	health_changed.emit(hp, max_hp, shield, max_shield)
	if hp <= 0.0:
		_die()


func apply_slime(duration: float) -> void:
	if not alive:
		return
	slime_t = maxf(slime_t, duration)
	slimed.emit(duration)
	Sfx.vibrate(40)


func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)
	health_changed.emit(hp, max_hp, shield, max_shield)


func apply_impulse(v: Vector3) -> void:
	external_impulse += v


func _die() -> void:
	alive = false
	hp = 0.0
	rig.visible = true
	rig.shatter(gw.debris, 9.0, 400)
	viewmodel.visible = false
	gw.fx.explosion(global_position + Vector3.UP, 2.5, Color(0.3, 0.8, 1.0))
	Sfx.play("death")
	gw.slowmo(1.2, 0.3)
	gw.on_player_died()


# ---------------------------------------------------------------- ввод

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.physical_keycode
		if code == KEY_ENTER or code == KEY_J:
			_keys["fire"] = k.pressed
		if not k.pressed or k.echo:
			return
		match code:
			KEY_SPACE:
				jump_buffer = 0.15
			KEY_SHIFT:
				_keys["dash"] = true
			KEY_Q:
				_keys["ability"] = true
			KEY_E:
				_keys["build"] = true
			KEY_R:
				aiming = not aiming
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				var idx := int(code - KEY_1)
				equip(WeaponData.ORDER[idx])


func _take_key(name_: String) -> bool:
	if bool(_keys.get(name_, false)):
		_keys[name_] = false
		return true
	return false


func _move_input() -> Vector2:
	var v := Vector2.ZERO
	if controls:
		v = controls.move_vector()
	var kv := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	if kv != Vector2.ZERO:
		v = kv.normalized()
	return v


# ---------------------------------------------------------------- цикл

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var input := _move_input()
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish := right * input.x + fwd * input.y
	var speed := BASE_SPEED * (1.0 + 0.08 * GameState.upgrade_level("speed")) * (0.6 if aiming else 1.0)
	speed *= (0.55 if slime_t > 0.0 else 1.0) * gw.slime_factor(global_position)

	# рывок
	dash_cd -= delta
	var dash_req := (controls != null and controls.consume("dash")) or _take_key("dash")
	if dash_req and dash_cd <= 0.0:
		dash_dir = wish.normalized() if wish.length() > 0.1 else fwd
		dash_t = DASH_TIME
		dash_cd = 1.6 - 0.2 * GameState.upgrade_level("dash")
		invuln = DASH_TIME + 0.08
		Sfx.play("dash")
		gw.fx.ring(global_position + Vector3.UP * 0.2, 1.6, Color(0.35, 0.85, 1.0), 0.25)

	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * DASH_SPEED
		velocity.y = 0.0
		for k in 3:
			gw.debris.spawn(global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.7), randf_range(-0.3, 0.3)), -dash_dir * 3.0 + Vector3.UP, Color(0.3, 0.75, 1.0), 0.017, true)
	else:
		var target := wish * speed
		var accel := 12.0 if is_on_floor() else 4.0
		var blend := 1.0 - exp(-accel * delta)
		velocity.x = lerpf(velocity.x, target.x, blend)
		velocity.z = lerpf(velocity.z, target.z, blend)
		velocity.y -= gw.gravity * delta

	# прыжок + двойной прыжок (реактивный выброс частиц)
	if (controls != null and controls.consume("jump")):
		jump_buffer = 0.15
	jump_buffer -= delta
	if is_on_floor():
		coyote = 0.12
		jumps_left = 1
	else:
		coyote -= delta
	if jump_buffer > 0.0:
		if coyote > 0.0:
			velocity.y = JUMP_V
			coyote = 0.0
			jump_buffer = 0.0
			Sfx.play("jump", -6.0)
		elif jumps_left > 0:
			velocity.y = JUMP_V * 0.92
			jumps_left -= 1
			jump_buffer = 0.0
			gw.debris.burst(global_position + Vector3.UP * 0.2, 80, Color(0.35, 0.85, 1.0), 4.0, 0.018, true, -4.0)
			gw.fx.ring(global_position + Vector3.UP * 0.1, 1.2, Color(0.35, 0.85, 1.0), 0.3)
			Sfx.play("jump", -3.0)

	if external_impulse != Vector3.ZERO:
		velocity += external_impulse
		external_impulse = Vector3.ZERO

	last_vy = velocity.y
	var horiz_before := Vector3(velocity.x, 0, velocity.z)
	move_and_slide()

	# подъём на невысокие ступени (кучи частиц, мост, бордюры)
	if is_on_wall() and horiz_before.length() > 1.0 and dash_t <= 0.0:
		var step := Vector3.UP * 0.55
		var motion := horiz_before.normalized() * 0.3
		if not test_move(global_transform, step) and not test_move(global_transform.translated(step), motion):
			global_position += step + motion * 0.5

	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		land_squash = clampf(-last_vy / 16.0, 0.15, 1.0)
		if last_vy < -9.0:
			gw.debris.burst(global_position + Vector3.UP * 0.1, 48, Color(0.6, 0.7, 0.9), 3.0, 0.016, false, 1.0)
	was_on_floor = on_floor

	# щит восстанавливается, если давно не получали урон
	if shield_delay > 0.0:
		shield_delay -= delta
	elif shield < max_shield:
		shield = minf(max_shield, shield + 16.0 * delta)
		health_changed.emit(hp, max_hp, shield, max_shield)
	invuln = maxf(invuln - delta, 0.0)
	slime_t = maxf(slime_t - delta, 0.0)

	# упал с платформы / вылетел из мира
	if global_position.y < -25.0:
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
		take_damage(20.0, global_position)

	# след из частиц при беге
	trail_t -= delta
	if on_floor and Vector2(velocity.x, velocity.z).length() > 4.0 and trail_t <= 0.0:
		trail_t = 0.07
		gw.debris.spawn(global_position + Vector3(randf_range(-0.2, 0.2), 0.15, randf_range(-0.2, 0.2)), Vector3(0, 1.2, 0), Color(0.3, 0.7, 1.0), 0.014, false)


func _process(delta: float) -> void:
	if not alive:
		return
	# камера
	var look := Vector2.ZERO
	if controls:
		look = controls.consume_look()
	var kl := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	look += kl * 500.0 * delta
	var sens := LOOK_SENS * float(GameState.get_setting("sensitivity", 1.0)) * (0.55 if aiming else 1.0)
	var inv := -1.0 if bool(GameState.get_setting("invert_y", false)) else 1.0
	yaw -= look.x * sens
	pitch = clampf(pitch - look.y * sens * inv, -1.25, 1.2)

	# мягкий магнит прицела во время стрельбы
	if controls and controls.fire_held:
		var cam_xf := camera.global_transform
		var tgt := _aim_assist_target(cam_xf.origin, -cam_xf.basis.z)
		if tgt:
			var to := (tgt.center() - cam_xf.origin).normalized()
			var want_yaw := atan2(-to.x, -to.z)
			var want_pitch := asin(clampf(to.y, -1.0, 1.0))
			var k := clampf(delta * 3.0, 0.0, 1.0)
			yaw = lerp_angle(yaw, want_yaw, k)
			pitch = lerpf(pitch, want_pitch, k)

	if controls:
		aiming = controls.aim_on
		var wsel := controls.consume_weapon()
		if wsel != "":
			equip(wsel)
		if controls.consume("next_weapon"):
			cycle_weapon()
		if controls.consume("build") or _take_key("build"):
			gw.build_wall(global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 3.4, yaw)
		if controls.consume("ability") or _take_key("ability"):
			_use_ability()
	else:
		if _take_key("build"):
			gw.build_wall(global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 3.4, yaw)
		if _take_key("ability"):
			_use_ability()

	cam_yaw.rotation.y = yaw
	cam_pitch.rotation.x = pitch
	var target_fov := 74.0 + (10.0 if dash_t > 0.0 else 0.0)
	if aiming:
		target_fov = 28.0 if weapon_id == "sniper" else 50.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 10.0, 0.0, 1.0))

	_update_weapons(delta)

	# анимация вида от первого лица: покачивание при беге, приседание при
	# приземлении, инерция оружия при повороте, отдача, тряска от взрывов
	var hv := Vector2(velocity.x, velocity.z).length()
	var move := clampf(hv / BASE_SPEED, 0.0, 1.3) if is_on_floor() else 0.0
	anim_t += delta * (4.0 + hv * 1.4)
	land_squash = maxf(land_squash - delta * 4.0, 0.0)
	_shake_t += delta * 40.0
	var sh := gw.shake * gw.shake
	camera.position = Vector3(
		cos(anim_t * 0.5) * 0.025 * move + sin(_shake_t * 1.3) * sh * 0.25,
		0.1 + absf(sin(anim_t * 0.5)) * 0.045 * move - land_squash * 0.14 + cos(_shake_t * 1.7) * sh * 0.25,
		0.0)
	camera.rotation.z = lerpf(camera.rotation.z, -look.x * sens * 0.6 + sh * sin(_shake_t) * 0.02, clampf(delta * 8.0, 0.0, 1.0))
	_sway = _sway.lerp(Vector2(-look.x, look.y) * sens * 0.6, clampf(delta * 10.0, 0.0, 1.0))
	viewmodel.position = Vector3(
		0.2 + _sway.x + cos(anim_t * 0.5) * 0.012 * move,
		-0.17 - _sway.y + absf(sin(anim_t * 0.5)) * 0.012 * move - land_squash * 0.05 - (0.04 if dash_t > 0.0 else 0.0),
		-0.36 + recoil * 0.05)
	viewmodel.rotation_degrees = Vector3(-2.0 + recoil * 6.0, 183.0 + _sway.x * 60.0, 0.0)
	hit_flash = maxf(hit_flash - delta * 5.0, 0.0)


func _use_ability() -> void:
	if gw.vortex_charge < 1.0:
		gw.notify.emit("Вихрь заряжается: %d%%" % int(gw.vortex_charge * 100.0), Color(0.7, 0.5, 1.0))
		return
	var cam_xf := camera.global_transform
	var fwd := -cam_xf.basis.z
	var hit := gw.raycast(cam_xf.origin + fwd * 0.5, cam_xf.origin + fwd * 35.0, GameWorld.L_WORLD | GameWorld.L_DESTRUCT | GameWorld.L_ENEMY)
	var p: Vector3 = cam_xf.origin + fwd * 25.0
	if not hit.is_empty():
		p = hit["position"]
	gw.use_vortex(p)
