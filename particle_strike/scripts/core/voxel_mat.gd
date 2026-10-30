class_name VoxelMat
## Материалы частиц-вокселей: цвет, свечение, прочность, горючесть, взрывоопасность.

enum {
	EMPTY, CONCRETE, GLASS, NEON_PINK, NEON_CYAN, WOOD, ROOF, LEAVES, STONE, METAL,
	EXPLOSIVE, ICE, CRYSTAL, SAND, ROCK, ASTEROID, WINDOW_DARK, PLASTER, TRUNK, HAY,
	RUST, BUILD, GOLD, PINE,
}

const FLAG_FLAMMABLE := 1
const FLAG_EXPLOSIVE := 2
const FLAG_BRITTLE := 4

# Цвет (rgb) + сила свечения (a).
const COLORS := [
	Color(0, 0, 0, 0),             # EMPTY
	Color(0.32, 0.36, 0.46, 0.05), # CONCRETE
	Color(1.0, 0.72, 0.38, 0.85),  # GLASS (горящие окна)
	Color(1.0, 0.25, 0.7, 1.0),    # NEON_PINK
	Color(0.2, 0.85, 1.0, 1.0),    # NEON_CYAN
	Color(0.55, 0.36, 0.2, 0.04),  # WOOD
	Color(0.62, 0.2, 0.14, 0.05),  # ROOF
	Color(0.24, 0.55, 0.2, 0.12),  # LEAVES
	Color(0.5, 0.5, 0.52, 0.03),   # STONE
	Color(0.35, 0.4, 0.48, 0.08),  # METAL
	Color(1.0, 0.3, 0.12, 0.9),    # EXPLOSIVE
	Color(0.6, 0.9, 1.0, 0.55),    # ICE
	Color(0.7, 0.35, 1.0, 0.95),   # CRYSTAL
	Color(0.85, 0.66, 0.42, 0.04), # SAND
	Color(0.55, 0.38, 0.28, 0.03), # ROCK
	Color(0.3, 0.27, 0.36, 0.05),  # ASTEROID
	Color(0.08, 0.1, 0.16, 0.02),  # WINDOW_DARK
	Color(0.86, 0.8, 0.68, 0.04),  # PLASTER
	Color(0.36, 0.24, 0.15, 0.02), # TRUNK
	Color(0.9, 0.78, 0.35, 0.08),  # HAY
	Color(0.6, 0.3, 0.16, 0.05),   # RUST
	Color(0.3, 0.95, 1.0, 0.9),    # BUILD (стены игрока)
	Color(1.0, 0.82, 0.3, 0.6),    # GOLD
	Color(0.12, 0.38, 0.22, 0.1),  # PINE
]

# 0 — разрушается сразу, 1 — почти неразрушим.
const HARDNESS := [
	0.0, 0.35, 0.0, 0.1, 0.1, 0.15, 0.2, 0.0, 0.45, 0.6,
	0.0, 0.0, 0.3, 0.1, 0.4, 0.4, 0.0, 0.2, 0.25, 0.0,
	0.4, 0.3, 0.3, 0.0,
]

const FLAGS := [
	0, 0, FLAG_BRITTLE, FLAG_BRITTLE, FLAG_BRITTLE, FLAG_FLAMMABLE, FLAG_FLAMMABLE, FLAG_FLAMMABLE, 0, 0,
	FLAG_EXPLOSIVE, FLAG_BRITTLE, FLAG_BRITTLE, 0, 0, 0, FLAG_BRITTLE, 0, FLAG_FLAMMABLE, FLAG_FLAMMABLE,
	0, 0, 0, FLAG_FLAMMABLE,
]

# Сколько «частиц-ресурсов» даёт материал (множитель).
const VALUE := [
	0.0, 1.0, 1.2, 2.0, 2.0, 1.0, 1.0, 0.6, 1.0, 1.4,
	2.0, 0.8, 3.0, 0.8, 1.0, 1.2, 1.0, 1.0, 1.0, 0.6,
	1.2, 0.0, 4.0, 0.6,
]


static func has_flag(mat: int, flag: int) -> bool:
	return (int(FLAGS[mat]) & flag) != 0


static func hardness(mat: int) -> float:
	return float(HARDNESS[mat])


static func base_color(mat: int) -> Color:
	return COLORS[mat]


static func vary(mat: int, seed_idx: int) -> Color:
	## Детерминированная вариация оттенка для каждой частицы.
	var c: Color = COLORS[mat]
	var h := ((seed_idx * 73856093) ^ (seed_idx >> 7) * 19349663) & 0xFFFF
	var f := 0.82 + float(h % 1000) / 1000.0 * 0.3
	var a := c.a
	if mat == GLASS:
		# часть окон тёмные, часть — холодный свет
		var r := h % 7
		if r == 0:
			return Color(0.25, 0.75, 1.0, 0.8)
		elif r == 1:
			return Color(0.12, 0.14, 0.22, 0.05)
	return Color(c.r * f, c.g * f, c.b * f, a)
