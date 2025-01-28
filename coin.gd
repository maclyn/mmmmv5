@tool
extends StaticBody3D

const RAD_PER_S = PI

var _has_collided = false
var _offset = 0.0

func _ready() -> void:
	rotation = rotation.rotated(Vector3.UP, randf_range(0.0, PI))

func _process(delta: float) -> void:
	if !_has_collided:
		rotation.y = rotation.y + (delta * RAD_PER_S)

func has_collided_before() -> bool:
	return _has_collided

func remove_self():
	_has_collided = true
	$CoinCollider.disabled = true
	$CoinSurface.visible = false
