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

var camera_sun = preload("res://player_camera_sun.tscn")
var camera_moon = preload("res://player_camera_moon.tscn")

var sensitivity = 0.0007
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

func restore_camera():
	var camera = $CameraRoot.get_child(0)
	if camera is Camera3D:
		camera.make_current()

func set_camera(sun: bool, moon: bool):
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
	look_rotation.y -= (delta_x * sensitivity)
	look_rotation.x -= delta_x * sensitivity
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

	if not in_quicksand:
		var input_dir := Input.get_vector("strafe_left", "strafe_right", "forward", "backwards")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed = SPEED if Input.is_action_pressed("walk") else RUN_SPEED
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

		# Debug purposes only
		var debug_dir := Input.get_vector("debug_east", "debug_west", "debug_south", "debug_north")
		if debug_dir.length() > 0:
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
		if collider.is_in_group("key_group"):
			at_key.emit()
		if collider.is_in_group("portal_group"):
			at_portal.emit()
		if collider.is_in_group("spike_group"):
			at_spike.emit()
		if collider.is_in_group("coin_group"):
			if not collider.has_collided_before():
				collider.remove_self()
				at_coin.emit()
	
	if in_quicksand:
		if !$Sounds/QuicksandPlayer.playing:
				$Sounds/QuicksandPlayer.play()
		if position.y < 0.25:
			die()
			at_quicksand.emit()
	
	_process_look(delta)
	
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and !Globals.is_mobile():
		look_rotation.y -= (event.relative.x * sensitivity)

func _unhandled_input(_event: InputEvent) -> void:
	if Engine.is_editor_hint() || !Globals.is_debug():
		return
	if Input.is_action_just_pressed("cheat"):
		cheat.emit()
		
func _process_look(delta: float):
	var angular_velocity = get_platform_angular_velocity()
	look_rotation.y += angular_velocity.y * delta
	rotation.y = look_rotation.y
	look_direction_changed.emit(position, rotation.y)
