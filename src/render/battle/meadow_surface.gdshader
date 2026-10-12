shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

uniform vec4 meadow : source_color = vec4(0.56, 0.62, 0.30, 1.0);
uniform vec4 sand : source_color = vec4(0.63, 0.53, 0.32, 1.0);
uniform vec2 field_size = vec2(72.0, 44.0);
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
	float lane = abs(ground_position.y - field_size.y * 0.45
		- sin(ground_position.x * 0.10) * 1.8);
	float branch = abs(ground_position.x - field_size.x * 0.5);
	float access = (1.0 - smoothstep(1.0, 3.0, branch))
		* (1.0 - smoothstep(field_size.y * 0.28, field_size.y * 0.48, ground_position.y));
	float worn = max(1.0 - smoothstep(2.0, 5.0, lane + middle * 1.3), access);
	vec3 grass = meadow.rgb * (0.80 + broad * 0.32 + middle * 0.10);
	vec3 color = mix(grass, sand.rgb * (0.90 + middle * 0.14), worn);
	float tufts = smoothstep(0.76, 0.9, noise(ground_position * 3.5));
	ALBEDO = color * (0.96 + grain * 0.075) + vec3(0.024, 0.031, 0.007) * tufts * (1.0 - worn);
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
