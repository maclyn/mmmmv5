shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform sampler2D portal_tex : source_color, filter_linear_mipmap;

void vertex() {
	// Default BoxMesh UVs try to 1 texture onto 6 sides; this undoes that
	// Same texture on all sides
	UV *= vec2(3.0, 2.0);
}

void fragment() {
	vec4 portal_viewport_value = texture(portal_tex, UV);
	
	// step between 0.0 addition
	
	// What we want to do is change the offset of the center as time goes on
	// Full sweep in 5 seconds maybe?
	float sweep_duration = 5.0;
	float offset = modf(TIME, sweep_duration) / sweep_duration;
	float uv_x_max = 1.0;
	// offset goes between 0.0 -> 1.0 over 5 seconds, and wraps around at 5
	float f = (sin(TIME * (modf(UV.x - offset, uv_x_max))) + 1.0) / 2.0;
	// We want 5 "bands" of brightness"
	// f *= (UV.x / 5.0);
	ALBEDO = vec3(
		clamp(portal_viewport_value.r, 0.0, 1.0) + f,
		clamp(portal_viewport_value.g, 0.0, 1.0) + f,
		clamp(portal_viewport_value.b, 0.0, 1.0) + f);
	// ALBEDO = portal_viewport_value.rgb;
}
