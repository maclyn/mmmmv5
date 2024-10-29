extends Control

signal start_easy_game()
signal start_normal_game()
signal start_spooky_game()

func _on_easy_button_pressed() -> void:
	start_easy_game.emit()

func _on_normal_button_pressed() -> void:
	start_normal_game.emit()

func _on_spooky_button_pressed() -> void:
	start_spooky_game.emit()
