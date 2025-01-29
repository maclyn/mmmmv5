extends Control

signal start_game()

func show_main_menu():
	$Music.play()
	
func hide_main_menu():
	$Music.stop()
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST && visible && Globals.on_back_notif_receieved():
		print("Qutting due to back from main menu")
		get_tree().quit()

func _on_normal_button_pressed() -> void:
	start_game.emit()

func _on_button_pressed() -> void:
	AudioServer.set_bus_mute(0, !AudioServer.is_bus_mute(0))
	
func _on_credits_pressed() -> void:
	_show_text_dialog("Credits", "res://misc/CREDITS.txt")
	
func _on_help_pressed() -> void:
	_show_text_dialog("Help", "res://misc/HELP.txt")

func _on_visibility_changed() -> void:
	if visible:
		var high_score = Globals.get_saver().get_high_score()
		$HighScoreLabel.text = "High Score: " + str(high_score)
		
func _show_text_dialog(title: String, path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var file_str = file.get_as_text()
	var d = AcceptDialog.new()
	d.title = title
	d.dialog_text = file_str
	d.ok_button_text = "Got it!"
	d.get_label().add_theme_font_size_override("font_size", 20)
	d.get_ok_button().add_theme_font_size_override("font_size", 28)
	add_child(d)
	d.popup_centered(Vector2i(300, 200))
	d.show()
