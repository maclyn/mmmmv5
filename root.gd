@tool
extends Node3D

func _ready() -> void:
	_show_main_menu()
	get_tree().set_auto_accept_quit(!Globals.is_mobile_native())
	
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if Input.is_action_just_pressed("wireframe_mode") && Globals.is_debug():
		var rs = get_viewport()
		rs.debug_draw = (rs.debug_draw + 1) % 5
	if Input.is_action_just_pressed("fullscreen"):
		if get_window().mode == Window.MODE_WINDOWED:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
	if Input.is_action_just_pressed("quit_game"): # Escape/Start
		_on_back()
	if Input.is_action_just_pressed("resume_game") or Input.is_action_just_pressed("jump"): # Enter/A button
		_on_resume()
	
func _show_main_menu():
	$MainMenu.show_main_menu()
	$MainMenu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func _hide_main_menu():
	$MainMenu.hide_main_menu()
	$MainMenu.visible = false
	if !Globals.is_mobile_native():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func _on_main_menu_start_game() -> void:
	_hide_main_menu()
	$Playfield.start_new_game()

func _on_playfield_game_over() -> void:
	_show_main_menu()

func _on_playfield_back_pressed() -> void:
	_on_back()
	
func _on_back() -> void:
	if $Playfield.is_in_game():
		if get_tree().paused:
			_on_resume()
			$Playfield._round_over(false, true)
		else:
			$Playfield/HUD/PausedContainer.visible = true
			get_tree().paused = true
			$ResumeButton.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume() -> void:
	get_tree().paused = false
	$Playfield/HUD/PausedContainer.visible = false
	$ResumeButton.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
