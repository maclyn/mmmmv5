@tool
extends Control

signal start_game()

const new_game_str = "(N)ew Game"
const loading_str = "Loading..."

var _saver = Globals.get_saver()
var _using_mobile_kludge = Globals.is_mobile_device()

func show_main_menu():
	if !Engine.is_editor_hint():
		$MenuMusic.play()
	$Buttons/NormalButton.grab_focus()
	$Buttons/NormalButton.text = new_game_str
	
func hide_main_menu():
	$MenuMusic.stop()
	
func _ready() -> void:
	if !Engine.is_editor_hint():
		_apply_mute_mode(_saver.get_is_muted())
		_apply_gfx_mode(_saver.get_graphics_mode())
		_apply_high_score(_saver.get_high_score())
	$Buttons/Quit.visible = !Globals.is_web() && !Globals.is_mobile_device()
	show_main_menu()
	
func _on_visibility_changed() -> void:
	if visible:
		_apply_high_score(_saver.get_high_score())
		
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel") && visible && !Globals.is_web():
		get_tree().quit()
		
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event = event
		print("event: " + str(touch_event.position) + "; " + str(touch_event.pressed))
		if visible && _using_mobile_kludge && touch_event.pressed:
			_try_mobile_web_kludge(touch_event.position)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST && visible && Globals.on_back_notif_receieved():
		print("Qutting due to back from main menu")
		get_tree().quit()
		
func _try_mobile_web_kludge(position: Vector2):
	print("Trying web kludge with press at " + str(position))
	var _buttons: Array[Button] = [
		$Buttons/NormalButton,
		$Buttons/GraphicsMode,
		$Buttons/Mute,
		$Buttons/Help,
		$Buttons/Credits
	]
	var _click_action = [
		_on_normal_button_pressed,
		_on_graphics_mode_pressed,
		_on_button_pressed,
		_on_help_pressed,
		_on_credits_pressed
	]
	for idx in _buttons.size():
		var button = _buttons[idx]
		if _is_point_in_control(position, button):
			print("Found press inside button; clicking " + button.text)
			_click_action[idx].call()

func _on_normal_button_pressed() -> void:
	$Buttons/NormalButton.text = loading_str
	await get_tree().create_timer(0.1).timeout
	start_game.emit()

func _on_button_pressed() -> void:
	var is_muted = !AudioServer.is_bus_mute(0)
	_saver.set_is_muted(is_muted)
	_apply_mute_mode(is_muted)
	
func _apply_mute_mode(is_muted: bool):
	$Buttons/Mute.text = "Unmute" if is_muted else "Mute"
	AudioServer.set_bus_mute(0, is_muted)
	
func _on_graphics_mode_pressed() -> void:
	var curr_mode = _saver.get_graphics_mode()
	var new_mode = "low"
	match curr_mode:
		"min":
			new_mode = "low"
		"low":
			new_mode = "medium"
		"medium":
			new_mode = "high"
		"high":
			if Globals.is_web():
				new_mode = "min"
			else:
				new_mode = "ultra"
		"ultra":
			new_mode = "min"
	_saver.set_graphics_mode(new_mode)
	_apply_gfx_mode(new_mode)
	
func _apply_gfx_mode(mode: String) -> void:
	Globals.set_graphics_mode(mode)
	$Buttons/GraphicsMode.text = _gfx_mode_to_label(mode)
	
func _apply_high_score(high_score: int) -> void:
	$HighScoreLabel.text = "High Score: " + str(high_score)
	
func _on_credits_pressed() -> void:
	_show_text_dialog("Credits", "res://misc/CREDITS.txt", 14)
	
func _on_help_pressed() -> void:
	_show_text_dialog("Help", "res://misc/HELP.txt")
	
func _on_quit_pressed() -> void:
	if Globals.is_web():
		return
	get_tree().quit()

func _gfx_mode_to_label(mode: String):
	match mode:
		"min":
			return "GFX-Min"
		"low":
			return "GFX-Low"
		"medium":
			return "GFX-Med"
		"high":
			return "GFX-High"
		"ultra":
			return "GFX-Ultra"
	return ""

func _show_text_dialog(title: String, path: String, font_size: int = 20) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var file_str = file.get_as_text()
	var d = AcceptDialog.new()
	d.title = title
	d.dialog_text = file_str
	d.ok_button_text = "Got it!"
	d.get_label().add_theme_font_size_override("font_size", font_size)
	d.get_ok_button().add_theme_font_size_override("font_size", 28)
	add_child(d)
	d.popup_centered(Vector2i(300, 200))
	d.show()
	
	if _using_mobile_kludge:
		await get_tree().create_timer(5).timeout
		d.hide()
		
func _is_point_in_control(point: Vector2, control: Control) -> bool:
	var control_pos = control.global_position
	var control_size = control.size
	var control_scale = control.get_global_transform_with_canvas().get_scale()
	var is_in_x: bool = point.x >= control_pos.x and point.x <= control_pos.x + (control_size.x * control_scale.x)
	var is_in_y: bool = point.y >= control_pos.y and point.y <= control_pos.y + (control_size.y * control_scale.y)
	return is_in_x and is_in_y
