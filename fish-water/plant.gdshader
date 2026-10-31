shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.05, 0.25, 0.08);
uniform vec3 tip_color : source_color = vec3(0.35, 0.75, 0.25);

void vertex() {
	float h = UV.y;
	float seed = float(INSTANCE_ID) * 1.37;
	VERTEX.x += (sin(TIME * 1.3 + seed) * 0.35 + sin(TIME * 2.1 + seed * 2.0) * 0.1) * h * h;
	VERTEX.z += cos(TIME * 1.1 + seed) * 0.15 * h * h;
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, UV.y) * COLOR.rgb;
	ROUGHNESS = 0.6;
}
