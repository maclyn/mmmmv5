extends Node

const SAVE_FILE = "user://score.save"
const SETTINGS_FILE = "user://settings.save"

const SCORE_KEY = "score"

const MUTE_KEY = "mute"

const GFX_KEY = "gfx_mode"
const GFX_VALUE_MIN = "min"
const GFX_VALUE_LOW = "low"
const GFX_VALUE_MEDIUM = "medium"
const GFX_VALUE_HIGH = "high"
const GFX_VALUE_ULTRA = "ultra"

const SENSITIVITY_MODIFIER_KEY = "sensitivity"

func get_graphics_mode() -> String:
	return _get_key_from_file(
		SETTINGS_FILE,
		GFX_KEY,
		GFX_VALUE_LOW if Globals.is_mobile_native() or Globals.is_web() else GFX_VALUE_MEDIUM)

func set_graphics_mode(new_mode: String):
	_save_key_to_file(SETTINGS_FILE, GFX_KEY, new_mode)
	
func get_is_muted() -> bool:
	return _get_key_from_file(SETTINGS_FILE, MUTE_KEY, false)
	
func set_is_muted(is_muted: bool) -> void:
	_save_key_to_file(SETTINGS_FILE, MUTE_KEY, is_muted)
	
func get_sensitivity_modifier() -> float:
	return _get_key_from_file(SETTINGS_FILE, SENSITIVITY_MODIFIER_KEY, 1.0)
	
func set_sensitivity_modifier(sensitivity: float) -> void:
	_save_key_to_file(SETTINGS_FILE, SENSITIVITY_MODIFIER_KEY, sensitivity)
	
func get_high_score() -> int:
	return _get_key_from_file(SAVE_FILE, SCORE_KEY, 0)

# Returns true on new high score
func compare_to_last_high_score_and_maybe_update(score: int) -> bool:
	var old_score = _get_key_from_file(SAVE_FILE, SCORE_KEY, 0)
	if old_score >= score:
		# Lower than old high score
		return false
		
	# We did better; update
	_save_key_to_file(SAVE_FILE, SCORE_KEY, score)
	return true
	
func _get_key_from_file(file_path: String, key: Variant, default: Variant) -> Variant:
	if !FileAccess.file_exists(file_path):
		print("File does not exist")
		return default
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		print("Parse result not OK: " + str(parse_result))
		print("Error at " + str(json.get_error_line()) + ": " + json.get_error_message())
		return default
	var dict: Dictionary = json.data
	if not dict.has(key):
		print("Key not in dict: " + str(dict))
		return default
	return dict[key]
	
func _save_key_to_file(file_path: String, key: Variant, value: Variant) -> void:
	if !FileAccess.file_exists(file_path):
		_create_empty_file(file_path)
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result_error = json.parse(json_string)
	var dict = {}
	if parse_result_error != Error.OK:
		_create_empty_file(file_path)
	else:
		dict = json.data
	dict[key] = value
	var to_str = JSON.stringify(dict)
	file.resize(0)
	file.store_string(to_str)
	
func _create_empty_file(file_path: String):
	var new_file = FileAccess.open(file_path, FileAccess.WRITE)
	var dict = {}
	new_file.store_line(JSON.stringify(dict))
