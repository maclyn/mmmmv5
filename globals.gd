extends Node

var tick_count: int

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS"
	
func is_debug() -> bool:
	return OS.has_feature("editor")

func _process(_delta: float) -> void:
	tick_count += 1
