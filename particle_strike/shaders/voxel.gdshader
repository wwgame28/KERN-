// Шейдер разрушаемой материи. Каждая логическая ячейка (куб 25 см) рисуется
// как сетка микрочастиц ~1.25 см с зазорами и мерцанием.
// Вблизи видна каждая частица; там, где частица меньше пикселя, узор плавно
// переходит в «зерно» из скоплений частиц — без ряби и муара.
// Цвет и свечение приходят из цвета экземпляра MultiMesh: rgb — цвет, a — свечение 0..1.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Пер-инстансные параметры.
instance uniform vec4 tint = vec4(0.0);
instance uniform float flash = 0.0;
// Сколько микрочастиц укладывается вдоль ребра куба (размер ячейки / размер частицы).
instance uniform float sub = 1.0;

uniform float glow_mult = 1.0;

varying vec3 v_local;
varying vec4 v_col;
varying float v_seed;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_local = VERTEX;
	v_col = COLOR;
	v_seed = fract(float(INSTANCE_ID) * 0.61803398875);
}

void fragment() {
	// плоская нормаль из производных — куб из 8 вершин вместо 24
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, -VERTEX) < 0.0) {
		n = -n;
	}
	NORMAL = n;

	// координаты на грани куба
	vec3 a = abs(v_local);
	vec2 uv;
	if (a.x >= a.y && a.x >= a.z) {
		uv = v_local.yz;
	} else if (a.y >= a.z) {
		uv = v_local.xz;
	} else {
		uv = v_local.xy;
	}
	vec2 seed = vec2(v_seed * 91.0, v_seed * 37.0);

	// микрочастицы
	vec2 g = (uv + 0.5) * sub;
	vec2 fc = floor(g);
	vec2 f = fract(g) - 0.5;
	float hf = hash2(fc + seed);
	float part_f = 1.0 - smoothstep(0.28, 0.44, max(abs(f.x), abs(f.y)));
	float aa_f = clamp(1.3 - (fwidth(g.x) + fwidth(g.y)) * 0.9, 0.0, 1.0);

	// скопления по 4×4 частицы — «зерно» на средней дистанции
	vec2 gc = g * 0.25;
	float hc = hash2(floor(gc) + seed + vec2(17.0, 5.0));
	float aa_c = clamp(1.3 - (fwidth(gc.x) + fwidth(gc.y)) * 0.9, 0.0, 1.0);

	float h = mix(mix(0.5, hc, aa_c), hf, aa_f);
	float part = mix(0.82, part_f, aa_f);

	vec3 base = mix(v_col.rgb, tint.rgb, tint.a);
	vec3 pc = base * (0.74 + 0.52 * h);
	float tw = 0.75 + 0.25 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	float hs = mix(hc, hf, aa_f);
	float spark = step(0.94, hs) * (0.5 + 0.5 * sin(TIME * (2.0 + hs * 5.0) + hs * 70.0)) * max(aa_c, aa_f);

	ALBEDO = mix(base * 0.22, pc, part);
	ROUGHNESS = 0.55;
	float em = v_col.a * glow_mult * tw;
	EMISSION = pc * part * (em * 1.6 + spark * (0.35 + v_col.a)) + vec3(flash);
}
