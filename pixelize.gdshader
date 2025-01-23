shader_type canvas_item;

// Animate to a pixelate version

uniform int total_anim_duration_ms;
uniform int appear_time_ms;
uniform int now; // used for debugging

global uniform int time_ms;

void fragment() {
	ivec2 tex_size = textureSize(TEXTURE, 0);
	// What x, y cell are we in
	int t = time_ms; // now 
	float x_cell_floor = float(tex_size.x) / 128.0;
	float y_cell_floor = float(tex_size.y) / 72.0;
	float x_cells = x_cell_floor;
	float y_cells = y_cell_floor;
	// As we get closer to time, x_cells and y_cells decrease in size
	if (t - appear_time_ms < total_anim_duration_ms) {
		int delta = t - appear_time_ms;
		x_cells = mix(float(tex_size.x), x_cell_floor, float(delta) / float(total_anim_duration_ms));
		y_cells = mix(float(tex_size.y), y_cell_floor, float(delta) / float(total_anim_duration_ms));
	}
	float x_cell_size = 1.0 / x_cells;
	float y_cell_size = 1.0 / y_cells;
	float half_x_cell_size = x_cell_size / 2.0;
	float half_y_cell_size = y_cell_size / 2.0;
	float x_cell = floor(UV.x / x_cell_size);
	float y_cell = floor(UV.y / y_cell_size);
	// Grab from center of that cell
	vec4 scaled_down = texture(
		TEXTURE,
		vec2(
			(x_cell * x_cell_size) + half_x_cell_size,
			(y_cell * y_cell_size) + half_y_cell_size));

	COLOR = vec4(mod(sin(TIME * 10.0), 1.0), scaled_down.g, scaled_down.b, 1.0);
}