extends Control

signal start_game()

func show_main_menu():
	$Music.play()
	
func hide_main_menu():
	$Music.stop()

func _on_normal_button_pressed() -> void:
	start_game.emit()

func _on_button_pressed() -> void:
	AudioServer.set_bus_mute(0, !AudioServer.is_bus_mute(0))

func _on_visibility_changed() -> void:
	if visible:
		var high_score = Globals.get_saver().get_high_score()
		$HighScoreLabel.text = "High Score: " + str(high_score)
