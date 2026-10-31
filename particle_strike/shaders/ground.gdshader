// Земля из микрочастиц: квадратные точки с мерцанием, дороги для города.
// Узор гаснет с расстоянием (fwidth), чтобы не было муара на телефоне.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.05, 0.06, 0.1);
uniform vec3 dot_color : source_color = vec3(0.3, 0.5, 1.0);
uniform float dot_scale = 2.0;
uniform float dot_glow = 0.6;
uniform float dot_size = 0.3;
uniform float contrast = 0.65;
uniform float roughness_val = 0.7;
uniform float metallic_val = 0.0;
uniform float road_spacing = 0.0;
uniform float road_width = 10.0;
uniform vec3 road_color : source_color = vec3(0.02, 0.02, 0.03);
uniform vec3 line_color : source_color = vec3(1.0, 0.8, 0.3);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * dot_scale;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(cell);
	float d = max(abs(f.x), abs(f.y));
	float sq = 1.0 - smoothstep(dot_size, dot_size + 0.08, d);
	float aa = clamp(1.6 - fwidth(p.x) * 2.5, 0.0, 1.0);
	sq *= aa;
	// скопления частиц 4×4 — зерно и искры там, где отдельная частица меньше пикселя
	vec2 pc = p * 0.25;
	float hc = hash(floor(pc) + vec2(7.0, 3.0));
	float aac = clamp(1.6 - fwidth(pc.x) * 2.5, 0.0, 1.0);
	float hh = mix(mix(0.5, hc, aac), h, aa);
	float tw = 0.5 + 0.5 * sin(TIME * (0.8 + hh * 2.0) + hh * 30.0);
	vec3 col = base_color * (0.7 + 0.6 * hh);
	vec3 albedo = mix(base_color * contrast, col, max(sq, (1.0 - aa) * aac * 0.6));
	float lit = max(sq, (1.0 - aa) * aac * 0.5);
	vec3 em = dot_color * lit * dot_glow * (0.15 + 0.85 * tw * step(0.72, hh));
	if (road_spacing > 0.0) {
		vec2 m = abs(mod(wpos.xz + road_spacing * 0.5, road_spacing) - road_spacing * 0.5);
		float road = step(min(m.x, m.y), road_width * 0.5);
		albedo = mix(albedo, road_color * (0.8 + 0.4 * h), road);
		em *= 1.0 - road * 0.7;
		float dash_x = step(m.x, 0.12) * step(0.5, fract(wpos.z * 0.25)) * step(road_width * 0.5, m.y);
		float dash_z = step(m.y, 0.12) * step(0.5, fract(wpos.x * 0.25)) * step(road_width * 0.5, m.x);
		em += line_color * clamp(dash_x + dash_z, 0.0, 1.0) * 1.5;
	}
	ALBEDO = albedo;
	EMISSION = em;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
}
