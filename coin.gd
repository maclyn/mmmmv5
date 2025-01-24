extends StaticBody3D

var _has_collided = false

func has_collided_before() -> bool:
	return _has_collided

func remove_self():
	_has_collided = true
	$CoinCollider.disabled = true
	$CoinSurface.visible = false
