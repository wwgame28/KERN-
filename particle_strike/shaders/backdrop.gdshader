// Дальний фон (силуэты небоскрёбов / горы). Вся панорама — один меш = один draw call.
// Окна и «пиксели» рисуются процедурно по мировым координатам.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec3 body_color : source_color = vec3(0.03, 0.04, 0.08);
uniform vec3 light_color : source_color = vec3(1.0, 0.7, 0.35);
uniform vec3 light_color2 : source_color = vec3(0.3, 0.7, 1.0);
uniform float window_mode = 1.0;
uniform float density = 0.35;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 uv = abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy;
	vec2 p = uv * vec2(0.9, 0.7);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
	float lit = step(1.0 - density, h) * win * window_mode * step(0.5, 1.0 - abs(wnorm.y));
	float dots = (1.0 - window_mode) * step(0.93, hash(floor(wpos.xz * 0.5 + wpos.y))) * 0.6;
	ALBEDO = body_color * (0.8 + 0.4 * h);
	EMISSION = mix(light_color, light_color2, step(0.85, h)) * (lit * 1.4 + dots) + body_color * 0.15;
	ROUGHNESS = 0.9;
}
