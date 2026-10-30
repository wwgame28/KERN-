class_name WeaponData
## Описание всех видов оружия. Значения — базовые, улучшения масштабируют их.

enum Element { NONE, ENERGY, EXPLOSIVE, LASER, ICE, PLASMA, FIRE }

const ORDER := ["pistol", "shotgun", "sniper", "rocket", "ice", "plasma"]

const DEFS := {
	"pistol": {
		"name": "Пистолет", "sub": "энергия", "color": Color(0.3, 0.6, 1.0), "cost": 0,
		"kind": "bolt", "damage": 16.0, "radius": 0.75, "interval": 0.17, "heat": 0.06,
		"speed": 95.0, "pellets": 1, "spread": 0.5, "element": Element.ENERGY,
		"hint": "Шанс цепной молнии на ближайшего врага",
	},
	"shotgun": {
		"name": "Дробовик", "sub": "взрывные", "color": Color(1.0, 0.55, 0.15), "cost": 300,
		"kind": "bolt", "damage": 11.0, "radius": 0.95, "interval": 0.8, "heat": 0.24,
		"speed": 75.0, "pellets": 8, "spread": 5.5, "element": Element.EXPLOSIVE,
		"hint": "Дробь взрывается и поджигает дерево",
	},
	"sniper": {
		"name": "Снайпер", "sub": "лазер", "color": Color(0.78, 0.35, 1.0), "cost": 500,
		"kind": "laser", "damage": 120.0, "radius": 0.6, "interval": 1.0, "heat": 0.34,
		"speed": 0.0, "pellets": 1, "spread": 0.0, "element": Element.LASER, "pierce": 16,
		"hint": "Прожигает тоннель и пробивает врагов насквозь",
	},
	"rocket": {
		"name": "Ракетница", "sub": "фрагменты", "color": Color(1.0, 0.32, 0.25), "cost": 800,
		"kind": "rocket", "damage": 130.0, "radius": 3.2, "interval": 1.15, "heat": 0.42,
		"speed": 40.0, "pellets": 1, "spread": 0.0, "element": Element.EXPLOSIVE,
		"hint": "Большой взрыв + разлёт осколков",
	},
	"ice": {
		"name": "Ледяное", "sub": "заморозка", "color": Color(0.55, 0.92, 1.0), "cost": 600,
		"kind": "bolt", "damage": 8.0, "radius": 1.3, "interval": 0.09, "heat": 0.045,
		"speed": 60.0, "pellets": 1, "spread": 1.6, "element": Element.ICE,
		"hint": "Замораживает врагов и превращает стены в хрупкий лёд",
	},
	"plasma": {
		"name": "Плазма", "sub": "разрушение", "color": Color(0.35, 1.0, 0.45), "cost": 1200,
		"kind": "plasma", "damage": 70.0, "radius": 1.45, "interval": 0.65, "heat": 0.3,
		"speed": 22.0, "pellets": 1, "spread": 0.0, "element": Element.PLASMA,
		"hint": "Сфера плазмы проедает всё на пути",
	},
}


static func stat(id: String, key: String) -> float:
	var d: Dictionary = DEFS[id]
	var base: float = float(d.get(key, 0.0))
	match key:
		"damage":
			return base * (1.0 + 0.2 * GameState.weapon_level(id, "dmg"))
		"radius":
			return base * (1.0 + 0.15 * GameState.weapon_level(id, "radius"))
		"interval":
			return base / (1.0 + 0.12 * GameState.weapon_level(id, "rate"))
		"cool":
			return 0.55 * (1.0 + 0.2 * GameState.weapon_level(id, "cool"))
	return base


static func color(id: String) -> Color:
	return DEFS[id]["color"]
