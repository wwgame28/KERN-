extends Node
## Stage 1 self-test.
## Open res://tests/stage1_self_test.tscn and run it as the current scene (in Xogot or Godot).
## It loads the real main scene, drives the same Input Actions a player would use and
## shows [OK] / [FAIL] / [SKIP] for each acceptance item on screen and in the Output log.
## It does NOT replace the manual checklist: visuals and real finger input still need a human.
## Headless runs (godot --headless) quit with exit code = number of failed checks.

const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const REQUIRED_RESOURCES: Array = [
	"res://scenes/main/main.tscn",
	"res://scenes/player/player.tscn",
	"res://scenes/planets/test_planet.tscn",
	"res://scenes/portals/portal.tscn",
	"res://scenes/ui/hud.tscn",
	"res://resources/planets/test_planet_gravity.tres",
]
const REQUIRED_ACTIONS: Array = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"camera_left", &"camera_right", &"camera_up", &"camera_down",
	&"jump", &"interact", &"toggle_gravity",
]
const EXPECTED_PORTAL_MESSAGE: String = "Портал пока не активирован"
## Touch indices far from real fingers, so simulated touches never collide with them.
const FAKE_TOUCH_STICK: int = 17
const FAKE_TOUCH_BUTTON: int = 18

var _main: Node = null
var _player: PlayerController = null
var _gravity: GravityController = null
var _planet: Planet = null
var _hud: Hud = null
var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _report: Label = null


func _ready() -> void:
	_build_overlay()
	_run.call_deferred()


func _run() -> void:
	_log("COSMIC SANDBOX — самопроверка этапа 1")
	_check_resources()
	_check_input_actions()

	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Главная сцена загружается", MAIN_SCENE)
		_finish()
		return
	_main = packed.instantiate()
	add_child(_main)
	_player = _main.get_node_or_null("Player") as PlayerController
	_gravity = _main.get_node_or_null("GravityController") as GravityController
	_planet = _main.get_node_or_null("TestPlanet") as Planet
	_hud = _main.get_node_or_null("HUD") as Hud
	if _player == null or _gravity == null or _planet == null or _hud == null:
		_fail("Стартовая сцена собрана", "нет Player/GravityController/TestPlanet/HUD")
		_finish()
		return
	_pass("Стартовая сцена запущена")

	await _wait(1.0)
	_expect(_player.is_on_floor(), "Персонаж стоит на поверхности после появления",
		"y = %.2f" % _player.global_position.y)

	await _test_movement()
	await _test_jump_and_gravity()
	await _test_camera()
	await _test_portal()
	await _test_touch_controls()
	await _test_respawn()
	_finish()


# --- Checks -----------------------------------------------------------------

func _check_resources() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(path):
			missing.append(path)
	_expect(missing.is_empty(), "Нет отсутствующих ресурсов", ", ".join(missing))


func _check_input_actions() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(String(action))
	_expect(missing.is_empty(), "Все Input Actions заданы в project.godot", ", ".join(missing))


func _test_movement() -> void:
	var start: Vector3 = _player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _wait(0.6)
	Input.action_release(InputActions.MOVE_FORWARD)
	await _wait(0.3)
	var moved: Vector3 = _player.global_position - start
	var horizontal: float = Vector2(moved.x, moved.z).length()
	_expect(horizontal > 1.5, "Персонаж двигается (действие move_forward)", "смещение %.2f м" % horizontal)
	_expect(moved.z < 0.0, "Движение «вперёд» идёт от камеры (к порталу)", "dz = %.2f" % moved.z)


func _test_jump_and_gravity() -> void:
	var jump_velocity: float = _player.jump_velocity
	var normal_expected: float = jump_velocity * jump_velocity / (2.0 * _gravity.settings.normal_strength)
	var low_expected: float = jump_velocity * jump_velocity / (2.0 * _gravity.settings.low_strength)

	var normal_height: float = await _measure_jump(2.0)
	_expect(absf(normal_height - normal_expected) < normal_expected * 0.3,
		"Прыжок при нормальной гравитации", "%.2f м (ожидалось ≈ %.2f)" % [normal_height, normal_expected])

	await _tap_action(InputActions.TOGGLE_GRAVITY)
	_expect(_gravity.mode == GravityController.Mode.LOW,
		"Действие toggle_gravity включает низкую гравитацию", "сила %.1f" % _gravity.get_strength())
	var gravity_label: Label = _hud.get_node("Root/SafeArea/TopBar/GravityLabel") as Label
	_expect(gravity_label.text.contains(_gravity.settings.low_label),
		"Индикатор гравитации в HUD обновился", gravity_label.text)
	var space: RID = _player.get_world_3d().space
	var space_gravity: float = PhysicsServer3D.area_get_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY)
	_expect(is_equal_approx(space_gravity, _gravity.settings.low_strength),
		"Гравитация физического пространства тоже изменилась", "%.2f" % space_gravity)

	var low_height: float = await _measure_jump(4.5)
	_expect(absf(low_height - low_expected) < low_expected * 0.3,
		"Прыжок при низкой гравитации выше", "%.2f м (ожидалось ≈ %.2f)" % [low_height, low_expected])

	await _tap_action(InputActions.TOGGLE_GRAVITY)
	_expect(_gravity.mode == GravityController.Mode.NORMAL,
		"Повторное переключение возвращает нормальную гравитацию", "сила %.1f" % _gravity.get_strength())


func _test_camera() -> void:
	var yaw_pivot: Node3D = _player.camera_rig.get_node("YawPivot") as Node3D
	var before: float = yaw_pivot.rotation.y
	_player.input.add_touch_look(Vector2(150.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var turned: float = absf(wrapf(yaw_pivot.rotation.y - before, -PI, PI))
	_expect(turned > 0.3, "Камера вращается от ввода свайпом", "поворот %.2f рад" % turned)

	await _wait(0.5)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var distance: float = -1.0
	if camera != null:
		distance = camera.global_position.distance_to(_player.global_position)
	_expect(camera != null and distance > 1.0 and distance < 9.0,
		"Камера следует за персонажем", "расстояние %.2f м" % distance)


func _test_portal() -> void:
	var portal: Portal = get_tree().get_first_node_in_group(Portal.GROUP) as Portal
	if portal == null:
		_fail("Портал есть на сцене", "группа '%s' пуста" % Portal.GROUP)
		return
	_teleport(portal.global_position + Vector3(0.0, 0.3, 3.2))
	await _wait(0.5)
	_expect(_player.interactor.focused == portal, "Вход в зону портала замечен", "")
	var prompt: Label = _hud.get_node("Root/SafeArea/PromptLabel") as Label
	_expect(prompt.visible, "Появилась подсказка взаимодействия", prompt.text)

	await _tap_action(InputActions.INTERACT)
	await _wait(0.1)
	var dialog: PortalDialog = _hud.get_node("Root/PortalDialog") as PortalDialog
	_expect(dialog.visible, "Портал реагирует на взаимодействие (окно открыто)", "")
	_expect(dialog.get_headline_text() == EXPECTED_PORTAL_MESSAGE,
		"Сообщение «%s»" % EXPECTED_PORTAL_MESSAGE, dialog.get_headline_text())
	_expect(not _player.input.enabled, "Пока окно открыто, управление персонажем отключено", "")

	dialog.close()
	await _wait(0.4)
	_expect(not dialog.visible and _player.input.enabled, "Окно закрывается, управление возвращается", "")


func _test_touch_controls() -> void:
	var touch_root: Control = _hud.get_node("Root/SafeArea/TouchControls") as Control
	if not touch_root.is_visible_in_tree():
		_skip("Сенсорное управление", "touch-интерфейс скрыт (ПК без сенсорного экрана)")
		return

	# Layout: on-screen controls must not cover the whole screen.
	var screen: Rect2 = get_viewport().get_visible_rect()
	var covered: float = 0.0
	var inside: bool = true
	for path in ["GravityButton", "InteractButton", "JumpButton"]:
		var button: Control = touch_root.get_node(path) as Control
		var rect: Rect2 = button.get_global_rect()
		covered += rect.get_area()
		if not screen.encloses(rect):
			inside = false
	var joystick: VirtualJoystick = touch_root.get_node("Joystick") as VirtualJoystick
	covered += PI * joystick.base_radius * joystick.base_radius
	var share: float = covered / screen.get_area()
	_expect(share < 0.25, "Мобильный интерфейс не перекрывает экран", "занято ≈ %d%%" % int(share * 100.0))
	_expect(inside, "Кнопки целиком на экране", "")

	# Virtual stick -> move_forward strength.
	var stick_start: Vector2 = joystick.get_global_rect().get_center()
	var stick_end: Vector2 = stick_start + Vector2(0.0, -joystick.base_radius)
	_send_touch(FAKE_TOUCH_STICK, stick_start, true)
	await _frames(3)
	_send_drag(FAKE_TOUCH_STICK, stick_end, stick_end - stick_start)
	await _frames(3)
	var strength: float = Input.get_action_strength(InputActions.MOVE_FORWARD)
	_send_touch(FAKE_TOUCH_STICK, stick_end, false)
	await _frames(3)
	_expect(strength > 0.5, "Виртуальный стик нажимает move_forward", "сила %.2f" % strength)
	_expect(is_zero_approx(Input.get_action_strength(InputActions.MOVE_FORWARD)),
		"Отпускание стика отпускает действие", "")

	# On-screen gravity button.
	var gravity_button: Control = touch_root.get_node("GravityButton") as Control
	var mode_before: int = _gravity.mode
	var center: Vector2 = gravity_button.get_global_rect().get_center()
	_send_touch(FAKE_TOUCH_BUTTON, center, true)
	await _frames(4)
	_send_touch(FAKE_TOUCH_BUTTON, center, false)
	await _frames(4)
	_expect(_gravity.mode != mode_before, "Экранная кнопка «Грав.» меняет гравитацию",
		_gravity.get_mode_name())
	if _gravity.mode != mode_before:
		_gravity.toggle_mode()


func _test_respawn() -> void:
	_teleport(Vector3(0.0, _player.kill_height - 2.0, 0.0))
	await _frames(4)
	var distance: float = _player.global_position.distance_to(_planet.get_spawn_position())
	_expect(distance < 1.5, "Падение с планеты возвращает на точку высадки", "%.2f м от точки" % distance)


# --- Helpers ----------------------------------------------------------------

func _measure_jump(max_duration: float) -> float:
	await _wait_until_on_floor(1.5)
	var start_y: float = _player.global_position.y
	var max_y: float = start_y
	var elapsed: float = 0.0
	var released: bool = false
	await get_tree().process_frame
	Input.action_press(InputActions.JUMP)
	while elapsed < max_duration:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if not released and elapsed > 0.1:
			Input.action_release(InputActions.JUMP)
			released = true
		max_y = maxf(max_y, _player.global_position.y)
		if elapsed > 0.3 and _player.is_on_floor():
			break
	if not released:
		Input.action_release(InputActions.JUMP)
	return max_y - start_y


func _wait_until_on_floor(timeout: float) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout and not _player.is_on_floor():
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()


## Presses an action at the start of a frame (before _process), like a real key press,
## so both _process and _physics_process see it as "just pressed".
func _tap_action(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await _wait(0.1)
	Input.action_release(action)
	await _wait(0.1)


func _teleport(target: Vector3) -> void:
	_player.global_position = target
	_player.velocity = Vector3.ZERO


func _send_touch(index: int, canvas_position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = _canvas_to_window(canvas_position)
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_drag(index: int, canvas_position: Vector2, canvas_relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = _canvas_to_window(canvas_position)
	event.relative = get_viewport().get_final_transform().basis_xform(canvas_relative)
	Input.parse_input_event(event)


## Parsed input events use window pixels; HUD controls use stretched canvas units.
func _canvas_to_window(point: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * point


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, title: String, details: String) -> void:
	if condition:
		_pass(title, details)
	else:
		_fail(title, details)


func _pass(title: String, details: String = "") -> void:
	_passed += 1
	_log("[OK]   " + _format(title, details))


func _fail(title: String, details: String = "") -> void:
	_failed += 1
	_log("[FAIL] " + _format(title, details))


func _skip(title: String, details: String = "") -> void:
	_skipped += 1
	_log("[SKIP] " + _format(title, details))


func _format(title: String, details: String) -> String:
	if details.is_empty():
		return title
	return "%s — %s" % [title, details]


func _log(line: String) -> void:
	print("[SELF-TEST] " + line)
	if _report != null:
		_report.text += line + "\n"


func _finish() -> void:
	var summary: String = "ИТОГ: OK %d · FAIL %d · SKIP %d" % [_passed, _failed, _skipped]
	_log("")
	_log(summary)
	if _failed > 0:
		push_error("Stage 1 self-test: %d check(s) failed" % _failed)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(24.0, 150.0)
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	layer.add_child(panel)
	_report = Label.new()
	_report.add_theme_font_size_override("font_size", 15)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.custom_minimum_size = Vector2(740.0, 0.0)
	panel.add_child(_report)
