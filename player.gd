@tool
extends CharacterBody3D

signal at_exit()
signal at_key()
signal at_portal()
signal at_quicksand()
signal at_spike()
signal at_coin()
signal cheat()
signal look_direction_changed(position: Vector3, rotation_y: float)

const DEBUG_MOVEMENT = false
const MOUSE_SENSITIVITY = 0.0007
const WEB_MOUSE_SENSITIVITY = 0.0018
const JOYSTICK_SENSITIVITY = 0.04
var USING_INPUT_FILTER = Globals.is_web() && !Globals.is_mobile_device()

var camera_sun = preload("res://player_camera_sun.tscn")
var camera_moon = preload("res://player_camera_moon.tscn")

var min_angle = -PI / 2
var max_angle = PI / 2

const SPEED = 2.5
const RUN_SPEED = SPEED * 3
const JUMP_VELOCITY = 3
const SINK_SPEED = 5.0

var look_rotation = Vector2(0, PI)
var cannot_move = false
var captured_by_bird = false
var in_quicksand = false
var ground_node: StaticBody3D = null

@onready var sensitivity_modifier = 1.0 if Engine.is_editor_hint() else Globals.get_saver().get_sensitivity_modifier()
var mouse_movement_count = 0
var mouse_movement_amount = 0

func restore_camera():
	var camera = $CameraRoot.get_child(0)
	if camera is Camera3D:
		camera.make_current()

func set_camera(sun: bool, moon: bool):
	mouse_movement_count = 0
	mouse_movement_amount = 0
	while $CameraRoot.get_child_count() > 0:
		$CameraRoot.remove_child($CameraRoot.get_child(0))
	if sun:
		$CameraRoot.add_child(camera_sun.instantiate())
	elif moon:
		$CameraRoot.add_child(camera_moon.instantiate())

func respawn():
	cannot_move = false
	rotation.x = 0
	rotation.y = PI
	look_rotation = Vector2(0, PI)

func die():
	cannot_move = true
	
func bird_capture():
	captured_by_bird = true
	
func bird_release():
	captured_by_bird = false
	
func external_x_movement(delta_x: float):
	if DEBUG_MOVEMENT:
		print("External delta x: " + str(delta_x))
	look_rotation.y -= (delta_x * MOUSE_SENSITIVITY)
	look_rotation.x -= delta_x * MOUSE_SENSITIVITY
	look_rotation.x = clamp(look_rotation.x, min_angle, max_angle)

func attach_ground(ground: Node3D):
	ground_node = ground

func on_enter_quicksand():
	in_quicksand = true
	ground_node.process_mode = Node.PROCESS_MODE_DISABLED
	
func on_exit_quicksand():
	in_quicksand = false
	ground_node.process_mode = Node.PROCESS_MODE_INHERIT

func _ready():
	if Engine.is_editor_hint():
		set_camera(true, false)

func _physics_process(delta: float) -> void:
	if cannot_move or Engine.is_editor_hint():
		return
		
	if captured_by_bird:
		_update_joystick_look_direction()
		_process_look(delta)
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Quicksand sinking
	if in_quicksand:
		velocity += get_gravity() * delta * 1.5

	# Handle jump.
	if Input.is_action_just_pressed("jump") and (is_on_floor() or in_quicksand):
		velocity.y = JUMP_VELOCITY
		_maybe_recapture()
		
	if Input.is_action_just_pressed("sensitivity_down"):
		sensitivity_modifier = max(0.1, sensitivity_modifier - 0.1)
		Globals.get_saver().set_sensitivity_modifier(sensitivity_modifier)
	if Input.is_action_just_pressed("sensitivity_up"):
		sensitivity_modifier = min(4.0, sensitivity_modifier + 0.1)
		Globals.get_saver().set_sensitivity_modifier(sensitivity_modifier)

	if not in_quicksand:
		var kb_input_dir := Input.get_vector("strafe_left", "strafe_right", "forward", "backwards")
		var joystick_input_dir := Input.get_vector("joystick_left", "joystick_right", "joystick_up", "joystick_down")
		var use_joystick = !joystick_input_dir.is_zero_approx()
		var chosen_input_dir = joystick_input_dir if use_joystick else kb_input_dir
		if !chosen_input_dir.is_zero_approx():
			_maybe_recapture()
		var direction := (transform.basis * Vector3(chosen_input_dir.x, 0, chosen_input_dir.y)).normalized()
		var speed = SPEED if Input.is_action_pressed("walk") else RUN_SPEED
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

		# Debug purposes only
		var debug_dir := Input.get_vector("debug_east", "debug_west", "debug_south", "debug_north")
		if debug_dir.length() > 0 && Globals.is_debug():
			var debug_direction := (transform.basis * Vector3(debug_dir.x, 0, debug_dir.y)).normalized()
			speed = RUN_SPEED * 2
			velocity.x = debug_direction.x * speed
			velocity.z = debug_direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	for collision_idx in range(get_slide_collision_count()):
		var collision = get_slide_collision(collision_idx)
		var collider = collision.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("exit_group"):
			at_exit.emit()
		elif collider.is_in_group("key_group"):
			at_key.emit()
		elif collider.is_in_group("portal_group"):
			at_portal.emit()
		elif collider.is_in_group("spike_group"):
			at_spike.emit()
		elif collider.is_in_group("coin_group"):
			if not collider.has_collided_before():
				collider.remove_self()
				at_coin.emit()
		elif collider.is_in_group("enemy_group"):
			collider.handle_external_collision()
		elif !collider.is_in_group("ground_group"):
			pass
			# print("Player hit interesting collider: " + str(collider))
	
	if in_quicksand:
		if !$Sounds/QuicksandPlayer.playing:
				$Sounds/QuicksandPlayer.play()
		if position.y < 0.25:
			die()
			at_quicksand.emit()

	_update_joystick_look_direction()
	_process_look(delta)
	
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and !Globals.is_mobile_device():
		if DEBUG_MOVEMENT:
			var p = event.position
			var pos = event.global_position
			print("Pos: " + str(p))
			print("Global pos: " + str(pos))
			print("Screen relative x: " + str(event.screen_relative.x))
			if event.relative.x != event.screen_relative.x:
				print("No match of relative and screen_relative!")

		var screen_relative_amount = event.screen_relative.x
		if USING_INPUT_FILTER:
			var amount_ceil = (mouse_movement_amount / mouse_movement_count) * 10.0 if mouse_movement_amount > 0 else 100.0
			if abs(screen_relative_amount) > amount_ceil:
				print("Filtering out look event.screen_relative.x of " + \
					str(screen_relative_amount) + \
					"; too large compared to input ceiling of " + \
					str(amount_ceil))
				return
			else:
				mouse_movement_amount += abs(screen_relative_amount)
				mouse_movement_count += 1
				
		var sensitivity = WEB_MOUSE_SENSITIVITY if Globals.is_web() else MOUSE_SENSITIVITY
		look_rotation.y -= screen_relative_amount * sensitivity * sensitivity_modifier

func _unhandled_input(_event: InputEvent) -> void:
	if Engine.is_editor_hint() || !Globals.is_debug():
		return
	if Input.is_action_just_pressed("cheat"):
		cheat.emit()
		
func _maybe_recapture():
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_joystick_look_direction():
	if Input.is_action_pressed("right_joystick_left") || Input.is_action_pressed("right_joystick_right"):
		var right_stick_vector = Input.get_vector("right_joystick_left", "right_joystick_right", "", "")
		var delta_x = right_stick_vector.x * JOYSTICK_SENSITIVITY * sensitivity_modifier
		look_rotation.y -= delta_x
		look_rotation.x -= delta_x 
		look_rotation.x = clamp(look_rotation.x, min_angle, max_angle)

func _process_look(delta: float):
	var angular_velocity = get_platform_angular_velocity()
	look_rotation.y += angular_velocity.y * delta
	rotation.y = look_rotation.y
	look_direction_changed.emit(position, rotation.y)
