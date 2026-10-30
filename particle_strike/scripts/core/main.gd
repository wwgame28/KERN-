extends Node
## Точка входа: меню → загрузка локации → игра → пауза/поражение.

var world: GameWorld
var player: Player
var director: WaveDirector
var ui_layer: CanvasLayer
var hud: HUD
var controls: TouchControls
var menus: Menus
var current_location := "city"
var _loading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	menus = Menus.new()
	ui_layer.add_child(menus)
	menus.start_location.connect(start_location)
	menus.resume_requested.connect(resume)
	menus.quit_requested.connect(quit_to_menu)
	menus.retry_requested.connect(_retry)
	menus.show_main()
	Sfx.play_music("menu")


func _retry() -> void:
	start_location(current_location)


func start_location(id: String) -> void:
	if _loading:
		return
	_loading = true
	current_location = id
	await _teardown()
	menus.show_loading("Сборка мира: " + String(GameState.LOCATION_NAMES.get(id, id)))
	await get_tree().process_frame
	if bool(GameState.get_setting("music", true)):
		Sfx.prepare_music(id)

	world = GameWorld.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var spawn: Vector3 = await LevelBuilder.build(world, id, menus.set_loading_progress)

	hud = HUD.new()
	ui_layer.add_child(hud)
	controls = TouchControls.new()
	ui_layer.add_child(controls)
	ui_layer.move_child(menus, -1)

	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	player.global_position = spawn
	player.setup(world, controls)
	world.player = player

	director = WaveDirector.new()
	director.name = "Waves"
	world.add_child(director)
	world.director = director
	director.start(world)

	controls.setup(world, player)
	hud.setup(world, player, controls)
	world.player_died.connect(_on_player_died)

	menus.hide_all()
	controls.visible = true
	get_tree().paused = false
	Perf.adaptive_active = true
	world.notify.emit(String(GameState.LOCATION_NAMES.get(id, id)).to_upper(), Color(0.5, 0.9, 1.0))
	Sfx.play_music(id)
	_loading = false
	if not bool(GameState.get_setting("tips_shown", false)):
		_run_tips()


func _run_tips() -> void:
	## Подсказки при первом запуске.
	var tips := [
		"Левый палец — бег, правый — поворот камеры",
		"Держи ОГОНЬ и веди пальцем — прицел следует за ним",
		"Стреляй в низ зданий — верх рухнет целиком",
		"Светящиеся частицы — валюта. Подходи ближе — магнит соберёт",
		"Вихрь заряжается от разрушений. Стена стоит 40 частиц",
	]
	var w := world
	for t in tips:
		await get_tree().create_timer(4.5, false).timeout
		if world != w or world == null or hud == null:
			return
		hud.show_tip(t, 4.2)
	GameState.set_setting("tips_shown", true)


func _teardown() -> void:
	Perf.adaptive_active = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(controls):
		controls.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	hud = null
	controls = null
	world = null
	player = null
	director = null
	await get_tree().process_frame
	await get_tree().process_frame


func pause() -> void:
	if world == null or world.game_over or _loading or get_tree().paused:
		return
	get_tree().paused = true
	Engine.time_scale = 1.0
	if controls:
		controls.reset()
		controls.visible = false
	menus.show_pause()


func resume() -> void:
	menus.hide_all()
	get_tree().paused = false
	if controls:
		controls.reset()
		controls.visible = true
	if player:
		player.apply_upgrades()


func quit_to_menu() -> void:
	if world and director:
		GameState.report_wave(current_location, director.wave)
	GameState.save_game()
	await _teardown()
	menus.show_main()
	Sfx.play_music("menu")


func _on_player_died() -> void:
	if controls:
		controls.reset()
	await get_tree().create_timer(2.2, true, false, true).timeout
	if world == null:
		return
	if controls:
		controls.visible = false
	Engine.time_scale = 1.0
	menus.show_game_over(world.stats, director.wave if director else 0)


func _process(_delta: float) -> void:
	if controls and controls.consume("pause"):
		pause()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		if get_tree().paused:
			resume()
		else:
			pause()


func _notification(what: int) -> void:
	# свернули приложение / входящий звонок — ставим на паузу и сохраняемся
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameState.save_game()
		pause()
