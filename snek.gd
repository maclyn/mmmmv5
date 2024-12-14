@tool
extends AnimatableBody3D

signal collided_with_player()

const SNAKE_SPEED_UNITS_PER_S = 7.0

var x_dir = 0
var y_dir = 0
var min_x = 0.0
var max_x = 0.0
var min_y = 0.0
var max_y = 0.0
var start_pos = Vector3()

# if the player hasn't seen us, we shouldn't kill the player
# it's too cheezy
var player_node: Node3D = null
var on_screen = false
var spotted = false

func _physics_process(delta: float) -> void:
	var new_pos = position
	new_pos.x += (x_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	new_pos.z += (y_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	if x_dir < 0 && new_pos.x < min_x:
		new_pos.x = max_x
		position = new_pos
		spotted = false
	elif x_dir > 0 && new_pos.x > max_x:
		new_pos.x = min_x
		position = new_pos
		spotted = false
	elif y_dir < 0 && new_pos.z < min_y:
		new_pos.z = max_y
		position = new_pos
		spotted = false
	elif y_dir > 0 && new_pos.z > max_y:
		new_pos.z = min_y
		position = new_pos
		spotted = false
	else:
		var collision = move_and_collide(
			Vector3(x_dir * SNAKE_SPEED_UNITS_PER_S * delta, 0, y_dir * SNAKE_SPEED_UNITS_PER_S * delta),
			false,
			0.001,
			false,
			1)
		if !spotted:
			# TODO: If close (<5 units away), check spotted
			pass
		if collision != null && player_node != null:
			if on_screen && !spotted:
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(self.position, player_node.position)
				query.exclude = [self]
				var result = space_state.intersect_ray(query)
				# TODO: Raycast to decide spotted
				collided_with_player.emit()


func init_snek(x_dir: int, y_dir: int, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	self.x_dir = x_dir
	self.y_dir = y_dir
	self.min_x = min_x
	self.max_x = max_x
	self.min_y = min_y
	self.max_y = max_y
	self.start_pos = position
	
func attach_player(node: Node3D):
	player_node = node

func _on_snek_notifier_screen_entered() -> void:
	on_screen = true

func _on_snek_notifier_screen_exited() -> void:
	on_screen = false
