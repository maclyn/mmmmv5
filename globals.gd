extends Node

var tick_count: int

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS"

func _process(_delta: float) -> void:
	tick_count += 1
