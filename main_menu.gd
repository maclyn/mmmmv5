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
	const credits_path = "res://misc/CREDITS.txt"
	var credits_file = FileAccess.open(credits_path, FileAccess.READ)
	var credits_str = credits_file.get_as_text()
	var c = AcceptDialog.new()
	c.title = "Credits"
	c.dialog_text = credits_str
	c.ok_button_text = "Got it!"
	
	c.get_label().add_theme_font_size_override("font_size", 20)
	c.get_ok_button().add_theme_font_size_override("font_size", 28)
	add_child(c)
	c.popup_centered(Vector2i(300, 200))
	c.show()

func _on_visibility_changed() -> void:
	if visible:
		var high_score = Globals.get_saver().get_high_score()
		$HighScoreLabel.text = "High Score: " + str(high_score)
