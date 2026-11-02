class_name Hud
extends CanvasLayer
## Minimal HUD: planet and gravity status, context prompt, FPS,
## touch controls (mobile) and the portal dialog.
## The HUD never moves the player itself - it only feeds Input Actions / PlayerInput.

const DESKTOP_HINT: String = "WASD — ходьба · мышь — камера (клик; Esc — отпустить) · стрелки — камера · Space — прыжок · E — действие · G — гравитация"
const TOUCH_HINT: String = "Стик слева — ходьба · свайп справа — камера · «Прыжок», «Грав.», «Действие» — кнопки справа"
const HINT_DIM_ALPHA: float = 0.45

## Show touch controls even on PC (handy for testing the layout with a touchscreen).
@export var force_touch_controls: bool = false
@export var hint_visible_seconds: float = 12.0
@export var toast_seconds: float = 2.2
## Base distance from the screen edges, in virtual pixels (on top of the device safe area).
@export var edge_margin: float = 16.0

var _player: PlayerController = null
var _gravity: GravityController = null
var _focused: Interactable = null
var _touch_enabled: bool = false
var _gameplay_active: bool = true
var _hint_time: float = 0.0
var _toast_time: float = 0.0
var _fps_timer: float = 0.0

@onready var _safe_area: Control = $Root/SafeArea
@onready var _planet_label: Label = $Root/SafeArea/TopBar/PlanetLabel
@onready var _gravity_label: Label = $Root/SafeArea/TopBar/GravityLabel
@onready var _hint_label: Label = $Root/SafeArea/TopBar/HintLabel
@onready var _fps_label: Label = $Root/SafeArea/StatusBox/FpsLabel
@onready var _prompt_label: Label = $Root/SafeArea/PromptLabel
@onready var _toast_label: Label = $Root/SafeArea/ToastLabel
@onready var _touch_controls: Control = $Root/SafeArea/TouchControls
@onready var _look_area: TouchLookArea = $Root/SafeArea/TouchControls/LookArea
@onready var _joystick: VirtualJoystick = $Root/SafeArea/TouchControls/Joystick
@onready var _gravity_button: TouchActionButton = $Root/SafeArea/TouchControls/GravityButton
@onready var _interact_button: TouchActionButton = $Root/SafeArea/TouchControls/InteractButton
@onready var _jump_button: TouchActionButton = $Root/SafeArea/TouchControls/JumpButton
@onready var _portal_dialog: PortalDialog = $Root/PortalDialog


func _ready() -> void:
	_touch_enabled = force_touch_controls or _is_touch_device()
	_touch_controls.visible = _touch_enabled
	_look_area.add_blocker(_joystick)
	_look_area.add_blocker(_gravity_button)
	_look_area.add_blocker(_interact_button)
	_look_area.add_blocker(_jump_button)
	_look_area.look_dragged.connect(_on_look_dragged)
	_interact_button.hide()
	_prompt_label.hide()
	_toast_label.hide()
	_hint_label.text = TOUCH_HINT if _touch_enabled else DESKTOP_HINT
	_hint_time = hint_visible_seconds
	_portal_dialog.closed.connect(_on_portal_dialog_closed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func setup(player: PlayerController, gravity: GravityController, planet: Planet) -> void:
	_player = player
	_gravity = gravity
	_planet_label.text = planet.display_name
	# On phones/tablets the mouse is never captured: touches also emulate mouse clicks.
	_player.input.mouse_capture_enabled = not OS.has_feature("mobile")
	_player.interactor.focus_changed.connect(_on_focus_changed)
	_player.respawned.connect(_on_player_respawned)
	_gravity.gravity_changed.connect(_on_gravity_changed)
	_update_gravity_label()


func show_portal_dialog(portal: Portal) -> void:
	_set_gameplay_active(false)
	_portal_dialog.open(portal)


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.show()
	_toast_time = toast_seconds


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_label.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast_label.hide()

	if _hint_time > 0.0:
		# The control hint stays on screen; after a while it just becomes less prominent.
		_hint_time -= delta
		_hint_label.modulate.a = lerpf(HINT_DIM_ALPHA, 1.0, clampf(_hint_time, 0.0, 1.0))


func _set_gameplay_active(active: bool) -> void:
	_gameplay_active = active
	if _player != null:
		_player.input.enabled = active
		if not active:
			_player.input.release_mouse()
	_touch_controls.visible = _touch_enabled and active
	_refresh_prompt()


func _refresh_prompt() -> void:
	var has_target: bool = _gameplay_active and _focused != null and is_instance_valid(_focused)
	if not has_target:
		_prompt_label.hide()
		_interact_button.hide()
		return
	if _touch_enabled:
		_prompt_label.text = "«Действие» — %s" % _focused.prompt_text
		_interact_button.show()
	else:
		_prompt_label.text = "[E] %s" % _focused.prompt_text
	_prompt_label.show()


func _update_gravity_label() -> void:
	if _gravity == null:
		return
	_gravity_label.text = "Гравитация: %s · %.1f м/с²" % [_gravity.get_mode_name(), _gravity.get_strength()]
	_gravity_button.set_label("Грав.")


func _apply_safe_area() -> void:
	var left: float = 0.0
	var top: float = 0.0
	var right: float = 0.0
	var bottom: float = 0.0
	# The display safe area is only meaningful on phones/tablets (notch, rounded corners).
	if OS.has_feature("mobile"):
		var window_size: Vector2i = DisplayServer.window_get_size()
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var visible_size: Vector2 = get_viewport().get_visible_rect().size
			var to_virtual: Vector2 = visible_size / Vector2(window_size)
			var max_x: float = visible_size.x * 0.15
			var max_y: float = visible_size.y * 0.15
			left = clampf(safe.position.x * to_virtual.x, 0.0, max_x)
			top = clampf(safe.position.y * to_virtual.y, 0.0, max_y)
			right = clampf((window_size.x - safe.end.x) * to_virtual.x, 0.0, max_x)
			bottom = clampf((window_size.y - safe.end.y) * to_virtual.y, 0.0, max_y)
	_safe_area.offset_left = edge_margin + left
	_safe_area.offset_top = edge_margin + top
	_safe_area.offset_right = -(edge_margin + right)
	_safe_area.offset_bottom = -(edge_margin + bottom)


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _on_look_dragged(relative: Vector2) -> void:
	if _player != null:
		_player.input.add_touch_look(relative)


func _on_focus_changed(interactable: Interactable) -> void:
	_focused = interactable
	_refresh_prompt()


func _on_gravity_changed(_mode: int, _strength: float) -> void:
	_update_gravity_label()
	show_toast("Гравитация: %s (%.1f м/с²)" % [_gravity.get_mode_name(), _gravity.get_strength()])


func _on_player_respawned() -> void:
	show_toast("Возврат на точку высадки")


func _on_portal_dialog_closed() -> void:
	# Short delay so the key/tap that closed the dialog does not also jump or re-open it.
	await get_tree().create_timer(0.15).timeout
	if not _portal_dialog.visible:
		_set_gameplay_active(true)
