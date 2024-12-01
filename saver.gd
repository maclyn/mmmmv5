extends Node

const SAVE_FILE = "user://score.save"

# Returns true on new high score
func compare_to_last_high_score_and_maybe_update(difficulties: Array[String], curr_difficulty: String, score: int) -> bool:
	if !FileAccess.file_exists(SAVE_FILE):
		_create_new_save(difficulties, curr_difficulty, score)
		return true
 
	var save_file = FileAccess.open(SAVE_FILE, FileAccess.READ_WRITE)
	var json_string = save_file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		print("Parse error; resetting save: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		_create_new_save(difficulties, curr_difficulty, score)
		return true
		
	var old_score = json.data[str(curr_difficulty)]
	if old_score > score:
		# Lower than old high score
		return false
		
	# We did better; update
	json.data[str(curr_difficulty)] = score
	var to_str = JSON.stringify(json.data)
	save_file.resize(0)
	save_file.store_string(to_str)
	return true
	
func _create_new_save(difficulties: Array[String], curr_difficulty: String, score: int):
	var new_save = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var dict = {}
	for difficulty in difficulties:
		dict[difficulty] = 0
	dict[str(curr_difficulty)] = score
	new_save.store_line(JSON.stringify(dict))
