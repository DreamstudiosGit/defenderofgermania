shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(0.12, 0.45, 0.60, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.20, 0.32, 1.0);
uniform vec4 foam_color : source_color = vec4(0.79, 0.94, 0.93, 1.0);
uniform float metallic = 0.12;
uniform float roughness = 0.3;
uniform float flow_speed = 0.65;
uniform float wave_height = 0.028;
uniform bool axis_swapped = false;
varying vec3 river_position;
varying vec2 flow_position;

float hash(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), blend.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), blend.x), blend.y);
}

void vertex() {
	river_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_position = vec2(
		dot(river_position.xz, normalize(MODEL_MATRIX[0].xz)),
		dot(river_position.xz, normalize(MODEL_MATRIX[2].xz))
	);
	if (axis_swapped) { flow_position = flow_position.yx; }
	float flow = TIME * flow_speed;
	float wave = sin(river_position.x * 1.8 + flow * 2.0)
		+ sin(river_position.z * 2.5 - flow * 3.0) * 0.45;
	VERTEX.y += wave * wave_height;
	NORMAL = normalize(vec3(-cos(river_position.x * 1.8 + flow * 2.0) * wave_height * 1.8,
		1.0, -cos(river_position.z * 2.5 - flow * 3.0) * wave_height * 1.125));
}

void fragment() {
	float time = TIME * flow_speed;
	vec2 point = flow_position;
	float variation = noise(point * 1.1 + vec2(time * 0.2, -time));
	float ripple = sin(point.x * 6.0 + point.y * 1.8 + variation * 6.0 - time * 4.0);
	float breakup = noise(point * vec2(3.0, 1.7) + vec2(0, -time * 1.3));
	float shore = pow(abs(UV.x - 0.5) * 2.0, 10.0);
	float foam = smoothstep(0.82, 0.99, ripple) * smoothstep(0.53, 0.80, breakup) * 0.55;
	foam = max(foam, shore * (0.28 + variation * 0.30));
	vec3 water = mix(deep_color.rgb, albedo.rgb, 0.40 + ripple * 0.16 + shore * 0.40);
	ALBEDO = mix(water, foam_color.rgb, foam);
	ROUGHNESS = roughness + shore * 0.25;
	METALLIC = metallic;
	SPECULAR = 0.65;
}
