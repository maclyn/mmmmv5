@tool
extends Node3D

func replace_map_material(tex: Texture2D, pin_x_units: float, pin_y_units: float) -> void:
	var shader_material = $Cube.get_active_material(1)
	if shader_material is ShaderMaterial:
		shader_material.set_shader_parameter("base_map", tex)
		shader_material.set_shader_parameter("map_size_units", 124.0)
		shader_material.set_shader_parameter("x_center_units", 42.0)
		shader_material.set_shader_parameter("y_center_units", 42.0)
		shader_material.set_shader_parameter("pin_x_units", pin_x_units)
		shader_material.set_shader_parameter("pin_y_units", pin_y_units)
	else:
		push_error("Map frame's center not set to expected shader!")
