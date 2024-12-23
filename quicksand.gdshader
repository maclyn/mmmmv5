shader_type spatial;

uniform sampler2D noise_tex_a : source_color, filter_linear_mipmap;
uniform sampler2D noise_tex_b : source_color, filter_linear_mipmap;

void fragment() {
	// Drop everything outside of a circle
	float dist = sqrt(pow(abs(UV.x - 0.5), 2) + pow(abs(UV.y - 0.5), 2));
	if (dist > 0.50) {
		discard;
	}
	ALPHA = 1.0;
	if (dist >= 0.45 && dist <= 0.50) {
		ALPHA = smoothstep(0.0, 1.0, (0.50 - dist) * 20.0);
	}
	
	// Render "sizzling" noise texture
	vec4 noise_value_a = texture(noise_tex_a, UV + vec2(TIME * 0.1, -TIME * 0.1)) / 2.0;
	vec4 noise_value_b = texture(noise_tex_b, UV + vec2(-TIME * 0.1, TIME * 0.1)) / 2.0;
	vec4 noise_value = noise_value_a + noise_value_b;
    ALBEDO = vec3(
        clamp(noise_value.r, 0.0, 1.0),
        clamp(noise_value.g, 0.0, 1.0),
        clamp(noise_value.b, 0.0, 1.0)
    );
}
