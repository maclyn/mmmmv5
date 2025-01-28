@tool
extends StaticBody3D

@export var direction: String

var _is_arrow_showing = false
var _is_map_showing = false

func _process(delta: float) -> void:
	_update_arrow_color($Arrows/ArrowContainerNW/maze_arrow/Cube_001)
	_update_arrow_color($Arrows/ArrowContainerSE/maze_arrow/Cube_001)

func rotate_mesh(rotation_rad: float):
	$hedge_wall.rotation.z = rotation_rad

func add_map(tex: Texture2D, pin_x_units: float, pin_y_units: float):
	var new_map = load("res://map_frame.tscn").instantiate()
	new_map.replace_map_material(tex, pin_x_units, pin_y_units)
	$MapContainer.add_child(new_map)
	_is_map_showing = true
	
func remove_map():
	if $MapContainer.get_child_count() > 0:
		$MapContainer.remove_child($MapContainer.get_child(0))
	_is_map_showing = false

func show_arrow(flip_arrow_direction: bool) -> void:
	if flip_arrow_direction:
		$Arrows/ArrowContainerSE/maze_arrow.rotate_y(deg_to_rad(180))
		$Arrows/ArrowContainerNW/maze_arrow.rotate_y(deg_to_rad(180))
	remove_map()
	_is_arrow_showing = true
	_apply_arrow_state()
	
func _ready() -> void:
	$Arrows/ArrowContainerSE.visible = direction == "S" || direction == "E"
	$Arrows/ArrowContainerNW.visible = direction == "N" || direction == "W"
	_is_arrow_showing = false
	_apply_arrow_state()

func _apply_arrow_state() -> void:
	$Arrows.visible = _is_arrow_showing

func _update_arrow_color(mesh: MeshInstance3D) -> void:
	if _is_arrow_showing || mesh.get_surface_override_material_count() < 1:
		return
	var mat: StandardMaterial3D = mesh.get_active_material(0)
	# ping-pong between red and white
	var amount = (sin(Time.get_ticks_msec() / 1000.0 * PI * 2.0) + 1.0) / 2.0
	mat.albedo_color.g = amount
	mat.albedo_color.b = amount
