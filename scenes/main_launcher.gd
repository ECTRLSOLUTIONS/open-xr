extends XROrigin3D

const SCENE_STEP_1 := "res://demos/step_1_setup/main_setup.tscn"
const SCENE_STEP_2 := "res://demos/step_2_interaction/main_interact.tscn"
const SCENE_STEP_3 := "res://demos/step_3_scene_mesch/main_scene_mesh.tscn"
const SCENE_STEP_4 := "res://demos/step_4_spatial_entities/main_spatial_entities.tscn"

const PINCH_THRESHOLD := 0.035
const GAZE_RAY_LENGTH := 6.0

@export var hand_path := "/user/hand_tracker/right"
@export var use_passthrough := false

@onready var camera: XRCamera3D = $XRCamera3D
@onready var status_label: Label3D = $LauncherBoard/StatusLabel
@onready var demo_1_area: Area3D = $LauncherBoard/Buttons/Demo1Button
@onready var demo_2_area: Area3D = $LauncherBoard/Buttons/Demo2Button
@onready var demo_3_area: Area3D = $LauncherBoard/Buttons/Demo3Button
@onready var demo_4_area: Area3D = $LauncherBoard/Buttons/Demo4Button
@onready var demo_1_label: Label3D = $LauncherBoard/Buttons/Demo1Button/ButtonText
@onready var demo_2_label: Label3D = $LauncherBoard/Buttons/Demo2Button/ButtonText
@onready var demo_3_label: Label3D = $LauncherBoard/Buttons/Demo3Button/ButtonText
@onready var demo_4_label: Label3D = $LauncherBoard/Buttons/Demo4Button/ButtonText

var _button_scene_map: Dictionary = {}
var _button_title_map: Dictionary = {}
var _button_label_map: Dictionary = {}
var _hovered_button: Area3D = null
var _pinch_down := false
var _confirm_down := false

func _ready() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		get_viewport().physics_object_picking = false
		_setup_background(xr_interface)

	_bind_buttons()
	status_label.text = "Look at a button and pinch to open"

func _physics_process(_delta: float) -> void:
	_hovered_button = _get_button_from_hand()
	if not _hovered_button:
		_hovered_button = _get_button_from_gaze()

	_update_button_highlight()
	_update_status_text()

	var pinch := _is_pinch_pressed()
	var confirm := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select")

	if _hovered_button and ((pinch and not _pinch_down) or (confirm and not _confirm_down)):
		_open_scene(_button_scene_map[_hovered_button])

	_pinch_down = pinch
	_confirm_down = confirm

func _bind_buttons() -> void:
	_register_button(demo_1_area, demo_1_label, SCENE_STEP_1, "Demo 1")
	_register_button(demo_2_area, demo_2_label, SCENE_STEP_2, "Demo 2")
	_register_button(demo_3_area, demo_3_label, SCENE_STEP_3, "Demo 3")
	_register_button(demo_4_area, demo_4_label, SCENE_STEP_4, "Demo 4")

func _register_button(area: Area3D, label: Label3D, scene_path: String, title: String) -> void:
	_button_label_map[area] = label
	if ResourceLoader.exists(scene_path):
		_button_scene_map[area] = scene_path
		_button_title_map[area] = title
	else:
		label.text += " (missing)"
		label.modulate = Color(0.7, 0.7, 0.7, 1.0)

func _get_button_from_hand() -> Area3D:
	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if not tracker or not tracker.has_tracking_data:
		return null

	var tip_local := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var tip_global := to_global(tip_local)
	return _get_button_at_point(tip_global)

func _get_button_from_gaze() -> Area3D:
	var origin := camera.global_transform.origin
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * GAZE_RAY_LENGTH)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider is Area3D and _button_scene_map.has(collider):
		return collider
	return null

func _get_button_at_point(world_point: Vector3) -> Area3D:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = world_point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_point(query, 16)

	for hit in hits:
		var collider = hit.get("collider")
		if collider is Area3D and _button_scene_map.has(collider):
			return collider
	return null

func _is_pinch_pressed() -> bool:
	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if not tracker or not tracker.has_tracking_data:
		return false

	var tip := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var thumb := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_THUMB_TIP).origin
	return tip.distance_to(thumb) < PINCH_THRESHOLD

func _update_button_highlight() -> void:
	for area in _button_label_map:
		var label: Label3D = _button_label_map[area]
		if area == _hovered_button:
			label.modulate = Color(1.0, 0.93, 0.35, 1.0)
		elif _button_scene_map.has(area):
			label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_status_text() -> void:
	if _hovered_button:
		status_label.text = "Ready: %s" % _button_title_map[_hovered_button]
	else:
		status_label.text = "Look at a button and pinch to open"

func _open_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		status_label.text = "Error loading %s (%d)" % [scene_path, error]

func _setup_background(xr: XRInterface) -> void:
	if use_passthrough:
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
			xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
			if has_node("WorldEnvironment"):
				$WorldEnvironment.environment.background_mode = Environment.BG_COLOR
				$WorldEnvironment.environment.background_color = Color(0, 0, 0, 0)
			return
		xr.start_passthrough()
		get_viewport().transparent_bg = true
		return

	get_viewport().transparent_bg = false
	if has_node("WorldEnvironment"):
		$WorldEnvironment.environment.background_mode = Environment.BG_SKY
