// Full-screen post effect of the battle: ink lines where depth or surface direction jumps
// (the scenery's outlines; figures have their own hull), parchment grain and a light vignette.
// Multiplies the rendered image, so it only darkens.
shader_type spatial;
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.13, 0.09, 0.07, 1.0);
uniform float edge_strength = 0.8;
// View-depth jump in metres that counts as an edge.
uniform float depth_threshold = 0.8;
// 1 - cos of the angle between neighbouring normals that counts as an edge.
uniform float normal_threshold = 0.35;
uniform float grain = 0.05;
uniform float vignette = 0.3;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_texture, uv).xyz * 2.0 - 1.0);
}

float hash(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = view_normal(SCREEN_UV);
	float edge = 0.0;
	vec2 offsets[4] = vec2[](vec2(pixel.x, 0.0), vec2(-pixel.x, 0.0), vec2(0.0, pixel.y),
		vec2(0.0, -pixel.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offsets[i];
		float jump = abs(view_depth(uv, INV_PROJECTION_MATRIX) - depth);
		edge = max(edge, step(depth_threshold, jump));
		edge = max(edge, step(normal_threshold, 1.0 - dot(normal, view_normal(uv))));
	}
	vec3 color = mix(vec3(1.0), ink.rgb, edge * edge_strength);
	color *= 1.0 + (hash(FRAGCOORD.xy) - 0.5) * grain;
	vec2 centered = SCREEN_UV - 0.5;
	color *= 1.0 - vignette * dot(centered, centered) * 2.0;
	ALBEDO = color;
}
