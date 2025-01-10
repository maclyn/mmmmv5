@tool
extends Node3D

func replace_map_material(material: BaseMaterial3D) -> void:
	$Cube.set_surface_override_material(1, material)
