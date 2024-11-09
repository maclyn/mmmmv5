extends Node

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS"
