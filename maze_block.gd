extends Node3D

const SNAKE_PASS_TIME_S = 1.5

var is_snek_going: bool = false
var snek_anim_start: int = 0
var snek: Node = null
var path_follow: PathFollow3D = null

func init_scene(is_north_south: bool):
	snek = $NSPath/NSFollow/SnekNS if is_north_south else $EWPath/EWFollow/SnekEW
	path_follow = $NSPath/NSFollow if is_north_south else $EWPath/EWFollow

func _ready():
	$HedgeWallN.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallS.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSW.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerNW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNW.rotate_y((PI / 2) * randi_range(0, 4))
	
func _process(delta: float) -> void:
	if is_snek_going:
		var progress_amount = (Time.get_ticks_msec() - snek_anim_start) / 1000.0 / SNAKE_PASS_TIME_S
		# moves the snek
		path_follow.progress_ratio = progress_amount

func configure_walls(north: bool, east: bool, south: bool, west: bool):
	#north = false
	#east = false
	#south = false
	#swest = false
	$HedgeWallN.visible = north
	$HedgeWallN.get_node("CollisionShape3D").disabled = !north
	$HedgeWallE.visible = east
	$HedgeWallE.get_node("CollisionShape3D").disabled = !east
	$HedgeWallS.visible = south
	$HedgeWallS.get_node("CollisionShape3D").disabled = !south
	$HedgeWallW.visible = west
	$HedgeWallW.get_node("CollisionShape3D").disabled = !west

func rotate_key_y(amount_in_rads: float):
	$KeyRoot.rotate_y(amount_in_rads)

func add_key():
	$KeyRoot.visible = true
	$KeyRoot/KeyCollider.disabled = false
	
func hide_key():
	$KeyRoot.visible = false
	$KeyRoot/KeyCollider.disabled = true

func add_exit():
	$ExitRoot.visible = true
	$ExitRoot/ExitCollider.disabled = false
	
func get_key_position() -> Vector3:
	return $KeyRoot.global_position
	
# PREPARE THE SNAKES.
func snekify():
	var timer = Timer.new()
	timer.one_shot = false
	timer.autostart = true
	timer.wait_time = randf_range(0.0, SNAKE_PASS_TIME_S * 6)
	timer.connect("timeout", _on_snake_timer_timeout)
	add_child(timer)
	
func _on_snake_timer_timeout():
	$SnekAnimationTimer.start()
	snek.visible = true
	snek_anim_start = Time.get_ticks_msec()
	is_snek_going = true
	# reset snek position

func _on_snek_animation_timer_timeout() -> void:
	is_snek_going = false
	snek.visible = false
