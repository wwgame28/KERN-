// Небо: градиент, солнце/луна, звёзды-частицы и туманность.
// TIME специально НЕ используется: тогда карта отражений считается один раз,
// а не каждый кадр (важно для мобильного GPU).
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.05, 0.08, 0.25);
uniform vec3 horizon_color : source_color = vec3(0.9, 0.45, 0.25);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.03, 0.05);
uniform vec3 sun_color : source_color = vec3(1.0, 0.75, 0.45);
uniform float sun_size = 0.025;
uniform float horizon_sharp = 0.35;
uniform float star_amount = 0.0;
uniform float nebula = 0.0;
uniform vec3 nebula_color : source_color = vec3(0.6, 0.2, 0.9);
uniform vec3 nebula_color2 : source_color = vec3(0.1, 0.5, 1.0);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, horizon_sharp, h));
	col = mix(col, bottom_color, 1.0 - smoothstep(-0.25, 0.0, h));
	if (LIGHT0_ENABLED) {
		float sd = dot(d, normalize(LIGHT0_DIRECTION));
		col += sun_color * (smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.6, sd) * 3.0);
		col += sun_color * pow(max(sd, 0.0), 10.0) * 0.45;
	}
	if (nebula > 0.0) {
		float n = vnoise(d * 3.0) * 0.6 + vnoise(d * 7.0) * 0.4;
		float n2 = vnoise(d * 4.0 + vec3(5.0));
		col += mix(nebula_color, nebula_color2, n2) * smoothstep(0.45, 0.85, n) * nebula * smoothstep(-0.1, 0.3, h);
	}
	if (star_amount > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 sp = d * 160.0;
		vec3 cell = floor(sp);
		float r = hash3(cell);
		vec3 f = fract(sp) - 0.5;
		float star = step(1.0 - star_amount * 0.03, r) * (1.0 - smoothstep(0.12, 0.3, max(max(abs(f.x), abs(f.y)), abs(f.z))));
		col += vec3(0.8, 0.9, 1.0) * star * (0.5 + r * 1.5) * smoothstep(-0.05, 0.25, h);
	}
	COLOR = col;
}
