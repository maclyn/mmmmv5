shader_type canvas_item;
uniform sampler2D screen_texture : source_color, hint_screen_texture, repeat_disable, filter_nearest;

uniform int color_levels : hint_range(2, 256) = 32;

vec3 quantize(vec3 color) {
    float quantizer = float(color_levels - 1);
    return floor(color * quantizer + 0.5) / quantizer;
}

void fragment() {
	// DISABLED:
	// If we put screen_texture at 0.5x resolution, but then scale up to 1x resolution
	// with a linear filter (unchangeable -- see https://github.com/godotengine/godot-proposals/issues/4697)
	// it looks bad
	// To work around this, we can, for a given point, we "undo" the linear filter by average neighboring
	// pixels 
	//ivec2 size = textureSize(screen_texture, 0);
	//vec2 low_res_size = vec2(size) * 0.5;
	//vec2 low_res_coord = SCREEN_UV * low_res_size;
	//vec2 snapped_coord = (floor(low_res_coord) + 0.5) / low_res_size;
	//vec3 screen_color = texture(screen_texture, snapped_coord).rgb;
	
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	// Now posterize, a la https://github.com/immaculate-lift-studio/PSX-Style-Camera-Shader
	vec3 final_color = quantize(screen_color.rgb);
	COLOR = vec4(final_color.r, final_color.g, final_color.b, 1.0);
}