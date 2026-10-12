// The parchment sheet under the realm, and the sea painted on it: mottled paper, browned
// towards the sheet's edges, engraved hatching on water.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 paper : source_color = vec4(0.84, 0.75, 0.58, 1.0);
uniform vec4 edge : source_color = vec4(0.54, 0.42, 0.25, 1.0);
// Sheet rectangle on the table: x, z of the corner, then width and depth.
uniform vec4 sheet = vec4(-50.0, -50.0, 100.0, 100.0);
uniform float edge_width = 7.0;
uniform float hatch = 0.0;

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
	vec2 point = world_position.xz;
	vec2 inside = min(point - sheet.xy, sheet.xy + sheet.zw - point);
	float border = min(inside.x, inside.y) + (noise(point * 0.4) - 0.5) * 3.0;
	float browned = 1.0 - smoothstep(0.0, edge_width, border);
	float mottle = noise(point * 0.12) * 0.6 + noise(point * 0.7) * 0.4;
	vec3 color = paper.rgb * (0.92 + mottle * 0.16);
	color = mix(color, edge.rgb, browned * 0.85);
	float lines = smoothstep(0.55, 0.9, sin(point.y * 9.0 + noise(point * 0.3) * 4.0));
	color *= 1.0 - lines * hatch;
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
