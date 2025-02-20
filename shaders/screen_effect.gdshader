shader_type canvas_item;
uniform sampler2D screen_texture : source_color, hint_screen_texture, repeat_disable, filter_nearest;

uniform int color_levels : hint_range(2, 256) = 24;

// Inspired by https://github.com/immaculate-lift-studio/PSX-Style-Camera-Shader?tab=MIT-1-ov-file#readme

vec3 quantize(vec3 color) {
    float quantizer = float(color_levels - 1);
    return floor(color * quantizer + 0.5) / quantizer;
}

void fragment() {
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;
	vec3 final_color = quantize(screen_color);
	COLOR = vec4(final_color.r, final_color.g, final_color.b, 1.0);
}