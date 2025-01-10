shader_type spatial;

uniform sampler2D base_map : source_color, filter_linear_mipmap;
uniform sampler2D pin : source_color, filter_linear_mipmap;

uniform float render_size_px;
uniform float map_size_units;
uniform float x_center_units;
uniform float y_center_units;

void fragment() {
	// UV will give us where we are on the square
	// 1) Where are we on the map after cropping and scaling
	// Without lead in, the map is 40x40
	// So let's target 45x45
	// 2) Based on where we are, place the pin appropriately
	
	vec4 map_f = texture(base_map, UV);
	vec4 pin_f = texture(pin, UV2);

	/*
    ALBEDO = vec3(
        clamp(noise_value.r, 0.0, 1.0),
        clamp(noise_value.g, 0.0, 1.0),
        clamp(noise_value.b, 0.0, 1.0)
    );
	*/
}
