shader_type spatial;
render_mode cull_disabled;

// UV.x = part id (0 body, 1 caudal, 2 dorsal/anal, 3 pectoral, 4 eye), UV.y = fin flex weight
uniform float swim_phase = 0.0;
uniform float swim_amount = 0.03;
uniform float fin_phase = 0.0;

varying float part;
varying vec2 body_uv;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	part = UV.x;
	body_uv = UV2;
	float w = clamp((VERTEX.z + 0.3) / 1.2, 0.0, 1.0);
	VERTEX.x += sin(VERTEX.z * 5.0 - swim_phase) * swim_amount * (0.2 + w * w * 2.5);
	if (part > 0.5 && part < 2.5) {
		VERTEX.x += sin(VERTEX.y * 9.0 + swim_phase * 1.5) * 0.012 * UV.y;
	} else if (part > 2.5 && part < 3.5) {
		VERTEX.y += sin(fin_phase) * 0.05 * UV.y;
		VERTEX.z += cos(fin_phase) * 0.03 * UV.y;
	}
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 0.5;
	SPECULAR = 0.5;
	if (part < 0.5) {
		vec2 g = vec2(body_uv.x * 36.0, body_uv.y * 42.0);
		g.x += mod(floor(g.y), 2.0) * 0.5;
		float d = length((fract(g) - vec2(0.5, 0.0)) * vec2(1.0, 1.3));
		c *= mix(1.0, 0.86 + 0.14 * (1.0 - smoothstep(0.35, 0.55, d)), smoothstep(0.08, 0.2, body_uv.y));
		ROUGHNESS = 0.3;
	} else if (part > 3.5) {
		ROUGHNESS = 0.05;
		SPECULAR = 1.0;
	}
	ALBEDO = c;
}
