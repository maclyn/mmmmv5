@tool
extends Node

# Playfield manages the "game", both overall, and within a given round
# When a round is won, round state is reset, but score isn't change and round number is bumped
# When the game ends, round state is reset

@export var default_map_env: Resource
@export var dark_map_env: Resource

signal back_pressed()
signal game_over()

const ROUND_TRANSITION_TIME_MS = 1500

# Overall game state
var score: int = 0
var round: int = 0
var round_transition_anim_start_time: int = 0

# Round state
var game_state: GameState = GameState.NOT_STARTED
var round_difficulty: Constants.GameDifficulty = Constants.GameDifficulty.EASY
var last_game_state_transition_time = Time.get_ticks_msec()
var player_rotation_y = 0.0
var minimap_atlas_texture: AtlasTexture
var first_frame_after_gen = -1
var have_viewports_been_marked_for_update = false
var have_viewports_been_applied = false

enum GameState {
	NOT_STARTED,
	GOING_TO_KEY,
	RETURNING_TO_LOCK,
	ROUND_OVER_WIN,
	GAME_OVER
}

func start_new_game() -> void:
	_start_new_game()
	
func is_in_game():
	return game_state != GameState.GAME_OVER && game_state != GameState.NOT_STARTED
	
func _ready():
	var indicator_size = $HUD/MiniMapContainer/PlayerIndicator.size.x
	$HUD/MiniMapContainer/PlayerIndicator.pivot_offset = Vector2(indicator_size / 2.0, indicator_size / 2.0)
	var minimap_size = $HUD/MiniMapContainer.size.x
	$HUD/MiniMapContainer.pivot_offset = Vector2(minimap_size / 2.0, minimap_size / 2.0)
	$HUD/MiniMapContainer.rotation_degrees = 180.0
	$Player.attach_ground($Ground)
	$MobileControls.hide_self()

	if Engine.is_editor_hint():
		print("Running playfield in editor")
		$MazeDebugCamera.current = true
		RenderingServer.global_shader_parameter_set("time_ms", 1000)
	
func _process(_delta: float) -> void:
	if game_state == GameState.GOING_TO_KEY || game_state == GameState.RETURNING_TO_LOCK:
		if !have_viewports_been_applied:
			var elapsed_frames = Engine.get_frames_drawn() - first_frame_after_gen
			if elapsed_frames > 1:
				if !have_viewports_been_marked_for_update:
					_prep_scene_for_capture()
					have_viewports_been_marked_for_update = true
				else:
					_apply_viewports_to_scene()
					have_viewports_been_applied = true
	match game_state:
		GameState.NOT_STARTED:
			pass
		GameState.ROUND_OVER_WIN:
			pass
		GameState.GAME_OVER:
			$Player.rotation.x = deg_to_rad($GameOver.pct_faded_in() * 45)
			pass
		GameState.GOING_TO_KEY:
			_format_label_to_remaining_timer()
			_update_minimap()
		GameState.RETURNING_TO_LOCK:
			$Maze.maybe_run_exit_ops()
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
		var viewport_size = 124.0 # 20 units * 4 = 80 units; 44 units padding (22 / 4 -> ~5.5 blocks of padding)
		var tex_size = Constants.MINIMAP_SIZE
		var tex_px_per_scene_unit = tex_size / viewport_size
		var desired_map_size_span_px = tex_px_per_scene_unit * 40.0 # 5 units on each side -> 20.0 -> 40.0
		var half_desired_map_size_span_px = desired_map_size_span_px / 2.0
		var player_center_x_in_px = player_pos.x * tex_px_per_scene_unit
		var player_center_y_in_px = player_pos.z * tex_px_per_scene_unit
		# Offset, since the edge of the map is not (0, 0)
		# 22.0 = 124.0 - (20.0 * 4) / 2.0; flip
		player_center_x_in_px -= (-22.0 * tex_px_per_scene_unit)
		player_center_y_in_px -= (-22.0 * tex_px_per_scene_unit)
		var new_region = Rect2(
			player_center_x_in_px - half_desired_map_size_span_px,
			player_center_y_in_px - half_desired_map_size_span_px,
			desired_map_size_span_px,
			desired_map_size_span_px)
		minimap_atlas_texture.region = new_region# Rect2(0.0, 0.0, tex_size, tex_size) #new_region
		$HUD/MiniMapContainer/PlayerIndicator.rotation = -(player_rotation_y)

func _on_player_look_direction_changed(position: Vector3, rotation_y: float) -> void:
	$Maze.update_player_marker(position, rotation_y)
	player_rotation_y = rotation_y

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
		_round_over(true)

func _on_player_at_key() -> void:
	game_state = GameState.RETURNING_TO_LOCK
	$Music/KeyHitPlayer.play()
	var time_to_key = Time.get_ticks_msec() - last_game_state_transition_time
	var pct_better_to_key = 1.0 - (time_to_key / _max_time_to_key_ms())
	score += floori(pct_better_to_key * 1000)
	_update_score_label()
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
	# This fires once the player has sunk into the quicksand, not on initial
	# hit
	_round_over(false)
	
func _on_player_at_spike() -> void:
	$Music/SpikePlayer.play()
	_round_over(false)
	
func _on_player_at_coin() -> void:
	$Music/CoinPlayer.play()
	score += 10
	_update_score_label()
	
func _on_game_timer_timeout() -> void:
	$Music/LosePlayer.play()
	_round_over(false)

func _format_label_to_remaining_timer():
	var time_left = $GameTimer.time_left
	var minutes = floor(time_left / 60)
	var seconds = floor(time_left - (minutes * 60))
	var milliseconds = (time_left - (minutes * 60) - (seconds)) * 10
	$HUD/TimerLabel.text = "%01d:%02d:%01.1d" % [minutes, seconds, milliseconds]

func _ms_per_block() -> float:
	match round_difficulty:
		Constants.GameDifficulty.EASY:
			return 800.0
		Constants.GameDifficulty.NORMAL:
			return 625.0
		Constants.GameDifficulty.SPOOKY:
			return 600.0
		Constants.GameDifficulty.HARD:
			return 500.0
	return 500.0

func _max_time_to_key_ms() -> float:
	var multiplier = 1.0
	match round_difficulty:
		Constants.GameDifficulty.EASY:
			multiplier = 4.0
		Constants.GameDifficulty.NORMAL:
			multiplier = 3.0
		Constants.GameDifficulty.SPOOKY:
			multiplier = 2.5
		Constants.GameDifficulty.HARD:
			multiplier = 2.0
	return multiplier * ($Maze.path_block_count() - 1) * 1000
	
func _max_time_to_return_s() -> float:
	return _ms_per_block() * 0.001 * $Maze.path_block_count()

func _start_new_game() -> void:
	round = 1
	score = 0
	_update_score_label()
	_update_loading_screen(true, "Loading...")
	_start_new_round()
	
func _start_new_round() -> void:
	game_state = GameState.NOT_STARTED
	if round == 1:
		round_difficulty = Constants.GameDifficulty.EASY
	elif round == 2:
		round_difficulty = Constants.GameDifficulty.NORMAL
	elif round == 3:
		round_difficulty = Constants.GameDifficulty.SPOOKY
	else:
		round_difficulty = Constants.GameDifficulty.HARD if round % 2 == 0 else Constants.GameDifficulty.SPOOKY
	last_game_state_transition_time = Time.get_ticks_msec()
	first_frame_after_gen = -1
	have_viewports_been_marked_for_update = false
	have_viewports_been_applied = false
	player_rotation_y = 0.0
	$HUD/RoundLabel.text = "Round %d" % round
	$Maze.clear_maze()
	$Maze.build_new_maze(round_difficulty)
	
func _on_maze_load_complete(start_position: Vector2i):
	if Globals.is_mobile_device():
		$MobileControls.show_self()
	$Player.position.x = start_position.x
	$Player.position.z = start_position.y
	$Player.respawn()

	game_state = GameState.GOING_TO_KEY
	last_game_state_transition_time = Time.get_ticks_msec()
	
	$Player.set_camera(
		round_difficulty != Constants.GameDifficulty.SPOOKY,
		round_difficulty == Constants.GameDifficulty.SPOOKY)
	$Sun.visible = round_difficulty != Constants.GameDifficulty.SPOOKY

	$Maze.set_map_env(default_map_env if round_difficulty != Constants.GameDifficulty.SPOOKY else dark_map_env)
	$Maze.attach_player($Player/Pivot, $Player)
	_update_loading_screen(false)
	if $HUD/NewRoundOverlay.texture != null:
		# Don't cut off animation if there's still time left
		var time_elapsed = Time.get_ticks_msec() - round_transition_anim_start_time
		if time_elapsed < ROUND_TRANSITION_TIME_MS:
			var delta = ROUND_TRANSITION_TIME_MS - time_elapsed
			await get_tree().create_timer(delta / 1000.0).timeout
		var tex: Texture2D = $HUD/NewRoundOverlay.texture
		$HUD/NewRoundOverlay.texture = null
		$HUD/NewRoundOverlay.visible = false
	if !Engine.is_editor_hint():
		if round_difficulty == Constants.GameDifficulty.EASY:
			$Music/NormalMusicPlayer.play()
		elif round_difficulty == Constants.GameDifficulty.NORMAL:
			$Music/NormalMusicPlayerAlt.play()
		elif round_difficulty == Constants.GameDifficulty.SPOOKY:
			$Music/SpookyMusicPlayer.play()
		else:
			if (round / 2) % 2 == 0:
				$Music/NormalMusicPlayer.play()
			else:
				$Music/NormalMusicPlayerAlt.play()
	$GameTimer.start(_max_time_to_key_ms() / 1000.0)
	first_frame_after_gen = Engine.get_frames_drawn()

func _prep_scene_for_capture():
	print("Prepping scene for capture at frame=" + str(Engine.get_frames_drawn()))
	$Maze.prep_for_viewport_capture()

func _apply_viewports_to_scene():
	print("Applying subviewports to scene at frame=" + str(Engine.get_frames_drawn()))
	$Maze.apply_viewports_to_textures()
	var overhead_image: Image = $Maze.get_overhead_camera_image().duplicate()
	overhead_image.rotate_180()
	var minimap_image_texture = ImageTexture.create_from_image(overhead_image)
	minimap_atlas_texture = AtlasTexture.new()
	minimap_atlas_texture.atlas = minimap_image_texture
	if !Engine.is_editor_hint():
		$HUD/MiniMapContainer/MiniMap.texture = minimap_atlas_texture
	
func _on_snake_hit():
	print("hit snake!")
	$Music/SnakeHissPlayer.play()
	$Player.die()
	await $Music/SnakeHissPlayer.finished
	_round_over(false)

func _round_over(did_win: bool = false, skip_anim: bool = false) -> void:
	if game_state == GameState.ROUND_OVER_WIN || game_state == GameState.GAME_OVER:
		return
	game_state = GameState.ROUND_OVER_WIN if did_win else GameState.GAME_OVER
	if did_win:
		var time_to_return = Time.get_ticks_msec() - last_game_state_transition_time
		var pct_better_to_return = 1.0 - (time_to_return / 1000.0 / (_max_time_to_return_s()))
		score += floori(pct_better_to_return * 500)
		_update_score_label()
	last_game_state_transition_time = Time.get_ticks_msec()
	$GameTimer.stop()
	$Music/SpookyMusicPlayer.stop()
	$Music/NormalMusicPlayer.stop()
	$Music/NormalMusicPlayerAlt.stop()
	$Player.die()
	$MobileControls.hide_self()
	if did_win:
		$Music/WinPlayer.play()
	
	if did_win:
		# Dump the framebuffer into a texture
		var freeze_frame: Image = get_viewport().get_texture().get_image()
		# Account for our "render at" resolution
		var scale_down = 0.4;
		freeze_frame.resize(freeze_frame.get_width() * scale_down, freeze_frame.get_height() * scale_down, Image.INTERPOLATE_NEAREST)
		var image_tex = ImageTexture.new()
		image_tex.image = freeze_frame
		$HUD/NewRoundOverlay.texture = image_tex
		$HUD/NewRoundOverlay.visible = true
		var shader_mat: ShaderMaterial = $HUD/NewRoundOverlay.material
		shader_mat.set_shader_parameter("total_anim_duration_ms", ROUND_TRANSITION_TIME_MS)
		shader_mat.set_shader_parameter("appear_time_ms", Globals.time_ms())
		round_transition_anim_start_time = Time.get_ticks_msec()
		round += 1
		_start_new_round()
		return
	
	if !skip_anim:
		# Quitting (even with a high score) prevents you from saving it
		# By design
		if Globals.get_saver().compare_to_last_high_score_and_maybe_update(score):
			$GameOver.new_high_score(score)
		else:
			$GameOver.game_over()
		await $GameOver.done_showing
	$Maze.clear_maze()
	game_over.emit()
	
func _update_score_label():
	var label = "%06d" % score
	$HUD/ScoreLabel.text = label

func _on_mobile_controls_h_swipe(delta_x: float) -> void:
	$Player.external_x_movement(delta_x * 3.0)

func _on_mobile_controls_main_menu() -> void:
	back_pressed.emit()
	
func _update_loading_screen(visible: bool, text: String = "") -> void:
	if round > 1:
		return
	$HUD/LoadingContainer.visible = visible
	$HUD/LoadingContainer/LoadingLabel.text = text

func _on_maze_on_load_changed(message: String) -> void:
	_update_loading_screen(true, message)

func _on_maze_player_in_quicksand() -> void:
	$Player.on_enter_quicksand()

func _on_maze_player_out_of_quicksand() -> void:
	$Player.on_exit_quicksand()
