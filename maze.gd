@tool
extends Node3D

signal on_snake_hit()
signal on_load_changed(message: String)
signal on_loaded(start_position: Vector2i)
signal player_in_quicksand()
signal player_out_of_quicksand()

var maze_block_scene = preload("res://maze_block.tscn")
var snake_scene = preload("res://snek.tscn")
var bird_scene = preload("res://birb.tscn")

# Set to true to make it all possible block types/shapes visible early in 
# the first maze
const DEBUG_ALL_BLOCKS = false

# These values are tied to assets, and are measured in units
# ANY CHANGES HERE NEED CORRESPONDING ASSET CHANGES TOO
const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const SNAKE_LENGTH = 2.2
const SNAKE_WIDTH = 0.2
const BIRD_LENGTH = 0.55
const BIRD_WIDTH = 0.77

# These values are tied to other assumptions in the codebase
# Specfically, in the map shaders and atlas texture logic
# You must change those too if you change the map size
const MAZE_WIDTH_AND_HEIGHT = 20
const MAZE_DIMENS_IN_SCENE_SPACE = MAZE_BLOCK_SQUARE_SIZE * MAZE_WIDTH_AND_HEIGHT
const LEAD_IN_DIST = 3
const MAX_DIST = MAZE_WIDTH_AND_HEIGHT * 4
const MAX_PCT_FORWARD_BLOCKS = 0.4
const SPECIAL_BLOCK_BOUNDARY_IN_BLOCKS = 2
const BIRD_COL_ROW_PADDING = 2 # first and last 2 columns shouldn't have the bird

# Derived from asset values + gameplay values
const EAST_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const WEST_SNAKE_EDGE = -SNAKE_LENGTH * 3
const SOUTH_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const NORTH_SNAKE_EDGE = (-LEAD_IN_DIST * MAZE_BLOCK_SQUARE_SIZE) + (SNAKE_LENGTH * -3)

const EAST_BIRD_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (BIRD_LENGTH * 3)
const WEST_BIRD_EDGE = -BIRD_LENGTH * 3
const SOUTH_BIRD_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (BIRD_LENGTH * 3)
const NORTH_BIRD_EDGE = (-LEAD_IN_DIST * MAZE_BLOCK_SQUARE_SIZE) + (BIRD_LENGTH * -3)

var gen_thread: Thread = null
var difficulty: Constants.GameDifficulty = Constants.GameDifficulty.EASY
# Dynamic root is a node that isn't attached until it's compeltely setup
# add_child(...) on anything already in the scene tree
var dynamic_root: Node3D = null
var blocks: Dictionary = {}
var blocks_count: int = 0
var player: Node3D = null
var snakes: Array[Node] = []
var bird: Node3D = null
var entrance_block: MazeBlock = null
var exit_block: MazeBlock = null
var portal_block: MazeBlock = null
var portal_exit_block: MazeBlock = null
var path_from_exit_to_entrance: Array[MazeBlock] = []
var map_blocks: Array[MazeBlock] = []

# Shared between overhead map and wall maps
var map_image_texture: ImageTexture

enum GridDirection {
	NORTH, 
	SOUTH,
	EAST,
	WEST
}

enum MovementDirection {
	FORWARD,
	BACKWARD,
	RIGHT,
	LEFT
}

enum FeatureType {
	NONE,
	LEFT_CORNER,
	RIGHT_CORNER,
	JUNCTION_TWO_WAY_SPLIT_L_R,
	JUNCTION_TWO_WAY_SPLIT_L_FWD,
	JUNCTION_TWO_WAY_SPLIT_R_FWD,
	JUNCTION_THREE_WAY_SPLIT_L_R_FWD,
	LEFT_S_SHAPE,
	RIGHT_S_SHAPE
}

class MovementList:
	var movements: Array[MovementDirection] = []
	
	func _init(movements_list: Array[MovementDirection]):
		self.movements = movements_list
	
class MazeBlock:
	var prev: MazeBlock = null
	var next: Array[MazeBlock] = []
	var walls = {
		GridDirection.NORTH: true,
		GridDirection.SOUTH: true,
		GridDirection.EAST: true,
		GridDirection.WEST: true
	}
	var position: Vector2i = Vector2i(0, 0)
	var is_entrance: bool = false
	var is_exit: bool = false
	var in_solution_path: bool = false
	var dist_from_start: int = 0
	var instance: Node = null
	
	func _init(x: int, y: int):
		position.x = x
		position.y = y
		
	func create_sibling(direction: GridDirection) -> MazeBlock:
		var x = 0
		var y = 0
		var opposite_wall
		match direction:
			GridDirection.NORTH:
				x = position.x
				y = position.y - 1
				opposite_wall = GridDirection.SOUTH
			GridDirection.SOUTH:
				x = position.x
				y = position.y + 1
				opposite_wall = GridDirection.NORTH
			GridDirection.EAST:
				x = position.x + 1
				y = position.y
				opposite_wall = GridDirection.WEST
			GridDirection.WEST:
				x = position.x - 1
				y = position.y
				opposite_wall = GridDirection.EAST
		var sibling = MazeBlock.new(x, y)
		sibling.dist_from_start = dist_from_start + 1
		sibling.prev = self
		walls[direction] = false
		sibling.walls[opposite_wall] = false
		self.next.push_back(sibling)
		return sibling
				
	func direction_from_prev() -> GridDirection:
		if prev == null:
			return GridDirection.SOUTH
		var curr_x = position.x
		var curr_y = position.y
		var dx = curr_x - prev.position.x
		var dy = curr_y - prev.position.y
		var direction = GridDirection.SOUTH
		if absi(dx) != 0:
			if dx > 0:
				direction = GridDirection.EAST
			else:
				direction = GridDirection.WEST
		else:
			if dy > 0:
				direction = GridDirection.SOUTH
			else:
				direction = GridDirection.NORTH
		return direction
		
	func actualize(maze_block: Node3D):
		var x = position.x * MAZE_BLOCK_SQUARE_SIZE
		var y = position.y * MAZE_BLOCK_SQUARE_SIZE
		maze_block.position.x = x + HEDGE_LENGTH
		maze_block.position.y = HEDGE_HEIGHT / 2.0
		maze_block.position.z = y + HEDGE_LENGTH
		instance = maze_block
		maze_block.configure_walls(
			walls[GridDirection.NORTH],
			walls[GridDirection.EAST],
			walls[GridDirection.SOUTH],
			walls[GridDirection.WEST]
		)
		if is_entrance:
			maze_block.add_exit()
		if is_exit:
			maze_block.add_key()
			match direction_from_prev():
				GridDirection.NORTH:
					instance.rotate_key_y(PI)
				GridDirection.SOUTH:
					instance.rotate_key_y(0)
				GridDirection.EAST:
					instance.rotate_key_y(PI * 1.5)
				GridDirection.WEST:
					instance.rotate_key_y(PI * 0.5)
		
	func snekify():
		instance.snekify()
		
	func show_arrow():
		var prev = direction_from_prev()
		instance.show_arrow(
			prev == GridDirection.NORTH,
			prev == GridDirection.SOUTH,
			prev == GridDirection.EAST,
			prev == GridDirection.WEST
		)

func build_new_maze(difficulty: Constants.GameDifficulty):
	self.difficulty = difficulty
	gen_thread = Thread.new()
	gen_thread.start(build_new_maze_impl, Thread.PRIORITY_HIGH)
	
func join_maze_gen_thread(start_position: Vector2i):
	if gen_thread != null:
		gen_thread.wait_to_finish()
	var exit_position = _maze_block_position_to_center_in_scene_space(exit_block.position.x, exit_block.position.y)
	$EndMarker.global_position = Vector3(exit_position.x, 4, exit_position.y)
	$StartMarker.global_position = Vector3(start_position.x, 4, start_position.y)
	$MapViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if Engine.is_editor_hint():
		print("Completed setup")
		# show_path_out()
	print("Background thread joined")
		
func build_new_maze_impl():
	var start_position = Vector2i.ZERO
	_emit_load_changed("Building maze...")
	if Engine.is_editor_hint():
		print("Building maze in editor")
	while start_position == Vector2i.ZERO:
		blocks.clear()
		blocks_count = 0
		start_position = _generate_maze(Engine.is_editor_hint())
	_emit_loaded(start_position)
	call_deferred("join_maze_gen_thread", start_position)
	print("Background thread complete")

func clear_maze() -> void:
	if dynamic_root == null:
		print("Will not clear maze witout dynamic_root set")
		return
	for x in blocks:
		for y in blocks[x]:
			var instance = blocks[x][y].instance
			dynamic_root.remove_child(instance)
			instance.queue_free()
	blocks = {}
	for snake in snakes:
		dynamic_root.remove_child(snake)
		snake.queue_free()
	snakes = []
	if bird != null:
		dynamic_root.remove_child(bird)
		bird.queue_free()
		bird = null
	portal_block = null
	portal_exit_block = null
	exit_block = null 
	map_blocks.clear()
	path_from_exit_to_entrance.clear()
	remove_child(dynamic_root)
	dynamic_root = null
		
func on_first_frame() -> void:
	var map_viewport_texture = $MapViewport.get_texture()
	var image: Image = map_viewport_texture.get_image()
	map_image_texture = ImageTexture.create_from_image(image)
	
	var wall_map_image: Image = image.duplicate(true)
	wall_map_image.rotate_90(CLOCKWISE)
	# Uncomment to generate a new textures/map_sample.png
	# wall_map_image.save_png("/Users/maclyn/Development/mmmmv5/textures/map_sample.png")
	var wall_map_image_texture = ImageTexture.create_from_image(wall_map_image)
	for block in map_blocks:
		var center = _maze_block_position_to_center_in_scene_space(block.position.x, block.position.y)
		block.instance.get_south_wall().add_map(wall_map_image_texture, center.x, center.y)
	
func show_path_out() -> void:
	if portal_block != null:
		portal_block.instance.drop_portal()
	if exit_block != null:
		exit_block.instance.hide_key()
	for block in path_from_exit_to_entrance:
		block.show_arrow()
	if is_instance_valid(bird):
		dynamic_root.remove_child(bird)
	_add_snakes()
	
# player is actually the pivot node for the player
func attach_player(player: Node3D, player_instance: Node3D) -> void:
	self.player = player
	if bird != null:
		bird.attach_player(player_instance)
	for x in blocks:
		for y in blocks[x]:
			var block = blocks[x][y]
			block.instance.attach_player(player)
	
func update_player_marker(x: float, z: float, rotation_y: float):
	$PlayerMarker.global_position = Vector3(x, 4, z)
	$PlayerMarker/DirectionRoot/DirectionArrow.rotation.z = -(rotation_y + (PI / 2))

func end_block_position_in_scene_space() -> Vector2i:
	return _maze_block_position_to_center_in_scene_space(exit_block.position.x, exit_block.position.y)
	
func before_start_block_position_in_scene_space() -> Vector2i:
	var start = path_from_exit_to_entrance[path_from_exit_to_entrance.size() - 1]
	return _maze_block_position_to_center_in_scene_space(start.position.x, start.position.y)

func before_end_block_position_in_scene_space() -> Vector2i:
	return _maze_block_position_to_center_in_scene_space(
		exit_block.prev.position.x,
		exit_block.prev.position.y)

func path_block_count() -> int:
	return path_from_exit_to_entrance.size()
	
func get_portal_exit_pos() -> Vector2:
	return portal_exit_block.instance.get_portal_exit()
	
func set_map_env(env: Environment):
	$MapViewport/MapViewportCamera.environment = env
	
func get_overhead_camera_image() -> Image:
	return map_image_texture.get_image()

func _ready() -> void:
	$MapViewport/MapViewportCamera.position.x = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	# strictly speaking: not important for an orthoganal camera
	$MapViewport/MapViewportCamera.position.y = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	$MapViewport/MapViewportCamera.position.z = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	if Engine.is_editor_hint():
		print("Generating maze in editor")
		build_new_maze_impl() # Threading leads to freezing on editor load

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug_graphics_change") && Globals.is_debug():
		Globals.next_graphics_mode()
		path_from_exit_to_entrance[0].instance.debug_reset_decals() # all decals are shared, so we just need 1

func _movement_dir_as_xy_when_pointing_in_dir(movement: MovementDirection, direction: GridDirection) -> Vector2i:
	var base_xy = _movement_dir_as_xy_when_pointing_north(movement)
	match direction:
		GridDirection.NORTH:
			return base_xy
		GridDirection.SOUTH:
			return Vector2i(-base_xy.x, -base_xy.y)
		GridDirection.EAST:
			return Vector2i(-base_xy.y, base_xy.x)
		GridDirection.WEST:
			return Vector2i(base_xy.y, -base_xy.x)
	assert(false, "failed to match dir")
	return Vector2i.ZERO

func _movement_dir_as_xy_when_pointing_north(movement: MovementDirection) -> Vector2i:
	match movement:
		MovementDirection.FORWARD:
			return Vector2i(0, -1)
		MovementDirection.BACKWARD:
			return Vector2i(0, 1)
		MovementDirection.RIGHT:
			return Vector2i(1, 0)
		MovementDirection.LEFT:
			return Vector2i(-1, 0)
	assert(false, "failed to match feature")
	return Vector2i.ZERO
	
func _movement_dir_as_grid_direction_when_pointing_in_dir(movement: MovementDirection, direction: GridDirection) -> GridDirection:
	var xy = _movement_dir_as_xy_when_pointing_in_dir(movement, direction)
	match xy:
		Vector2i(0, 1):
			return GridDirection.SOUTH
		Vector2i(0, -1):
			return GridDirection.NORTH
		Vector2i(1, 0):
			return GridDirection.EAST
		Vector2i(-1, 0):
			return GridDirection.WEST
	assert(false, "failed to match dir")
	return GridDirection.NORTH

func _feature_to_movement_list_array(feature: FeatureType) -> Array[MovementList]:
	match feature:
		FeatureType.NONE:
			return [MovementList.new([MovementDirection.FORWARD])]
		FeatureType.LEFT_CORNER:
			return [MovementList.new([MovementDirection.LEFT])]
		FeatureType.RIGHT_CORNER:
			return [MovementList.new([MovementDirection.RIGHT])]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R:
			return [MovementList.new([MovementDirection.LEFT]), MovementList.new([MovementDirection.RIGHT])]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD:
			return [MovementList.new([MovementDirection.LEFT]), MovementList.new([MovementDirection.FORWARD])]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD:
			return [MovementList.new([MovementDirection.RIGHT]), MovementList.new([MovementDirection.FORWARD])]
		FeatureType.JUNCTION_THREE_WAY_SPLIT_L_R_FWD:
			return [MovementList.new([MovementDirection.LEFT]), MovementList.new([MovementDirection.RIGHT]), MovementList.new([MovementDirection.FORWARD])]
		FeatureType.LEFT_S_SHAPE:
			return [MovementList.new([MovementDirection.FORWARD, MovementDirection.LEFT, MovementDirection.LEFT, MovementDirection.RIGHT, MovementDirection.RIGHT])]
		FeatureType.RIGHT_S_SHAPE:
			return [MovementList.new([MovementDirection.FORWARD, MovementDirection.RIGHT, MovementDirection.RIGHT, MovementDirection.LEFT, MovementDirection.LEFT])]
	assert(false, "Feature not matched!")
	return []
	
func _choose_random_feature() -> FeatureType:
	var choice = randi_range(0, 100)
	if choice < 20:
		return FeatureType.NONE # i.e. go forward
	if choice < 35:
		return FeatureType.LEFT_CORNER
	if choice < 50:
		return FeatureType.RIGHT_CORNER
	if choice < 60:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD
	if choice < 70:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD
	if choice < 80:
		return FeatureType.JUNCTION_THREE_WAY_SPLIT_L_R_FWD
	if choice < 86:
		return FeatureType.LEFT_S_SHAPE
	if choice < 93:
		return FeatureType.RIGHT_S_SHAPE
	return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R

func _create_sibling_from_movement(base: MazeBlock, movement: MovementDirection) -> MazeBlock:
	var dir = _movement_dir_as_grid_direction_when_pointing_in_dir(movement, base.direction_from_prev())
	return base.create_sibling(dir)

func _can_add_feature_after_block(block: MazeBlock, feature: FeatureType) -> bool:
	var movement_list_array = _feature_to_movement_list_array(feature)
	for movement_list in movement_list_array:
		var curr_x = block.position.x
		var curr_y = block.position.y
		var curr_direction = block.direction_from_prev()
		for movement in movement_list.movements:
			var dxdy = _movement_dir_as_xy_when_pointing_in_dir(movement, curr_direction)
			curr_x += dxdy.x
			curr_y += dxdy.y
			if curr_x >= MAZE_WIDTH_AND_HEIGHT || curr_y >= MAZE_WIDTH_AND_HEIGHT:
				return false
			if curr_x < 0 || curr_y < 0:
				return false
			if _has_block_at_position(curr_x, curr_y):
				return false
			curr_direction = _movement_dir_as_grid_direction_when_pointing_in_dir(movement, curr_direction)
	return true
	
# This will explode if called *without* first checking if this is possible
# See _can_add_feature_after_block
func _add_feature_after_block_and_return_new_heads(block: MazeBlock, feature: FeatureType) -> Array[MazeBlock]:
	var new_heads: Array[MazeBlock] = []
	var movement_list_array = _feature_to_movement_list_array(feature)
	for movement_list in movement_list_array:
		var curr_head = block
		for movement in movement_list.movements:
			curr_head = _create_sibling_from_movement(curr_head, movement)
			_add_block_at_position(curr_head)
		new_heads.push_back(curr_head)
	assert(new_heads.size() > 0, "should have some new heads")
	return new_heads

func _has_block_at_position(x: int, y: int):
	if x not in blocks:
		return false
	var sub_dict = blocks[x]
	return y in sub_dict
	
func _add_block_at_position(block: MazeBlock):
	var x = block.position.x
	var y = block.position.y
	if x not in blocks:
		blocks[x] = {}
	var sub_dict = blocks[x]
	assert(y not in sub_dict, "should not add block at existing position")
	sub_dict[y] = block
	blocks_count += 1
	
# Generate the maze, and return the center of the maze entrance in world space
# or return Vector2i.ZERO if it failed to generate a good maze
# We consider a maze "bad" in 2 situations:
# -- If there is no "solution" (i.e. we don't have a block at the bottom-most
# part of the maze that is less than MAX_DIST away from the start block)
# -- If the maze is too many straightaways (i.e. unfun)
func _generate_maze(allow_bad_mazes: bool = false):
	print("Generating maze...")
	var start_x = int(MAZE_WIDTH_AND_HEIGHT / 2.0)
	var start_y = int(-LEAD_IN_DIST / 2.0)
	var start_block: MazeBlock = MazeBlock.new(start_x, start_y)
	start_block.is_entrance = true
	_add_block_at_position(start_block)
	entrance_block = start_block
	
	var last_block: MazeBlock = start_block
	var none_feature_count = 0
	var total_feature_count = 0
	
	# Create a little start path
	for _i in range(LEAD_IN_DIST):
		var new_block = last_block.create_sibling(GridDirection.SOUTH)
		last_block.next.push_back(new_block)
		new_block.prev = last_block
		_add_block_at_position(new_block)
		last_block = new_block
		none_feature_count += 1
		total_feature_count += 1
		
	var heads: Array[MazeBlock] = [last_block]
	var end_block_dist = -1
	var end_block: MazeBlock = null
	while !heads.is_empty():
		var head: MazeBlock = heads.pop_front()
		var feature_generation_attempts = 0
		while true:
			var feature = _choose_random_feature()
			feature_generation_attempts += 1
			var does_fit = _can_add_feature_after_block(head, feature)
			if does_fit:
				var new_heads = _add_feature_after_block_and_return_new_heads(head, feature)
				heads.append_array(new_heads)
				if feature == FeatureType.NONE:
					none_feature_count += 1
				total_feature_count += 1
				break
				
			if feature_generation_attempts > 15:
				if head.position.y == MAZE_WIDTH_AND_HEIGHT - 1:
					if head.dist_from_start > end_block_dist && head.dist_from_start < MAX_DIST:
						end_block_dist = head.dist_from_start
						end_block = head
				break
	
	var forward_block_pct = float(none_feature_count) / float(total_feature_count)
	if forward_block_pct > MAX_PCT_FORWARD_BLOCKS && !allow_bad_mazes:
		# FAILURE -- Probably a boring maze to play
		print("Failed boring maze of ", str(forward_block_pct), "% forward blocks")
		return Vector2i.ZERO
	if end_block == null:
		# FAILURE -- We didn't build a good path
		return Vector2i.ZERO
	else:
		# SUCCESS -- We have a path
		end_block.is_exit = true
		exit_block = end_block
		var node = exit_block
		while node != null:
			path_from_exit_to_entrance.push_back(node)
			node = node.prev
		
	# Place objects in the scene
	# Also choose special maze blocks
	_emit_load_changed("Building completed maze...")
	
	# We can add_child(...) to a dummy node so long as we don't took the
	# actual scene graph (which needs to be deferred)
	dynamic_root = Node3D.new()
	
	var blocks_built = 0
	for x in blocks:
		for y in blocks[x]:
			var block = blocks[x][y]
			block.actualize(maze_block_scene.instantiate()) # The slowest line here
			dynamic_root.add_child(block.instance)
			blocks_built += 1
			_emit_load_changed("Added " + str(blocks_built) + " of " + str(blocks_count))
			
			if y < SPECIAL_BLOCK_BOUNDARY_IN_BLOCKS \
				|| y > MAZE_WIDTH_AND_HEIGHT - SPECIAL_BLOCK_BOUNDARY_IN_BLOCKS \
				|| x < SPECIAL_BLOCK_BOUNDARY_IN_BLOCKS \
				|| x > MAZE_WIDTH_AND_HEIGHT - SPECIAL_BLOCK_BOUNDARY_IN_BLOCKS \
			:
				continue


			# Place a map on the south wall every ~50 blocks, and never
			# in first or last 2 blocks
			# Add map (maybe)
			if randf_range(0.0, 1.0) > (1.0 - _percent_chance_of_map_block()):
				print("Added map block at " + str(x) + ", " + str(y))
				map_blocks.push_back(block)
				
			# Maybe portal too?
			if (
				portal_block == null &&
				block.walls[GridDirection.SOUTH] &&
				randf_range(0.0, 1.0) > (1.0 - _percent_chance_of_portal_block())
			):
				portal_block = block
				# Choose an exit block
				var half_grid_height = int(MAZE_WIDTH_AND_HEIGHT / 2)
				for i in blocks:
					for j in half_grid_height:
						var y_idx = j + half_grid_height
						if !_has_block_at_position(i, y_idx):
							continue
						var portal_exit_candidate = blocks[i][y_idx]
						if (
							portal_exit_candidate != null &&
							portal_exit_candidate.walls[GridDirection.NORTH] &&
							randf_range(0.0, 1.0) > (1.0 - _percent_chance_of_portal_block())
						):
							portal_exit_block = portal_exit_candidate
				if portal_exit_block == null:
					portal_block = null
				else:
					print("Chose portal block at " + str(x) + ", " + str(y))
			elif randf_range(0.0, 1.0) > (1.0 - _percent_chance_of_quicksand_block()):
				print("Added quicksand block at " + str(x) + ", " + str(y))
				block.instance.add_quicksand()
				block.instance.connect("player_in_quicksand", _emit_in_quicksand)
				block.instance.connect("player_out_of_quicksand", _emit_out_of_quicksand)
			elif randf_range(0.0, 1.0) > (1.0 - _percent_chance_of_spike_block()):
				print("Added spike block at " + str(x) + ", " + str(y))
				block.instance.add_spike()
	if portal_block:
		portal_block.instance.enable_portal(portal_exit_block.instance)
		portal_exit_block.instance.set_as_portal_exit()
	_add_bird()
	add_child.call_deferred(dynamic_root)
	return _maze_block_position_to_center_in_scene_space(start_x, start_y)
		
func _maze_block_position_to_center_in_scene_space(x: int, y: int) -> Vector2i:
	return Vector2i(
		x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)
		
func _add_snakes():
	# New snake, who this
	for x in range(1, MAZE_WIDTH_AND_HEIGHT):
		var should_snake = randf_range(0.0, 1.0) <= _percent_chance_of_snake_per_row_col() && (exit_block == null || x != exit_block.position.x)
		if !should_snake:
			continue
		var north_to_south = randf_range(0.0, 1.0) > 0.5
		var dx = 0
		var dy = 1 if north_to_south else -1
		var x_pos = _maze_block_position_to_center_in_scene_space(x, 0).x - (SNAKE_WIDTH / 2.0)
		var y_pos = NORTH_SNAKE_EDGE if north_to_south else SOUTH_SNAKE_EDGE
		var near_exit = exit_block != null && abs(x - exit_block.position.x) < 3
		y_pos += ((1 if north_to_south else -1) * randf_range(0.2 if near_exit else 0.0, MAZE_DIMENS_IN_SCENE_SPACE * 0.5))
		_new_snake(dx, dy, x_pos, y_pos, 90.0 if north_to_south else 270.0)
	for y in range(1, MAZE_WIDTH_AND_HEIGHT - 1):
		var should_snake = randf_range(0.0, 1.0) <= _percent_chance_of_snake_per_row_col() && exit_block != null && y != exit_block.position.y
		if !should_snake:
			continue
		var west_to_east = randf_range(0.0, 1.0) > 0.5
		var dx = 1 if west_to_east else -1
		var dy = 0
		var x_pos = WEST_SNAKE_EDGE if west_to_east else EAST_SNAKE_EDGE
		var near_exit = abs(y - exit_block.position.y) < 3
		x_pos += ((1 if west_to_east else -1) * randf_range(0.2 if near_exit else 0.0, MAZE_DIMENS_IN_SCENE_SPACE * 0.5))
		var y_pos = _maze_block_position_to_center_in_scene_space(0, y).y - (SNAKE_WIDTH / 2.0)
		_new_snake(dx, dy, x_pos, y_pos, 180.0 if west_to_east else 0.0)
		
func _add_bird():
	var is_col_bird = randi_range(0, 1) == 0 # true
	# Birds always go south-to-north *or* east-to-west
	var row_or_col = randi_range(BIRD_COL_ROW_PADDING, MAZE_WIDTH_AND_HEIGHT - BIRD_COL_ROW_PADDING) # 10
	var dx = 0 if is_col_bird else -1
	var dy = -1 if is_col_bird else 0
	var centered_in_row_or_col_pos = (
		_maze_block_position_to_center_in_scene_space(0, row_or_col).y if is_col_bird
		else _maze_block_position_to_center_in_scene_space(row_or_col, 0).x)
	var x_pos = centered_in_row_or_col_pos if is_col_bird else EAST_BIRD_EDGE
	var y_pos = centered_in_row_or_col_pos if !is_col_bird else SOUTH_BIRD_EDGE # (MAZE_DIMENS_IN_SCENE_SPACE / 4.0)
	var drop_location_cell = exit_block.prev.position
	var drop_location_xz = _maze_block_position_to_center_in_scene_space(drop_location_cell.x, drop_location_cell.y)
	_new_bird(dx, dy, drop_location_xz, x_pos, y_pos, 0.0 if is_col_bird else 90.0)

func _new_snake(dx: int, dy: int, start_x_pos: float, start_y_pos: float, snake_rot_deg: float = 0.0):
	var snake = snake_scene.instantiate()
	snake.position.x = start_x_pos
	snake.position.z = start_y_pos
	snake.rotation.y = deg_to_rad(snake_rot_deg)
	snake.init_snek(dx, dy, WEST_SNAKE_EDGE, EAST_SNAKE_EDGE, NORTH_SNAKE_EDGE, SOUTH_SNAKE_EDGE)
	snake.attach_player(player)
	snake.connect("collided_with_player", _on_snake_hit)
	dynamic_root.add_child(snake)
	snakes.push_back(snake)
	
func _new_bird(dx: int, dy: int, target: Vector2i, start_x_pos: float, start_y_pos: float, bird_rot_deg: float = 0.0):
	bird = bird_scene.instantiate()
	bird.position.x = start_x_pos
	bird.position.y = 4.5
	bird.position.z = start_y_pos
	bird.rotation.y = deg_to_rad(bird_rot_deg)
	bird.init_bird(dx, dy, target, WEST_BIRD_EDGE, EAST_BIRD_EDGE, NORTH_BIRD_EDGE, SOUTH_BIRD_EDGE)
	bird.attach_player(player)
	bird.connect("player_dropped", _on_player_dropped_by_bird)
	print("Added bird at " + str(bird.position))
	dynamic_root.add_child(bird)
	
func _percent_chance_of_map_block():
	if DEBUG_ALL_BLOCKS:
		return 0.25
	match difficulty:
		Constants.GameDifficulty.EASY:
			return 0.02
		Constants.GameDifficulty.NORMAL:
			return 0.02
		Constants.GameDifficulty.SPOOKY:
			return 0.02
		Constants.GameDifficulty.HARD:
			return 0.02
	return 0.05
	
func _percent_chance_of_portal_block():
	# Doesn't change per difficulty
	# Only 1 per map, and we want it to show up earlier, so skew prob.
	# higher so we hit it soon
	if DEBUG_ALL_BLOCKS:
		return 0.5
	return 0.1
	
func _percent_chance_of_quicksand_block():
	if DEBUG_ALL_BLOCKS:
		return 0.15
	match difficulty:
		Constants.GameDifficulty.EASY:
			return 0.05
		Constants.GameDifficulty.NORMAL:
			return 0.06
		Constants.GameDifficulty.SPOOKY:
			return 0.06
		Constants.GameDifficulty.HARD:
			return 0.07
	return 0.07

func _percent_chance_of_spike_block():
	if DEBUG_ALL_BLOCKS:
		return 0.15
	match difficulty:
		Constants.GameDifficulty.EASY:
			return 0.04
		Constants.GameDifficulty.NORMAL:
			return 0.05
		Constants.GameDifficulty.SPOOKY:
			return 0.05
		Constants.GameDifficulty.HARD:
			return 0.06
	return 0.06
	
func _percent_chance_of_snake_per_row_col():
	if DEBUG_ALL_BLOCKS:
		return 1.0
	match difficulty:
		Constants.GameDifficulty.EASY:
			return 0.60
		Constants.GameDifficulty.NORMAL:
			return 0.75
		Constants.GameDifficulty.SPOOKY:
			return 0.65
		Constants.GameDifficulty.HARD:
			return 0.80
	return 0.80

func _on_snake_hit():
	on_snake_hit.emit()

func _on_player_dropped_by_bird():
	dynamic_root.remove_child(bird)

func _emit_load_changed(msg: String) -> void:
	call_deferred("emit_signal", "on_load_changed", msg)

func _emit_loaded(start_position: Vector2i):
	print("Emiting maze loaded with start_pos=" + str(start_position))
	call_deferred("emit_signal", "on_loaded", start_position)

func _emit_in_quicksand() -> void:
	player_in_quicksand.emit()
	
func _emit_out_of_quicksand() -> void:
	player_out_of_quicksand.emit()
