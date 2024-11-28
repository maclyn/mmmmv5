extends Control

signal start_easy_game()
signal start_normal_game()
signal start_spooky_game()

func show_main_menu():
	$Music.play()
	
func hide_main_menu():
	$Music.stop()

func _on_easy_button_pressed() -> void:
	start_easy_game.emit()

func _on_normal_button_pressed() -> void:
	start_normal_game.emit()

func _on_spooky_button_pressed() -> void:
	start_spooky_game.emit()

func _on_button_pressed() -> void:
	AudioServer.set_bus_mute(0, !AudioServer.is_bus_mute(0))
