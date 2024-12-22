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
	
func remove_map():
	if $MapContainer.get_child_count() > 0:
		$MapContainer.remove_child($MapContainer.get_child(0))

func show_arrow(flip_arrow_direction: bool) -> void:
	$Arrows.visible = true
	if flip_arrow_direction:
		$Arrows/ArrowContainerSE/maze_arrow.rotate_y(deg_to_rad(180))
		$Arrows/ArrowContainerNW/maze_arrow.rotate_y(deg_to_rad(180))
	$MapContainer.visible = false
	
func _ready() -> void:
	$Arrows/ArrowContainerSE.visible = direction == "S" || direction == "E"
	$Arrows/ArrowContainerNW.visible = direction == "N" || direction == "W"
	$Arrows.visible = false
