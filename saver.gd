extends Node

const SAVE_FILE = "user://score.save"
const SETTINGS_FILE = "user://settings.save"

const SCORE_KEY = "score"
const MUTE_KEY = "mute"

func get_high_score() -> int:
	if !FileAccess.file_exists(SAVE_FILE):
		return 0
	var save_file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	var json_string = save_file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		return 0
	if not SCORE_KEY in json.data:
		return 0
	return json.data[SCORE_KEY]

# Returns true on new high score
func compare_to_last_high_score_and_maybe_update(score: int) -> bool:
	if !FileAccess.file_exists(SAVE_FILE):
		_create_new_save_file(score)
		return true
 
	var save_file = FileAccess.open(SAVE_FILE, FileAccess.READ_WRITE)
	var json_string = save_file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK || not SCORE_KEY in json.data:
		print("Parse error; resetting save: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		_create_new_save_file(score)
		return true
		
	var old_score = json.data[SCORE_KEY]
	if old_score >= score:
		# Lower than old high score
		return false
		
	# We did better; update
	json.data[SCORE_KEY] = score
	var to_str = JSON.stringify(json.data)
	save_file.resize(0)
	save_file.store_string(to_str)
	return true
	
func _create_new_save_file(score: int):
	var new_save = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var dict = {}
	dict[SCORE_KEY] = score
	new_save.store_line(JSON.stringify(dict))
