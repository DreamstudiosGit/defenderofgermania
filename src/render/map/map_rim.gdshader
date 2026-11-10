// Light along a border or round a figure on the map table: a flat colour whose strength
// breathes slowly (reachable provinces, the selected army's ring) or is set per instance
// (the rim that swells out of a conquered province). The breath runs on the shader's clock,
// so nothing is computed per frame in script.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
// Share of the strength that fades out and back in each breath.
uniform float breath = 0.0;
// In step with the glow of the fields (map_field.gdshader).
uniform float breath_speed = 3.0;
instance uniform float strength = 1.0;

void fragment() {
	float wave = 1.0 - breath * (0.5 - 0.5 * sin(TIME * breath_speed));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * strength * wave;
}
