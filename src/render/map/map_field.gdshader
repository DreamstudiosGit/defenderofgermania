// A province field on the map table: owner paint with brush streaks over the parchment,
// darker walls, and a pulsing brightening for the selected and the reachable provinces
// (a multiplier, so black paint stays black).
shader_type spatial;
render_mode specular_disabled;

instance uniform vec4 paint : source_color = vec4(0.62, 0.56, 0.44, 1.0);
instance uniform float glow = 0.0;
uniform float variation = 0.1;
uniform float wall_shade = 0.62;

varying vec3 world_position;
varying float wall;

float hash(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	vec2 blend = part * part * (3.0 - 2.0 * part);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wall = 1.0 - step(0.5, (MODEL_MATRIX * vec4(NORMAL, 0.0)).y);
}

void fragment() {
	vec2 point = world_position.xz;
	float streaks = noise(point * vec2(0.35, 2.2)) * 0.55 + noise(point * 0.9) * 0.3
		+ hash(floor(point * 24.0)) * 0.15;
	vec3 color = paint.rgb * (1.0 + (streaks - 0.5) * 2.0 * variation);
	color *= mix(1.0, wall_shade, wall);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = color * (1.0 + glow * pulse);
	ROUGHNESS = 0.85;
}
