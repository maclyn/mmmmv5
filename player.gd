extends CharacterBody3D

signal look_direction_changed(position: Vector3, rotation: Vector3)

@export var sensitivity = 0.005
@export var min_angle = -PI / 2
@export var max_angle = PI / 2

const SPEED = 5.0
const RUN_SPEED = SPEED * 2
const JUMP_VELOCITY = 3

var look_rotation = Vector2(0, PI)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("strafe_left", "strafe_right", "forward", "backwards")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = RUN_SPEED if Input.is_action_pressed("run") else SPEED
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

	move_and_slide()
	
	var angular_velocity = get_platform_angular_velocity()
	look_rotation.y += angular_velocity.y * delta
	rotation.y = look_rotation.y
	
	look_direction_changed.emit(position, rotation)
	

	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_rotation.y -= (event.relative.x * sensitivity)
		look_rotation.x -= (event.relative.x * sensitivity)
		look_rotation.x = clamp(look_rotation.x, min_angle, max_angle)

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if Input.is_action_just_pressed("wireframe_mode"):
		var rs = get_viewport()
		rs.debug_draw = (rs.debug_draw + 1) % 5
