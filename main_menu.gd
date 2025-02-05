extends Control

signal start_game()

var _saver = Globals.get_saver()

func _ready() -> void:
	_apply_mute_mode(_saver.get_is_muted())
	_apply_gfx_mode(_saver.get_graphics_mode())
	_apply_high_score(_saver.get_high_score())
	$Buttons/Quit.visible = !Globals.is_web()
	show_main_menu()
	
func _on_visibility_changed() -> void:
	if visible:
		_apply_high_score(_saver.get_high_score())
		
func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel") && visible:
		get_tree().quit()

func show_main_menu():
	$MenuMusic.play()
	$Buttons/NormalButton.grab_focus()
	
func hide_main_menu():
	$MenuMusic.stop()
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST && visible && Globals.on_back_notif_receieved():
		print("Qutting due to back from main menu")
		get_tree().quit()

func _on_normal_button_pressed() -> void:
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
