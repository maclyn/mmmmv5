@tool
extends Node3D

func attach_portal_tex(tex: Texture2D):
	if !Engine.is_editor_hint():
		$Cube.get_active_material(0).set_shader_parameter("portal_tex", tex)
