// Обломки-частицы, полностью симулируемые на GPU.
// CPU только один раз записывает стартовые данные экземпляра:
//   transform.origin — точка появления,
//   custom.xyz       — начальная скорость, custom.w — время появления,
//   color.rgb        — цвет, color.a — размер*0.5 (+0.5, если частица «горячая»).
// Траектория (полёт, удар о землю, отскок, скольжение, вращение, исчезновение)
// считается аналитически в вершинном шейдере — ноль затрат CPU на кадр.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float u_time = 0.0;
uniform float gravity = 20.0;
uniform float ground_y = 0.0;
uniform float life = 3.2;
uniform float bounce = 0.32;

varying vec3 v_col;
varying float v_heat;

mat3 rot_axis(vec3 ax, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	float t = 1.0 - c;
	return mat3(
		vec3(t * ax.x * ax.x + c, t * ax.x * ax.y + s * ax.z, t * ax.x * ax.z - s * ax.y),
		vec3(t * ax.x * ax.y - s * ax.z, t * ax.y * ax.y + c, t * ax.y * ax.z + s * ax.x),
		vec3(t * ax.x * ax.z + s * ax.y, t * ax.y * ax.z - s * ax.x, t * ax.z * ax.z + c));
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float t = u_time - cd.w;
	float h = fract(float(INSTANCE_ID) * 0.7548776662);
	float lf = life * (0.7 + 0.6 * h);
	float hot = step(0.5, COLOR.a);
	float size = (COLOR.a - hot * 0.5) * 2.0;
	v_col = COLOR.rgb;
	v_heat = 0.0;
	if (t < 0.0 || t > lf) {
		VERTEX = vec3(0.0);
	} else {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float hgt = origin.y - ground_y - size * 0.5;
		float vy = cd.y;
		float g = gravity;
		float disc = vy * vy + 2.0 * g * max(hgt, 0.0);
		float vimp = sqrt(disc);
		float t1 = (vy + vimp) / g;
		vec3 off;
		float spin_t;
		if (t < t1) {
			off = vec3(cd.x * t, vy * t - 0.5 * g * t * t, cd.z * t);
			spin_t = t;
		} else {
			float tb = t - t1;
			float vb = vimp * bounce;
			float tb_end = 2.0 * vb / g;
			float tb2 = min(tb, tb_end);
			float yb = vb * tb2 - 0.5 * g * tb2 * tb2;
			float slide = (1.0 - exp(-3.0 * tb)) * 0.2;
			off = vec3(cd.x * (t1 + slide), -max(hgt, 0.0) + yb, cd.z * (t1 + slide));
			spin_t = t1 + tb2;
		}
		vec3 ax = normalize(vec3(h - 0.5, fract(h * 7.31) - 0.5, fract(h * 3.17) - 0.5) + vec3(0.001));
		mat3 R = rot_axis(ax, spin_t * (4.0 + 8.0 * h));
		float shrink = clamp((lf - t) / 0.6, 0.0, 1.0);
		VERTEX = R * (VERTEX * size * shrink) + off;
		v_heat = hot * clamp(1.0 - t / 0.9, 0.0, 1.0);
	}
}

void fragment() {
	vec3 hotc = vec3(1.7, 0.8, 0.28);
	ALBEDO = mix(v_col * 1.15, hotc, v_heat);
}
