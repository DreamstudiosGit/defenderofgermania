shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.85;
uniform float wind_strength = 0.035;
uniform float wind_speed = 1.2;
uniform float canopy_height = 4.5;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float height = max(VERTEX.y, 0.0);
	float weight = height * height / max(canopy_height, 0.5);
	float gust = sin(TIME * wind_speed + origin.x * 0.12 + origin.z * 0.09);
	float flutter = sin(TIME * wind_speed * 2.7 + VERTEX.x * 2.1 + VERTEX.z * 1.5);
	VERTEX.x += (gust + flutter * 0.18) * weight * wind_strength;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + origin.z * 0.08) * weight * wind_strength * 0.45;
}

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
