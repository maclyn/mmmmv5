@tool
extends AnimatableBody3D

signal collided_with_player()

const SNAKE_SPEED_UNITS_PER_S = 7.0
const MAX_DIST_FOR_VALID_HIT = 6.0

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
var collided = false

func _physics_process(delta: float) -> void:
	if collided:
		return
	var new_pos = position
	var x_delta = (x_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	var z_delta = (y_dir * SNAKE_SPEED_UNITS_PER_S * delta)
	new_pos.x += x_delta
	new_pos.z += z_delta
	if x_dir < 0 && new_pos.x < min_x:
		new_pos.x = max_x
		_reset_position(new_pos)
	elif x_dir > 0 && new_pos.x > max_x:
		new_pos.x = min_x
		_reset_position(new_pos)
	elif y_dir < 0 && new_pos.z < min_y:
		new_pos.z = max_y
		_reset_position(new_pos)
	elif y_dir > 0 && new_pos.z > max_y:
		new_pos.z = min_y
		_reset_position(new_pos)
	else:
		if player_node != null && !spotted:
			_check_spotted()
		var collision = move_and_collide(
			Vector3(x_delta, 0, z_delta),
			false,
			0.001,
			false,
			1)
		if collision != null:
			if !spotted:
				print("Droppping unfair collision with unspotted player")
				_reset_position(start_pos)
			else:
				print("Colliding!")
				collided = true
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
	
func _reset_position(new_pos: Vector3):
	position = new_pos
	spotted = false
	
func _check_spotted() -> void:
	# Check in camera frustrum
	if !on_screen:
		return
	# Check distance
	if self.global_position.distance_to(player_node.global_position) > MAX_DIST_FOR_VALID_HIT:
		return
	
	# Make sure not behind wall
	var space_state = get_world_3d().direct_space_state
	var start = Vector3(global_position.x, 1, global_position.z)
	var end = Vector3(player_node.global_position.x, 2, player_node.global_position.z)
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [self]
	query.hit_from_inside = false
	var result = space_state.intersect_ray(query)
	if result.size() < 1:
		return
	var collider = result["collider"]
	if collider.is_in_group("player_group"):
		spotted = true
