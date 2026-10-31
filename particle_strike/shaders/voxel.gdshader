// Шейдер разрушаемой материи. Каждая логическая ячейка (куб) рисуется
// как сетка мелких частиц ~5 см с тёмными зазорами и мерцанием — «мир из
// миллионов частиц» без миллионов отдельных объектов.
// Цвет и свечение приходят из цвета экземпляра MultiMesh: rgb — цвет, a — свечение 0..1.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Пер-инстансные параметры.
instance uniform vec4 tint = vec4(0.0);
instance uniform float flash = 0.0;
// Сколько мелких частиц укладывается вдоль ребра куба (размер ячейки / 5 см).
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
	vec2 g = (uv + 0.5) * sub;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash2(cell + vec2(v_seed * 91.0, v_seed * 37.0));
	float d = max(abs(f.x), abs(f.y));
	float part = 1.0 - smoothstep(0.30, 0.44, d);
	// вдали узор сливается — плавно гасим его (без муара)
	float aa = clamp(1.4 - fwidth(g.x) * 1.6, 0.0, 1.0);
	part = mix(0.8, part, aa);

	vec3 base = mix(v_col.rgb, tint.rgb, tint.a);
	vec3 pc = base * (0.72 + 0.56 * h);
	float tw = 0.75 + 0.25 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	float spark = step(0.93, h) * (0.5 + 0.5 * sin(TIME * (2.0 + h * 5.0) + h * 70.0));

	ALBEDO = mix(base * 0.22, pc, part);
	ROUGHNESS = 0.55;
	float em = v_col.a * glow_mult * tw;
	EMISSION = pc * part * (em * 1.6 + spark * aa * (0.35 + v_col.a)) + vec3(flash);
}
