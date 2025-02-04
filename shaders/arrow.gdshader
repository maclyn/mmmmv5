shader_type spatial;

void fragment() {
	// Called for every pixel the material is visible on.\
	float amount = (sin(TIME * PI * 2.0) + 1.0) / 2.0;
	ALBEDO = vec3(1.0, amount, amount);
}