@tool
extends AnimatableBody3D

const BIRD_SPEED_UNITS_PER_S = 7.0
const COASTING_HEIGHT = 4.5
const MAX_DIST_FOR_DUCKING = 5.0
const PICKUP_HEIGHT = 2.25

enum BirdState {
	COASTING,
	PICKING_UP_PLAYER,
	GOAL_SEEKING
}

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
var state: BirdState = BirdState.COASTING
var pickup_time = Time.get_ticks_msec()
var pickup_location = Vector3.ZERO

# TODO: Goal coordinates
func init_bird(x_dir: int, y_dir: int, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	self.x_dir = x_dir
	self.y_dir = y_dir
	self.min_x = min_x
	self.max_x = max_x
	self.min_y = min_y
	self.max_y = max_y
	self.start_pos = position
	
func attach_player(node: Node3D):
	player_node = node

func _physics_process(delta: float) -> void:
	var new_pos = position
	var x_delta = (x_dir * BIRD_SPEED_UNITS_PER_S * delta)
	var z_delta = (y_dir * BIRD_SPEED_UNITS_PER_S * delta)
	new_pos.x += x_delta
	new_pos.z += z_delta
	
	if state == BirdState.PICKING_UP_PLAYER || state == BirdState.GOAL_SEEKING:
		# TODO: 
		# TODO: Advance torwards goal
		# TODO: If close to goal, drop the player
		position = new_pos
		player_node.global_position = new_pos
		return
	
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
		# We dip down to y = 3 to get close to player when we're withing x units
		var y_delta = 0.0
		if player_node != null:
			var xz_loc = Vector2(global_position.x, global_position.z)
			var player_xz_loc = Vector2(player_node.global_position.x, player_node.global_position.z)
			var dist = xz_loc.distance_to(player_xz_loc)
			# print("dist = " + str(dist))
			var updated_height = position.y
			if dist < MAX_DIST_FOR_DUCKING:
				# bird coasts at 4.5 units normally
				# we need to get down to 3.0 units to have the jump collide
				# at dist = 0, we want to be
				var height_delta = COASTING_HEIGHT - PICKUP_HEIGHT
				# 5.0 - 4.5 / 5.0 = 0.3
				var pct_from_center = 1.0 - ((MAX_DIST_FOR_DUCKING - dist) / MAX_DIST_FOR_DUCKING)
				var new_height = PICKUP_HEIGHT + (height_delta * pct_from_center)
				# print("new height = " + str(new_height))
				updated_height = new_height
			else:
				updated_height = COASTING_HEIGHT
			if updated_height != position.y:
				y_delta = updated_height - position.y
				print("y_delta = " + str(y_delta))
		var collision = move_and_collide(
			Vector3(x_delta, y_delta, z_delta),
			false,
			0.001,
			false,
			1)
		print("new y position = " + str(position.y))
		if collision != null:
			print("Bird collided with player!")
			state = BirdState.PICKING_UP_PLAYER
			pickup_time = Time.get_ticks_msec()
			pickup_location = Vector3(player_node.global_position.x, global_position.y, player_node.global_position.z)
			player_node.bird_capture()
	
func _reset_position(new_pos: Vector3):
	position = new_pos
