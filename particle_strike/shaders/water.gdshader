// Вода из мерцающих частиц (непрозрачная — дёшево для мобильного GPU).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.02, 0.1, 0.2);
uniform vec3 sparkle_color : source_color = vec3(0.6, 0.85, 1.0);
uniform float flow = 0.6;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.7 + TIME * 1.3) * 0.03 + cos(wpos.z * 0.9 + TIME) * 0.03;
}

void fragment() {
	vec2 p = wpos.xz * 2.5 + vec2(TIME * flow, TIME * flow * 0.3);
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(cell);
	float sq = 1.0 - smoothstep(0.18, 0.3, max(abs(f.x), abs(f.y)));
	float aa = clamp(1.6 - fwidth(p.x) * 2.5, 0.0, 1.0);
	float tw = pow(0.5 + 0.5 * sin(TIME * (2.0 + h * 3.0) + h * 50.0), 4.0);
	ALBEDO = deep_color;
	METALLIC = 0.3;
	ROUGHNESS = 0.08;
	EMISSION = sparkle_color * sq * aa * tw * step(0.55, h) * 1.4 + deep_color * 0.3;
}
