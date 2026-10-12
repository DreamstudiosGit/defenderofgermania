// Oiled oak planks of the war table: grain along x, seams between planks along z.
shader_type spatial;

uniform vec4 light_wood : source_color = vec4(0.48, 0.32, 0.2, 1.0);
uniform vec4 dark_wood : source_color = vec4(0.24, 0.14, 0.08, 1.0);
uniform float plank_width = 7.5;

varying vec3 world_position;

float hash(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	vec2 blend = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = world_position.xz + vec2(0.0, world_position.y * 3.0);
	float plank = floor(point.y / plank_width);
	vec2 local = vec2(point.x + hash(vec2(plank, 3.0)) * 40.0, point.y);
	float warp = noise(local * vec2(0.04, 0.5)) * 6.0;
	float grain = sin((local.y + warp) * 5.0 + noise(local * vec2(0.08, 1.4)) * 3.0);
	float tone = 0.5 + 0.25 * grain + 0.35 * (noise(local * vec2(0.03, 0.4)) - 0.5);
	tone = mix(tone, tone * 0.8, hash(vec2(plank, 7.0)));
	float seam = smoothstep(0.0, 0.05, abs(fract(point.y / plank_width) - 0.5) * 2.0 - 0.94);
	vec3 color = mix(dark_wood.rgb, light_wood.rgb, clamp(tone, 0.0, 1.0));
	ALBEDO = color * (1.0 - seam * 0.6);
	ROUGHNESS = 0.45 + 0.2 * tone;
	SPECULAR = 0.45;
}
