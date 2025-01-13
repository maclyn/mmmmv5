shader_type spatial;

uniform sampler2D base_map : source_color, filter_linear_mipmap;
uniform sampler2D pin : source_color, filter_linear;

uniform float map_size_units;
uniform float x_center_units;
uniform float y_center_units;
uniform float pin_x_units;
uniform float pin_y_units;

void fragment() {
	// UV will give us where we are on the square
	float x = UV.x;
	float y = UV.y;

	// Non-uniform constants
	float target_square_units = 100.0;
	float pin_size_as_pct_of_output = 0.10; // Square pin should take 10% of the map

	// MAP CROP

	// 1) Where are we on the map after cropping and scaling
	// Without lead in, the map is 80x80
	// The map is centered anyways, so we can crop in
	// So let's target 90x90 total units
	float pct_of_map_visible = target_square_units / map_size_units;
	// let's say this was 0.75 -- we want the inner 75% of the maps
	// if we were at 0.01, we'd want to sample from 0.125(ish)
	// so we need an offset
	float offset_start = (1.0 - pct_of_map_visible) / 2.0;
	float inset_x = x * pct_of_map_visible;
	float inset_y = y * pct_of_map_visible;
	vec4 map_f = texture(base_map, vec2(offset_start + inset_x, offset_start + inset_y));

	// PIN PLACEMENT

	// So the map as-is is a target square units map centered (map size units / 2)
	// at (40, 40)
	// In our default config, that's left-most/top-most side at 40 - (124 / 2) = -22
	// ...but we're cropped in by pct_of_map_visible
	float lhs_bound_unit = x_center_units - (target_square_units / 2.0);
	float top_bound_unit = y_center_units - (target_square_units / 2.0);
	// We find the "center" relative to the units displayed as a % x,  y in the screen
	float pin_center_pct_over_x = (pin_x_units - lhs_bound_unit) / target_square_units;
	float pin_center_pct_over_y = (pin_y_units - top_bound_unit) / target_square_units;
	// And then we get the bounds
	float lhs_pin_pct_of_output = pin_center_pct_over_x - (pin_size_as_pct_of_output / 2.0);
	float rhs_pin_pct_of_output = lhs_pin_pct_of_output + pin_size_as_pct_of_output;
	float top_pin_pct_of_output = pin_center_pct_over_y - (pin_size_as_pct_of_output / 2.0);
	float bottom_pin_pct_of_output = top_pin_pct_of_output + pin_size_as_pct_of_output;
	if (x >= lhs_pin_pct_of_output && x <= rhs_pin_pct_of_output &&
		y >= top_pin_pct_of_output && y <= bottom_pin_pct_of_output)
	{
		// The pin texture has transparency, so it we can just sum up the map + pin using that
		// Now we adjust for where *we* are (x, y of UV)
		// Basically, what % of the pin shape are we at
		// This gives us the UV to use for the pin texture
		float pct_into_pin_tex_x = (x - lhs_pin_pct_of_output) / pin_size_as_pct_of_output;
		float pct_into_pin_tex_y = (y - top_pin_pct_of_output) / pin_size_as_pct_of_output;
		vec4 pin_f = texture(pin, vec2(pct_into_pin_tex_x, pct_into_pin_tex_y));
		ALBEDO = vec3(
			(map_f.r * (1.0 - pin_f.a)) + (pin_f.r * pin_f.a),
			(map_f.g * (1.0 - pin_f.a)) + (pin_f.g * pin_f.a),
			(map_f.b * (1.0 - pin_f.a)) + (pin_f.b * pin_f.a)
		);
	} else {
		ALBEDO = map_f.rgb;
	}
}
