extends Node
## Синтезированные звуки (без аудиофайлов — проект лёгкий и сразу запускается).
## Пул плееров + ограничение частоты одинаковых звуков.

const RATE := 22050
const POOL_SIZE := 10

# имя: [длительность, f0, f1, шум, затухание, волна(0 sin,1 square,2 saw), lowpass, громкость]
const DEFS := {
	"pistol": [0.09, 1100.0, 320.0, 0.15, 5.0, 2, 0.6, 0.5],
	"shotgun": [0.22, 180.0, 60.0, 0.85, 7.0, 1, 0.35, 0.8],
	"laser": [0.3, 1800.0, 180.0, 0.05, 4.0, 2, 0.7, 0.45],
	"rocket": [0.35, 220.0, 90.0, 0.7, 3.0, 2, 0.25, 0.7],
	"ice": [0.07, 2400.0, 1600.0, 0.3, 6.0, 0, 0.8, 0.3],
	"plasma": [0.35, 160.0, 420.0, 0.2, 3.0, 1, 0.3, 0.6],
	"explosion": [0.9, 90.0, 30.0, 0.9, 4.5, 1, 0.12, 1.0],
	"crumble": [0.6, 300.0, 80.0, 0.95, 4.0, 0, 0.3, 0.6],
	"pickup": [0.07, 1300.0, 1900.0, 0.0, 3.0, 0, 1.0, 0.25],
	"hit": [0.05, 600.0, 200.0, 0.4, 8.0, 1, 0.5, 0.35],
	"hurt": [0.18, 160.0, 90.0, 0.3, 4.0, 1, 0.4, 0.6],
	"dash": [0.22, 300.0, 900.0, 0.8, 3.0, 0, 0.2, 0.5],
	"jump": [0.12, 300.0, 700.0, 0.05, 4.0, 0, 0.8, 0.3],
	"wave": [0.7, 220.0, 440.0, 0.0, 2.0, 2, 0.4, 0.45],
	"build": [0.35, 500.0, 1500.0, 0.1, 2.5, 1, 0.5, 0.35],
	"vortex": [1.2, 60.0, 260.0, 0.5, 1.2, 2, 0.15, 0.8],
	"ui": [0.04, 900.0, 900.0, 0.0, 6.0, 0, 1.0, 0.25],
	"enemy_shot": [0.12, 500.0, 250.0, 0.2, 5.0, 1, 0.5, 0.35],
	"death": [0.45, 400.0, 60.0, 0.5, 3.0, 2, 0.35, 0.6],
	"freeze": [0.25, 3000.0, 2000.0, 0.5, 5.0, 0, 0.9, 0.3],
	"overheat": [0.4, 900.0, 200.0, 0.6, 3.0, 2, 0.5, 0.4],
}

var _streams := {}
var _music: AudioStreamPlayer
var _music_cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key in DEFS.keys():
		var d: Array = DEFS[key]
		_streams[key] = _synth(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7])
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	GameState.settings_changed.connect(_on_settings)


func _on_settings() -> void:
	if not bool(GameState.get_setting("music", true)) and _music.playing:
		_music.stop()


# ---------------------------------------------------------------- вибрация

func vibrate(ms: int) -> void:
	if bool(GameState.get_setting("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- музыка

# Аккорды-«подложки» для локаций (Гц). Частоты кратны 1/8 Гц — петля 8 с без щелчка.
const MOODS := {
	"city": [110.0, 164.75, 220.0, 261.625, 329.625],
	"village": [130.75, 196.0, 261.625, 329.625, 392.0],
	"wasteland": [73.375, 110.0, 146.875, 220.0, 293.625],
	"space": [82.375, 123.5, 164.75, 246.875, 369.875],
	"menu": [98.0, 146.875, 196.0, 293.625, 370.0],
}


func prepare_music(mood: String) -> void:
	## Генерация заранее (на экране загрузки), чтобы не было рывка в игре.
	if not _music_cache.has(mood):
		_music_cache[mood] = _pad(MOODS.get(mood, MOODS["menu"]))


func play_music(mood: String) -> void:
	if not bool(GameState.get_setting("music", true)):
		return
	prepare_music(mood)
	if _music.stream == _music_cache[mood] and _music.playing:
		return
	_music.stream = _music_cache[mood]
	_music.play()


func stop_music() -> void:
	_music.stop()


func _pad(freqs: Array) -> AudioStreamWAV:
	## Медленный эмбиент-аккорд: синусы с лёгкой расстройкой и «дыханием» громкости.
	var dur := 8.0
	var rate := 11025
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var count := freqs.size()
	for i in n:
		var t := float(i) / rate
		var s := 0.0
		for k in count:
			var f: float = freqs[k]
			var lfo := 0.55 + 0.45 * sin(TAU * t / dur * float(k % 2 + 1) + float(k))
			s += sin(TAU * f * t) * lfo
			s += sin(TAU * (f * 2.0) * t) * 0.12 * lfo
		s = s / float(count) * 0.55
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if not bool(GameState.get_setting("sound", true)):
		return
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -1000)) < 35:
		return
	_last_play[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db: float = 0.0) -> void:
	var cam := get_viewport().get_camera_3d()
	var dist := 0.0
	if cam:
		dist = cam.global_position.distance_to(pos)
	if dist > 90.0:
		return
	play(sound, volume_db - dist * 0.25)


func _synth(dur: float, f0: float, f1: float, noise: float, decay: float, wave: int, lp: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp_state := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 13.0 + dur * 1000.0)
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		phase += f / RATE
		var s := 0.0
		match wave:
			0:
				s = sin(TAU * phase)
			1:
				s = 0.6 if fmod(phase, 1.0) < 0.5 else -0.6
			_:
				s = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.7
		s = lerpf(s, rng.randf_range(-1.0, 1.0), noise)
		lp_state += (s - lp_state) * lp
		var env := exp(-k * decay) * minf(1.0, t * 300.0)
		var v := int(clampf(lp_state * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
