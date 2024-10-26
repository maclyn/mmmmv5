extends Node

@export var maze_block_scene: PackedScene

const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const MAZE_WIDTH_AND_HEIGHT = 25
const LEAD_IN_DIST = 5
const MAX_DIST = MAZE_WIDTH_AND_HEIGHT * 4

var blocks: Dictionary = {}

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
	
	func _init(movements: Array[MovementDirection]):
		self.movements = movements
		
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
	if choice < 30:
		return FeatureType.NONE
	if choice < 40:
		return FeatureType.LEFT_CORNER
	if choice < 50:
		return FeatureType.RIGHT_CORNER
	if choice < 65:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD
	if choice < 75:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD
	if choice < 80:
		return FeatureType.JUNCTION_THREE_WAY_SPLIT_L_R_FWD
	if choice < 90:
		return FeatureType.LEFT_S_SHAPE
	if choice < 95:
		return FeatureType.RIGHT_S_SHAPE
	return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R
	##
	#if choice < 50:
		#return FeatureType.NONE
	#return FeatureType.JUNCTION_THREE_WAY_SPLIT_L_R_FWD

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
		maze_block.configure_walls(
			walls[GridDirection.NORTH],
			walls[GridDirection.EAST],
			walls[GridDirection.SOUTH],
			walls[GridDirection.WEST]
		)
		maze_block.position.x = x + HEDGE_LENGTH
		maze_block.position.y = HEDGE_HEIGHT / 2.0
		maze_block.position.z = y + HEDGE_LENGTH
		root.add_child(maze_block)

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
	if feature != FeatureType.NONE:
		print("generated a " + str(feature))
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

func _ready() -> void:
	var start_position = Vector2i.ZERO
	while start_position == Vector2i.ZERO:
		blocks.clear()
		start_position = _generate_maze()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y

func _process(_delta: float) -> void:
	pass

# Generate the maze, and return the center of the maze entrance in world space
# or ZERO if it failed to generate a valid maze, which is (theoretically) 
# possible
# We could attempt a walk back approach (rewind when hitting a dead end, and
# try again and again), but (a) this isn't the best approach, and (b) it's 
# probably faster just to keep trying this
func _generate_maze() -> Vector2i:
	var start_x = int(MAZE_WIDTH_AND_HEIGHT / 2.0)
	var start_y = -LEAD_IN_DIST / 2
	var curr_x = start_x
	var curr_y = start_y
	var start_block: MazeBlock = MazeBlock.new(start_x, start_y)
	start_block.is_entrance = true
	_add_block_at_position(start_block)
	
	var last_block: MazeBlock = start_block
	
	# Create a little start path
	for _i in range(LEAD_IN_DIST):
		curr_y += 1
		var new_block = last_block.create_sibling(GridDirection.SOUTH)
		last_block.next.push_back(new_block)
		new_block.prev = last_block
		_add_block_at_position(new_block)
		last_block = new_block
		
	var heads: Array[MazeBlock] = [last_block]
	var end_block_dist = -1
	var end_block: MazeBlock = null
	while !heads.is_empty():
		var head: MazeBlock = heads.pop_front()
		var feature_generation_attempts = 0
		while true:
			var feature = _choose_random_feature()
			feature_generation_attempts += 1
			if feature != FeatureType.NONE:
				print("not none")
			var does_fit = _can_add_feature_after_block(head, feature)
			if does_fit:
				var new_heads = _add_feature_after_block_and_return_new_heads(head, feature)
				heads.append_array(new_heads)
				break
				
			if feature_generation_attempts > 15:
				if head.position.y == MAZE_WIDTH_AND_HEIGHT - 1:
					if head.dist_from_start > end_block_dist && head.dist_from_start < MAX_DIST:
						end_block_dist = head.dist_from_start
						end_block = head
				break
	
	if end_block == null:
		# FAILURE -- We didn't build a good path
		return Vector2i.ZERO
	else:
		# SUCCESS -- We have a path
		end_block.is_exit = true
		end_block.walls[GridDirection.SOUTH] = false
		
	# Place objects in the scene
	for x in blocks:
		for y in blocks[x]:
			blocks[x][y].actualize(maze_block_scene, self)
	
	return Vector2i(
		start_x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		start_y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)


func _on_player_look_direction_changed(position: Vector3, rotation: Vector3) -> void:
	$DebugOverheadCamera.position.x = position.x
	$DebugOverheadCamera.position.z = position.z + MAZE_WIDTH_AND_HEIGHT
	$DebugOverheadCamera.position.y = MAZE_WIDTH_AND_HEIGHT * 3
