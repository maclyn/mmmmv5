@tool
extends StaticBody3D

@export var map_scene: PackedScene
@export var direction: String

func rotate_mesh(rotation_rad: float):
	$hedge_wall.rotation.z = rotation_rad

func add_map(tex: Texture2D):
	var new_map = map_scene.instantiate()
	new_map.attach_viewport_tex(tex)
	new_map.rotation.y = deg_to_rad(90)
	$MapContainer.add_child(new_map)

func show_arrow(should_face_right: bool) -> void:
	$Arrows.visible = true
	if !should_face_right:
		$Arrows/ArrowContainerSE/maze_arrow.rotate_y(deg_to_rad(180))
		$Arrows/ArrowContainerNW/maze_arrow.rotate_y(deg_to_rad(180))
	$MapContainer.visible = false

func _ready() -> void:
	$Arrows/ArrowContainerSE.visible = direction == "S" || direction == "E"
	$Arrows/ArrowContainerNW.visible = direction == "N" || direction == "W"
	$Arrows.visible = false
