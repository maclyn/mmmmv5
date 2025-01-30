extends Node

class_name Constants
enum GameDifficulty {
	EASY,
	NORMAL,
	SPOOKY,
	HARD
}

const Saver = preload("res://saver.gd")

var saver = Saver.new()
var graphics_mode: String = "low"
var tick_count: int
var last_handled_back_notif: int = 0
var shader_update_thread: Thread = null
var shutting_down: bool = false
var start_time_s: float = 0
var shader_time_ms: int = 0

func get_saver() -> Object:
	return saver
	
func set_graphics_mode(mode: String):
	graphics_mode = mode

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS" || emulate_mobile()
	
func emulate_mobile() -> bool:
	return false
	
func is_debug() -> bool:
	return OS.has_feature("editor")
	
func time_ms() -> int:
	return shader_time_ms

func on_back_notif_receieved() -> bool:
	var now = Time.get_ticks_msec()
	var should_handle = (now - last_handled_back_notif) > 250
	last_handled_back_notif = now
	return should_handle

func _ready() -> void:
	#ProjectSettings.set_restart_if_changed("input_devices/pointing/emulate_touch_from_mouse", true)
	#ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", emulate_mobile())
	#ProjectSettings.save()
	
	start_time_s = Time.get_unix_time_from_system()
	shader_update_thread = Thread.new()
	shader_update_thread.start(_update_shader_time)

func _process(_delta: float) -> void:
	tick_count += 1
		
func _update_shader_time() -> void:
	while not shutting_down:
		var delta = Time.get_unix_time_from_system() - start_time_s
		var now_ms = int(delta * 1000.0)
		if now_ms != shader_time_ms:
			shader_time_ms = now_ms
			RenderingServer.global_shader_parameter_set("time_ms", shader_time_ms)
	call_deferred("_join_shader_update_thread")
	
func _join_shader_update_thread():
	shader_update_thread.wait_to_finish()

func _exit_tree() -> void:
	shutting_down = true
