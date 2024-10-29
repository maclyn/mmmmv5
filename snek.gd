extends AnimatableBody3D

const SNAKE_SPEED_UNITS_PER_S = 25.0

var x_dir = 0
var y_dir = 0
var min_x = 0.0
var max_x = 0.0
var min_y = 0.0
var max_y = 0.0
var pos_updated = false
var updated_to_value = Vector3()

func _process(delta: float) -> void:
	var new_pos = position
	new_pos.x += (x_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	new_pos.z += (y_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	if x_dir < 0 && new_pos.x < min_x:
		new_pos.x = max_x
	elif x_dir > 0 && new_pos.x > max_x:
		new_pos.x = min_x
	elif y_dir < 0 && new_pos.z < min_y:
		new_pos.z = max_y
	elif y_dir > 0 && new_pos.z > max_y:
		new_pos.z = min_y
	position = new_pos

func init_snek(x_dir: int, y_dir: int, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	self.x_dir = x_dir
	self.y_dir = y_dir
	self.min_x = min_x
	self.max_x = max_x
	self.min_y = min_y
	self.max_y = max_y
