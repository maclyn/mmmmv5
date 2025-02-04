@tool
extends Node3D

signal player_in_quicksand()
signal player_out_of_quicksand()

const DISABLE_DECALS = false
# Jitter is the process of applying random movement (a little) to grass and 
# hedges
static var DISABLE_JITTER = false
const HIDE_WALLS = false
const HIDE_WALL_DECALS = false || DISABLE_DECALS
const HIDE_CORNERS = false
const HIDE_CORNER_DECALS = false || DISABLE_DECALS
const DISABLE_WALL_COLLISIONS = false

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
	$HedgeWallN.visible = north && !HIDE_WALLS
	$HedgeMultiMeshes/HedgeWallNMultiMesh.visible = north && !HIDE_WALL_DECALS
	$HedgeWallN.get_node("CollisionShape3D").disabled = !north || DISABLE_WALL_COLLISIONS
	
	$HedgeWallE.visible = east && !HIDE_WALLS
	$HedgeMultiMeshes/HedgeWallEMultiMesh.visible = east && !HIDE_WALL_DECALS
	$HedgeWallE.get_node("CollisionShape3D").disabled = !east || DISABLE_WALL_COLLISIONS
	
	$HedgeWallS.visible = south && !HIDE_WALLS
	$HedgeMultiMeshes/HedgeWallSMultiMesh.visible = south && !HIDE_WALL_DECALS
	$HedgeWallS.get_node("CollisionShape3D").disabled = !south || DISABLE_WALL_COLLISIONS
	
	$HedgeWallW.visible = west && !HIDE_WALLS
	$HedgeMultiMeshes/HedgeWallWMultiMesh.visible = west && !HIDE_WALL_DECALS
	$HedgeWallW.get_node("CollisionShape3D").disabled = !west || DISABLE_WALL_COLLISIONS
	
	$HedgeCornerNE.visible = !HIDE_CORNERS
	$HedgeCornerNW.visible = !HIDE_CORNERS
	$HedgeCornerSW.visible = !HIDE_CORNERS
	$HedgeCornerSE.visible = !HIDE_CORNERS
	$HedgeMultiMeshes/HedgeCornerMultiMesh.visible = !HIDE_CORNER_DECALS
	
func debug_reset_decals() -> void:
	_has_configured_grass = false
	_has_configured_hedges = false
	_configure_grass()
	_configure_hedge()
	
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
		$QuickSandGrassMultiMesh.visible = _has_quicksand
		$GrassMultiMesh.visible = !_has_quicksand
	
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
	if DISABLE_DECALS:
		detail_level = "min"
	print("Configuring grass with detail_level " + detail_level)
	var instance_count_for_detail_level = 16
	var qs_instance_count_for_detail_level = 16
	match detail_level:
		"min":
			instance_count_for_detail_level = 0
		"low":
			instance_count_for_detail_level = 256
		"medium":
			instance_count_for_detail_level = 1024
		"high":
			instance_count_for_detail_level = 3600
		"ultra":
			instance_count_for_detail_level = 4900
	
	var mesh: MultiMesh = $GrassMultiMesh.multimesh
	mesh.visible_instance_count = instance_count_for_detail_level
	if instance_count_for_detail_level > 0:
		var center_of_block = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.90, 0.0))
		var blade_units_per_edge = sqrt(instance_count_for_detail_level)
		var dist_between_units = 4.0 / blade_units_per_edge
		var start_pos = dist_between_units / 2.0
		var last_idx = 0
		for x in blade_units_per_edge:
			for z in blade_units_per_edge:
				var idx = (x * blade_units_per_edge) + z
				last_idx = idx
				var transform = Transform3D(center_of_block)
				transform.origin.x = start_pos + (x * dist_between_units) - 2.0
				if !DISABLE_JITTER:
					transform.origin.x += randf_range(-dist_between_units, dist_between_units)
				transform.origin.z = start_pos + (z * dist_between_units) - 2.0
				if !DISABLE_JITTER:
					transform.origin.z += randf_range(-dist_between_units, dist_between_units)
				var grass_width_length = randf_range(1.0, 2.0)
				var grass_height = randf_range(1.5, 2.0)
				transform.basis = Basis.IDENTITY.rotated(Vector3.UP, randf_range(0.0, TAU)).scaled(Vector3(grass_width_length, grass_height, grass_width_length))
				mesh.set_instance_transform(idx, transform)
		print("Configured " + str(last_idx + 1) + " grass clumps")
	
	# Quicksand covers 30.6% of the area
	var qsmesh = $QuickSandGrassMultiMesh.multimesh
	qs_instance_count_for_detail_level = int(0.694 * float(instance_count_for_detail_level))
	qsmesh.visible_instance_count = qs_instance_count_for_detail_level
	if qs_instance_count_for_detail_level > 0:
		var blades_added = 0
		var center_of_block = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.90, 0.0))
		while blades_added != qs_instance_count_for_detail_level:
			var rx = randf_range(-2.0, 2.0)
			var ry = randf_range(-2.0, 2.0)
			# Drop anything in the circle
			if pow(rx, 2) + pow(ry, 2) < pow(1.20, 2):
				continue
			var transform = Transform3D(center_of_block)
			transform.origin.x = rx
			transform.origin.z = ry
			var grass_width_length = randf_range(1.0, 2.0)
			var grass_height = randf_range(1.5, 2.0)
			transform.basis = Basis.IDENTITY.rotated(Vector3.UP, randf_range(0.0, TAU)).scaled(Vector3(grass_width_length, grass_height, grass_width_length))
			qsmesh.set_instance_transform(blades_added, transform)
			blades_added += 1
	
func _configure_hedge() -> void:
	if _has_configured_hedges:
		return
	_has_configured_hedges = true
	var detail_level = _get_detail_level()
	if DISABLE_DECALS:
		detail_level = "min"
	print("Configuring hedges with detail_level " + detail_level)
	var instance_count_for_detail_level = 16
	var instance_count_for_all_corners = 24
	var corner_face_instance_count_width = 1
	var corner_face_instance_count_height = 3
	match detail_level:
		"min":
			instance_count_for_detail_level = 0
			corner_face_instance_count_width = 0
			corner_face_instance_count_height = 0
		"low":
			instance_count_for_detail_level = 256
			corner_face_instance_count_width = 1
			corner_face_instance_count_height = 16
		"medium":
			instance_count_for_detail_level = 576
			corner_face_instance_count_width = 1
			corner_face_instance_count_height = 24
		"high":
			instance_count_for_detail_level = 1600
			corner_face_instance_count_width = 2
			corner_face_instance_count_height = 40
		"ultra":
			instance_count_for_detail_level = 2304 # 48x48
			corner_face_instance_count_width = 3 
			corner_face_instance_count_height = 48
	instance_count_for_all_corners = corner_face_instance_count_height * corner_face_instance_count_width * 16
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallWMultiMesh, false, false, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallEMultiMesh, false, true, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallSMultiMesh, true, false, instance_count_for_detail_level)
	_configure_hedge_wall($HedgeMultiMeshes/HedgeWallNMultiMesh, true, true, instance_count_for_detail_level)
		
	# Splatter decals around the corners
	var labels = [
		"SE", "SE", "SE", "SE", # Good
		"SW", "SW", "SW", "SW", # Good
		"NE", "NE", "NE", "NE", # Good
		"NW", "NW", "NW", "NW" # Good
	]
	var directions_facing = [
		"S", "E", "N", "W", # Good
		"S", "E", "N", "W", # Good
		"S", "E", "N", "W", # Good
		"S", "E", "N", "W", # Good
	]
	var xz_starts = [
		1.80, 1.80, 1.80, 1.80, # Good
		-2.0, 1.80, -2.0, 1.80, # Good
		1.80, -2.0, 1.80, -2.0, # Good
		-2.0, -2.0, -2.0, -2.0 # Good
	]
	var half_decal_size = _hedge_decal_rough_size() / 2.0 / 2.0
	var xz_clamp_starts = [
		1.80 , 1.80, 1.80, 1.80,
		-2.00, 1.80, -2.00, 1.80,
		1.80, -2.00, 1.80, -2.00,
		-2.00, -2.00, -2.00, -2.00
	]
	for clamp_idx in xz_clamp_starts.size():
		xz_clamp_starts[clamp_idx] += half_decal_size
	var xz_clamp_ends = [
		2.00 - half_decal_size, 2.00 - half_decal_size, 2.00 - half_decal_size, 2.00 - half_decal_size,
		-1.80 - half_decal_size, 2.00 - half_decal_size, -2.00 + half_decal_size, 2.00 - half_decal_size,
		2.00 - half_decal_size, -1.80 - half_decal_size, 2.00 - half_decal_size, -1.80 - half_decal_size,
		-1.80 - half_decal_size, -1.80 - half_decal_size, -1.80 - half_decal_size, -1.80 - half_decal_size
	]
	var fixed_values = [
		2.0, 2.0, 1.8, 1.8, # Good
		1.80, -1.8, 2.0, -2.0, # Good
		-2.0, 2.0, -1.80, 1.80, # Good
		-1.80, -1.80, -2.0, -2.0 # Good
	]
	var rotations = [
		PI * 1.5, 0.0, PI * 0.5, PI, # Good
		PI * 0.5, 0.0, PI * 1.5, PI, # Good
		PI * 0.5, 0.0, PI * 1.5, PI, # Good
		PI * 1.5, 0.0, PI * 0.5, PI, # Good
	]
	var decals_setup_count = 0
	for idx in labels.size():
		var direction_facing = directions_facing[idx]
		#print("Configuring hedge corner at " + labels[idx] + " facing " + direction_facing)
		if corner_face_instance_count_height < 1 || corner_face_instance_count_width < 1:
			continue
		decals_setup_count = _apply_hedge_around_corner(
			xz_starts[idx],
			xz_clamp_starts[idx],
			xz_clamp_ends[idx],
			fixed_values[idx],
			direction_facing == "N" || direction_facing == "S",
			rotations[idx],
			decals_setup_count,
			corner_face_instance_count_width,
			corner_face_instance_count_height
		)

	print("Hedge corner decals setup: " + str(decals_setup_count))
	$HedgeMultiMeshes/HedgeCornerMultiMesh.multimesh.visible_instance_count = decals_setup_count

# is_x is really "plants on the xy plane"
# !is_x is really "plants on the yz plane"
func _configure_hedge_wall(
	wall_node: MultiMeshInstance3D,
	is_xy_plane: bool,
	is_e: bool,
	count: int
):
	var mesh: MultiMesh = wall_node.multimesh
	mesh.visible_instance_count = count
	if count < 1:
		return
		
	var base_origin = Vector3.ZERO
	# Each wall will have one fixed unit (the "edge" of the wall)
	if is_xy_plane:
		if is_e:
			base_origin.z = -1.9 # Not sure why, but this works
		else:
			base_origin.z = 1.8
	else:
		if is_e:
			base_origin.x = 1.8
		else:
			base_origin.x = -1.8
			
	var units_per_edge = sqrt(count)
	var dist_between_units_x = 3.6 / units_per_edge
	var dist_between_units_x_half = dist_between_units_x / 2.0
	var dist_between_units_y = 4.0 / units_per_edge
	var dist_between_units_y_half = dist_between_units_y / 2.0
	var last_idx = 0
	var decal_scale = _hedge_decal_scale()
	var half_decal_size = _hedge_decal_rough_size() / 2.0
	for i in units_per_edge:
		for y in units_per_edge:
			# Choose point on face
			
			# Choose x/z points 
			var idx = (i * units_per_edge) + y
			last_idx = idx
			var origin = Vector3(base_origin)
			var i_pos = dist_between_units_x_half + (i * dist_between_units_x) - 1.8
			if not DISABLE_JITTER:
				i_pos += randf_range(-dist_between_units_x_half, dist_between_units_x_half)
			if is_xy_plane:
				origin.x = i_pos
			else:
				origin.z = i_pos
			# Choose y point
			var y_pos = (y * dist_between_units_y) + dist_between_units_y_half - half_decal_size - 2.0
			if not DISABLE_JITTER:
				y_pos += randf_range(-dist_between_units_y_half, dist_between_units_y_half)
			y_pos = clamp(y_pos, -2.0 + half_decal_size, 2.0 - half_decal_size)
			origin.y = y_pos
			
			# Apply scaling and rotation
			var basis = Basis.IDENTITY
			# Rotate to face the right direction
			if is_xy_plane:
				if not is_e:
					basis = basis.rotated(Vector3.UP, PI / 2.0)
				else:
					basis = basis.rotated(Vector3.UP, PI * 1.5)
			else:
				if is_e:
					basis = basis.rotated(Vector3.UP, PI)
				else:
					basis = basis.rotated(Vector3.UP, 0.0)
					
			# Rotate randomly around the center of the model to add some
			# flair to it
			var rotation_amount = 0.0 if DISABLE_JITTER else randf_range(-TAU, TAU)
			if is_xy_plane:
				if is_e:
					basis = basis.rotated(Vector3.FORWARD, rotation_amount)
				else:
					basis = basis.rotated(Vector3.BACK, rotation_amount)
			else:
				# Rotate along the front axis
				if is_e:
					basis = basis.rotated(Vector3.RIGHT, rotation_amount)
				else:
					basis = basis.rotated(Vector3.LEFT, rotation_amount)
					
			# Scale the model up
			var scale = decal_scale if DISABLE_JITTER \
				else randf_range( \
					decal_scale - (0.2 * decal_scale),
					decal_scale + (0.2 * decal_scale))
			basis = basis.scaled(Vector3(scale, scale, scale))
			
			mesh.set_instance_transform(idx, Transform3D(basis, origin))
	print("Configured " + str(last_idx + 1) + " hedge plant clumps")

# Returns: number of items setup
func _apply_hedge_around_corner(
	xz_start: float,
	xz_clamp_start: float,
	xz_clamp_end: float,
	fixed_plane_value: float,
	is_xy_plane: bool,
	rotation_amount: float,
	start_idx: int,
	item_count_width: int,
	item_count_height: int
) -> int:
	var mesh: MultiMesh = $HedgeMultiMeshes/HedgeCornerMultiMesh.multimesh
	var space_between_height_items = 4.0 / float(item_count_height)
	var half_height = space_between_height_items / 2.0
	var space_between_width_items = 0.20 / (item_count_width)
	var half_width = space_between_width_items / 2.0
	var decal_scale = _hedge_decal_scale()
	var half_decal_size = _hedge_decal_rough_size() / 2.0
	for width_idx in item_count_width:
		for height_idx in item_count_height:
			var instance_idx = start_idx + (width_idx * item_count_height) + height_idx
			#print("IDX/W/H: " + str(instance_idx) + " / " + str(width_idx) + "x" + str(height_idx))
			var y_val = (height_idx * space_between_height_items) + half_height - half_decal_size - 2.0
			if !DISABLE_JITTER:
				y_val += randf_range(-half_height, half_height)
			var xz_val = xz_start + (width_idx * space_between_width_items) + half_width
			if !DISABLE_JITTER:
				xz_val += randf_range(-space_between_width_items, space_between_width_items)
			# Clamp values already account for the size of the decal
			
			xz_val = \
				clamp(
					xz_val,
					xz_clamp_start if xz_clamp_start <= xz_clamp_end else xz_clamp_end,
					xz_clamp_end if xz_clamp_end >= xz_clamp_start else xz_clamp_start)
			
			var scale = decal_scale if DISABLE_JITTER \
				else randf_range( \
					decal_scale - (0.2 * decal_scale),
					decal_scale + (0.2 * decal_scale))
					
			var origin = Vector3(
				xz_val if is_xy_plane else fixed_plane_value,
				clamp(y_val, -2.00 + half_decal_size, 2.00 - half_decal_size),
				fixed_plane_value if is_xy_plane else xz_val
			)
			#print("Origin: " + str(origin))
			var basis = Basis.IDENTITY
			if is_xy_plane:
				basis = basis \
					.rotated(Vector3.UP, rotation_amount) \
					.rotated(Vector3.FORWARD, 0.0 if DISABLE_JITTER else randf_range(-TAU, TAU)) \
					.scaled(Vector3(scale, scale, scale))
			else:
				basis = basis \
					.rotated(Vector3.UP, rotation_amount) \
					.rotated(Vector3.RIGHT, 0.0 if DISABLE_JITTER else randf_range(-TAU, TAU)) \
					.scaled(Vector3(scale, scale, scale))
			var transform = Transform3D(basis, origin)
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
		
func _hedge_decal_scale() -> float:
	var size = 5.0
	match _get_detail_level():
		"min":
			size = 0.0
		"low":
			size = 12.0
		"medium":
			size = 10.0
		"high":
			size = 8.0
		"ultra":
			size = 8.0
	return size
	
func _hedge_decal_rough_size() -> float:
	return 0.02 * _hedge_decal_scale()

func _get_detail_level() -> String:
	if Engine.is_editor_hint():
		return "high"
	return Globals.get_graphics_mode()
