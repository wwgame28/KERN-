class_name Menus
extends Control
## Все экраны интерфейса, собранные кодом: главное меню, выбор локации,
## улучшения (персонаж и оружие), настройки, пауза, поражение, загрузка, справка.

signal start_location(id: String)
signal resume_requested
signal quit_requested
signal retry_requested

var bg: Control
var center: CenterContainer
var panel: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var loading_bar: ProgressBar
var loading_label: Label
var overlay := false
var _dots: Array = []
var _from_pause := false
var _reset_armed := false
var _stats := {}
var _wave := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	bg = Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.draw.connect(_draw_bg)
	add_child(bg)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	for i in 110:
		_dots.append([randf(), randf(), randf_range(0.004, 0.02), randf_range(2.0, 6.0), randi() % 3])
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var vp := get_viewport_rect().size
	var w := minf(860.0, vp.x - 120.0)
	var h := vp.y - 40.0
	panel.custom_minimum_size = Vector2(w, h)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.22, 0.9)
	sb.border_color = Color(0.35, 0.7, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.12, 0.2, 0.38, 0.95)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.2, 0.45, 0.9, 0.95)
	var sbd := sb.duplicate() as StyleBoxFlat
	sbd.bg_color = Color(0.06, 0.07, 0.1, 0.6)
	sbd.border_color = Color(0.3, 0.32, 0.4, 0.5)
	for cls in ["Button", "CheckButton"]:
		t.set_stylebox("normal", cls, sb)
		t.set_stylebox("hover", cls, sbh)
		t.set_stylebox("pressed", cls, sbp)
		t.set_stylebox("hover_pressed", cls, sbp)
		t.set_stylebox("disabled", cls, sbd)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, Color(0.9, 0.96, 1.0))
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(0.55, 0.58, 0.65))
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.03, 0.04, 0.09, 0.9)
	pb.border_color = Color(0.3, 0.6, 1.0, 0.6)
	pb.set_border_width_all(2)
	pb.set_corner_radius_all(22)
	pb.set_content_margin_all(22)
	t.set_stylebox("panel", "PanelContainer", pb)
	t.set_color("font_color", "Label", Color(0.85, 0.92, 1.0))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.07, 0.14, 0.9)
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.75, 1.0)
	bar_fill.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


# ---------------------------------------------------------------- фон

func _process(_delta: float) -> void:
	if visible:
		bg.queue_redraw()


func _draw_bg() -> void:
	var vp := bg.size
	bg.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.015, 0.04, 0.6 if overlay else 1.0))
	var t := Time.get_ticks_msec() * 0.001
	var cols := [Color(0.3, 0.7, 1.0), Color(1.0, 0.45, 0.2), Color(0.75, 0.4, 1.0)]
	for d in _dots:
		var x := fmod(float(d[0]) + t * float(d[2]) * 0.3, 1.0) * vp.x
		var y := fmod(float(d[1]) - t * float(d[2]) + 10.0, 1.0) * vp.y
		var s := float(d[3])
		var c: Color = cols[int(d[4])]
		var a := (0.25 if overlay else 0.55) * (0.6 + 0.4 * sin(t * 2.0 + float(d[0]) * 30.0))
		bg.draw_rect(Rect2(x, y, s, s), Color(c.r, c.g, c.b, a))


# ---------------------------------------------------------------- утилиты

func _clear() -> void:
	for c in content.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0
	visible = true
	panel.visible = true
	_reset_armed = false


func _label(text: String, size: int = 22, color: Color = Color(0.85, 0.92, 1.0), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	content.add_child(l)
	return l


func _button(text: String, cb: Callable, parent: Control = null, min_h: float = 56.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	var on_press := func() -> void:
		Sfx.play("ui")
		cb.call()
	b.pressed.connect(on_press)
	(parent if parent else content).add_child(b)
	return b


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	content.add_child(h)
	return h


func _pips(level: int, max_level: int) -> String:
	var s := ""
	for i in max_level:
		s += "■" if i < level else "□"
	return s


func hide_all() -> void:
	visible = false


# ---------------------------------------------------------------- экраны

func show_main() -> void:
	overlay = false
	_from_pause = false
	_clear()
	_label("PARTICLE STRIKE", 54, Color(0.45, 0.85, 1.0))
	_label("Мир из частиц. Разрушай всё.", 20, Color(1.0, 0.7, 0.4))
	_label("Частицы: %d" % GameState.particles, 20, Color(0.7, 0.95, 1.0))
	_button("ИГРАТЬ", show_locations)
	_button("УЛУЧШЕНИЯ", _open_shop_main)
	_button("НАСТРОЙКИ", _open_settings_main)
	_button("КАК ИГРАТЬ", show_help)


func show_locations() -> void:
	_clear()
	_label("Выбор локации", 32, Color(0.45, 0.85, 1.0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for id in GameState.LOCATIONS:
		var unlocked := GameState.is_location_unlocked(id)
		var title: String = GameState.LOCATION_NAMES[id]
		if GameState.cleared_locations.has(id):
			title += "  ★"
		var best := int(GameState.best_wave.get(id, 0))
		var txt := title + "\n" + String(GameState.LOCATION_DESC[id])
		txt += "\nРекорд: волна %d" % best if unlocked else "\nЗакрыто: пройди %d волн на прошлой локации" % GameState.WAVES_TO_CLEAR
		var b := Button.new()
		b.text = txt
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(360, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.disabled = not unlocked
		var loc: String = id
		var on_loc := func() -> void:
			Sfx.play("ui")
			start_location.emit(loc)
		b.pressed.connect(on_loc)
		grid.add_child(b)
	_button("Назад", show_main)


func show_shop(from_pause: bool) -> void:
	_from_pause = from_pause
	overlay = from_pause
	_clear()
	_label("Улучшения", 32, Color(0.45, 0.85, 1.0))
	_label("Частицы: %d" % GameState.particles, 22, Color(0.7, 0.95, 1.0))
	_label("— Персонаж —", 22, Color(1.0, 0.75, 0.4))
	for key in GameState.PLAYER_UPGRADES.keys():
		var d: Dictionary = GameState.PLAYER_UPGRADES[key]
		var lvl := GameState.upgrade_level(key)
		var mx := int(d["max"])
		var row := _row()
		var l := Label.new()
		l.text = "%s  %s\n%s" % [d["name"], _pips(lvl, mx), d["desc"]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 19)
		row.add_child(l)
		var k: String = key
		if lvl >= mx:
			var b0 := _button("МАКС", _noop, row)
			b0.disabled = true
		else:
			var cost := GameState.player_upgrade_cost(key)
			var buy := func() -> void:
				if GameState.upgrade_player(k):
					Sfx.play("build")
				show_shop(_from_pause)
			var b := _button("%d ◆" % cost, buy, row)
			b.disabled = GameState.particles < cost
			b.custom_minimum_size.x = 150
	_label("— Оружие —", 22, Color(1.0, 0.75, 0.4))
	for id in WeaponData.ORDER:
		var wd: Dictionary = WeaponData.DEFS[id]
		var wl := _label("%s (%s) — %s" % [wd["name"], wd["sub"], wd["hint"]], 20, wd["color"], HORIZONTAL_ALIGNMENT_LEFT)
		wl.add_theme_constant_override("outline_size", 4)
		wl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		var wid: String = id
		if not GameState.is_weapon_unlocked(id):
			var cost2 := int(wd["cost"])
			var unlock := func() -> void:
				if GameState.unlock_weapon(wid):
					Sfx.play("build")
				show_shop(_from_pause)
			var bu := _button("Открыть за %d ◆" % cost2, unlock)
			bu.disabled = GameState.particles < cost2
			continue
		for stat in GameState.WEAPON_UPGRADES.keys():
			var sd: Dictionary = GameState.WEAPON_UPGRADES[stat]
			var lv := GameState.weapon_level(id, stat)
			var smax := int(sd["max"])
			var r2 := _row()
			var l2 := Label.new()
			l2.text = "   %s  %s  (%s)" % [sd["name"], _pips(lv, smax), sd["desc"]]
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l2.add_theme_font_size_override("font_size", 18)
			r2.add_child(l2)
			var st: String = stat
			if lv >= smax:
				var bm := _button("МАКС", _noop, r2, 46.0)
				bm.disabled = true
			else:
				var c2 := GameState.weapon_upgrade_cost(id, stat)
				var upg := func() -> void:
					if GameState.upgrade_weapon(wid, st):
						Sfx.play("build")
					show_shop(_from_pause)
				var bb := _button("%d ◆" % c2, upg, r2, 46.0)
				bb.disabled = GameState.particles < c2
				bb.custom_minimum_size.x = 150
	_button("Назад", _back)


func _noop() -> void:
	pass


func _back() -> void:
	if _from_pause:
		show_pause()
	else:
		show_main()


func _toggle(text: String, key: String) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = bool(GameState.get_setting(key, false))
	cb.custom_minimum_size = Vector2(0, 50)
	var on_toggle := func(on: bool) -> void:
		Sfx.play("ui")
		GameState.set_setting(key, on)
	cb.toggled.connect(on_toggle)
	content.add_child(cb)


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := _row()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 260
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameState.get_setting(key, 1.0))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 44
	var val := Label.new()
	val.text = "%.2f" % s.value
	val.custom_minimum_size.x = 70
	var on_change := func(v: float) -> void:
		val.text = "%.2f" % v
		GameState.set_setting(key, v)
	s.value_changed.connect(on_change)
	row.add_child(s)
	row.add_child(val)


func show_settings(from_pause: bool) -> void:
	_from_pause = from_pause
	overlay = from_pause
	_clear()
	_label("Настройки", 32, Color(0.45, 0.85, 1.0))
	var q := int(GameState.get_setting("quality", 2))
	var cycle_q := func() -> void:
		GameState.set_setting("quality", (q + 1) % Perf.PRESETS.size())
		show_settings(_from_pause)
	_button("Качество графики: %s" % Perf.PRESETS[q]["name"], cycle_q)
	_label("Высокое — оптимально для iPhone 16 Pro Max. Изменение теней/качества применяется к новой локации.", 16, Color(0.6, 0.7, 0.85))
	_toggle("Адаптивное разрешение (держит FPS)", "adaptive")
	_toggle("120 FPS (ProMotion, сильнее греет телефон)", "fps120")
	_toggle("Помощь в прицеливании", "aim_assist")
	_toggle("Замедление времени при крупных разрушениях", "slowmo")
	_toggle("Вид от первого лица", "first_person")
	_toggle("Инверсия по вертикали", "invert_y")
	_toggle("Звук", "sound")
	_toggle("Показывать FPS", "show_fps")
	_toggle("Открыть все локации", "all_locations")
	_slider("Чувствительность", "sensitivity", 0.3, 2.5, 0.05)
	_slider("Тряска камеры", "shake", 0.0, 1.5, 0.05)
	var rb := _button("Сбросить прогресс", _noop)
	var on_reset := func() -> void:
		if _reset_armed:
			GameState.reset_progress()
			show_settings(_from_pause)
		else:
			_reset_armed = true
			rb.text = "Точно сбросить? Нажми ещё раз"
	rb.pressed.connect(on_reset)
	_button("Назад", _back)


func show_help() -> void:
	_clear()
	_label("Как играть", 32, Color(0.45, 0.85, 1.0))
	var t := ""
	t += "• Левый палец — джойстик движения (появляется там, где коснёшься).\n"
	t += "• Правый палец — свайп поворачивает камеру. Кнопку ОГОНЬ можно держать и вести прицел.\n"
	t += "• ПРИЦЕЛ — приближение (снайпер — оптика). ПРЫЖОК дважды — двойной прыжок.\n"
	t += "• РЫВОК — короткий бросок с неуязвимостью.\n"
	t += "• СТЕНА — собирает укрытие из 40 частиц. ВИХРЬ — затягивает врагов и постройки, заряжается от разрушений.\n"
	t += "• Нижняя панель — выбор оружия. 1P/3P — вид камеры.\n\n"
	t += "Всё вокруг состоит из частиц: стреляй по низу зданий — верх рухнет целиком и разобьёт всё внизу. "
	t += "Красные частицы взрываются, дерево горит, лёд хрупкий. Собирай светящиеся частицы — это валюта для улучшений. "
	t += "Быстрые разрушения поднимают КОМБО-множитель. Переживи 5 волн, чтобы открыть следующую локацию.\n\n"
	t += "Клавиатура: WASD, стрелки — обзор, Пробел, Shift — рывок, Enter — огонь, R — прицел, 1–6, Q — вихрь, E — стена, V — камера, Esc — пауза."
	_label(t, 18, Color(0.85, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_button("Назад", show_main)


func show_pause() -> void:
	overlay = true
	_from_pause = true
	_clear()
	_label("ПАУЗА", 40, Color(0.45, 0.85, 1.0))
	_label("Частицы: %d" % GameState.particles, 20, Color(0.7, 0.95, 1.0))
	_button("Продолжить", _emit_resume)
	_button("Улучшения", _open_shop_pause)
	_button("Настройки", _open_settings_pause)
	_button("Выйти в меню", _emit_quit)


func show_game_over(stats: Dictionary, wave: int) -> void:
	overlay = true
	_from_pause = false
	_stats = stats
	_wave = wave
	_clear()
	_label("ЧАСТИЦЫ РАССЕЯНЫ", 40, Color(1.0, 0.4, 0.4))
	_label("Волна: %d" % wave, 24)
	_label("Врагов уничтожено: %d" % int(stats.get("kills", 0)), 22)
	_label("Частиц разрушено: %d" % int(stats.get("voxels", 0)), 22)
	_label("Частиц собрано: %d" % int(stats.get("particles", 0)), 22, Color(0.7, 0.95, 1.0))
	_button("Ещё раз", _emit_retry)
	_button("Улучшения", _shop_from_game_over)
	_button("В меню", _emit_quit)


func _shop_from_game_over() -> void:
	show_shop(false)
	# кнопка «Назад» в магазине вернёт на экран поражения
	var back: Button = content.get_child(content.get_child_count() - 1)
	for c in back.pressed.get_connections():
		back.pressed.disconnect(c["callable"])
	back.pressed.connect(_back_to_game_over)


func _emit_resume() -> void:
	resume_requested.emit()


func _emit_quit() -> void:
	quit_requested.emit()


func _emit_retry() -> void:
	retry_requested.emit()


func _back_to_game_over() -> void:
	show_game_over(_stats, _wave)


func _open_shop_main() -> void:
	show_shop(false)


func _open_shop_pause() -> void:
	show_shop(true)


func _open_settings_main() -> void:
	show_settings(false)


func _open_settings_pause() -> void:
	show_settings(true)


func show_loading(text: String) -> void:
	overlay = false
	_clear()
	_label(text, 30, Color(0.45, 0.85, 1.0))
	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 1.0
	loading_bar.value = 0.0
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size = Vector2(0, 22)
	content.add_child(loading_bar)
	loading_label = _label("Генерация разрушаемого мира...", 18, Color(0.6, 0.75, 0.95))


func set_loading_progress(v: float) -> void:
	if is_instance_valid(loading_bar):
		loading_bar.value = v
