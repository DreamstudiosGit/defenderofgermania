shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.8;
uniform float stride_rate = 9.0;
uniform float stride_length = 0.22;
uniform float body_bob = 0.035;

void vertex() {
	float cycle = INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.w * stride_rate;
	float stride = sin(cycle + UV2.y * 3.14159265);
	VERTEX.z += stride * UV2.x * INSTANCE_CUSTOM.y * stride_length;
	VERTEX.y += max(0.0, cos(cycle + UV2.y * 3.14159265))
		* UV2.x * INSTANCE_CUSTOM.y * body_bob * 2.0;
	VERTEX.y += abs(sin(cycle)) * INSTANCE_CUSTOM.y * body_bob;
	VERTEX.z += sin(cycle * 0.65) * INSTANCE_CUSTOM.z * 0.025 * VERTEX.y;
}

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
