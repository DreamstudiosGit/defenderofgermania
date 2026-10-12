// Jousting lance painted in spiral stripes of the rider's two house colours.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

instance uniform vec4 house_primary : source_color = vec4(1.0);
instance uniform vec4 house_secondary : source_color = vec4(1.0);
// Stripes along the whole lance; UV.x runs once around the shaft, UV.y from butt to tip.
uniform float stripes = 9.0;

void fragment() {
	float band = fract(UV.y * stripes + UV.x);
	ALBEDO = band < 0.5 ? house_primary.rgb : house_secondary.rgb;
	ROUGHNESS = 0.85;
}
