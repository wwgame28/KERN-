class_name HUD
extends Control
## Минималистичный HUD, рисуется одним _draw без лишних нод:
## здоровье и щит, частицы, комбо, волна, миникарта, прицел с хитмаркером,
## индикатор направления урона, виньетка, полоса босса, уведомления, FPS.

var gw: GameWorld
var player: Player
var controls: TouchControls

var _notes: Array = []
var _hit_t := 0.0
var _kill_t := 0.0
var _dmg_t := 0.0
var _dmg_from := Vector3.ZERO
var _combo_pop := 0.0
var _hp := 100.0
var _max_hp := 100.0
var _shield := 50.0
var _max_shield := 50.0
var _shown_particles := 0.0
var _tip := ""
var _blobs: Array = []
var _slime_t := 0.0
var _slime_max := 1.0
var _tip_t := 0.0


func setup(world: GameWorld, p: Player, c: TouchControls) -> void:
	gw = world
	player = p
	controls = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gw.notify.connect(_on_notify)
	gw.hit_marker.connect(_on_hit)
	gw.combo_changed.connect(_on_combo)
	player.damaged.connect(_on_damaged)
	player.slimed.connect(_on_slimed)
	player.health_changed.connect(_on_health)
	_on_health(player.hp, player.max_hp, player.shield, player.max_shield)
	_shown_particles = float(GameState.particles)


func _on_notify(text: String, color: Color) -> void:
	for n in _notes:
		if n["text"] == text:
			n["t"] = 2.2
			return
	_notes.append({"text": text, "color": color, "t": 2.2})
	if _notes.size() > 3:
		_notes.pop_front()


func show_tip(text: String, duration: float) -> void:
	_tip = text
	_tip_t = duration


func _on_hit(kill: bool) -> void:
	_hit_t = 0.18
	if kill:
		_kill_t = 0.35
		Sfx.play("hit", -6.0)


func _on_combo(_c: int, _m: float) -> void:
	_combo_pop = 1.0


func _on_slimed(duration: float) -> void:
	## Плевок попал в «камеру»: капли слюны на экране, стекают и высыхают.
	_slime_t = duration
	_slime_max = duration
	var vp := get_viewport_rect().size
	var u := controls.u if controls else 1.0
	for k in randi_range(4, 7):
		var edge := randf() < 0.7
		var p := Vector2(randf_range(0.05, 0.95) * vp.x, randf_range(0.05, 0.7) * vp.y)
		if edge:
			p = Vector2(randf_range(0.0, 0.3) * vp.x if randf() < 0.5 else randf_range(0.7, 1.0) * vp.x, randf_range(0.0, 0.8) * vp.y)
		_blobs.append({"p": p, "r": randf_range(28.0, 85.0) * u, "drip": randf_range(40.0, 140.0) * u})
	while _blobs.size() > 14:
		_blobs.pop_front()


func _on_damaged(from_pos: Vector3) -> void:
	_dmg_t = 0.9
	_dmg_from = from_pos


func _on_health(hp: float, max_hp: float, shield: float, max_shield: float) -> void:
	_hp = hp
	_max_hp = max_hp
	_shield = shield
	_max_shield = max_shield


func _process(delta: float) -> void:
	_hit_t = maxf(_hit_t - delta, 0.0)
	_kill_t = maxf(_kill_t - delta, 0.0)
	_dmg_t = maxf(_dmg_t - delta, 0.0)
	_combo_pop = maxf(_combo_pop - delta * 4.0, 0.0)
	_tip_t = maxf(_tip_t - delta, 0.0)
	if _slime_t > 0.0:
		_slime_t = maxf(_slime_t - delta, 0.0)
		if _slime_t <= 0.0:
			_blobs.clear()
	for i in range(_notes.size() - 1, -1, -1):
		_notes[i]["t"] = float(_notes[i]["t"]) - delta
		if float(_notes[i]["t"]) <= 0.0:
			_notes.remove_at(i)
	_shown_particles = lerpf(_shown_particles, float(GameState.particles), clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, pos + Vector2(1.5, 1.5), s, align, width, size, Color(0, 0, 0, col.a * 0.6))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	if gw == null or player == null or controls == null:
		return
	var font := get_theme_default_font()
	var vp := get_viewport_rect().size
	var u := controls.u
	var ml := controls.margin_l
	var mr := controls.margin_r
	var mt := controls.margin_t

	# --- здоровье, щит
	var ac := Vector2(ml + 30.0 * u, mt + 36.0 * u)
	draw_circle(ac, 26.0 * u, Color(0.04, 0.06, 0.12, 0.6))
	draw_arc(ac, 26.0 * u, 0.0, TAU, 40, Color(0.4, 0.8, 1.0, 0.8), 2.0 * u, true)
	for k in 9:
		var gx := float(k % 3) - 1.0
		var gy := float(k / 3) - 1.0
		if k == 0 or k == 2:
			continue
		draw_rect(Rect2(ac + Vector2(gx, gy) * 9.0 * u - Vector2(3.5, 3.5) * u, Vector2(7, 7) * u), Color(0.45, 0.85, 1.0, 0.9))
	var bx := ml + 66.0 * u
	var bw := 220.0 * u
	var hp_k := clampf(_hp / maxf(_max_hp, 1.0), 0.0, 1.0)
	var sh_k := clampf(_shield / maxf(_max_shield, 1.0), 0.0, 1.0)
	draw_rect(Rect2(bx, mt + 16.0 * u, bw, 13.0 * u), Color(0.05, 0.05, 0.08, 0.6))
	draw_rect(Rect2(bx, mt + 16.0 * u, bw * hp_k, 13.0 * u), Color(1.0, 0.25, 0.3).lerp(Color(1, 1, 1), 0.3 * float(hp_k < 0.3) * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))))
	draw_rect(Rect2(bx, mt + 33.0 * u, bw, 8.0 * u), Color(0.05, 0.05, 0.08, 0.6))
	draw_rect(Rect2(bx, mt + 33.0 * u, bw * sh_k, 8.0 * u), Color(0.25, 0.55, 1.0))
	_text(font, Vector2(bx + bw + 8.0 * u, mt + 28.0 * u), str(int(ceil(_hp))), int(15 * u), Color(1, 1, 1, 0.9))

	# --- частицы и комбо
	var py := mt + 62.0 * u
	var dc := Vector2(bx + 7.0 * u, py - 5.0 * u)
	draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -7) * u, dc + Vector2(6, 0) * u, dc + Vector2(0, 7) * u, dc + Vector2(-6, 0) * u]), Color(0.45, 0.85, 1.0))
	_text(font, Vector2(bx + 18.0 * u, py + 2.0 * u), str(int(round(_shown_particles))), int(18 * u), Color(0.75, 0.95, 1.0))
	if gw.combo > 0:
		var s := 1.0 + _combo_pop * 0.35
		var a := clampf(gw.combo_timer / 0.6, 0.0, 1.0)
		_text(font, Vector2(bx, py + 26.0 * u), "КОМБО ×%.2f" % gw.combo_mult(), int(17 * u * s), Color(1.0, 0.8, 0.3, a))
		draw_rect(Rect2(bx, py + 32.0 * u, 120.0 * u * clampf(gw.combo_timer / 2.5, 0.0, 1.0), 3.0 * u), Color(1.0, 0.8, 0.3, a))

	# --- волна или счётчик разрушений (песочница)
	if gw.director:
		_text(font, Vector2(0, mt + 24.0 * u), gw.director.info_text(), int(17 * u), Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	else:
		_text(font, Vector2(0, mt + 24.0 * u), "Разрушено: %d" % int(gw.stats["voxels"]), int(17 * u), Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vp.x)

	# --- полоса босса
	for e: Enemy in gw.enemies:
		if e.is_boss and e.is_alive():
			var w := vp.x * 0.42
			var x := (vp.x - w) * 0.5
			var by := mt + 36.0 * u
			var bar_col := Color(1.0, 0.25, 0.45) if e.phase2 else Color(1.0, 0.45, 0.75)
			draw_rect(Rect2(x, by, w, 12.0 * u), Color(0.05, 0.02, 0.05, 0.75))
			draw_rect(Rect2(x, by, w * clampf(e.hp / e.max_hp, 0.0, 1.0), 12.0 * u), bar_col)
			draw_rect(Rect2(x, by, w, 12.0 * u), Color(1, 1, 1, 0.35), false, 1.5)
			_text(font, Vector2(x, by + 30.0 * u), "БОСС: " + String(e.def["name"]).to_upper(), int(15 * u), Color(1.0, 0.7, 0.88), HORIZONTAL_ALIGNMENT_CENTER, w)
			break

	# --- миникарта
	var mc := Vector2(vp.x - mr - 72.0 * u, mt + 76.0 * u)
	var mrad := 60.0 * u
	draw_circle(mc, mrad, Color(0.03, 0.05, 0.1, 0.55))
	draw_arc(mc, mrad, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.7), 2.0 * u, true)
	draw_arc(mc, mrad * 0.5, 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 0.15), 1.0, true)
	var yaw := player.yaw
	var f := Vector2(-sin(yaw), -cos(yaw))
	var rt := Vector2(cos(yaw), -sin(yaw))
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var map_scale := mrad / 45.0
	for o: VoxelObject in gw.objects:
		if o.initial_count < 600:
			continue
		var oc := o.world_aabb.get_center()
		var rel := Vector2(oc.x, oc.z) - pp
		var sp := Vector2(rel.dot(rt), -rel.dot(f)) * map_scale
		if sp.length() < mrad - 4.0 * u:
			var hs := clampf(o.world_aabb.size.x * map_scale * 0.4, 2.0, 9.0 * u)
			draw_rect(Rect2(mc + sp - Vector2(hs, hs), Vector2(hs, hs) * 2.0), Color(0.6, 0.7, 0.9, 0.22))
	for e: Enemy in gw.enemies:
		var rel2 := Vector2(e.global_position.x, e.global_position.z) - pp
		var sp2 := Vector2(rel2.dot(rt), -rel2.dot(f)) * map_scale
		if sp2.length() > mrad - 5.0 * u:
			sp2 = sp2.normalized() * (mrad - 5.0 * u)
		var er := (6.0 if e.is_boss else 3.0) * u
		draw_circle(mc + sp2, er, Color(1.0, 0.25, 0.3, 0.95))
	draw_colored_polygon(PackedVector2Array([mc + Vector2(0, -7) * u, mc + Vector2(5, 5) * u, mc + Vector2(-5, 5) * u]), Color(0.5, 0.9, 1.0))

	# --- прицел
	var cc := vp * 0.5
	var wcol := WeaponData.color(player.weapon_id)
	var gap := (7.0 if player.aiming else 11.0) * u + player.recoil * 6.0 * u
	var ln := 9.0 * u
	var chc := Color(1, 1, 1, 0.9)
	draw_line(cc + Vector2(-gap - ln, 0), cc + Vector2(-gap, 0), chc, 2.0 * u)
	draw_line(cc + Vector2(gap, 0), cc + Vector2(gap + ln, 0), chc, 2.0 * u)
	draw_line(cc + Vector2(0, -gap - ln), cc + Vector2(0, -gap), chc, 2.0 * u)
	draw_line(cc + Vector2(0, gap), cc + Vector2(0, gap + ln), chc, 2.0 * u)
	draw_circle(cc, 2.0 * u, wcol)
	var h: float = player.heat.get(player.weapon_id, 0.0)
	if h > 0.02:
		var over: bool = player.overheated.get(player.weapon_id, false)
		draw_arc(cc, 26.0 * u, PI * 0.75, PI * 0.75 + PI * 0.5 * h, 24, Color(1.0, 0.3, 0.15) if over else Color(1.0, 0.7, 0.25, 0.8), 3.0 * u, true)
	if _hit_t > 0.0 or _kill_t > 0.0:
		var kc := Color(1.0, 0.25, 0.25) if _kill_t > 0.0 else Color(1, 1, 1)
		var hs2 := (8.0 + (6.0 if _kill_t > 0.0 else 0.0)) * u
		for sgn in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(cc + sgn * hs2 * 0.6, cc + sgn * hs2 * 1.3, kc, 2.5 * u)

	# --- направление урона
	if _dmg_t > 0.0:
		var rel3 := Vector2(_dmg_from.x, _dmg_from.z) - pp
		var ang := atan2(-rel3.dot(f), rel3.dot(rt))
		draw_arc(cc, 90.0 * u, ang - 0.35, ang + 0.35, 16, Color(1.0, 0.2, 0.2, _dmg_t), 6.0 * u, true)

	# --- виньетка урона / низкого здоровья
	var va := _dmg_t * 0.45
	if hp_k < 0.3:
		va = maxf(va, 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	if va > 0.01:
		var e0 := Color(0.8, 0.0, 0.05, va)
		var e1 := Color(0.8, 0.0, 0.05, 0.0)
		var t := 70.0 * u
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x - t, t), Vector2(t, t)]), PackedColorArray([e0, e0, e1, e1]))
		draw_polygon(PackedVector2Array([Vector2(0, vp.y), Vector2(t, vp.y - t), Vector2(vp.x - t, vp.y - t), Vector2(vp.x, vp.y)]), PackedColorArray([e0, e1, e1, e0]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(t, t), Vector2(t, vp.y - t), Vector2(0, vp.y)]), PackedColorArray([e0, e1, e1, e0]))
		draw_polygon(PackedVector2Array([Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(vp.x - t, vp.y - t), Vector2(vp.x - t, t)]), PackedColorArray([e0, e0, e1, e1]))

	# --- уведомления
	var ny := vp.y * 0.26
	for n in _notes:
		var a2 := clampf(float(n["t"]) / 0.4, 0.0, 1.0)
		var c: Color = n["color"]
		_text(font, Vector2(0, ny), String(n["text"]), int(26 * u), Color(c.r, c.g, c.b, a2), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		ny += 34.0 * u

	# --- потёки слюны на экране
	if _slime_t > 0.0 and not _blobs.is_empty():
		var sa := clampf(_slime_t / _slime_max, 0.0, 1.0)
		var flow := 1.0 - sa
		for b in _blobs:
			var bp: Vector2 = b["p"]
			var br: float = b["r"]
			var dl: float = b["drip"] * flow
			var sc := Color(0.55, 1.0, 0.85, 0.32 * sa)
			draw_rect(Rect2(bp.x - br * 0.18, bp.y, br * 0.36, dl), sc)
			draw_circle(bp + Vector2(0, dl), br * 0.2, sc)
			draw_circle(bp, br, sc)
			draw_circle(bp + Vector2(br * 0.35, br * 0.25), br * 0.45, Color(0.55, 1.0, 0.85, 0.22 * sa))
			draw_circle(bp - Vector2(br, br) * 0.3, br * 0.18, Color(1, 1, 1, 0.35 * sa))

	# --- подсказка обучения
	if _tip_t > 0.0 and _tip != "":
		var ta := clampf(_tip_t / 0.5, 0.0, 1.0)
		var tw := minf(vp.x * 0.5, 620.0 * u)
		var tr := Rect2((vp.x - tw) * 0.5, vp.y * 0.62, tw, 44.0 * u)
		draw_rect(tr, Color(0.03, 0.05, 0.12, 0.7 * ta))
		draw_rect(tr, Color(0.4, 0.8, 1.0, 0.6 * ta), false, 2.0)
		_text(font, tr.position + Vector2(0, 29.0 * u), _tip, int(18 * u), Color(0.9, 0.97, 1.0, ta), HORIZONTAL_ALIGNMENT_CENTER, tw)

	# --- FPS
	if bool(GameState.get_setting("show_fps", false)):
		var fps_txt := "%d FPS · 3D %d%%" % [int(Engine.get_frames_per_second()), int(Perf.current_scale * 100.0)]
		_text(font, Vector2(ml, vp.y - controls.margin_b - 70.0 * u), fps_txt, int(13 * u), Color(0.6, 1.0, 0.6))
