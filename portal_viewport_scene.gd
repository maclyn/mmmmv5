@tool
extends SubViewport

func get_camera():
	return $PortalCamera

func set_camera_position(basis_for_cam: Vector3):
	$PortalCamera.global_position = basis_for_cam
