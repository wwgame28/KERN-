extends Node
## Пресеты качества и адаптивное разрешение.
## Цель по умолчанию — iPhone 16 Pro Max (A18 Pro, экран 2868×1320, ProMotion 120 Гц):
## 3D рендерится в пониженном разрешении и апскейлится FSR 1.0, интерфейс остаётся чётким.

signal preset_applied

const PRESETS := [
	{"name": "Низкое", "scale": 0.6, "msaa": false, "shadows": false, "glow": false,
		"debris": 1500, "per_event": 160, "ambient": 60, "view": 120.0, "shadow_dist": 0.0},
	{"name": "Среднее", "scale": 0.72, "msaa": false, "shadows": false, "glow": true,
		"debris": 3000, "per_event": 260, "ambient": 120, "view": 160.0, "shadow_dist": 0.0},
	{"name": "Высокое", "scale": 0.82, "msaa": true, "shadows": true, "glow": true,
		"debris": 5000, "per_event": 420, "ambient": 200, "view": 200.0, "shadow_dist": 45.0},
	{"name": "Ультра", "scale": 1.0, "msaa": true, "shadows": true, "glow": true,
		"debris": 7000, "per_event": 560, "ambient": 260, "view": 240.0, "shadow_dist": 70.0},
]

const MIN_SCALE := 0.5
const STEP := 0.05

var preset: Dictionary = PRESETS[2]
var current_scale := 0.82
var target_fps := 60
var adaptive_active := false

var _last_usec := 0
var _acc_ms := 0.0
var _frames := 0
var _good_seconds := 0.0
var _cooldown := 0.0


func _ready() -> void:
	apply()
	GameState.settings_changed.connect(apply)


func quality_index() -> int:
	return clampi(int(GameState.get_setting("quality", 2)), 0, PRESETS.size() - 1)


func apply() -> void:
	preset = PRESETS[quality_index()]
	target_fps = 120 if bool(GameState.get_setting("fps120", false)) else 60
	Engine.max_fps = target_fps
	# Физика синхронно с частотой кадров — плавное движение на 120 Гц без интерполяции.
	Engine.physics_ticks_per_second = target_fps
	current_scale = float(preset["scale"])
	_apply_scale()
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if bool(preset["msaa"]) else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if bool(preset["msaa"]) else Viewport.SCREEN_SPACE_AA_FXAA
	preset_applied.emit()


func _upscale_mode() -> int:
	## FSR 1.0 в Godot 4.4 есть только в Forward+. На Mobile-рендере под Metal
	## (Godot 4.5+) берём MetalFX Spatial, иначе — билинейный апскейл.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		return Viewport.SCALING_3D_MODE_FSR
	var metalfx := "SCALING_3D_MODE_METALFX_SPATIAL"
	if ClassDB.class_has_integer_constant("Viewport", metalfx) and RenderingServer.get_current_rendering_driver_name() == "metal":
		return ClassDB.class_get_integer_constant("Viewport", metalfx)
	return Viewport.SCALING_3D_MODE_BILINEAR


func _apply_scale() -> void:
	var vp := get_viewport()
	if current_scale < 0.99:
		vp.scaling_3d_mode = _upscale_mode() as Viewport.Scaling3DMode
		vp.fsr_sharpness = 0.35
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = current_scale


func get_value(key: String) -> Variant:
	return preset.get(key)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec == 0:
		_last_usec = now
		return
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	if not adaptive_active or not bool(GameState.get_setting("adaptive", true)):
		return
	_acc_ms += frame_ms
	_frames += 1
	if _acc_ms < 1000.0:
		return
	var avg := _acc_ms / float(_frames)
	_acc_ms = 0.0
	_frames = 0
	_cooldown = maxf(_cooldown - 1.0, 0.0)
	var budget := 1000.0 / float(target_fps)
	var max_scale := float(preset["scale"])
	if avg > budget * 1.12 and current_scale > MIN_SCALE + 0.001:
		current_scale = maxf(current_scale - STEP, MIN_SCALE)
		_apply_scale()
		_good_seconds = 0.0
		_cooldown = 8.0
	elif avg < budget * 1.03:
		_good_seconds += 1.0
		if _good_seconds >= 4.0 and _cooldown <= 0.0 and current_scale < max_scale - 0.001:
			current_scale = minf(current_scale + STEP, max_scale)
			_apply_scale()
			_good_seconds = 0.0
	else:
		_good_seconds = 0.0
