class_name TouchControls
extends Control
## Мультитач-управление: плавающий джойстик слева, обзор свайпом справа,
## кнопка огня (с ней же можно вести прицел), прицел, прыжок, рывок, вихрь, стена,
## панель оружия и пауза. Учитывает «чёлку» и Dynamic Island.

const BTN_IDS := ["fire", "jump", "aim", "dash", "ability", "build", "pause"]

var gw: GameWorld
var player: Player

var buttons := {}
var weapon_slots: Array = []
var touches := {}
var move_vec := Vector2.ZERO
var joy_origin := Vector2.ZERO
var joy_home := Vector2.ZERO
var joy_r := 70.0
var joy_touch := -1
var look_accum := Vector2.ZERO
var fire_held := false
var aim_on := false
var _pressed := {}
var _weapon_pick := ""
var _flash := {}
var u := 1.0
var margin_l := 16.0
var margin_r := 16.0
var margin_t := 8.0
var margin_b := 10.0
var _last_size := Vector2.ZERO


func setup(world: GameWorld, p: Player) -> void:
	gw = world
	player = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()


func reset() -> void:
	touches.clear()
	joy_touch = -1
	move_vec = Vector2.ZERO
	fire_held = false
	look_accum = Vector2.ZERO
	_pressed.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0:
		return
	_last_size = vp
	# безопасная зона (вырез экрана, Dynamic Island, полоска «домой»)
	var ws := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	margin_l = 16.0
	margin_r = 16.0
	margin_t = 8.0
	margin_b = 10.0
	if ws.x > 0 and ws.y > 0 and sa.size.x > 0:
		var sx := vp.x / float(ws.x)
		var sy := vp.y / float(ws.y)
		margin_l = maxf(margin_l, float(sa.position.x) * sx)
		margin_r = maxf(margin_r, float(ws.x - sa.end.x) * sx)
		margin_t = maxf(margin_t, float(sa.position.y) * sy)
		margin_b = maxf(margin_b, float(ws.y - sa.end.y) * sy)
	u = clampf(vp.y / 590.0, 0.8, 1.7)
	var f := Vector2(vp.x - margin_r - 100.0 * u, vp.y - margin_b - 105.0 * u)
	buttons = {
		"fire": {"c": f, "r": 62.0 * u},
		"jump": {"c": f + Vector2(-152, 42) * u, "r": 40.0 * u},
		"aim": {"c": f + Vector2(-132, -92) * u, "r": 40.0 * u},
		"dash": {"c": f + Vector2(-8, -166) * u, "r": 38.0 * u},
		"ability": {"c": f + Vector2(-248, -18) * u, "r": 38.0 * u},
		"build": {"c": f + Vector2(-238, -122) * u, "r": 32.0 * u},
		"pause": {"c": Vector2(vp.x - margin_r - 172.0 * u, margin_t + 30.0 * u), "r": 24.0 * u},
	}
	joy_r = 70.0 * u
	joy_home = Vector2(margin_l + 120.0 * u, vp.y - margin_b - 125.0 * u)
	if joy_touch < 0:
		joy_origin = joy_home
	weapon_slots.clear()
	var slot := 50.0 * u
	var gap := 6.0 * u
	var total := WeaponData.ORDER.size() * slot + (WeaponData.ORDER.size() - 1) * gap
	var x0 := vp.x * 0.47 - total * 0.5
	for i in WeaponData.ORDER.size():
		weapon_slots.append({"id": WeaponData.ORDER[i], "rect": Rect2(x0 + i * (slot + gap), vp.y - margin_b - slot - 6.0 * u, slot, slot)})


# ---------------------------------------------------------------- API для игрока

func move_vector() -> Vector2:
	return move_vec


func consume_look() -> Vector2:
	var v := look_accum
	look_accum = Vector2.ZERO
	return v


func consume(action: String) -> bool:
	if bool(_pressed.get(action, false)):
		_pressed[action] = false
		return true
	return false


func consume_weapon() -> String:
	var w := _weapon_pick
	_weapon_pick = ""
	return w


# ---------------------------------------------------------------- ввод

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position, d.relative)


func _touch_down(i: int, pos: Vector2) -> void:
	for id in BTN_IDS:
		var b: Dictionary = buttons[id]
		if pos.distance_to(b["c"]) <= float(b["r"]) * 1.15:
			_flash[id] = 1.0
			match id:
				"fire":
					fire_held = true
					touches[i] = {"kind": "fire"}
				"aim":
					aim_on = not aim_on
					touches[i] = {"kind": "button"}
				_:
					_pressed[id] = true
					touches[i] = {"kind": "button"}
			return
	for s in weapon_slots:
		var r: Rect2 = s["rect"]
		if r.grow(4.0).has_point(pos):
			var wid: String = s["id"]
			if GameState.is_weapon_unlocked(wid):
				_weapon_pick = wid
			elif gw:
				gw.notify.emit("%s закрыт — открой в «Улучшениях»" % WeaponData.DEFS[wid]["name"], Color(1, 0.6, 0.4))
			touches[i] = {"kind": "button"}
			return
	var vp := get_viewport_rect().size
	if joy_touch < 0 and pos.x < vp.x * 0.4 and pos.y > vp.y * 0.28:
		joy_touch = i
		joy_origin = pos
		move_vec = Vector2.ZERO
		touches[i] = {"kind": "move"}
		return
	touches[i] = {"kind": "look"}


func _touch_move(i: int, pos: Vector2, rel: Vector2) -> void:
	if not touches.has(i):
		return
	var kind: String = touches[i]["kind"]
	match kind:
		"move":
			var v := (pos - joy_origin) / joy_r
			if v.length() > 1.0:
				# джойстик «едет» за пальцем
				joy_origin = pos - v.normalized() * joy_r
				v = v.normalized()
			move_vec = Vector2(v.x, -v.y)
		"look", "fire":
			look_accum += rel


func _touch_up(i: int) -> void:
	if not touches.has(i):
		return
	var kind: String = touches[i]["kind"]
	touches.erase(i)
	if kind == "move":
		joy_touch = -1
		move_vec = Vector2.ZERO
		joy_origin = joy_home
	elif kind == "fire":
		fire_held = false
		for k in touches.keys():
			if touches[k]["kind"] == "fire":
				fire_held = true


# ---------------------------------------------------------------- отрисовка

func _process(delta: float) -> void:
	if get_viewport_rect().size != _last_size:
		_layout()
	for k in _flash.keys():
		_flash[k] = maxf(float(_flash[k]) - delta * 5.0, 0.0)
	queue_redraw()


func _btn_bg(id: String, ring: Color, active: bool) -> void:
	var b: Dictionary = buttons[id]
	var c: Vector2 = b["c"]
	var r: float = b["r"]
	var fl := float(_flash.get(id, 0.0))
	draw_circle(c, r, Color(0.04, 0.06, 0.12, 0.42 + 0.25 * fl))
	draw_arc(c, r, 0.0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.85 if active else 0.55), 2.5 * u, true)
	if fl > 0.0:
		draw_circle(c, r * (1.0 + 0.15 * (1.0 - fl)), Color(ring.r, ring.g, ring.b, 0.18 * fl))


func _draw() -> void:
	if buttons.is_empty():
		return
	var font := get_theme_default_font()
	var white := Color(1, 1, 1, 0.9)
	var wcol := WeaponData.color(player.weapon_id) if player else Color(0.4, 0.7, 1.0)

	# джойстик
	var ja := 0.85 if joy_touch >= 0 else 0.35
	draw_circle(joy_origin, joy_r, Color(0.05, 0.08, 0.15, 0.3 * ja))
	draw_arc(joy_origin, joy_r, 0.0, TAU, 48, Color(0.5, 0.75, 1.0, 0.5 * ja), 2.0 * u, true)
	var knob := joy_origin + Vector2(move_vec.x, -move_vec.y) * joy_r
	draw_circle(knob, 28.0 * u, Color(0.7, 0.85, 1.0, 0.45 * ja + 0.1))

	# огонь + индикатор перегрева
	var fb: Dictionary = buttons["fire"]
	var fc: Vector2 = fb["c"]
	var fr: float = fb["r"]
	_btn_bg("fire", wcol, fire_held)
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		draw_line(fc + Vector2(cos(a), sin(a)) * fr * 0.18, fc + Vector2(cos(a), sin(a)) * fr * 0.48, wcol, 4.0 * u, true)
	draw_circle(fc, fr * 0.12, wcol)
	if player:
		var h: float = player.heat.get(player.weapon_id, 0.0)
		var over: bool = player.overheated.get(player.weapon_id, false)
		if h > 0.01:
			var hc := Color(1.0, 0.25, 0.15) if over else Color(1.0, 0.75, 0.2).lerp(Color(1, 0.3, 0.1), h)
			draw_arc(fc, fr + 7.0 * u, -PI * 0.5, -PI * 0.5 + TAU * h, 48, hc, 5.0 * u, true)

	# прицел
	var ab: Dictionary = buttons["aim"]
	var ac: Vector2 = ab["c"]
	var ar: float = ab["r"]
	_btn_bg("aim", Color(0.6, 0.9, 1.0), aim_on)
	if aim_on:
		draw_circle(ac, ar * 0.9, Color(0.4, 0.8, 1.0, 0.25))
	draw_arc(ac, ar * 0.42, 0.0, TAU, 32, white, 2.0 * u, true)
	draw_line(ac + Vector2(-ar * 0.65, 0), ac + Vector2(-ar * 0.2, 0), white, 2.0 * u)
	draw_line(ac + Vector2(ar * 0.2, 0), ac + Vector2(ar * 0.65, 0), white, 2.0 * u)
	draw_line(ac + Vector2(0, -ar * 0.65), ac + Vector2(0, -ar * 0.2), white, 2.0 * u)
	draw_line(ac + Vector2(0, ar * 0.2), ac + Vector2(0, ar * 0.65), white, 2.0 * u)

	# прыжок
	var jc: Vector2 = buttons["jump"]["c"]
	var jr: float = buttons["jump"]["r"]
	_btn_bg("jump", Color(0.6, 0.9, 1.0), false)
	draw_colored_polygon(PackedVector2Array([jc + Vector2(0, -jr * 0.5), jc + Vector2(jr * 0.4, -jr * 0.05), jc + Vector2(-jr * 0.4, -jr * 0.05)]), white)
	draw_rect(Rect2(jc + Vector2(-jr * 0.13, -jr * 0.06), Vector2(jr * 0.26, jr * 0.5)), white)

	# рывок + перезарядка
	var dc: Vector2 = buttons["dash"]["c"]
	var dr: float = buttons["dash"]["r"]
	_btn_bg("dash", Color(0.4, 0.85, 1.0), false)
	for k in 2:
		var ox := (float(k) - 0.5) * dr * 0.45
		draw_polyline(PackedVector2Array([dc + Vector2(ox - dr * 0.2, -dr * 0.35), dc + Vector2(ox + dr * 0.15, 0), dc + Vector2(ox - dr * 0.2, dr * 0.35)]), white, 3.0 * u, true)
	if player and player.dash_cd > 0.0:
		var dmax := 1.6 - 0.2 * GameState.upgrade_level("dash")
		draw_arc(dc, dr + 5.0 * u, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - player.dash_cd / dmax), 32, Color(0.4, 0.85, 1.0, 0.8), 3.0 * u, true)

	# гравивихрь + заряд
	var vc: Vector2 = buttons["ability"]["c"]
	var vr: float = buttons["ability"]["r"]
	var charge := gw.vortex_charge if gw else 0.0
	var vcol := Color(0.75, 0.45, 1.0)
	_btn_bg("ability", vcol, charge >= 1.0)
	for k in 3:
		var a0 := TAU * float(k) / 3.0 + Time.get_ticks_msec() * 0.003 * (1.0 if charge >= 1.0 else 0.2)
		draw_arc(vc, vr * (0.25 + 0.12 * k), a0, a0 + PI * 0.9, 16, white, 2.5 * u, true)
	draw_arc(vc, vr + 5.0 * u, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, Color(vcol.r, vcol.g, vcol.b, 0.95), 4.0 * u, true)
	if charge >= 1.0:
		draw_circle(vc, vr * (1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.01)), Color(vcol.r, vcol.g, vcol.b, 0.15))

	# стена из частиц
	var bc: Vector2 = buttons["build"]["c"]
	var br: float = buttons["build"]["r"]
	_btn_bg("build", Color(0.3, 0.95, 1.0), false)
	for row in 2:
		for col in 3:
			var off := Vector2((float(col) - 1.0) * br * 0.36 + (br * 0.18 if row == 1 else 0.0), (float(row) - 0.5) * br * 0.34)
			draw_rect(Rect2(bc + off - Vector2(br * 0.15, br * 0.13), Vector2(br * 0.3, br * 0.26)), Color(0.3, 0.95, 1.0, 0.9))
	draw_string(font, bc + Vector2(-br, br + 14.0 * u), str(GameWorld.WALL_COST), HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, int(13 * u), Color(0.6, 0.95, 1.0, 0.9))

	# пауза
	var pc: Vector2 = buttons["pause"]["c"]
	var pr: float = buttons["pause"]["r"]
	_btn_bg("pause", Color(0.8, 0.85, 1.0), false)
	draw_rect(Rect2(pc + Vector2(-pr * 0.35, -pr * 0.4), Vector2(pr * 0.22, pr * 0.8)), white)
	draw_rect(Rect2(pc + Vector2(pr * 0.13, -pr * 0.4), Vector2(pr * 0.22, pr * 0.8)), white)

	# оружие
	for s in weapon_slots:
		var r: Rect2 = s["rect"]
		var id: String = s["id"]
		var unlocked := GameState.is_weapon_unlocked(id)
		var col := WeaponData.color(id)
		var current := player != null and player.weapon_id == id
		draw_rect(r, Color(0.04, 0.06, 0.12, 0.65 if current else 0.4))
		draw_rect(r, Color(col.r, col.g, col.b, 0.95 if current else (0.5 if unlocked else 0.15)), false, (3.0 if current else 1.5) * u)
		if unlocked:
			var ic := r.get_center()
			draw_rect(Rect2(ic + Vector2(-r.size.x * 0.32, -r.size.y * 0.12), Vector2(r.size.x * 0.64, r.size.y * 0.16)), col)
			draw_rect(Rect2(ic + Vector2(-r.size.x * 0.28, 0.0), Vector2(r.size.x * 0.12, r.size.y * 0.18)), col.darkened(0.3))
			if player:
				var hh: float = player.heat.get(id, 0.0)
				if hh > 0.01:
					draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4.0 * u), Vector2(r.size.x * hh, 4.0 * u)), Color(1.0, 0.4, 0.2))
		else:
			draw_string(font, r.position + Vector2(0, r.size.y * 0.62), "×", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(18 * u), Color(1, 1, 1, 0.35))
		draw_string(font, r.position + Vector2(4.0 * u, 13.0 * u), str(WeaponData.ORDER.find(id) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(1, 1, 1, 0.6))
