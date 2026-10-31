shader_type sky;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 zenith : source_color = vec3(0.18, 0.42, 0.85);
uniform vec3 horizon : source_color = vec3(0.72, 0.84, 0.95);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;

void sky() {
	vec3 d = EYEDIR;
	vec3 col = mix(horizon, zenith, pow(clamp(d.y, 0.0, 1.0), 0.5));
	if (d.y < 0.0) {
		col = mix(horizon, vec3(0.35, 0.4, 0.45), clamp(-d.y * 3.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (smoothstep(0.9993, 0.9997, s) * 4.0 + pow(s, 64.0) * 0.3);
	}
	if (d.y > 0.01) {
		vec2 uv = d.xz / d.y * 0.12;
		float n = texture(cloud_noise, uv).r * 0.7 + texture(cloud_noise, uv * 2.3 + 0.3).r * 0.3;
		float cl = smoothstep(1.0 - cloud_cover, 1.25 - cloud_cover, n) * smoothstep(0.01, 0.2, d.y);
		col = mix(col, vec3(1.0), cl * 0.9);
	}
	COLOR = col;
}
