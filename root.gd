extends Node

@export var hedge_scene: PackedScene

const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4

class MazeBlock:
	var occupied: bool = false
	var prev: MazeBlock = null
	var next: MazeBlock = null
	var north_wall: bool = false
	var south_wall: bool = false
	var east_wall: bool = false
	var west_wall: bool = false
	var position: Vector2i = Vector2i(0, 0)
	var is_entrance: bool = false
	var is_exit: bool = false
	var in_solution_path: bool = false
	
	func _init(x: int = 0, y: int = 0):
		position.x = x
		position.y = y
		
	func _add_hedge(scene: PackedScene, root: Node, x: float = 0, y: float = 0, y_rotation_deg: int = 0):
		var new_hedge = scene.instantiate()
		new_hedge.position.x = x
		new_hedge.position.y = HEDGE_HEIGHT / 2
		new_hedge.position.z = y
		# Flip upside down to provide a little variation in texture looks
		# new_hedge.rotation.z = (0 if randi_range(0, 1) == 1 else PI)
		# Rotate around y axis 
		new_hedge.rotation.y = deg_to_rad(y_rotation_deg)
		root.add_child(new_hedge)
		
	func north_of(other: MazeBlock) -> bool:
		return other.position.x == position.x && other.position.y == position.y - 1
		
	func south_of(other: MazeBlock) -> bool:
		return other.position.x == position.x && other.position.y == position.y + 1
		
	func east_of(other: MazeBlock) -> bool:
		return other.position.x - 1 == position.x && other.position.y == position.y
		
	func west_of(other: MazeBlock) -> bool:
		return other.position.x + 1 == position.x && other.position.y == position.y
		
	func actualize(scene: PackedScene, root: Node):
		var base_x = position.x * MAZE_BLOCK_SQUARE_SIZE
		var base_z = position.y * MAZE_BLOCK_SQUARE_SIZE
		if north_wall:
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
		if south_wall:
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
		if east_wall:
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
		if west_wall:
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


var blocks: Dictionary = {}

func _ready() -> void:
	var start_position = generate_maze()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y

func _process(delta: float) -> void:
	pass

# Generate the maze, and return the center of the maze entrance
func generate_maze() -> Vector2i:
	var maze_width = randi_range(20, 30) # 20, 30
	var maze_height = int(maze_width * randf_range(1.0, 1.5))
	for x in range(maze_width):
		blocks[x] = {}
		for y in range(maze_height):
			blocks[x][y] = MazeBlock.new(x, y)
			
	# Pass 1: Build a path from entrance to exit
	var start_x = 2
	var start_y = 0
	var end_x = maze_width - 2
	var end_y = maze_height - 1
	var curr_x = start_x
	var curr_y = start_y
	var last_block = null
	while true:
		var block: MazeBlock = blocks[curr_x][curr_y]
		block.in_solution_path = true
		block.occupied = true
		block.prev = last_block
		block.is_entrance = curr_x == start_x && curr_y == start_y
		if curr_x == end_x && curr_y == end_y:
			block.is_exit = true
		if last_block != null:
			last_block.next = block
		if end_x - curr_x > end_y - curr_y:
			curr_x += 1
		else:
			curr_y += 1
			
		# Figure out which walls should exist
		block.north_wall = !block.is_entrance && last_block && !last_block.north_of(block)
		block.south_wall = last_block && !last_block.south_of(block)
		block.east_wall = true
		block.west_wall = true
			
		last_block = block
		if block.is_exit:
			break
		
	var count = 0
	for x in range(maze_width):
		for y in range(maze_height):
			var block: MazeBlock = blocks[x][y]
			if block.occupied && count < 10:
				block.actualize(hedge_scene, self)
				count += 1
				
	return Vector2i(
		start_x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		start_y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)
