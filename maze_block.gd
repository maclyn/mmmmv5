@tool
extends Node3D

var _is_portal: bool = false
var _has_updated_updated_portal_tex: bool = false
var _exit_portal: Node3D = null

func _ready():
	$HedgeWallN.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallE.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallS.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallW.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSW.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerNW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNW.rotate_y((PI / 2) * randi_range(0, 4))
	$PortalBody/PortalCollider.disabled = true
	$PortalBody/PortalSurface.visible = false
	$QuickSand/QuickSandCollider.disabled = true
	$QuickSand/QuickSandSurface.visible = false

func configure_walls(north: bool, east: bool, south: bool, west: bool):
	$HedgeWallN.visible = north
	$HedgeWallN.get_node("CollisionShape3D").disabled = !north
	$HedgeWallE.visible = east
	$HedgeWallE.get_node("CollisionShape3D").disabled = !east
	$HedgeWallS.visible = south
	$HedgeWallS.get_node("CollisionShape3D").disabled = !south
	$HedgeWallW.visible = west
	$HedgeWallW.get_node("CollisionShape3D").disabled = !west
	
func get_south_wall() -> Node3D:
	return $HedgeWallS

func rotate_key_y(amount_in_rads: float):
	$KeyRoot.rotate_y(amount_in_rads)

func add_key():
	$KeyRoot.visible = true
	$KeyRoot/KeyCollider.disabled = false
	
func hide_key():
	$KeyRoot.visible = false
	$KeyRoot/KeyCollider.disabled = true

func add_exit():
	$ExitRoot.visible = true
	$ExitRoot/ExitCollider.disabled = false
	
func hide_exit():
	$ExitRoot.visible = false
	$ExitRoot/ExitCollider.disabled = true
	
func get_key_position() -> Vector3:
	return $KeyRoot.global_position

func enable_portal(exit_portal_maze_block: Node3D) -> void:
	_is_portal = true
	_exit_portal = exit_portal_maze_block
	$PortalBody/PortalCollider.disabled = false
	$PortalBody/PortalSurface.visible = true

func get_portal_exit() -> Vector2:
	var start = $HedgeWallN.global_position
	var fwd = $HedgeWallN.get_global_transform().basis.z
	var exit = start + (fwd * 0.5)
	return Vector2(exit.x, exit.z)
	
func add_quicksand() -> void:
	$QuickSand/QuickSandCollider.disabled = false
	$QuickSand/QuickSandSurface.visible = true
	
func set_as_portal_exit():
	# Camera is a globally shared (non-unique) node, so even though it's
	# positioned correctly in the MazeBlock scene, it needs to be moved to the
	# center of *this* block
	var basis_for_cam = Vector3($InPathBlock.global_position)
	basis_for_cam.y = 2
	$PortalViewport/PortalCamera.global_position = basis_for_cam
	
func get_snapshot() -> Texture2D:
	await RenderingServer.frame_post_draw
	var portal_viewport_texture = $PortalViewport.get_texture()
	var image = portal_viewport_texture.get_image()
	var portal_image_texture = ImageTexture.create_from_image(image)
	return portal_image_texture

func _process(delta: float) -> void:
	if _is_portal && !_has_updated_updated_portal_tex:
		get_south_wall().remove_map()
		var tex = await _exit_portal.get_snapshot()
		$PortalBody/PortalSurface.attach_portal_tex(tex)
		_has_updated_updated_portal_tex = true
	
func drop_portal():
	$PortalBody/PortalSurface.visible = false
	$PortalBody/PortalCollider.disabled = true
	
func show_arrow(
	dir_from_prev_north: bool,
	dir_from_prev_south: bool,
	dir_from_prev_east: bool,
	dir_from_prev_west: bool
):
	# Arrows are configured on the maze block to always point right
	# Pass "true" to show_arrow to flip the direction
	# This operates OPPOSITE to how you might think when in "exit" mode,
	# since block->prev is the previous when walking to the key
	# block->prev is actually block->next when exiting!
	$InPathBlock.visible = true
	if dir_from_prev_north: # is_next_south
		$HedgeWallE.show_arrow(false)
		$HedgeWallW.show_arrow(true)
		if $HedgeWallE.visible:
			$HedgeWallN.show_arrow(false)
		else:
			$HedgeWallN.show_arrow(true)
	elif dir_from_prev_south: # is_next_north
		$HedgeWallE.show_arrow(true)
		$HedgeWallW.show_arrow(false)
		if $HedgeWallE.visible:
			$HedgeWallS.show_arrow(true)
		else:
			$HedgeWallS.show_arrow(false)
	elif dir_from_prev_east: # is_next_west
		$HedgeWallN.show_arrow(true)
		$HedgeWallS.show_arrow(false)
		if $HedgeWallN.visible:
			$HedgeWallE.show_arrow(true)
		else:
			$HedgeWallE.show_arrow(false)
	elif dir_from_prev_west: # is_next_east
		$HedgeWallN.show_arrow(false)
		$HedgeWallS.show_arrow(true)
		if $HedgeWallN.visible:
			$HedgeWallW.show_arrow(false)
		else:
			$HedgeWallW.show_arrow(true)
