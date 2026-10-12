shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

#include "res://src/render/battle/unit_motion.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.8;
// 0: the surface's own albedo; 1: house field colour; 2: house charge colour.
uniform int house_slot = 0;
instance uniform vec4 house_primary : source_color = vec4(1.0);
instance uniform vec4 house_secondary : source_color = vec4(1.0);

void vertex() {
	VERTEX = unit_motion(VERTEX, UV2, INSTANCE_CUSTOM);
}

void fragment() {
	vec3 color = albedo.rgb;
	if (house_slot == 1) {
		color *= house_primary.rgb;
	} else if (house_slot == 2) {
		color *= house_secondary.rgb;
	}
	ALBEDO = color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
