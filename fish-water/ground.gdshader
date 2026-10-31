shader_type spatial;

uniform vec3 color : source_color = vec3(0.82, 0.72, 0.52);
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D caustic_tex : filter_linear_mipmap, repeat_enable;
uniform float caustic_scale = 0.22;
uniform float caustic_strength = 0.9;
uniform bool displace = true;
uniform float dune_height = 0.3;
uniform float back_slope = 0.6;
uniform float half_depth = 7.0;
uniform float lump = 0.0;

varying vec3 wpos;

float height(vec2 xz) {
	return (textureLod(detail, xz * 0.04, 0.0).r - 0.5) * 2.0 * dune_height - xz.y / half_depth * back_slope;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (displace) {
		float e = 0.2;
		VERTEX.y += height(w.xz);
		NORMAL = normalize(vec3(height(w.xz - vec2(e, 0.0)) - height(w.xz + vec2(e, 0.0)), 2.0 * e,
				height(w.xz - vec2(0.0, e)) - height(w.xz + vec2(0.0, e))));
	} else if (lump > 0.0) {
		VERTEX += NORMAL * (textureLod(detail, VERTEX.xz * 0.6 + VERTEX.y * 0.4 + w.xz, 0.0).r - 0.5) * lump;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(detail, wpos.xz * 0.5 + wpos.y * 0.3).r;
	vec3 c = color * (0.8 + 0.35 * n);
	vec2 cuv = wpos.xz * caustic_scale;
	float c1 = texture(caustic_tex, cuv + vec2(TIME * 0.03, TIME * 0.02)).r;
	float c2 = texture(caustic_tex, cuv * 1.3 - vec2(TIME * 0.025, -TIME * 0.035)).r;
	float up = clamp((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, 0.0, 1.0);
	c += vec3(0.8, 1.0, 1.0) * pow(1.0 - min(c1, c2), 6.0) * caustic_strength * up;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
