@tool
extends Node

@export var default_map_env: Resource
@export var dark_map_env: Resource

const Saver = preload("res://saver.gd")
var saver = Saver.new()

signal game_over()

# All game state
var game_state: GameState = GameState.NOT_STARTED
var curr_difficulty: GameDifficulty = GameDifficulty.NORMAL
var last_game_state_transition_time = Time.get_ticks_msec()
var time_to_key = -1
var time_to_return = -1

var minimap_atlas_texture: AtlasTexture

enum GameDifficulty {
	EASY,
	NORMAL,
	SPOOKY
}

var difficulties_str_list: Array[String] = [
	str(GameDifficulty.EASY),
	str(GameDifficulty.NORMAL),
	str(GameDifficulty.SPOOKY)
]

enum GameState {
	NOT_STARTED,
	GOING_TO_KEY,
	RETURNING_TO_LOCK,
	GAME_OVER_WIN,
	GAME_OVER_LOSS
}
	
func start_easy_game() -> void:
	_start_new_game(GameDifficulty.EASY)

func start_normal_game() -> void:
	_start_new_game(GameDifficulty.NORMAL)

func start_spooky_game() -> void:
	_start_new_game(GameDifficulty.SPOOKY)
	
func _ready():
	$GameOver.visible = false
	if Engine.is_editor_hint():
		print("Running playfield in editor")
		$MazeDebugCamera.current = true
	
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
			_update_minimap()
		GameState.RETURNING_TO_LOCK:
			_format_label_to_remaining_timer()
			_update_minimap()
			
func _update_minimap():
	var player_pos = $Player.global_position
	if minimap_atlas_texture != null:
		# region is 0.0 to 2048.0
		# actual bounds of visible area to camera are 124, centered at (40, 40)
		# we want to crop in so we can see 20, 20 on each side
		# so visible area is [-10, 90], [-10, 90]
		# a x = 0 and w = 2048, and y = 0 and h = 2048 just draws the whole map
		# the center is (40, 40)
		var viewport_size = 124.0
		var tex_size = 2048.0
		var tex_px_per_scene_unit = tex_size / viewport_size
		var desired_span_px = tex_px_per_scene_unit * 20.0 # 10 units across
		var half_span = desired_span_px / 2.0
		var player_center_x_in_px = player_pos.x * desired_span_px
		var player_center_y_in_px = player_pos.z * desired_span_px
		var ideal_start_x = player_center_x_in_px - half_span
		var ideal_end_x = player_center_x_in_px + half_span
		var ideal_start_y = player_center_y_in_px - half_span
		var ideal_end_y = player_center_y_in_px + half_span
		var new_region = Rect2(tex_size - ideal_start_x, tex_size - ideal_start_y, desired_span_px, desired_span_px)
		# minimap_atlas_texture.filter_clip = true
		minimap_atlas_texture.region = Rect2(0.0, 0.0, tex_size, tex_size) #new_region
		# TODO: Rotate it
		# $HUD/MiniMapContainer/MiniMap.rotation_degrees = Time.get_ticks_msec() / 100.0

func _on_player_look_direction_changed(position: Vector3, rotation_y: float) -> void:
	$Maze.update_player_marker(position.x, position.z, rotation_y)

func _on_player_cheat() -> void:
	if game_state == GameState.GOING_TO_KEY:
		var real_pos = $Maze.end_block_position_in_scene_space()
		$Player.position.x = real_pos.x + 1
		$Player.position.z = real_pos.y + 1
	elif game_state == GameState.RETURNING_TO_LOCK:
		var real_pos = $Maze.before_start_block_position_in_scene_space()
		$Player.position.x = real_pos.x + 1
		$Player.position.z = real_pos.y + 1
	
func _on_player_at_exit() -> void:
	if game_state == GameState.RETURNING_TO_LOCK:
		_game_over(true)

func _on_player_at_key() -> void:
	game_state = GameState.RETURNING_TO_LOCK
	$Music/KeyHitPlayer.play()
	time_to_key = Time.get_ticks_msec() - last_game_state_transition_time
	last_game_state_transition_time = Time.get_ticks_msec()
	$GameTimer.stop()
	$GameTimer.start(_max_time_to_return_s())
	$Maze.show_path_out()
	var prev_block = $Maze.before_end_block_position_in_scene_space()
	$Player.look_at(Vector3(prev_block.x, $Player.global_position.y, prev_block.y), Vector3.UP, true)
	
func _on_player_at_portal() -> void:
	var exit_xz = $Maze.get_portal_exit_pos()
	$Player.global_position = Vector3(exit_xz.x, $Player.global_position.y, exit_xz.y)
	
func _on_player_at_quicksand() -> void:
	_game_over(false)
	
func _on_player_at_spike() -> void:
	_game_over(false)
	
func _on_game_timer_timeout() -> void:
	_game_over(false)

func _format_label_to_remaining_timer():
	var time_left = $GameTimer.time_left
	var minutes = floor(time_left / 60)
	var seconds = floor(time_left - (minutes * 60))
	var milliseconds = (time_left - (minutes * 60) - (seconds)) * 10
	$HUD/TimerLabel.text = "%01d:%02d:%01.1d" % [minutes, seconds, milliseconds]

func _ms_per_block() -> float:
	match curr_difficulty:
		GameDifficulty.EASY:
			return 800.0
		GameDifficulty.NORMAL:
			return 625.0
		GameDifficulty.SPOOKY:
			return 600.0
	return 500.0

func _max_time_to_key_ms() -> float:
	var multiplier = 1.0
	match curr_difficulty:
		GameDifficulty.EASY:
			multiplier = 4.0
		GameDifficulty.NORMAL:
			multiplier = 3.0
		GameDifficulty.SPOOKY:
			multiplier = 2.5
	return multiplier * ($Maze.path_block_count() - 1) * 1000
	
func _max_time_to_return_s() -> float:
	return _ms_per_block() * 0.001 * $Maze.path_block_count()

func _start_new_game(difficulty: GameDifficulty) -> void:
	curr_difficulty = difficulty
	_update_loading_screen(true, "Loading...")
	$Maze.build_new_maze()
	
func _on_maze_load_complete(start_position: Vector2i):
	$MobileControls.visible = !Engine.is_editor_hint() && Globals.is_mobile()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y
	$Player.rotation.x = 0
	$Player.rotation.x = 0
	$Player.respawn()

	game_state = GameState.GOING_TO_KEY
	last_game_state_transition_time = Time.get_ticks_msec()
	
	$Player.set_camera(
		curr_difficulty != GameDifficulty.SPOOKY,
		curr_difficulty == GameDifficulty.SPOOKY)
	$Sun.visible = curr_difficulty != GameDifficulty.SPOOKY
	if !Globals.is_debug():
		if curr_difficulty != GameDifficulty.SPOOKY:
			$Music/NormalMusicPlayer.play()
		else:
			$Music/SpookyMusicPlayer.play()
	$Maze.set_map_env(default_map_env if curr_difficulty != GameDifficulty.SPOOKY else dark_map_env)
	$Maze.attach_player($Player/Pivot, $Player)
	$GameTimer.start(_max_time_to_key_ms() / 1000.0)
	_update_loading_screen(false)
	RenderingServer.request_frame_drawn_callback(_on_first_frame)
	
func _on_first_frame():
	print("on first frame")
	$Maze.on_first_frame()
	var minimap_image_texture = ImageTexture.create_from_image($Maze.get_overhead_camera_image())
	minimap_atlas_texture = AtlasTexture.new()
	minimap_atlas_texture.atlas = minimap_image_texture
	$HUD/MiniMapContainer/MiniMap.texture = minimap_atlas_texture
	
func _on_snake_hit():
	_game_over(false, false)

func _game_over(did_win: bool = false, skip_anim: bool = false) -> void:
	if game_state == GameState.GAME_OVER_WIN || game_state == GameState.GAME_OVER_LOSS:
		return
	game_state = GameState.GAME_OVER_WIN if did_win else GameState.GAME_OVER_LOSS
	if did_win:
		time_to_return = Time.get_ticks_msec() - last_game_state_transition_time
	last_game_state_transition_time = Time.get_ticks_msec()
	$GameTimer.stop()
	$Music/SpookyMusicPlayer.stop()
	$Music/NormalMusicPlayer.stop()
	$Player.die()
	if did_win:
		$Music/WinPlayer.play()
	else:
		$Music/LosePlayer.play()
	if !skip_anim:
		if did_win:
			var score = _calculate_score()
			$GameOver.win(
				score,
				saver.compare_to_last_high_score_and_maybe_update(
					difficulties_str_list,
					str(curr_difficulty),
					score))
		else:
			$GameOver.lose()
		$GameOver.visible = true
		await get_tree().create_timer($GameOver.get_show_time_s()).timeout
	$Maze.clear_maze()
	game_over.emit()
	
func _calculate_score() -> int:
	# Score is based on what % you did better than the expected time
	var pct_better_to_key = 1.0 - (time_to_key / _max_time_to_key_ms())
	var pct_better_to_return = 1.0 - (time_to_return / 1000.0 / (_max_time_to_return_s()))
	return floori((pct_better_to_key * 1000) + (pct_better_to_return * 500))

func _on_mobile_controls_h_swipe(delta_x: float) -> void:
	$Player.external_x_movement(delta_x)

func _on_mobile_controls_main_menu() -> void:
	_game_over(false, true)
	
func _update_loading_screen(visible: bool, text: String = "") -> void:
	$HUD/LoadingContainer.visible = visible
	$HUD/LoadingContainer/LoadingLabel.text = text

func _on_maze_on_load_changed(message: String) -> void:
	_update_loading_screen(true, message)
