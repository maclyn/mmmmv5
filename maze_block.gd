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
static var _has_configured_hedges = false
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
	
	$GrassMultiMesh.rotate(Vector3.UP, randi_range(0, 4) * (PI / 2.0))
	
	if Engine.is_editor_hint() && get_parent() == null:
		print("Null scene, so probably rooted in editor; enabling N + E walls")
		configure_walls(true, true, false, false)
	
	_configure_key()
	_configure_exit()
	_configure_portal()
	_configure_portal_exit()
	_configure_quicksand()
	_configure_spike()
	_configure_coin()
	_configure_grass()
	_configure_hedge()
	
func _exit_tree() -> void:
	_has_configured_grass = false
	_has_configured_hedges = false

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
	$HedgeMultiMeshes/HedgeWallNMultiMesh.visible = false #north
	$HedgeWallN.get_node("CollisionShape3D").disabled = !north
	
	$HedgeWallE.visible = east
	$HedgeMultiMeshes/HedgeWallEMultiMesh.visible = false #east
	$HedgeWallE.get_node("CollisionShape3D").disabled = !east
	
	$HedgeWallS.visible = south
	$HedgeMultiMeshes/HedgeWallSMultiMesh.visible = false #south
	$HedgeWallS.get_node("CollisionShape3D").disabled = !south
	
	$HedgeWallW.visible = west
	$HedgeMultiMeshes/HedgeWallWMultiMesh.visible = false # west
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
	var detail_level = _get_detail_level()
	print("Configuring grass with detail_level " + detail_level)
	var instance_count_for_detail_level = 16
	match detail_level:
		"low":
			instance_count_for_detail_level = 256
		"medium":
			instance_count_for_detail_level = 1024
		"high":
			instance_count_for_detail_level = 6400
	var mesh: MultiMesh = $GrassMultiMesh.multimesh
	mesh.visible_instance_count = instance_count_for_detail_level
	var center_of_block = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.90, 0.0))
	var instance_count = mesh.visible_instance_count
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
	print("Configured " + str(last_idx + 1) + " grass clumps")
	
func _configure_hedge() -> void:
	if _has_configured_hedges:
		return
	_has_configured_hedges = true
	var detail_level = _get_detail_level()
	print("Configuring hedges with detail_level " + detail_level)
	var instance_count_for_detail_level = 16
	var instance_count_for_all_corners = 24
	var corner_face_instance_count_width = 1
	var corner_face_instance_count_height = 3
	match detail_level:
		"low":
			instance_count_for_detail_level = 256
			instance_count_for_all_corners = 384
			corner_face_instance_count_width = 1
			corner_face_instance_count_height = 24
		"medium":
			instance_count_for_detail_level = 576
			instance_count_for_all_corners = 512
			corner_face_instance_count_width = 1
			corner_face_instance_count_height = 32
		"high":
			instance_count_for_detail_level = 1600
			instance_count_for_all_corners = 1536
			corner_face_instance_count_width = 2
			corner_face_instance_count_height = 48
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallWMultiMesh, false, false, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallEMultiMesh, false, true, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallSMultiMesh, true, false, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallNMultiMesh, true, true, instance_count_for_detail_level)
	
	var corner_face_item_count = corner_face_instance_count_width * corner_face_instance_count_height
	# Everything facing "in" (facing E/W)
	var setup_count = _apply_hedge_around_corner(  # NE, facing W
		-1.98, # xz_start -- this must grow *positively*
		-1.79, # fixed value (x)
		false, # is_xy plane (no, yz)
		0, # rotation 
		0, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # SE, facing W
		1.82, # xz_start
		-1.79, # fixed value (x)
		false, # is_xy plane (no, yz)
		0, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # NW, facing E
		-1.98, # xz_start
		1.79, # fixed value (x)
		false, # is_xy plane (no, yz)
		PI, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # SW, facing E
		1.82, # xz_start
		1.79, # fixed value (x)
		false, # is_xy plane (no, yz)
		PI, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	# TODO: ADD OPPOSITE DIRECTIONS HERE
	
	# Everything facing "out" (N/S)
	
	setup_count = _apply_hedge_around_corner(  # SE, facing N
		-1.98, # xz_start -- this must grow *positively*
		1.81, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 1.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # SE, facing S
		-1.98, # xz_start -- this must grow *positively*
		1.99, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 0.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	
	setup_count = _apply_hedge_around_corner(  # SW, facing N
		1.82, # xz_start -- this must grow *positively*
		1.81, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 1.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # SW, facing S
		1.82, # xz_start -- this must grow *positively*
		1.99, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 0.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	
	setup_count = _apply_hedge_around_corner(  # NW, facing N
		-1.98, # xz_start -- this must grow *positively*
		-1.81, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 1.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # NW, facing S
		-1.98, # xz_start -- this must grow *positively*
		-1.99, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 0.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	
	# TODO: fix
	setup_count = _apply_hedge_around_corner(  # NE, facing N
		-1.82, # xz_start -- this must grow *positively*
		-1.81, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 1.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)
	setup_count = _apply_hedge_around_corner(  # NE, facing S
		-1.82, # xz_start -- this must grow *positively*
		-1.99, # fixed value (z)
		true, # is_xy plane (no, yz)
		PI * 0.5, # rotation 
		setup_count + 1, # start_idx
		corner_face_instance_count_width,
		corner_face_instance_count_height
	)

	print("count: " + str(setup_count))
	$HedgeMultiMeshes/HedgeCornerMultiMesh.multimesh.visible_instance_count = setup_count

# is_x is really "plants on the xy plane"
# !is_x is really "plants on the yz plane"
func _configure_hedge_wall(wall_node: MultiMeshInstance3D, is_x: bool, is_e: bool, count: int):
	var mesh: MultiMesh = wall_node.multimesh
	mesh.visible_instance_count = count
	var center_of_block = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	
	# Each wall will have one fixed unit (the "edge" of the wall)
	if is_x:
		if is_e:
			center_of_block.origin.z = -1.8
		else:
			center_of_block.origin.z = 1.8
	else:
		if is_e:
			center_of_block.origin.x = 1.8
		else:
			center_of_block.origin.x = -1.8
			
	var instance_count = mesh.visible_instance_count
	var units_per_edge = sqrt(instance_count)
	var dist_between_units_x = 3.6 / units_per_edge
	var dist_between_units_y = 4.0 / units_per_edge
	var start_pos_x = 0.2
	var start_pos_y = dist_between_units_y / 2.0
	var last_idx = 0
	for i in units_per_edge:
		for y in units_per_edge:
			# Choose a point on the right (xy or yz) plane
			var idx = (i * units_per_edge) + y
			last_idx = idx
			var transform = Transform3D(center_of_block)
			var i_pos = (start_pos_x + (i * dist_between_units_x) + randf_range(-dist_between_units_x, dist_between_units_x)) - 2.0
			if is_x:
				transform.origin.x = i_pos
			else:
				transform.origin.z = i_pos
			transform.origin.y = (start_pos_y + (y * dist_between_units_y) + randf_range(-dist_between_units_y, dist_between_units_y)) - 2.0
			
			# Scale the model up
			var scale = randf_range(8.0, 10.0)
			var basis = Basis.IDENTITY
			if is_x:
				basis = basis.scaled(Vector3(1.0, scale, scale))
			else:
				basis = basis.scaled(Vector3(1.0, scale, scale))
				
			# Rotate to face the right direction
			if is_x:
				if not is_e:
					transform.basis = basis.rotated(Vector3.UP, PI / 2.0)
				else:
					transform.basis = basis.rotated(Vector3.UP, PI * 1.5)
			else:
				if is_e:
					basis = basis.rotated(Vector3.UP, PI)
					
			# Rotate randomly around the center of the model to add some
			# flair to it
			if is_x:
				#transform.basis = basis.rotated(Vector3.UP, randf_range(0.0, PI))
				pass
			else:
				# Rotate along the front axis
				transform.basis = basis.rotated(Vector3.RIGHT, randf_range(0.0, TAU))
			mesh.set_instance_transform(idx, transform)
	print("Configured " + str(last_idx + 1) + " hedge plant clumps")

# Returns: number of items setup
func _apply_hedge_around_corner(
	xz_start: float,
	fixed_plane_value: float,
	is_xy_plane: bool,
	rotation_amount: float,
	start_idx: int,
	item_count_width: int,
	item_count_height: int
) -> int:
	var mesh: MultiMesh = $HedgeMultiMeshes/HedgeCornerMultiMesh.multimesh
	var space_between_height_items = 3.96 / float(item_count_height)
	var half_height = space_between_height_items / 2.0
	var space_between_width_items = 0.16 / (item_count_width)
	var half_width = space_between_width_items / 2.0
	for width_idx in item_count_width:
		for height_idx in item_count_height:
			print("W/H: " + str(width_idx) + "x" + str(height_idx))
			var instance_idx = start_idx + (width_idx * item_count_height) + height_idx
			var y_val = (0.1 + half_height + (height_idx * space_between_height_items)) - 2.0
			var xz_val = xz_start + half_width + (width_idx * space_between_width_items)
			var scale = randf_range(8.0, 10.0)
			var origin = Vector3(
				xz_val if is_xy_plane else fixed_plane_value,
				y_val,
				fixed_plane_value if is_xy_plane else xz_val
			)
			print("Origin: " + str(origin))
			var basis = Basis.IDENTITY
			if is_xy_plane:
				basis = basis \
					.rotated(Vector3.UP, rotation_amount) \
					.rotated(Vector3.FORWARD, randf_range(0.0, TAU)) \
					.scaled(Vector3(scale, scale, scale))
			else:
				basis = basis \
					.rotated(Vector3.UP, rotation_amount) \
					.rotated(Vector3.RIGHT, randf_range(0.0, TAU)) \
					.scaled(Vector3(scale, scale, scale))
			var transform = Transform3D(basis, origin)
			print("idx = " + str(instance_idx))
			mesh.set_instance_transform(instance_idx, transform)
	return start_idx + (item_count_width * item_count_height)
	
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

func _get_detail_level() -> String:
	if Engine.is_editor_hint():
		return "high"
	return Globals.get_saver().get_graphics_mode()
