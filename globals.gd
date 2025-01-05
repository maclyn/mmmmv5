extends Node

var tick_count: int

func is_mobile() -> bool:
	return OS.get_name() == "Android" || OS.get_name() == "iOS" || emulate_mobile()
	
func emulate_mobile() -> bool:
	return false
	
func is_debug() -> bool:
	return OS.has_feature("editor")
	
func wait_for_ready(node: Node) -> void:
	if node.is_node_ready():
		return
	await node.ready

func _ready() -> void:
	#ProjectSettings.set_restart_if_changed("input_devices/pointing/emulate_touch_from_mouse", true)
	#ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", emulate_mobile())
	#ProjectSettings.save()
	pass

func _process(_delta: float) -> void:
	tick_count += 1
