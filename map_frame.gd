extends Node3D

func attach_viewport_tex(tex: Texture2D) -> void:
	var mat: Material = $Cube.get_active_material(1)
	mat.set("albedo_texture", tex)
