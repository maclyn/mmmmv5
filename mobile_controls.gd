extends Control

signal h_swipe(delta_x: float)
signal main_menu()

const UNSET_TOUCH_IDX = -1
const RUN_BOUNDARY_PCT = 0.10
const DEAD_ZONE_PCT = 0.10

var joystick_touch_down_idx = UNSET_TOUCH_IDX
var jump_touch_down_idx = UNSET_TOUCH_IDX
var drag_idx = UNSET_TOUCH_IDX
var drag_idx_last_pos = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var event_index = event.index
		if event.pressed:
			# Equivalent to ACTION_DOWN
			var pos = event.position
			if _is_point_in_control(pos, $JoystickRect):
				joystick_touch_down_idx = event_index
			elif _is_point_in_control(pos, $JumpRect):
				jump_touch_down_idx = event_index
				Input.action_press("ui_accept")
			elif _is_point_in_control(pos, $QuitRect):
				main_menu.emit()
			elif drag_idx == UNSET_TOUCH_IDX:
				drag_idx = event_index
				drag_idx_last_pos = event.position
		else:
			if event.index == joystick_touch_down_idx:
				joystick_touch_down_idx = UNSET_TOUCH_IDX
				Input.action_release("run")
				Input.action_release("backwards")
				Input.action_release("forward")
				Input.action_release("strafe_left")
				Input.action_release("strafe_right")
			elif event.index == jump_touch_down_idx:
				jump_touch_down_idx = UNSET_TOUCH_IDX
				Input.action_release("ui_accept")
			elif event.index == drag_idx:
				drag_idx = UNSET_TOUCH_IDX
				drag_idx_last_pos = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var pos = event.position
		if event.index == joystick_touch_down_idx:
			var pct_x = _pct_of_x(pos)
			var pct_y = _pct_of_y(pos)
			if absf(pct_x - 0.5) > absf(pct_y - 0.5):
				Input.action_release("backwards")
				Input.action_release("forward")
				if pct_x > (0.5 - RUN_BOUNDARY_PCT) || pct_x < (0.5 + RUN_BOUNDARY_PCT):
					Input.action_press("walk")
				else:
					Input.action_release("walk")
				if pct_x < (0.5 - DEAD_ZONE_PCT):
					Input.action_release("strafe_right")
					Input.action_press("strafe_left")
				elif pct_x > (0.5 + DEAD_ZONE_PCT):
					Input.action_release("strafe_left")
					Input.action_press("strafe_right")
			else:
				Input.action_release("strafe_left")
				Input.action_release("strafe_right")
				if pct_y > (0.5 - RUN_BOUNDARY_PCT) || pct_y < (0.5 + RUN_BOUNDARY_PCT):
					Input.action_press("walk")
				else:
					Input.action_release("walk")
				if pct_y < (0.5 - DEAD_ZONE_PCT):
					Input.action_release("backwards")
					Input.action_press("forward")
				elif pct_y > (0.5 + DEAD_ZONE_PCT):
					Input.action_release("forward")
					Input.action_press("backwards")
		elif event.index == drag_idx:
			var x_range = get_viewport_rect().size.abs().x
			if x_range <= 0:
				x_range = 1.0
			var x_delta = event.position.x - drag_idx_last_pos.x
			var hscroll_pct = abs(x_delta) / x_range
			drag_idx_last_pos = event.position
			h_swipe.emit(x_delta)

func _is_point_in_control(point: Vector2, control: Control) -> bool:
	var control_pos = control.global_position
	var control_size = control.size
	var control_scale = control.get_global_transform_with_canvas().get_scale()
	var is_in_x: bool = point.x >= control_pos.x and point.x <= control_pos.x + (control_size.x * control_scale.x)
	var is_in_y: bool = point.y >= control_pos.y and point.y <= control_pos.y + (control_size.y * control_scale.y)
	return is_in_x and is_in_y
	
func _pct_of_x(point: Vector2) -> float:
	var control = $JoystickRect
	var control_pos = control.global_position
	var control_size = control.size
	var control_scale = control.get_global_transform_with_canvas().get_scale()
	var start_bound = control_pos.x
	var end_bound =  control_pos.x + (control_size.x * control_scale.x)
	var total_size_px = end_bound - start_bound
	if total_size_px <= 0.0:
		total_size_px = 1.0
	var raw_pct = (point.x - start_bound) / total_size_px
	if raw_pct < 0.0:
		return 0.0
	if raw_pct > 1.0:
		return 1.0
	return raw_pct
	
func _pct_of_y(point: Vector2) -> float:
	var control = $JoystickRect
	var control_pos = control.global_position
	var control_size = control.size
	var control_scale = control.get_global_transform_with_canvas().get_scale()
	var start_bound = control_pos.y
	var end_bound =  control_pos.y + (control_size.y * control_scale.y)
	var total_size_px = end_bound - start_bound
	if total_size_px <= 0.0:
		total_size_px = 1.0
	var raw_pct = (point.y - start_bound) / total_size_px
	if raw_pct < 0.0:
		return 0.0
	if raw_pct > 1.0:
		return 1.0
	return raw_pct

	#if use_input_actions:
		## Release actions
		#if output.x >= 0 and Input.is_action_pressed(action_left):
			#Input.action_release(action_left)
		#if output.x <= 0 and Input.is_action_pressed(action_right):
			#Input.action_release(action_right)
		#if output.y >= 0 and Input.is_action_pressed(action_up):
			#Input.action_release(action_up)
		#if output.y <= 0 and Input.is_action_pressed(action_down):
			#Input.action_release(action_down)
		## Press actions
		#if output.x < 0:
			#Input.action_press(action_left, -output.x)
		#if output.x > 0:
			#Input.action_press(action_right, output.x)
		#if output.y < 0:
			#Input.action_press(action_up, -output.y)
		#if output.y > 0:
			#Input.action_press(action_down, output.y)
