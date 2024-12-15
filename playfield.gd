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

var minimap_viewport_texture: ViewportTexture
var minimap_image_texture: ImageTexture

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
	if !Engine.is_editor_hint():
		minimap_viewport_texture = $MiniMapViewport.get_texture()
		minimap_image_texture = ImageTexture.create_from_image(minimap_viewport_texture.get_image())
		$HUD/MiniMapContainer/MiniMap.texture = minimap_image_texture
	else:
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
			if Globals.tick_count % 2 == 0:
				$Maze.update_maps()
			else:
				_update_minimap()
		GameState.RETURNING_TO_LOCK:
			_format_label_to_remaining_timer()
			$Maze.update_maps()
			_update_minimap()
			
func _update_minimap():
	var player_pos = $Player.global_position
	$MiniMapViewport/MiniMapCamera.global_position.x = player_pos.x
	$MiniMapViewport/MiniMapCamera.global_position.z = player_pos.z
	minimap_image_texture.update(minimap_viewport_texture.get_image())

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
	$MobileControls.visible = Globals.is_mobile()
	var start_position = $Maze.build_new_maze()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y
	$Player.rotation.x = 0
	$Player.rotation.x = 0
	$Player.respawn()

	game_state = GameState.GOING_TO_KEY
	last_game_state_transition_time = Time.get_ticks_msec()
	
	$Player.set_camera(
		difficulty != GameDifficulty.SPOOKY,
		difficulty == GameDifficulty.SPOOKY)
	$Sun.visible = difficulty != GameDifficulty.SPOOKY
		
	if difficulty != GameDifficulty.SPOOKY:
		$Music/NormalMusicPlayer.play()
		$MiniMapViewport/MiniMapCamera.environment = default_map_env
	else:
		$Music/SpookyMusicPlayer.play()
		$MiniMapViewport/MiniMapCamera.environment = dark_map_env
	$Maze.set_map_env($MiniMapViewport/MiniMapCamera.environment)
	$Maze.connect("on_snake_hit", _game_over)
	$Maze.attach_player($Player/Pivot)
	
	$GameTimer.start(_max_time_to_key_ms() / 1000.0)

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
