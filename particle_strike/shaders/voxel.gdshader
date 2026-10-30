// Шейдер «частицы-вокселя». Один материал на все разрушаемые объекты,
// персонажей и врагов. Цвет и яркость свечения приходят из цвета экземпляра
// MultiMesh: rgb — цвет, a — сила свечения (0..1).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Пер-инстансные параметры (вспышка попадания, заморозка и т.п.).
instance uniform vec4 tint = vec4(0.0);
instance uniform float flash = 0.0;

uniform float glow_mult = 1.0;
uniform float edge_mult = 1.0;

varying vec3 v_local;
varying vec4 v_col;
varying float v_seed;

void vertex() {
	v_local = VERTEX;
	v_col = COLOR;
	v_seed = fract(float(INSTANCE_ID) * 0.61803398875);
}

void fragment() {
	// Подсветка рёбер куба — каждая частица читается отдельно.
	vec3 a = abs(v_local) * 2.0;
	vec3 s = smoothstep(vec3(0.70), vec3(1.0), a);
	float edge = clamp(s.x + s.y + s.z - 1.0, 0.0, 1.0);
	vec3 base = mix(v_col.rgb, tint.rgb, tint.a);
	float tw = 0.8 + 0.2 * sin(TIME * (1.3 + v_seed * 2.7) + v_seed * 40.0);
	float em = v_col.a * glow_mult * tw;
	ALBEDO = base * (0.6 + 0.4 * (1.0 - edge));
	ROUGHNESS = 0.55;
	EMISSION = base * (em * 1.6 + edge * (0.25 + v_col.a) * edge_mult) + vec3(flash);
}
