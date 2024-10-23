extends Node

@export var hedge_scene: PackedScene

const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const MAZE_WIDTH_AND_HEIGHT = 75
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
	JUNCTION_TWO_WAY_SPLIT_R_FWD
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
			return Vector2i(base_xy.x, -base_xy.y)
		GridDirection.WEST:
			return Vector2i(-base_xy.x, base_xy.y)
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
	assert(false, "Feature not matched!")
	return []
	
func _choose_random_feature() -> FeatureType:
	var choice = randi_range(0, 100)
	if choice < 40:
		return FeatureType.NONE
	if choice < 50:
		return FeatureType.LEFT_CORNER
	if choice < 60:
		return FeatureType.RIGHT_CORNER
	if choice < 85:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD
	if choice < 95:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD
	return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R

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
		
	func _add_hedge(scene: PackedScene, root: Node, x: float = 0, y: float = 0, y_rotation_deg: int = 0):
		var new_hedge = scene.instantiate()
		new_hedge.position.x = x
		new_hedge.position.y = HEDGE_HEIGHT / 2.0
		new_hedge.position.z = y
		# Flip upside down to provide a little variation in texture looks
		new_hedge.rotation.z = (0.0 if randi_range(0, 1) == 0 else PI)
		# Rotate around y axis 
		new_hedge.rotation.y = deg_to_rad(y_rotation_deg)
		root.add_child(new_hedge)
		
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
		if direction == GridDirection.NORTH || direction == GridDirection.SOUTH:
			walls[direction] = false
			sibling.walls[opposite_wall] = false
		else:
			walls[opposite_wall] = false
			sibling.walls[direction] = false
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
		var base_x = position.x * MAZE_BLOCK_SQUARE_SIZE
		var base_z = position.y * MAZE_BLOCK_SQUARE_SIZE
		if walls[GridDirection.NORTH]:
			_add_hedge(
				scene, root,
				base_x + HEDGE_HALF_LENGTH,
				base_z + HEDGE_HALF_THICKNESS,
				0)
			_add_hedge(
				scene, root,
				base_x + HEDGE_LENGTH + HEDGE_HALF_LENGTH,
				base_z + HEDGE_HALF_THICKNESS,
				0)
		if walls[GridDirection.SOUTH]:
			_add_hedge(
				scene, root,
				base_x + HEDGE_HALF_LENGTH,
				base_z + MAZE_BLOCK_SQUARE_SIZE - HEDGE_HALF_THICKNESS,
				0)
			_add_hedge(
				scene, root,
				base_x + HEDGE_LENGTH + HEDGE_HALF_LENGTH,
				base_z + MAZE_BLOCK_SQUARE_SIZE - HEDGE_HALF_THICKNESS,
				0)
		if walls[GridDirection.EAST]:
			_add_hedge(
				scene, root,
				base_x + HEDGE_HALF_THICKNESS,
				base_z + HEDGE_HALF_LENGTH,
				90)
			_add_hedge(
				scene, root,
				base_x + HEDGE_HALF_THICKNESS,
				base_z + HEDGE_LENGTH +  HEDGE_HALF_LENGTH,
				90)
		if walls[GridDirection.WEST]:
			_add_hedge(
				scene, root,
				base_x + MAZE_BLOCK_SQUARE_SIZE - HEDGE_HALF_THICKNESS,
				base_z + HEDGE_HALF_LENGTH,
				90)
			_add_hedge(
				scene, root,
				base_x + MAZE_BLOCK_SQUARE_SIZE - HEDGE_HALF_THICKNESS,
				base_z + HEDGE_LENGTH +  HEDGE_HALF_LENGTH,
				90)

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

func _ready() -> void:
	var start_position = Vector2i.ZERO
	while start_position == Vector2i.ZERO:
		blocks.clear()
		start_position = _generate_maze()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y
	
	# TODO: Fix z-fighting and clipped corners
	# var first = MazeBlock.new(0, 0)
	# var second = first.create_sibling(Direction.EAST)
	#first.actualize(hedge_scene, self)
	#second.actualize(hedge_scene, self)

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
				break
				
			if feature_generation_attempts > 15:
				# The head might actually solve the maze -- let's see
		# 		# TODO: Check if on bottom edge; if yes --> is_exit
				break
	
	# FAILURE -- We didn't build a good path
	# TODO: Once we setup end blocks, check this
	# if end_block == null:
	#	return Vector2i.ZERO

	# SUCCESS -- We have a path

	# Place objects in the scene
	for x in blocks:
		for y in blocks[x]:
			blocks[x][y].actualize(hedge_scene, self)
	
	return Vector2i(
		start_x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		start_y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)
