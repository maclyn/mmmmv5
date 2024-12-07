@tool
extends Node3D

func _ready():
	$HedgeWallN.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallE.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallS.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeWallW.rotate_mesh(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSE.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSE.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerSW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerSW.rotate_y((PI / 2) * randi_range(0, 4))
	$HedgeCornerNW.rotate_z(PI if randi_range(0, 1) == 0 else 0.0)
	$HedgeCornerNW.rotate_y((PI / 2) * randi_range(0, 4))

func configure_walls(north: bool, east: bool, south: bool, west: bool):
	$HedgeWallN.visible = north
	$HedgeWallN.get_node("CollisionShape3D").disabled = !north
	$HedgeWallE.visible = east
	$HedgeWallE.get_node("CollisionShape3D").disabled = !east
	$HedgeWallS.visible = south
	$HedgeWallS.get_node("CollisionShape3D").disabled = !south
	$HedgeWallW.visible = west
	$HedgeWallW.get_node("CollisionShape3D").disabled = !west
	
func get_south_wall() -> Node3D:
	return $HedgeWallS

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
	
func show_arrow(was_prev_north: bool, was_prev_south: bool, was_prev_east: bool, was_prev_west: bool):
	# Arrows are configured on the maze block to always point right
	# Pass "true" to show_arrow to flip the direction
	if was_prev_south:
		$HedgeWallE.show_arrow(true)
		$HedgeWallW.show_arrow(false)
		if !$HedgeWallE.visible && !$HedgeWallW.visible:
			return
		elif $HedgeWallE.visible:
			$HedgeWallS.show_arrow(true)
		else:
			$HedgeWallS.show_arrow(false)
	elif was_prev_north:
		$HedgeWallE.show_arrow(false)
		$HedgeWallW.show_arrow(true)
		if !$HedgeWallE.visible && !$HedgeWallW.visible:
			return
		elif $HedgeWallE.visible:
			$HedgeWallS.show_arrow(false)
		else:
			$HedgeWallS.show_arrow(true)
	elif was_prev_east:
		$HedgeWallN.show_arrow(true)
		$HedgeWallS.show_arrow(false)
		if !$HedgeWallN.visible && !$HedgeWallS.visible:
			return
		elif $HedgeWallN.visible:
			$HedgeWallW.show_arrow(true)
		else:
			$HedgeWallW.show_arrow(false)
	elif was_prev_west:
		$HedgeWallN.show_arrow(false)
		$HedgeWallS.show_arrow(true)
		if !$HedgeWallN.visible && !$HedgeWallS.visible:
			return
		elif $HedgeWallN.visible:
			$HedgeWallW.show_arrow(false)
		else:
			$HedgeWallW.show_arrow(true)
