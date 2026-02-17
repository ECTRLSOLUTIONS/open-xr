extends Node3D

const LAUNCHER_SCENE := "res://scenes/main_launcher.tscn"
const PINCH_THRESHOLD := 0.035
const GAZE_RAY_LENGTH := 8.0

@export var hand_path := "/user/hand_tracker/right"
@export var camera_path: NodePath = NodePath("../XRCamera3D")
@export var idle_color := Color(1.0, 1.0, 1.0, 1.0)
@export var hover_color := Color(1.0, 0.93, 0.35, 1.0)

@onready var button_area: Area3D = $BackButtonArea
@onready var button_label: Label3D = $BackButtonArea/ButtonLabel
@onready var hint_label: Label3D = $HintLabel

var _camera: XRCamera3D
var _xr_origin: XROrigin3D
var _hovered := false
var _pinch_down := false
var _confirm_down := false

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as XRCamera3D
	_xr_origin = get_parent() as XROrigin3D
	if not _camera:
		push_warning("BackToMenuButton: camera not found at %s" % camera_path)

func _physics_process(_delta: float) -> void:
	if not _camera:
		return

	_hovered = _is_hovered_from_hand() or _is_hovered_from_gaze()
	button_label.modulate = hover_color if _hovered else idle_color
	hint_label.text = "Pinch to return to main menu" if _hovered else "Look at button + pinch"

	var pinch := _is_pinch_pressed()
	var confirm := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select") or Input.is_action_pressed("ui_cancel")
	if _hovered and ((pinch and not _pinch_down) or (confirm and not _confirm_down)):
		_open_launcher_scene()

	_pinch_down = pinch
	_confirm_down = confirm

func _is_hovered_from_gaze() -> bool:
	var origin := _camera.global_transform.origin
	var direction := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * GAZE_RAY_LENGTH)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.get("collider") == button_area

func _is_hovered_from_hand() -> bool:
	if not _xr_origin:
		return false

	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if not tracker or not tracker.has_tracking_data:
		return false

	var tip_local := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var tip_global := _xr_origin.to_global(tip_local)

	var query := PhysicsPointQueryParameters3D.new()
	query.position = tip_global
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_point(query, 16)
	for hit in hits:
		if hit.get("collider") == button_area:
			return true
	return false

func _is_pinch_pressed() -> bool:
	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if not tracker or not tracker.has_tracking_data:
		return false

	var tip := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var thumb := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_THUMB_TIP).origin
	return tip.distance_to(thumb) < PINCH_THRESHOLD

func _open_launcher_scene() -> void:
	var err := get_tree().change_scene_to_file(LAUNCHER_SCENE)
	if err != OK:
		hint_label.text = "Cannot open launcher (%d)" % err
