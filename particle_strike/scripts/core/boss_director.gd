class_name BossDirector
extends Node
## Босс песочницы — Света Салеева. Приходит через минуту игры (с предупреждением),
## после победы возвращается через 2 минуты, сильнее прежнего. Можно вызвать из паузы.

const BOSS_TYPE := "sveta"
const FIRST_DELAY := 60.0
const RESPAWN_DELAY := 120.0

var gw: GameWorld
var boss: Enemy = null
var t := 0.0
var next_spawn := FIRST_DELAY
var warned := false
var defeats := 0


func start(world: GameWorld) -> void:
	gw = world
	t = 0.0
	next_spawn = FIRST_DELAY
	warned = false


func boss_alive() -> bool:
	return is_instance_valid(boss) and boss.is_alive()


func summon_now() -> void:
	if boss_alive() or gw == null or gw.game_over:
		return
	next_spawn = t
	_spawn()


func _process(delta: float) -> void:
	if gw == null or gw.game_over or gw.player == null or boss_alive():
		return
	t += delta
	if not warned and t >= next_spawn - 6.0:
		warned = true
		var bname: String = Enemy.TYPES[BOSS_TYPE]["name"]
		gw.notify.emit(bname + " приближается…", Color(1.0, 0.65, 0.85))
		Sfx.play("wave")
	if t >= next_spawn:
		_spawn()


func _spawn() -> void:
	var pos := _spawn_point()
	var e := Enemy.new()
	e.setup(gw, BOSS_TYPE, 1.0 + 0.3 * float(defeats))
	e.position = pos
	gw.add_child(e)
	gw.enemies.append(e)
	e.died.connect(_on_boss_died)
	boss = e
	var glow: Color = Enemy.TYPES[BOSS_TYPE]["glow"]
	gw.fx.ring(Vector3(pos.x, 0.15, pos.z), 7.0, glow, 0.9)
	for k in 60:
		var off := Vector3(randf_range(-3.0, 3.0), randf_range(3.0, 9.0), randf_range(-3.0, 3.0))
		gw.debris.spawn(pos + off, -off * 1.4, glow, 0.06, true)
	gw.notify.emit("БОСС: " + String(Enemy.TYPES[BOSS_TYPE]["name"]).to_upper(), Color(1.0, 0.5, 0.8))
	gw.add_shake(0.4)
	gw.slowmo(0.6, 0.4)
	Sfx.play("vortex")


func _on_boss_died(_e: Enemy) -> void:
	defeats += 1
	var bonus := 600 + 250 * (defeats - 1)
	GameState.add_particles(bonus)
	GameState.save_game()
	gw.notify.emit("%s повержена!  +%d частиц" % [Enemy.TYPES[BOSS_TYPE]["name"], bonus], Color(0.6, 1.0, 0.7))
	next_spawn = t + RESPAWN_DELAY
	warned = false


func _spawn_point() -> Vector3:
	## Появляется на дороге в 26–40 м от игрока, не внутри зданий.
	var pp := gw.player.global_position
	var lim := gw.bounds - 4.0
	for attempt in 24:
		var a := randf() * TAU
		var d := randf_range(26.0, 40.0)
		var p := pp + Vector3(cos(a) * d, 0.0, sin(a) * d)
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		if Vector2(p.x - pp.x, p.z - pp.z).length() < 16.0:
			continue
		if gw.point_blocked(p + Vector3.UP, 2.0):
			continue
		return Vector3(p.x, 0.3, p.z)
	return Vector3(0.0, 0.3, -30.0 if pp.z > 0.0 else 30.0)
