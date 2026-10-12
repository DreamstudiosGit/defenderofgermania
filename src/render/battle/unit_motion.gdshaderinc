// Limb motion of a batched figure, shared by the figure shader and its ink outline.
// UV2.x = stride weight, UV2.y = left/right phase; INSTANCE_CUSTOM = (phase, movement,
// contact, simulation time).

uniform float stride_rate = 9.0;
uniform float stride_length = 0.22;
uniform float body_bob = 0.035;

vec3 unit_motion(vec3 vertex, vec2 uv2, vec4 custom) {
	float cycle = custom.x + custom.w * stride_rate;
	float stride = sin(cycle + uv2.y * 3.14159265);
	vertex.z += stride * uv2.x * custom.y * stride_length;
	vertex.y += max(0.0, cos(cycle + uv2.y * 3.14159265)) * uv2.x * custom.y * body_bob * 2.0;
	vertex.y += abs(sin(cycle)) * custom.y * body_bob;
	vertex.z += sin(cycle * 0.65) * custom.z * 0.025 * vertex.y;
	return vertex;
}
