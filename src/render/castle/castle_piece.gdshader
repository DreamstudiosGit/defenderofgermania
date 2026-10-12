// House-coloured surfaces of a castle piece: the static sibling of unit_motion.gdshader.
// The white house_primary / house_secondary masks from Blender take the owner's colours from
// the piece's instance uniforms.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.8;
// 1: house field colour; 2: house charge colour.
uniform int house_slot = 1;
instance uniform vec4 house_primary : source_color = vec4(1.0);
instance uniform vec4 house_secondary : source_color = vec4(1.0);

void fragment() {
	vec3 color = albedo.rgb * (house_slot == 2 ? house_secondary.rgb : house_primary.rgb);
	ALBEDO = color;
	ROUGHNESS = roughness;
}
