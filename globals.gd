extends Node

class_name Constants
enum GameDifficulty {
	EASY,
	NORMAL,
	SPOOKY,
	HARD
}

const Saver = preload("res://saver.gd")

var _saver = Saver.new()
var _graphics_mode: String = "low"

var _last_handled_back_notif: int = 0

var _shader_update_thread: Thread = null
var _shutting_down: bool = false
var _start_time_s: float = 0
var _shader_time_ms: int = 0

func get_saver() -> Object:
	return _saver
	
func set_graphics_mode(mode: String):
	_graphics_mode = mode
	
func get_graphics_mode():
	return _graphics_mode

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS" || emulate_mobile()
	
func emulate_mobile() -> bool:
	return false
	
func is_debug() -> bool:
	return OS.has_feature("editor")
	
func time_ms() -> int:
	return _shader_time_ms

func on_back_notif_receieved() -> bool:
	var now = Time.get_ticks_msec()
	var should_handle = (now - _last_handled_back_notif) > 250
	_last_handled_back_notif = now
	return should_handle

func _ready() -> void:
	#ProjectSettings.set_restart_if_changed("input_devices/pointing/emulate_touch_from_mouse", true)
	#ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", emulate_mobile())
	#ProjectSettings.save()
	
	_start_time_s = Time.get_unix_time_from_system()
	_shader_update_thread = Thread.new()
	_shader_update_thread.start(_update_shader_time)
		
func _update_shader_time() -> void:
	while not _shutting_down:
		var delta = Time.get_unix_time_from_system() - _start_time_s
		var now_ms = int(delta * 1000.0)
		if now_ms != _shader_time_ms:
			_shader_time_ms = now_ms
			RenderingServer.global_shader_parameter_set("time_ms", _shader_time_ms)
	call_deferred("_join_shader_update_thread")
	
func _join_shader_update_thread():
	_shader_update_thread.wait_to_finish()

func _exit_tree() -> void:
	_shutting_down = true
