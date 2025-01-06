shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform sampler2D portal_tex : source_color, filter_linear_mipmap;

void fragment() {
	vec4 portal_viewport_value = texture(portal_tex, vec2(-UV.x, UV.y));
    vec2 center = vec2(0.5, 0.5);
    float distance = length(UV - center);
    float frequency = 20.0; // Number of ripples
    float time_factor = (cos((distance * frequency * PI) - (TIME * 15.0)) + 1.0) / 2.0;
    time_factor = pow(time_factor, 10.0); // Adjust the power for sharper ripples
    ALBEDO = vec3(
        clamp(portal_viewport_value.r + time_factor, 0.0, 1.0),
        clamp(portal_viewport_value.g + time_factor, 0.0, 1.0),
        clamp(portal_viewport_value.b + time_factor, 0.0, 1.0)
    );
}
