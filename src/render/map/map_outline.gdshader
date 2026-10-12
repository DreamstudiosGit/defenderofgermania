// Ink outline of a painted table piece (inverted hull): the mesh pushed out along its
// normals, back faces only, in the ink colour. Width is in object units, so it scales with
// the piece.
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.16, 0.11, 0.07, 1.0);
uniform float width = 0.025;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
