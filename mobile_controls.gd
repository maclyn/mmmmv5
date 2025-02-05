extends Control

signal h_swipe(delta_x: float)
signal main_menu()

const DEBUG_MOBILE_CONTROLS = true

const UNSET_TOUCH_IDX = -1
const DEAD_ZONE_PCT = 0.05

var joystick_touch_down_idx = UNSET_TOUCH_IDX
var jump_touch_down_idx = UNSET_TOUCH_IDX
var drag_idx = UNSET_TOUCH_IDX
var drag_idx_last_pos = Vector2.ZERO

var _start_position_joystick = Vector2.ZERO
var _joystick_size = 0.0
var _has_seen_non_touch_input = false

func show_self() -> void:
	_has_seen_non_touch_input = false
	visible = true

func _ready() -> void:
	_start_position_joystick = $JoystickRect.position
	_joystick_size = $JoystickRect.size.x

func _notification(what: int) -> void:
	if not visible:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST && Globals.on_back_notif_receieved():
		print("Going back from game")
		main_menu.emit()

func _input(event: InputEvent) -> void:
	if _has_seen_non_touch_input:
		return
	if event is InputEventScreenTouch:
		var event_index = event.index
		if event.pressed:
			# Equivalent to ACTION_DOWN
			var pos = event.position
			if _is_point_in_control(pos, $JoystickRect):
				joystick_touch_down_idx = event_index
				_set_control_is_pressed($JoystickRect, true)
			elif _is_point_in_control(pos, $JumpRect):
				jump_touch_down_idx = event_index
				_press_key("jump")
				_set_control_is_pressed($JumpRect, true)
			elif drag_idx == UNSET_TOUCH_IDX:
				drag_idx = event_index
				drag_idx_last_pos = event.position
			# Also handle like an ACTION_MOVE, since you should start moving
			# in a direction as soon as the finger goes down
			_process_finger_at_point(event)
		else:
			# Equivalent to ACTION_UP
			if event.index == joystick_touch_down_idx:
				joystick_touch_down_idx = UNSET_TOUCH_IDX
				_release_key("joystick_right")
				_release_key("joystick_left")
				_release_key("joystick_up")
				_release_key("joystick_down")
				_set_control_is_pressed($JoystickRect, false)
				$JoystickRect.position = _start_position_joystick
			elif event.index == jump_touch_down_idx:
				jump_touch_down_idx = UNSET_TOUCH_IDX
				_release_key("jump")
				_set_control_is_pressed($JumpRect, false)
			elif event.index == drag_idx:
				drag_idx = UNSET_TOUCH_IDX
				drag_idx_last_pos = Vector2.ZERO
	elif event is InputEventScreenDrag:
		# Equivalent to ACTION_MOVE
		_process_finger_at_point(event)
	elif event is InputEventKey:
		if (Input.is_action_pressed("backwards") ||
			Input.is_action_pressed("forward") ||
			Input.is_action_pressed("strafe_left") ||
			Input.is_action_pressed("strafe_right") ||
			Input.is_action_pressed("jump")
		):
			_set_has_alternate_controls()
	elif event is InputEventJoypadButton || event is InputEventJoypadMotion:
		_set_has_alternate_controls()
			 
func _process_finger_at_point(event: InputEvent) -> void:
	var pos = event.position
	if event.index == joystick_touch_down_idx:
		var pct_x = _pct_of_x(pos)
		var pct_y = _pct_of_y(pos)
		if DEBUG_MOBILE_CONTROLS:
			print("X: " + str(pct_x) + " Y:" + str(pct_y))
		
		if abs(pct_x - 0.5) > DEAD_ZONE_PCT:
			if pct_x < 0.5:
				_release_key("joystick_right")
				_press_key_with_strength("joystick_left", abs(pct_x - 0.5) / 0.5)
			else:
				_release_key("joystick_left")
				_press_key_with_strength("joystick_right", abs(pct_x - 0.5) / 0.5)
		else:
			_release_key("joystick_left")
			_release_key("joystick_right")
				
		if abs(pct_y - 0.5) > DEAD_ZONE_PCT:
			if pct_y < 0.5:
				_release_key("joystick_down")
				_press_key_with_strength("joystick_up", abs(pct_y - 0.5) / 0.5)
			else:
				_release_key("joystick_up")
				_press_key_with_strength("joystick_down", abs(pct_y - 0.5) / 0.5)
		else:
			_release_key("joystick_up")
			_release_key("joystick_down")
			
		# Move the joystick to match position
		$JoystickRect.set_position(
			Vector2(
				_start_position_joystick.x + ((pct_x - 0.5) * (_joystick_size / 2.0)),
				_start_position_joystick.y + ((pct_y - 0.5) * (_joystick_size / 2.0)),
			)
		)
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
	var control = $JoystickBG
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
	
func _set_control_is_pressed(control: TextureRect, is_pressed: bool) -> void:
	control.self_modulate.a = 1.0 if is_pressed else 0.8
	if is_pressed:
		Input.vibrate_handheld(50, 0.2)

func _press_key(key: String):
	if DEBUG_MOBILE_CONTROLS:
		print("Pressing " + key)
	Input.action_press(key)
	
func _press_key_with_strength(key: String, strength: float):
	if DEBUG_MOBILE_CONTROLS:
		print("Pressing " + key + " with " + str(strength))
	Input.action_press(key, strength)
	
func _release_key(key: String):
	if DEBUG_MOBILE_CONTROLS:
		print("Releasing " + key)
	Input.action_release(key)

func _set_has_alternate_controls() -> void:
	_has_seen_non_touch_input = true
	visible = false
