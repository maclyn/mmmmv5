extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_show_main_menu()
	
func _show_main_menu():
	$MainMenu.show_main_menu()
	$MainMenu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func _hide_main_menu():
	$MainMenu.hide_main_menu()
	$MainMenu.visible = false
	if !Globals.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_main_menu_start_easy_game() -> void:
	_hide_main_menu()
	$Playfield.start_easy_game()

func _on_main_menu_start_normal_game() -> void:
	_hide_main_menu()
	$Playfield.start_normal_game()

func _on_main_menu_start_spooky_game() -> void:
	_hide_main_menu()
	$Playfield.start_spooky_game()

func _on_playfield_game_over() -> void:
	_show_main_menu()
