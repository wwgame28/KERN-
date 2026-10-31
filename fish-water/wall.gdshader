shader_type spatial;

uniform sampler2D caustic_tex : filter_linear_mipmap, repeat_enable;
uniform float water_level = 0.0;
uniform float floor_level = -8.0;
uniform float tile = 0.35;
uniform float caustic_scale = 0.22;
uniform float caustic_strength = 0.6;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grout(vec2 f, float width) {
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	return smoothstep(width, width + 0.04, e);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = vec2(abs(wnorm.x) > 0.5 ? wpos.z : wpos.x, wpos.y);
	vec3 c;
	float g;

	if (p.y > water_level - 0.15) {
		// Above the water: large cream tiles.
		vec2 cell = floor(p / 0.7);
		g = grout(fract(p / 0.7), 0.02);
		c = vec3(0.92, 0.9, 0.84) * (0.94 + 0.06 * hash(cell));
	} else if (p.y > water_level - 0.95) {
		// Ornamental border at the waterline: gold wave scroll framed by gold lines.
		float ly = (p.y - (water_level - 0.95)) / 0.8;
		vec3 bg = vec3(0.02, 0.1, 0.3);
		vec3 gold = vec3(0.95, 0.72, 0.25);
		float wave = 0.5 + 0.28 * sin(p.x * TAU / 1.2);
		float curl = abs(length(vec2(fract(p.x / 0.6) - 0.5, (ly - 0.5) * 1.5)) - 0.22);
		float line = min(abs(ly - wave), curl);
		float frame = min(abs(ly - 0.06), abs(ly - 0.94));
		float m = 1.0 - smoothstep(0.03, 0.06, min(line, frame));
		vec2 f = fract(p / (tile * 0.5));
		g = grout(f, 0.04);
		c = mix(bg, gold, m);
	} else {
		// Underwater mosaic: blue gradient with lighter wave stripes.
		vec2 cell = floor(p / tile);
		g = grout(fract(p / tile), 0.04);
		float depth = clamp((p.y - floor_level) / (water_level - floor_level), 0.0, 1.0);
		vec3 deep = vec3(0.02, 0.12, 0.35);
		vec3 shallow = vec3(0.1, 0.55, 0.7);
		c = mix(deep, shallow, depth);
		float stripe = fract((cell.y + 2.5 * sin(cell.x * 0.25)) / 9.0);
		if (stripe < 0.12) {
			c = vec3(0.85, 0.95, 1.0);
		} else if (stripe < 0.22) {
			c = mix(c, vec3(0.2, 0.75, 0.85), 0.7);
		}
		c *= 0.85 + 0.3 * hash(cell);
		float cuv1 = texture(caustic_tex, p * caustic_scale + vec2(TIME * 0.03, -TIME * 0.02)).r;
		float cuv2 = texture(caustic_tex, p * caustic_scale * 1.3 - vec2(TIME * 0.025, TIME * 0.03)).r;
		c += vec3(0.8, 1.0, 1.0) * pow(1.0 - min(cuv1, cuv2), 6.0) * caustic_strength;
	}

	ALBEDO = mix(vec3(0.55, 0.55, 0.52), c, g);
	ROUGHNESS = mix(0.9, 0.12, g);
	SPECULAR = 0.6;
}
