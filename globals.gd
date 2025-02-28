@tool
extends Node

class_name Constants
enum GameDifficulty {
	EASY,
	NORMAL,
	SPOOKY,
	HARD
}

const MINIMAP_SIZE = 1024.0

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
	
func next_graphics_mode():
	var new_mode = "min"
	match _graphics_mode:
		"min":
			new_mode = "low"
		"low":
			new_mode = "medium"
		"medium":
			new_mode = "high"
		"high":
			new_mode = "ultra"
		"ultra":
			new_mode = "min"
	set_graphics_mode(new_mode)
	
func set_graphics_mode(mode: String):
	_graphics_mode = mode
	
	# DISABLED: Doesn't match the aesthetics 
	#var msaa_value = Viewport.MSAA_DISABLED
	#match mode:
		#"min":
			#msaa_value = Viewport.MSAA_DISABLED
		#"low":
			#msaa_value = Viewport.MSAA_DISABLED
		#"medium":
			#msaa_value = Viewport.MSAA_DISABLED
		#"high":
			#msaa_value = Viewport.MSAA_2X
		#"ultra":
			#msaa_value = Viewport.MSAA_4X
	#get_viewport().msaa_3d = msaa_value
	#if mode == "medium":
		#get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	#else:
		#get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	
	# Weirdly stuttery without these
	Engine.physics_jitter_fix = 0
	Input.set_use_accumulated_input(false)
	
	# This makes the game a lot more responsive (at the cost of CPU consumption, but
	# physics on this game are really easy, so we can eat it in most cases )
	var refresh = DisplayServer.screen_get_refresh_rate()
	if mode != "low" && !Globals.is_web():
		Engine.physics_ticks_per_second = DisplayServer.screen_get_refresh_rate()
	
func get_graphics_mode():
	return _graphics_mode

func is_mobile_native() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS" || emulate_mobile()
	
func is_web() -> bool:
	return OS.get_name() == "Web" || emulate_web()
	
func is_threaded() -> bool:
	return !is_web()
	
func is_mobile_web() -> bool:
	if !is_web():
		return false
	return (OS.has_feature("web_ios") ||
		OS.has_feature("web_android") ||
		(!OS.has_feature("web_linuxbsd") && !OS.has_feature("web_macos") && !OS.has_feature("web_windows"))
	)
	
func is_mobile_device():
	return is_mobile_native() || is_mobile_web()
	
func emulate_web() -> bool:
	return false
	
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
	if !is_web():
		_start_time_s = Time.get_unix_time_from_system()
		_shader_update_thread = Thread.new()
		_shader_update_thread.start(_update_shader_time)
	else:
		print("WARNING: Inside a web project; updating shader global time on main thread in _process")
	
func _process(delta: float) -> void:
	if is_web():
		_update_shader_time_param()
		
func _update_shader_time() -> void:
	while not _shutting_down:
		_update_shader_time_param()
	call_deferred("_join_shader_update_thread")
	
func _update_shader_time_param() -> void:
	var delta = Time.get_unix_time_from_system() - _start_time_s
	var now_ms = int(delta * 1000.0)
	if now_ms != _shader_time_ms:
		_shader_time_ms = now_ms
		RenderingServer.global_shader_parameter_set("time_ms", _shader_time_ms)
				
func _join_shader_update_thread():
	_shader_update_thread.wait_to_finish()

func _exit_tree() -> void:
	_shutting_down = true
