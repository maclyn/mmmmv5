extends StaticBody3D

@export var map_scene: PackedScene

func rotate_mesh(rotation_rad: float):
	$MeshInstance3D.rotation.z = rotation_rad

func add_map(tex: Texture2D):
	var new_map = map_scene.instantiate()
	new_map.attach_viewport_tex(tex)
	new_map.rotation.y = deg_to_rad(90)
	$MapContainer.add_child(new_map)
