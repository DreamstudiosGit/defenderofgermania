shader_type spatial;
render_mode depth_draw_never, diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(0.66, 0.49, 0.27, 1.0);
uniform float roughness = 1.0;
varying vec2 path_position;

void vertex() {
	path_position = VERTEX.xz + vec2(0.5);
}

void fragment() {
	float broken_edge = sin(path_position.x * 37.0) * 0.025
		+ sin(path_position.x * 91.0) * 0.012;
	float cross = abs(path_position.y - 0.5) + broken_edge;
	float ends = smoothstep(0.0, 0.06, path_position.x)
		* (1.0 - smoothstep(0.94, 1.0, path_position.x));
	ALBEDO = albedo.rgb * (0.93 + sin(path_position.x * 157.0 + path_position.y * 113.0) * 0.045);
	ROUGHNESS = roughness;
	ALPHA = (1.0 - smoothstep(0.24, 0.5, cross)) * ends * 0.85;
}
