// Ink outline of a batched figure (inverted hull): the moved mesh, pushed out along its
// normals, drawn back faces only in the ink colour behind the figure.
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

#include "res://src/render/battle/unit_motion.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.13, 0.09, 0.07, 1.0);
uniform float width = 0.035;

void vertex() {
	VERTEX = unit_motion(VERTEX, UV2, INSTANCE_CUSTOM) + NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
