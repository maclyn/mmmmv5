@tool
extends Node3D

signal player_in_quicksand()
signal player_out_of_quicksand()

# Block state
var _is_key: bool = false
var _key_rotation_rads: float = 0.0
var _is_exit: bool = false
var _is_portal: bool = false
var _is_portal_exit: bool = false
var _has_spike: bool = false
var _has_quicksand: bool = false
var _has_coin: bool = true

# Portal entrance state
var _exit_portal: Node3D = null

# Portal exit state
var _has_setup_portal_exit_viewport: bool = false
var _has_updated_updated_portal_tex: bool = false
var _portal_node: SubViewport = null

# Multi-mesh rendering state
static var _has_configured_grass = false
var _player_pivot: Node3D = null

func _ready():
	# Rotate the walls and corners randomly so the same texture 
	# smattered over a bunch of walls looks less monotonous
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
	
	_configure_key()
	_configure_exit()
	_configure_portal()
	_configure_portal_exit()
	_configure_quicksand()
	_configure_spike()
	_configure_coin()
	_configure_grass()

func _process(delta: float) -> void:
	if _is_portal && !_has_updated_updated_portal_tex:
		get_south_wall().remove_map()
		var tex = await _exit_portal.get_snapshot()
		$PortalBody/PortalSurface.attach_portal_tex(tex)
		_has_updated_updated_portal_tex = true
		
func _physics_process(_delta: float) -> void:
	if _has_spike:
		var secs = Time.get_ticks_msec() / 1000.0
		$Spike.position.y = ((sin(secs * 2.0) + 1)) - 3.0
		$Spike.rotation.y = cos(secs * 4.0)

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
	assert(is_node_ready())
	return $HedgeWallS

func rotate_key_y(amount_in_rads: float):
	_key_rotation_rads = amount_in_rads
	_configure_key()

func add_key():
	_is_key = true
	_has_coin = false
	_configure_key()
	_configure_coin()
	
func hide_key():
	_is_key = false
	_configure_key()
	
func _configure_key():
	if is_node_ready():
		$KeyRoot.visible = _is_key
		$KeyRoot.rotate_y(_key_rotation_rads)
		$KeyRoot/KeyCollider.disabled = !_is_key

func add_exit():
	_is_exit = true
	_has_coin = false
	_configure_exit()
	_configure_coin()
	
func attach_player(player_pivot: Node3D):
	_player_pivot = player_pivot
	
func _configure_exit():
	if is_node_ready():
		$ExitRoot.visible = _is_exit
		$ExitRoot/ExitCollider.disabled = !_is_exit

func enable_portal(exit_portal_maze_block: Node3D) -> void:
	_is_portal = true
	_exit_portal = exit_portal_maze_block
	_has_coin = false
	_configure_portal()
	_configure_coin()
	
func drop_portal():
	_is_portal = false
	_exit_portal = null
	_configure_portal()
	
func _configure_portal():
	if is_node_ready():
		$PortalBody/PortalCollider.disabled = !_is_portal
		$PortalBody/PortalSurface.visible = _is_portal

func get_portal_exit() -> Vector2:
	assert(is_node_ready())
	var start = $HedgeWallN.global_position
	var fwd = $HedgeWallN.get_global_transform().basis.z
	var exit = start + (fwd * 0.5)
	return Vector2(exit.x, exit.z)
	
func add_quicksand() -> void:
	_has_quicksand = true
	_has_coin = false
	_configure_quicksand()
	_configure_coin()
	
func _configure_quicksand():
	if is_node_ready():
		$QuickSand/QuickSandCollider.disabled = !_has_quicksand
		$QuickSand/QuickSandSurface.visible = _has_quicksand
	
func add_spike() -> void:
	_has_spike = true
	_has_coin = false
	_configure_spike()
	_configure_coin()
	
func _configure_spike():
	if is_node_ready():
		$Spike/SpikeCollider.disabled = !_has_spike
		$Spike/SpikeSurface.visible = _has_spike
	
func set_as_portal_exit():
	_is_portal_exit = true
	_configure_portal_exit()
	
func _configure_portal_exit():
	if is_node_ready() && _is_portal_exit && !_has_setup_portal_exit_viewport:
		# Camera is a globally shared (non-unique) node, so even though it's
		# positioned correctly in the MazeBlock scene, it needs to be moved to the
		# center of *this* block
		var basis_for_cam = Vector3($InPathBlock.global_position)
		basis_for_cam.y = 2
		_portal_node = load("res://portal_viewport_scene.tscn").instantiate()
		add_child(_portal_node)
		_portal_node.set_camera_position(basis_for_cam)
		_has_setup_portal_exit_viewport = true
		
func _configure_coin():
	if is_node_ready():
		$Coin/CoinCollider.disabled = !_has_coin
		$Coin/CoinSurface.visible = _has_coin
		
func _configure_grass():
	if _has_configured_grass:
		return
	_has_configured_grass = true
	print("Configuring grass...")
	var mesh: MultiMesh = $GrassMultiMesh.multimesh
	var center_of_block = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.90, 0.0))
	var instance_count = mesh.instance_count
	var blade_units_per_edge = sqrt(instance_count)
	var dist_between_units = 4.0 / blade_units_per_edge
	var start_pos = dist_between_units / 2.0
	var last_idx = 0
	for x in blade_units_per_edge:
		for z in blade_units_per_edge:
			var idx = (x * blade_units_per_edge) + z
			last_idx = idx
			var transform = Transform3D(center_of_block)
			transform.origin.x = (start_pos + (x * dist_between_units) + randf_range(-dist_between_units, dist_between_units)) - 2.0
			transform.origin.z = (start_pos + (z * dist_between_units) + randf_range(-dist_between_units, dist_between_units)) - 2.0
			transform.basis = Basis.IDENTITY.rotated(Vector3.UP, randf_range(0.0, TAU)).scaled(Vector3(1.0, randf_range(0.0, 2.0), 1.0))
			mesh.set_instance_transform(idx, transform)
	print("configured " + str(last_idx))
	
func get_snapshot() -> Texture2D:
	if _portal_node == null:
		return
	assert(is_node_ready())
	assert(_is_portal_exit)
	await RenderingServer.frame_post_draw
	var portal_viewport_texture = _portal_node.get_texture()
	var image = portal_viewport_texture.get_image()
	var portal_image_texture = ImageTexture.create_from_image(image)
	return portal_image_texture
	
func show_arrow(
	dir_from_prev_north: bool,
	dir_from_prev_south: bool,
	dir_from_prev_east: bool,
	dir_from_prev_west: bool
):
	assert(is_node_ready())
	
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


func _on_quick_sand_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_group"):
		print("Player in quicksand!")
		player_in_quicksand.emit()

func _on_quick_sand_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_group"):
		print("Player out of quicksand!")
		player_out_of_quicksand.emit()
