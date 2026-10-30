class_name WaveDirector
extends Node
## Режим выживания: волны врагов с ростом сложности, босс каждые 5 волн,
## награда за волну, зачистка локации открывает следующую.

signal wave_started(n: int)
signal wave_cleared(n: int)

var gw: GameWorld
var wave := 0
var state := "break"
var break_t := 5.0
var to_spawn: Array[String] = []
var spawn_t := 0.0
var alive_cap := 14
var hp_mult := 1.0
var killed_this_wave := 0


func start(world: GameWorld) -> void:
	gw = world
	wave = 0
	state = "break"
	break_t = 5.0


func remaining() -> int:
	return to_spawn.size() + gw.enemies.size()


func info_text() -> String:
	if state == "break":
		return "Волна %d через %d с" % [wave + 1, int(ceil(break_t))]
	return "Волна %d · врагов: %d" % [wave, remaining()]


func on_enemy_killed(_e: Enemy) -> void:
	killed_this_wave += 1


func skip_break() -> void:
	if state == "break":
		break_t = 0.0


func _process(delta: float) -> void:
	if gw == null or gw.game_over or gw.player == null:
		return
	match state:
		"break":
			break_t -= delta
			if break_t <= 0.0:
				_begin_wave()
		"fighting":
			spawn_t -= delta
			if not to_spawn.is_empty() and spawn_t <= 0.0 and gw.enemies.size() < alive_cap:
				spawn_t = maxf(0.6 - wave * 0.03, 0.25)
				_spawn(to_spawn.pop_back())
			if to_spawn.is_empty() and gw.enemies.is_empty():
				_finish_wave()


func _begin_wave() -> void:
	wave += 1
	killed_this_wave = 0
	hp_mult = 1.0 + 0.12 * float(wave - 1)
	alive_cap = mini(10 + wave, 22)
	to_spawn.clear()
	var n := 5 + wave * 3
	for i in n:
		var r := randf()
		var t := "swarmer"
		if wave >= 2 and r < 0.35:
			t = "shooter"
		if wave >= 3 and r >= 0.35 and r < 0.55:
			t = "drone"
		if wave >= 4 and r >= 0.55 and r < 0.66:
			t = "brute"
		to_spawn.append(t)
	to_spawn.shuffle()
	if wave % 5 == 0:
		to_spawn.append("boss")
	state = "fighting"
	spawn_t = 0.5
	wave_started.emit(wave)
	gw.notify.emit("ВОЛНА %d" % wave + ("  ·  БОСС: КОЛОСС" if wave % 5 == 0 else ""), Color(1.0, 0.85, 0.4))
	Sfx.play("wave")


func _finish_wave() -> void:
	state = "break"
	break_t = 8.0
	var bonus := 40 * wave
	GameState.add_particles(bonus)
	GameState.report_wave(gw.location_id, wave)
	gw.notify.emit("Волна %d пройдена  +%d частиц" % [wave, bonus], Color(0.5, 1.0, 0.6))
	if wave == GameState.WAVES_TO_CLEAR:
		var opened := GameState.mark_cleared(gw.location_id)
		var msg := "ЛОКАЦИЯ ЗАЧИЩЕНА!"
		if opened != "":
			msg += "  Открыта: " + String(GameState.LOCATION_NAMES[opened])
		gw.notify.emit(msg, Color(1.0, 0.8, 0.3))
	GameState.save_game()
	wave_cleared.emit(wave)


func _spawn(t: String) -> void:
	var flying := t == "drone"
	var pos := _spawn_point(flying, t == "boss" or t == "brute")
	var e := Enemy.new()
	e.setup(gw, t, hp_mult)
	e.position = pos
	gw.add_child(e)
	gw.enemies.append(e)
	var glow: Color = Enemy.TYPES[t]["glow"]
	gw.fx.ring(Vector3(pos.x, 0.15, pos.z), 2.0 if t != "boss" else 5.0, glow, 0.6)
	for k in 10:
		var off := Vector3(randf_range(-1.5, 1.5), randf_range(3.0, 6.0), randf_range(-1.5, 1.5))
		gw.debris.spawn(pos + off, -off * 1.4, glow, 0.12, true)


func _spawn_point(flying: bool, big: bool) -> Vector3:
	var pp := gw.player.global_position
	var lim := gw.bounds - 3.0
	for attempt in 14:
		var a := randf() * TAU
		var d := randf_range(24.0, 38.0)
		var p := pp + Vector3(cos(a) * d, 0.0, sin(a) * d)
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		if Vector2(p.x - pp.x, p.z - pp.z).length() < 14.0:
			continue
		if not flying and gw.point_blocked(p + Vector3.UP, 1.5 if big else 0.8):
			continue
		p.y = 8.0 if flying else 0.3
		return p
	return Vector3(randf_range(-lim, lim) * 0.5, 8.0 if flying else 0.3, randf_range(-lim, lim) * 0.5)
