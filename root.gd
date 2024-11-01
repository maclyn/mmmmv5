extends Node

@export var maze_block_scene: PackedScene
@export var snake_scene: PackedScene
@export var map_scene: PackedScene

const DEBUG = false

const HEDGE_HEIGHT = 4
const HEDGE_LENGTH = 2
const HEDGE_HALF_LENGTH = 1
const HEDGE_THICKNESS = 0.2
const HEDGE_HALF_THICKNESS = 0.1
const MAZE_BLOCK_SQUARE_SIZE = 4
const MAZE_WIDTH_AND_HEIGHT = 25
const MAZE_DIMENS_IN_SCENE_SPACE = MAZE_BLOCK_SQUARE_SIZE * MAZE_WIDTH_AND_HEIGHT
const LEAD_IN_DIST = 5
const MAX_DIST = MAZE_WIDTH_AND_HEIGHT * 4

const SNAKE_LENGTH = 2.2 # units
const SNAKE_WIDTH = 0.2 # units
const SNAKE_SPAWN_PER_COL_ROW_PROB = 0.75 # most rows/columns get a snake

const EAST_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const WEST_SNAKE_EDGE = -SNAKE_LENGTH * 3
const SOUTH_SNAKE_EDGE = (MAZE_DIMENS_IN_SCENE_SPACE) + (SNAKE_LENGTH * 3)
const NORTH_SNAKE_EDGE = (-LEAD_IN_DIST * MAZE_BLOCK_SQUARE_SIZE) + (SNAKE_LENGTH * -3)

# All game state
var blocks: Dictionary = {}
var snakes: Array[Node] = []
var entrance_block: MazeBlock = null
var exit_block: MazeBlock = null
var path_from_exit_to_entrance: Array[MazeBlock] = []
var game_state: GameState = GameState.NOT_STARTED
var curr_difficulty: GameDifficulty = GameDifficulty.NORMAL
var last_game_state_transition_time = Time.get_ticks_msec()

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

enum GameDifficulty {
	EASY,
	NORMAL,
	SPOOKY
}

enum GameState {
	NOT_STARTED,
	GOING_TO_KEY,
	RETURNING_TO_LOCK,
	GAME_OVER_WIN,
	GAME_OVER_LOSS
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
	if choice < 20:
		return FeatureType.NONE
	if choice < 35:
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
		var prev = direction_from_prev()
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
					instance.rotate_key_y(PI * 1.5)
				GridDirection.EAST:
					instance.rotate_key_y(0)
				GridDirection.WEST:
					instance.rotate_key_y(PI / 2)
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
	
func _ready():
	_show_main_menu()
	# TODO: Switch to this over project settings scaling when
	# nearest neighbor 3D scaling is added to Godot
	# get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# get_tree().root.scaling_3d_scale = 0.333
	
func _process(_delta: float) -> void:
	match game_state:
		GameState.NOT_STARTED:
			pass
		GameState.GAME_OVER_WIN:
			pass
		GameState.GAME_OVER_LOSS:
			$Player.rotation.x = deg_to_rad($GameOver.pct_faded_in() * 45)
			pass
		GameState.GOING_TO_KEY:

			_format_label_to_remaining_timer()
		GameState.RETURNING_TO_LOCK:
			_format_label_to_remaining_timer()
			# LERP exit follow mesh back
			# Assume each block takes ~1 second to traverse
			var elapsed = Time.get_ticks_msec() - last_game_state_transition_time
			var segment_count = path_from_exit_to_entrance.size() - 1
			var total_time_ms = _ms_per_block_when_exiting() * segment_count
			var pct_complete = elapsed / total_time_ms
			if pct_complete > 0.0 && pct_complete < 1.0:
				var segment_idx = lerpf(0.0, segment_count, pct_complete)
				# Segment 0 -> between idx 0 and idx 1
				# Segment 1 -> between idx 1 and idx 2
				# Etc.
				var start_idx = floori(segment_idx)
				var pct_in_segment = segment_idx - start_idx
				if start_idx + 1 < path_from_exit_to_entrance.size():
					var start_block = path_from_exit_to_entrance[start_idx]
					var end_block = path_from_exit_to_entrance[start_idx + 1]
					var start_pos = _maze_block_position_to_center_in_scene_space(
						start_block.position.x, start_block.position.y)
					var end_pos = _maze_block_position_to_center_in_scene_space(
						end_block.position.x, end_block.position.y)
					$ExitFollowMesh.position = Vector3(
						lerpf(start_pos.x, end_pos.x, pct_in_segment),
						$ExitFollowMesh.position.y,
						lerpf(start_pos.y, end_pos.y, pct_in_segment))
			
			var player_pos = $Player.global_position
			$ExitFollowMesh.look_at(Vector3(player_pos.x, $ExitFollowMesh.position.y, player_pos.z), Vector3.UP, true)

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
	entrance_block = start_block
	
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
		exit_block = end_block
		var node = exit_block
		while node != null:
			path_from_exit_to_entrance.push_back(node)
			node = node.prev
		
	# Place objects in the scene, along with maps
	for x in blocks:
		for y in blocks[x]:
			blocks[x][y].actualize(maze_block_scene, self)
			if curr_difficulty == GameDifficulty.EASY && y % 3 == 0 && x % 3 == 0:
				blocks[x][y].instance.get_south_wall().add_map($MapViewport.get_texture())
			elif curr_difficulty == GameDifficulty.NORMAL && y % 5 == 0 && x % 5 == 0:
				blocks[x][y].instance.get_south_wall().add_map($MapViewport.get_texture())
				
	return _maze_block_position_to_center_in_scene_space(start_x, start_y)
		
func _maze_block_position_to_center_in_scene_space(x: int, y: int) -> Vector2i:
	return Vector2i(
		x * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH,
		y * MAZE_BLOCK_SQUARE_SIZE + HEDGE_LENGTH)

func _on_player_look_direction_changed(position: Vector3, rotation: Vector3) -> void:
	$MapViewport/MapViewportCamera/PlayerMarker.global_position = Vector3(position.x, 4, position.z)
	pass

func _add_snakes():
	# New snake, who this
	for x in MAZE_WIDTH_AND_HEIGHT:
		var should_snake = randf_range(0.0, 1.0) <= SNAKE_SPAWN_PER_COL_ROW_PROB
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
	for y in MAZE_WIDTH_AND_HEIGHT:
		var should_snake = randf_range(0.0, 1.0) <= SNAKE_SPAWN_PER_COL_ROW_PROB
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
	self.add_child(snake)
	snakes.push_back(snake)

func _on_player_cheat() -> void:
	if game_state == GameState.GOING_TO_KEY:
		var real_pos = _maze_block_position_to_center_in_scene_space(exit_block.position.x, exit_block.position.y)
		$Player.position.x = real_pos.x + 1
		$Player.position.z = real_pos.y + 1
	elif game_state == GameState.RETURNING_TO_LOCK:
		var start = path_from_exit_to_entrance[path_from_exit_to_entrance.size() - 1]
		var real_pos = _maze_block_position_to_center_in_scene_space(start.position.x, start.position.y)
		$Player.position.x = real_pos.x + 1
		$Player.position.z = real_pos.y + 1
		
func _on_player_at_enemy() -> void:
	_game_over(false)
	
func _on_player_at_exit() -> void:
	if game_state == GameState.RETURNING_TO_LOCK:
		_game_over(true)

func _on_player_at_key() -> void:
	game_state = GameState.RETURNING_TO_LOCK
	last_game_state_transition_time = Time.get_ticks_msec()
	$GameTimer.stop()
	$GameTimer.start(_ms_per_block_when_exiting() * 0.001 * path_from_exit_to_entrance.size())
	var key_pos = exit_block.get_key_position()
	exit_block.hide_key()
	$ExitFollowMesh.visible = true
	$ExitFollowMesh.position = key_pos
	var prev_block = _maze_block_position_to_center_in_scene_space(
		exit_block.prev.position.x,
		exit_block.prev.position.y)
	$Player.look_at(Vector3(prev_block.x, $Player.global_position.y, prev_block.y), Vector3.UP, true)
	_add_snakes()
	
func _on_game_timer_timeout() -> void:
	_game_over(false)

func _format_label_to_remaining_timer():
	var time_left = $GameTimer.time_left
	var minutes = floor(time_left / 60)
	var seconds = floor(time_left - (minutes * 60))
	var milliseconds = (time_left - (minutes * 60) - (seconds)) * 10
	$HUD/TimerLabel.text = "%01d:%02d:%01.1d" % [minutes, seconds, milliseconds]

func _ms_per_block_when_exiting() -> float:
	match curr_difficulty:
		GameDifficulty.EASY:
			return 800.0
		GameDifficulty.NORMAL:
			return 625.0
		GameDifficulty.SPOOKY:
			return 600.0
	return 500.0

func _on_main_menu_start_easy_game() -> void:
	_start_new_game(GameDifficulty.EASY)

func _on_main_menu_start_normal_game() -> void:
	_start_new_game(GameDifficulty.NORMAL)

func _on_main_menu_start_spooky_game() -> void:
	_start_new_game(GameDifficulty.SPOOKY)

func _start_new_game(difficulty: GameDifficulty) -> void:
	curr_difficulty = difficulty
	_hide_main_menu()
	var start_position = Vector2i.ZERO
	while start_position == Vector2i.ZERO:
		blocks.clear()
		start_position = _generate_maze()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y
	$Player.rotation.x = 0
	$Player.rotation.x = 0
	$Player.respawn()
	$MapViewport/MapViewportCamera.position.x = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	$MapViewport/MapViewportCamera.position.y = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	$MapViewport/MapViewportCamera.position.z = MAZE_DIMENS_IN_SCENE_SPACE / 2.0
	var exit_position = exit_block.instance.global_position
	$MapViewport/MapViewportCamera/EndMarker.global_position = Vector3(exit_position.x, 4, exit_position.z)


	game_state = GameState.GOING_TO_KEY
	last_game_state_transition_time = Time.get_ticks_msec()
	
	var multiplier = 1.0
	var has_sun = true
	var has_moon = false
	match difficulty:
		GameDifficulty.EASY:
			multiplier = 4.0
		GameDifficulty.NORMAL:
			multiplier = 3.0
		GameDifficulty.SPOOKY:
			multiplier = 2.5
			has_sun = false
			has_moon = true
	$Sun.visible = has_sun
	$Moon.visible = has_moon
	$Player.set_camera(has_sun, has_moon)
	
	if DEBUG:
		$DebugOverheadCamera.make_current()
	
	$GameTimer.start(path_from_exit_to_entrance.size() * multiplier)

func _game_over(did_win: bool) -> void:
	game_state = GameState.GAME_OVER_WIN if did_win else GameState.GAME_OVER_LOSS
	last_game_state_transition_time = Time.get_ticks_msec()
	$GameTimer.stop()
	if did_win:
		$GameOver.win()
	else:
		$GameOver.lose()
	$GameOver.visible = true
	$Player.die()
	await get_tree().create_timer($GameOver.get_show_time_s()).timeout
	for x in blocks:
		for y in blocks[x]:
			remove_child(blocks[x][y].instance)
	blocks = {}
	for snake in snakes:
		remove_child(snake)
	exit_block = null
	path_from_exit_to_entrance.clear()
	_show_main_menu()
	
func _hide_main_menu():
	$MainMenu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_main_menu():
	$MainMenu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$GameOver.visible = false
