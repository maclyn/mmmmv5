extends Node

@export var hedge_scene: PackedScene

const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const MAZE_WIDTH_AND_HEIGHT = 25
const LEAD_IN_DIST = 4
const MAX_DIST = MAZE_WIDTH_AND_HEIGHT * 4

var blocks: Dictionary = {}

enum Direction { NORTH, SOUTH, EAST, WEST }

func _dir_to_grid_move(direction: Direction) -> Vector2i:
	match direction:
		Direction.NORTH:
			return Vector2i(0, -1)
		Direction.SOUTH:
			return Vector2i(0, 1)
		Direction.EAST:
			return Vector2i(1, 0)
		Direction.WEST:
			return Vector2i(-1, 0)
	assert(false, "failed to match dir")
	return Vector2i.ZERO

enum FeatureType {
	NONE,
	LEFT_CORNER,
	RIGHT_CORNER,
	JUNCTION_TWO_WAY_SPLIT_L_R,
	JUNCTION_TWO_WAY_SPLIT_L_FWD,
	JUNCTION_TWO_WAY_SPLIT_R_FWD
}
	
func _feature_topology_relative_to_south_movement_as_dirs(feature: FeatureType) -> Array[Direction]:
	match feature:
		FeatureType.NONE:
			return [Direction.SOUTH]
		FeatureType.LEFT_CORNER:
			return [Direction.EAST]
		FeatureType.RIGHT_CORNER:
			return [Direction.WEST]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R:
			return [Direction.EAST, Direction.WEST]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD:
			return [Direction.SOUTH, Direction.EAST]
		FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD:
			return [Direction.SOUTH, Direction.WEST]
	assert(false, "Feature not matched!")
	return []
	
func _feature_topology_relative_to_south_movement(feature: FeatureType) -> Array[Vector2i]:
	var as_dirs = _feature_topology_relative_to_south_movement_as_dirs(feature)
	var rval: Array[Vector2i] = []
	for dir in as_dirs:
		rval.push_back(_dir_to_grid_move(dir))
	return rval
	
func _choose_random_feature() -> FeatureType:
	var choice = randi_range(0, 100)
	if choice < 70:
		return FeatureType.NONE
	if choice < 75:
		return FeatureType.LEFT_CORNER
	if choice < 80:
		return FeatureType.RIGHT_CORNER
	if choice < 87:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_FWD
	if choice < 94:
		return FeatureType.JUNCTION_TWO_WAY_SPLIT_R_FWD
	return FeatureType.JUNCTION_TWO_WAY_SPLIT_L_R

class MazeBlock:
	var prev: MazeBlock = null
	var next: Array[MazeBlock] = []
	var walls = {
		Direction.NORTH: true,
		Direction.SOUTH: true,
		Direction.EAST: true,
		Direction.WEST: true
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
		
	func create_sibling(direction: Direction) -> MazeBlock:
		var x = 0
		var y = 0
		var opposite_wall
		match direction:
			Direction.NORTH:
				x = position.x
				y = position.y - 1
				opposite_wall = Direction.SOUTH
			Direction.SOUTH:
				x = position.x
				y = position.y + 1
				opposite_wall = Direction.NORTH
			Direction.EAST:
				x = position.x + 1
				y = position.y
				opposite_wall = Direction.WEST
			Direction.WEST:
				x = position.x - 1
				y = position.y
				opposite_wall = Direction.EAST
		var sibling = MazeBlock.new(x, y)
		sibling.dist_from_start = dist_from_start + 1
		if direction == Direction.NORTH || direction == Direction.SOUTH:
			walls[direction] = false
			sibling.walls[opposite_wall] = false
		else:
			walls[opposite_wall] = false
			sibling.walls[direction] = false
		return sibling
		
	func actualize(scene: PackedScene, root: Node):
		var base_x = position.x * MAZE_BLOCK_SQUARE_SIZE
		var base_z = position.y * MAZE_BLOCK_SQUARE_SIZE
		if walls[Direction.NORTH]:
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
		if walls[Direction.SOUTH]:
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
		if walls[Direction.EAST]:
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
		if walls[Direction.WEST]:
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
				
func _dir_of_path_of_block(block: MazeBlock):
	if block.prev == null:
		return Direction.SOUTH
	var curr_x = block.position.x
	var curr_y = block.position.y
	var prev = block.prev
	var dx = prev.position.x - curr_x
	var dy = prev.position.y - curr_y
	var direction = Direction.NORTH
	if absi(dx) != 0:
		if dx > 0:
			direction = Direction.EAST
		else:
			direction = Direction.WEST
	else:
		if dy > 0:
			direction = Direction.SOUTH
		else:
			direction = Direction.NORTH
	return direction
				
func _build_topology_for_block_and_feature(block: MazeBlock, feature: FeatureType) -> Array[Vector2i]:
	var direction = _dir_of_path_of_block(block)
	var base_topology = _feature_topology_relative_to_south_movement(feature)
	var topology: Array[Vector2i] = []
	# https://stackoverflow.com/questions/4780119/2d-euclidean-vector-rotations
	match direction:
		Direction.NORTH:
			for cell in base_topology:
				topology.push_back(Vector2i(cell.x, -cell.y))
		Direction.SOUTH:
			topology.append_array(base_topology)
		Direction.WEST:
			for cell in base_topology:
				topology.push_back(Vector2i(cell.y, -cell.x))
		Direction.EAST:
			for cell in base_topology:
				topology.push_back(Vector2i(-cell.y, cell.x))
	return topology

func _can_fit_feature(block: MazeBlock, feature: FeatureType) -> bool:
	var topology = _build_topology_for_block_and_feature(block, feature)
	if topology.is_empty():
		return false
	var curr_x = block.position.x
	var curr_y = block.position.y
	for cell in topology:
		var x = curr_x + cell.x
		var y = curr_y + cell.y
		if x < 0 || y < 0:
			return false
		if x >= MAZE_WIDTH_AND_HEIGHT || y >= MAZE_WIDTH_AND_HEIGHT:
			return false
		if _has_block_at_position(x, y):
			return false
	return true

func _has_block_at_position(x: int, y: int):
	if x not in blocks:
		return false
	var sub_dict = blocks[x]
	return y in sub_dict
	
func _add_block_at_position(block: MazeBlock, x: int, y: int):
	if x not in blocks:
		blocks[x] = {}
	var sub_dict = blocks[x]
	assert(y not in sub_dict, "should not overwrite!")
	sub_dict[y] = block

func _ready() -> void:
	var start_position = Vector2i.ZERO
	while start_position == Vector2i.ZERO:
		start_position = generate_maze()
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
func generate_maze() -> Vector2i:
	var maze_width = MAZE_WIDTH_AND_HEIGHT
	var maze_height = MAZE_WIDTH_AND_HEIGHT

	var start_x = int(maze_width / 2.0)
	var start_y = -LEAD_IN_DIST / 2
	var curr_x = start_x
	var curr_y = start_y
	var start_block: MazeBlock = MazeBlock.new(start_x, start_y)
	start_block.is_entrance = true
	
	var get_all_blocks = func() -> Array[MazeBlock]:
		var all_blocks: Array[MazeBlock] = []
		var leads: Array[MazeBlock] = [start_block]
		while !leads.is_empty():
			var block = leads.pop_front()
			all_blocks.push_back(block)
			for next_block in block.next:
				leads.push_back(next_block)
		return all_blocks
	
	var last_block: MazeBlock = start_block
	
	# Create a little start path
	for _i in range(LEAD_IN_DIST):
		curr_y += 1
		var new_block = last_block.create_sibling(Direction.SOUTH)
		last_block.next.push_back(new_block)
		new_block.prev = last_block
		last_block = new_block
		
	var heads: Array[MazeBlock] = [last_block]
	var end_block: MazeBlock = null
	while !heads.is_empty():
		var head = heads.pop_front()
		var feature_generation_attempts = 0
		while true:
			var feature = _choose_random_feature()
			feature_generation_attempts += 1
			var does_fit = _can_fit_feature(head, feature)
			if does_fit:
				# This is a little wasteful, but whatever
				var topology = _build_topology_for_block_and_feature(head, feature)
				
			if feature_generation_attempts > 15:
				break
	
	# FAILURE -- We didn't build a good path
	#if end_block == null:
	#	blocks.clear()
	#	return Vector2i.ZERO

	# SUCCESS -- We have a path

	# Place objects in the scene
	var all_blocks = get_all_blocks.call()
	for block in all_blocks:
		block.actualize(hedge_scene, self)
	
	return Vector2i(
		start_x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		start_y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)
