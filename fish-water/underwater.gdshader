shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.6, 0.85, 0.9);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 25.0 + TIME * 2.0), cos(uv.x * 20.0 + TIME * 1.7)) * 0.0025 * strength;
	vec3 c = texture(screen_tex, uv).rgb * mix(vec3(1.0), tint, strength);
	float v = 1.0 - smoothstep(0.3, 0.9, length(SCREEN_UV - 0.5));
	c *= mix(1.0, mix(0.55, 1.0, v), strength);
	COLOR = vec4(c, 1.0);
}
