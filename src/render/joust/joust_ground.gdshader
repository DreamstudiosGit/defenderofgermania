// Meadow around the lists with a straight band of trampled sand along x for the run-up.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

uniform vec4 meadow : source_color = vec4(0.33, 0.42, 0.16, 1.0);
uniform vec4 sand : source_color = vec4(0.69, 0.54, 0.30, 1.0);
uniform float lists_half_width = 7.0;
uniform float lists_half_length = 36.0;
varying vec2 ground_position;

float hash(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), local.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), local.x), local.y);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float broad = noise(ground_position * 0.11);
	float middle = noise(ground_position * 0.6);
	float grain = noise(ground_position * 12.0);
	vec2 inside = vec2(lists_half_length, lists_half_width) - abs(ground_position);
	float worn = smoothstep(-1.5, 1.0, min(inside.x, inside.y) + (middle - 0.5) * 2.0);
	// The hooves churn two darker tracks beside the barrier.
	float track = 1.0 - smoothstep(0.3, 0.9, abs(abs(ground_position.y) - 1.25));
	vec3 grass = meadow.rgb * (0.80 + broad * 0.32 + middle * 0.10);
	vec3 dirt = sand.rgb * (0.90 + middle * 0.14) * (1.0 - track * 0.16 * step(0.0, inside.x));
	vec3 color = mix(grass, dirt, worn);
	float tufts = smoothstep(0.76, 0.9, noise(ground_position * 3.5));
	ALBEDO = color * (0.96 + grain * 0.075) + vec3(0.024, 0.031, 0.007) * tufts * (1.0 - worn);
	ROUGHNESS = 1.0;
}
