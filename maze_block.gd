extends Node3D

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
