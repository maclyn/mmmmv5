@tool
extends Node3D

signal on_snake_hit()

@export var maze_block_scene: PackedScene
@export var snake_scene: PackedScene

# These values are tied to assets
# ANY CHANGES HERE NEED CORRESPONDING ASSET CHANGES TOO
const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const SNAKE_LENGTH = 2.2 # units
const SNAKE_WIDTH = 0.2 # units

# These values can be tweaked for gameplay reasons
const MAZE_WIDTH_AND_HEIGHT = 20
const MAZE_DIMENS_IN_SCENE_SPACE = MAZE_BLOCK_SQUARE_SIZE * MAZE_WIDTH_AND_HEIGHT
const LEAD_IN_DIST = 3
const MAX_DIST = MAZE_WIDTH_AND_HEIGHT * 4
const MAX_PCT_FORWARD_BLOCKS = 0.4
const MAP_BLOCKS_APPROX_PERCENT = 0.03
const PERCENT_CHANCE_OF_PORTAL_BLOCK = 0.1
const MAP_BLOCKS_BOUNDARY_SIZE_IN_BLOCKS = 2
const SNAKE_SPAWN_PER_COL_ROW_PROB = 0.75 # most rows/columns get a snake

# Derived from asset values + gameplay values
const EAST_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const WEST_SNAKE_EDGE = -SNAKE_LENGTH * 3
const SOUTH_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const NORTH_SNAKE_EDGE = (-LEAD_IN_DIST * MAZE_BLOCK_SQUARE_SIZE) + (SNAKE_LENGTH * -3)

var blocks: Dictionary = {}
var player: Node3D = null
var snakes: Array[Node] = []
var entrance_block: MazeBlock = null
var exit_block: MazeBlock = null
var portal_block: MazeBlock = null
var portal_exit_block: MazeBlock = null
var path_from_exit_to_entrance: Array[MazeBlock] = []

# Workaround for (what seems like) a bug in ViewportTexture
# https://github.com/godotengine/godot/issues/81928#issuecomment-2337645721
# draw_list_bind_uniform_set: Attempted to use the same texture in framebuffer attachment and a uniform (set: 3, binding: 1), this is not allowed.
var viewport_texture: ViewportTexture
var image_texture: ImageTexture

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
		
	func actualize(scene: PackedScene, root: Node):
		var x = position.x * MAZE_BLOCK_SQUARE_SIZE
		var y = position.y * MAZE_BLOCK_SQUARE_SIZE
		var maze_block = scene.instantiate()
		instance = maze_block
		maze_block.configure_walls(
			walls[GridDirection.NORTH],
			walls[GridDirection.EAST],
			walls[GridDirection.SOUTH],
			walls[GridDirection.WEST]
		)
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
		if is_entrance:
			maze_block.add_exit()
		maze_block.position.x = x + HEDGE_LENGTH
		maze_block.position.y = HEDGE_HEIGHT / 2.0
		maze_block.position.z = y + HEDGE_LENGTH
		root.add_child(maze_block)
		
	func hide_key():
		instance.hide_key()
		
	func get_key_position() -> Vector3:
		return instance.get_key_position()
		
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
		
func build_new_maze() -> Vector2i:
	var start_position = Vector2i.ZERO
	if Engine.is_editor_hint():
		# 5 tries to generate before giving up (to avoid editor freezes)
		print("Building maze in editor")
		var count = 0
		while count < 5 && start_position == Vector2i.ZERO:
			blocks.clear()
			start_position = _generate_maze()
			count += 1
	else:
		while start_position == Vector2i.ZERO:
			blocks.clear()
			start_position = _generate_maze()
	if start_position == Vector2i.ZERO:
		push_error("Failed to generate maze in editor!")
		return Vector2i.ZERO
	var exit_position = exit_block.instance.global_position
	$EndMarker.global_position = Vector3(exit_position.x, 4, exit_position.z)
	return start_position
		
func clear_maze() -> void:
	for x in blocks:
		for y in blocks[x]:
			remove_child(blocks[x][y].instance)
	blocks = {}
	for snake in snakes:
		remove_child(snake)
	snakes = []
	portal_block = null
	portal_exit_block = null
	exit_block = null 
	path_from_exit_to_entrance.clear()
		
func update_maps() -> void:
	image_texture.update(viewport_texture.get_image())
	
func show_path_out() -> void:
	if portal_block != null:
		portal_block.instance.drop_portal()
	exit_block.hide_key()
	for block in path_from_exit_to_entrance:
		block.show_arrow()
	_add_snakes()
	
func attach_player(player: Node3D) -> void:
	self.player = player
	
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

func _ready() -> void:
	viewport_texture = $MapViewport.get_texture()
	image_texture = ImageTexture.create_from_image(viewport_texture.get_image())
	$MapViewport/MapViewportCamera.position.x = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	$MapViewport/MapViewportCamera.position.y = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	$MapViewport/MapViewportCamera.position.z = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	if Engine.is_editor_hint():
		print("Generating maze in editor")
		build_new_maze()
		show_path_out()

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
	
# Generate the maze, and return the center of the maze entrance in world space
# or return Vector2i.ZERO if it failed to generate a good maze
# We consider a maze "bad" in 2 situations:
# -- If there is no "solution" (i.e. we don't have a block at the bottom-most
# part of the maze that is less than MAX_DIST away from the start block)
# -- If the maze is too many straightaways (i.e. unfun)
func _generate_maze() -> Vector2i:
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
	if forward_block_pct > MAX_PCT_FORWARD_BLOCKS:
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
		
	# Place objects in the scene, along with maps
	for x in blocks:
		for y in blocks[x]:
			var block = blocks[x][y]
			block.actualize(maze_block_scene, self)
			# Uncomment this block to make the first south wall you see be a portal blockww
			#if portal_block == null && x == 10 && block.walls[GridDirection.SOUTH]:
				#portal_block = block
			#if portal_block != null && portal_exit_block == null && block.walls[GridDirection.NORTH]:
				#portal_exit_block = block

			# Place a map on the south wall every ~50 blocks, and never
			# in first or last 2 blocks
			if y > MAP_BLOCKS_BOUNDARY_SIZE_IN_BLOCKS && y < MAZE_WIDTH_AND_HEIGHT - MAP_BLOCKS_BOUNDARY_SIZE_IN_BLOCKS && x > MAP_BLOCKS_BOUNDARY_SIZE_IN_BLOCKS && x < MAZE_WIDTH_AND_HEIGHT - MAP_BLOCKS_BOUNDARY_SIZE_IN_BLOCKS:
				if randf_range(0.0, 1.0) > (1.0 - MAP_BLOCKS_APPROX_PERCENT):
					block.instance.get_south_wall().add_map(image_texture)
				# Maybe portal too?
				if (
					portal_block == null &&
					block.walls[GridDirection.SOUTH] &&
					randf_range(0.0, 1.0) > (1.0 - PERCENT_CHANCE_OF_PORTAL_BLOCK)
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
								randf_range(0.0, 1.0) > (1.0 - PERCENT_CHANCE_OF_PORTAL_BLOCK)
							):
								portal_exit_block = portal_exit_candidate
					if portal_exit_block == null:
						portal_block = null
					else:
						print("Chose portal block at " + str(x) + ", " + str(y))
	if portal_block:
		portal_block.instance.enable_portal(portal_exit_block.instance)
		portal_exit_block.instance.set_as_portal_exit()
	return _maze_block_position_to_center_in_scene_space(start_x, start_y)
		
func _maze_block_position_to_center_in_scene_space(x: int, y: int) -> Vector2i:
	return Vector2i(
		x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)
		
func _add_snakes():
	# New snake, who this
	for x in range(1, MAZE_WIDTH_AND_HEIGHT):
		var should_snake = randf_range(0.0, 1.0) <= SNAKE_SPAWN_PER_COL_ROW_PROB && x != exit_block.position.x
		if !should_snake:
			continue
		var north_to_south = randf_range(0.0, 1.0) > 0.5
		var dx = 0
		var dy = 1 if north_to_south else -1
		var x_pos = _maze_block_position_to_center_in_scene_space(x, 0).x - (SNAKE_WIDTH / 2.0)
		var y_pos = NORTH_SNAKE_EDGE if north_to_south else SOUTH_SNAKE_EDGE
		var near_exit = abs(x - exit_block.position.x) < 3
		y_pos += ((1 if north_to_south else -1) * randf_range(0.2 if near_exit else 0.0, MAZE_DIMENS_IN_SCENE_SPACE * 0.5))
		_new_snake(dx, dy, x_pos, y_pos, 90.0 if north_to_south else 270.0)
	for y in range(1, MAZE_WIDTH_AND_HEIGHT - 1):
		var should_snake = randf_range(0.0, 1.0) <= SNAKE_SPAWN_PER_COL_ROW_PROB && y != exit_block.position.y
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


func _new_snake(dx: int, dy: int, start_x_pos: float, start_y_pos: float, snake_rot_deg: float = 0.0):
	var snake = snake_scene.instantiate()
	snake.position.x = start_x_pos
	snake.position.z = start_y_pos
	snake.rotation.y = deg_to_rad(snake_rot_deg)
	snake.init_snek(dx, dy, WEST_SNAKE_EDGE, EAST_SNAKE_EDGE, NORTH_SNAKE_EDGE, SOUTH_SNAKE_EDGE)
	snake.attach_player(player)
	self.add_child(snake)
	snake.connect("collided_with_player", _on_snake_hit)
	snakes.push_back(snake)

func _on_snake_hit():
	on_snake_hit.emit()
