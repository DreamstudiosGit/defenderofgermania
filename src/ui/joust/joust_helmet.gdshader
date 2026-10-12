// Inside of a great helm over the first-person joust view: dark iron with a lit rim around a
// wide eye slit, rivets along the slit and breathing holes on the right cheek.
shader_type canvas_item;

uniform vec4 iron : source_color = vec4(0.13, 0.12, 0.11, 1.0);
uniform vec4 shine : source_color = vec4(0.55, 0.5, 0.42, 1.0);
// Slit in fractions of the screen height (x is scaled by the aspect ratio).
uniform float slit_center = 0.46;
uniform float slit_half_height = 0.24;
uniform float slit_half_width = 0.47;
uniform float softness = 0.006;
uniform float opacity : hint_range(0.0, 1.0) = 0.97;

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = size.x / size.y;
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - slit_center);
	// The slit narrows a little towards both ends like a real visor.
	float taper = 1.0 - 0.25 * smoothstep(0.2, 1.0, abs(p.x) / (slit_half_width * aspect));
	vec2 half_size = vec2(slit_half_width * aspect, slit_half_height * taper);
	float d = rounded_box(p, half_size, slit_half_height * 0.8 * taper);
	float open = 1.0 - smoothstep(-softness, softness, d);
	float curve = 0.8 + 0.35 * (1.0 - abs(UV.x - 0.5) * 2.0) - 0.25 * abs(UV.y - 0.5);
	vec3 color = iron.rgb * curve;
	float rim = smoothstep(0.03, 0.0, abs(d - 0.016));
	color = mix(color, shine.rgb, rim * 0.55);
	// Rivets just outside the slit.
	vec2 rivet_cell = vec2(fract(p.x / 0.12) - 0.5, 0.0);
	float rivet_row = abs(abs(p.y) - (half_size.y + 0.05));
	float rivet = smoothstep(0.011, 0.006, length(vec2(rivet_cell.x * 0.12, rivet_row)));
	color = mix(color, shine.rgb * 0.55, rivet * step(abs(p.x), half_size.x - 0.05));
	// Breathing holes in a cross on the lower right.
	vec2 holes = p - vec2(0.5 * aspect - 0.32, 0.36);
	vec2 cell = fract(holes / 0.045) - 0.5;
	vec2 index = floor(holes / 0.045);
	float in_cross = step(abs(index.x), 3.0) * step(abs(index.y), 0.0)
		+ step(abs(index.y), 2.0) * step(abs(index.x), 0.0);
	float hole = smoothstep(0.28, 0.2, length(cell)) * min(in_cross, 1.0);
	color *= 1.0 - hole * 0.85;
	// A soft shadow inside the slit edge.
	float inner = smoothstep(-0.06, 0.0, d) * open;
	COLOR = vec4(color * (1.0 - inner * 0.6), max(1.0 - open, inner * 0.55) * opacity);
}
