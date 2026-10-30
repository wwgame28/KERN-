extends Node
## Глобальное состояние: валюта (частицы), улучшения, открытые локации,
## настройки и сохранение в user://.

signal particles_changed(value: int)
signal settings_changed

const SAVE_PATH := "user://particle_strike_save.json"
const LOCATIONS := ["city", "village", "wasteland", "space"]
const LOCATION_NAMES := {
	"city": "Город", "village": "Деревня", "wasteland": "Пустошь", "space": "Космос",
}
const LOCATION_DESC := {
	"city": "Ночной мегаполис. Небоскрёбы рушатся целиком.",
	"village": "Закатная деревня: дерево горит, мосты обваливаются.",
	"wasteland": "Руины в пыли, ржавые машины-бомбы и кристаллы.",
	"space": "Орбитальная платформа. Низкая гравитация!",
}
const WAVES_TO_CLEAR := 5

const PLAYER_UPGRADES := {
	"hp": {"name": "Здоровье", "desc": "+20 к макс. здоровью", "max": 5, "base": 120},
	"shield": {"name": "Щит-броня", "desc": "+15 к щиту", "max": 5, "base": 120},
	"speed": {"name": "Скорость", "desc": "+8% к скорости бега", "max": 5, "base": 100},
	"magnet": {"name": "Магнит частиц", "desc": "+1.5 м к радиусу сбора", "max": 5, "base": 80},
	"dash": {"name": "Рывок", "desc": "-0.2 с перезарядки рывка", "max": 4, "base": 150},
	"vortex": {"name": "Гравивихрь", "desc": "Заряжается на 20% быстрее", "max": 3, "base": 250},
}
const WEAPON_UPGRADES := {
	"dmg": {"name": "Урон", "desc": "+20% урона", "max": 5, "base": 90},
	"radius": {"name": "Разрушение", "desc": "+15% радиуса", "max": 5, "base": 90},
	"rate": {"name": "Темп", "desc": "+12% скорострельности", "max": 5, "base": 110},
	"cool": {"name": "Охлаждение", "desc": "+20% к остыванию", "max": 5, "base": 70},
}

var particles := 0
var total_collected := 0
var weapons := {}
var upgrades := {}
var unlocked_locations: Array = ["city"]
var cleared_locations: Array = []
var best_wave := {}
var settings := {
	"quality": 2,
	"adaptive": true,
	"fps120": false,
	"sensitivity": 1.0,
	"aim_assist": true,
	"slowmo": true,
	"shake": 1.0,
	"show_fps": false,
	"first_person": false,
	"all_locations": false,
	"invert_y": false,
	"sound": true,
	"music": true,
	"vibration": true,
	"tips_shown": false,
}


func _ready() -> void:
	_reset_defaults()
	load_game()


func _reset_defaults() -> void:
	particles = 0
	total_collected = 0
	weapons = {}
	for id in WeaponData.ORDER:
		weapons[id] = {"unlocked": id == "pistol", "dmg": 0, "radius": 0, "rate": 0, "cool": 0}
	upgrades = {}
	for k in PLAYER_UPGRADES.keys():
		upgrades[k] = 0
	unlocked_locations = ["city"]
	cleared_locations = []
	best_wave = {}


# ---------- Валюта ----------

func add_particles(n: int) -> void:
	if n <= 0:
		return
	particles += n
	total_collected += n
	particles_changed.emit(particles)


func spend(n: int) -> bool:
	if particles < n:
		return false
	particles -= n
	particles_changed.emit(particles)
	save_game()
	return true


# ---------- Оружие ----------

func is_weapon_unlocked(id: String) -> bool:
	return bool(weapons.get(id, {}).get("unlocked", false))


func weapon_level(id: String, stat_key: String) -> int:
	return int(weapons.get(id, {}).get(stat_key, 0))


func unlock_weapon(id: String) -> bool:
	if is_weapon_unlocked(id):
		return false
	var cost: int = int(WeaponData.DEFS[id]["cost"])
	if not spend(cost):
		return false
	weapons[id]["unlocked"] = true
	save_game()
	return true


func weapon_upgrade_cost(id: String, stat_key: String) -> int:
	var lvl := weapon_level(id, stat_key)
	var base: int = int(WEAPON_UPGRADES[stat_key]["base"])
	var tier: float = 1.0 + float(WeaponData.ORDER.find(id)) * 0.25
	return int(base * tier * pow(1.55, lvl))


func upgrade_weapon(id: String, stat_key: String) -> bool:
	var lvl := weapon_level(id, stat_key)
	if lvl >= int(WEAPON_UPGRADES[stat_key]["max"]):
		return false
	if not spend(weapon_upgrade_cost(id, stat_key)):
		return false
	weapons[id][stat_key] = lvl + 1
	save_game()
	return true


# ---------- Персонаж ----------

func upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))


func player_upgrade_cost(key: String) -> int:
	var lvl := upgrade_level(key)
	return int(int(PLAYER_UPGRADES[key]["base"]) * pow(1.6, lvl))


func upgrade_player(key: String) -> bool:
	var lvl := upgrade_level(key)
	if lvl >= int(PLAYER_UPGRADES[key]["max"]):
		return false
	if not spend(player_upgrade_cost(key)):
		return false
	upgrades[key] = lvl + 1
	save_game()
	return true


# ---------- Локации ----------

func is_location_unlocked(id: String) -> bool:
	return bool(settings.get("all_locations", false)) or unlocked_locations.has(id)


func mark_cleared(id: String) -> String:
	## Возвращает id новой открытой локации (или "").
	if not cleared_locations.has(id):
		cleared_locations.append(id)
	var i := LOCATIONS.find(id)
	var opened := ""
	if i >= 0 and i + 1 < LOCATIONS.size():
		var next_id: String = LOCATIONS[i + 1]
		if not unlocked_locations.has(next_id):
			unlocked_locations.append(next_id)
			opened = next_id
	save_game()
	return opened


func report_wave(id: String, wave: int) -> void:
	if wave > int(best_wave.get(id, 0)):
		best_wave[id] = wave
		save_game()


# ---------- Настройки ----------

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_game()
	settings_changed.emit()


func get_setting(key: String, default_value: Variant = null) -> Variant:
	return settings.get(key, default_value)


# ---------- Сохранение ----------

func save_game() -> void:
	var data := {
		"particles": particles,
		"total": total_collected,
		"weapons": weapons,
		"upgrades": upgrades,
		"unlocked": unlocked_locations,
		"cleared": cleared_locations,
		"best": best_wave,
		"settings": settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	particles = int(d.get("particles", 0))
	total_collected = int(d.get("total", 0))
	var w: Dictionary = d.get("weapons", {})
	for id in w.keys():
		if weapons.has(id):
			var src: Dictionary = w[id]
			for k in src.keys():
				if k == "unlocked":
					weapons[id][k] = bool(src[k])
				else:
					weapons[id][k] = int(src[k])
	var u: Dictionary = d.get("upgrades", {})
	for k in u.keys():
		if upgrades.has(k):
			upgrades[k] = int(u[k])
	unlocked_locations = d.get("unlocked", ["city"])
	if not unlocked_locations.has("city"):
		unlocked_locations.append("city")
	cleared_locations = d.get("cleared", [])
	best_wave = d.get("best", {})
	var s: Dictionary = d.get("settings", {})
	for k in s.keys():
		if settings.has(k):
			settings[k] = s[k]


func reset_progress() -> void:
	var keep := settings.duplicate()
	_reset_defaults()
	settings = keep
	save_game()
	particles_changed.emit(particles)
