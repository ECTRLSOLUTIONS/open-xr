extends XROrigin3D

enum DemoState {
	SEARCHING,
	DETECTED,
	ANCHORED,
	TRACKING_LOST,
	UNSUPPORTED
}

const TRACKING_LOST_TIMEOUT_SEC := 3.0

@onready var qr_manager: QRSpatialManager = $QRSpatialManager
@onready var instruction_sign: Node3D = get_node_or_null("InstructionSign")

var _state: DemoState = DemoState.SEARCHING
var _lost_since_sec := -1.0

func _ready() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		_setup_passthrough(xr_interface)
	else:
		_set_state(DemoState.UNSUPPORTED, "OpenXR not initialized")
		return

	if not ClassDB.class_exists("OpenXRMarkerTracker"):
		_set_state(DemoState.UNSUPPORTED, "OpenXR marker tracking classes are unavailable")
		return

	qr_manager.marker_anchor_added.connect(_on_marker_anchor_added)
	qr_manager.marker_anchor_removed.connect(_on_marker_anchor_removed)
	qr_manager.marker_tracker_detected.connect(_on_marker_tracker_detected)

	if instruction_sign:
		instruction_sign.visible = true

	_set_state(DemoState.SEARCHING, "Point headset camera to a printed QR code")

func _process(_delta: float) -> void:
	if _state == DemoState.TRACKING_LOST and _lost_since_sec > 0.0:
		var elapsed := Time.get_ticks_msec() / 1000.0 - _lost_since_sec
		if elapsed >= TRACKING_LOST_TIMEOUT_SEC:
			_set_state(DemoState.SEARCHING, "Tracking timeout. Scan the QR code again")

func _on_marker_anchor_added(_anchor: XRAnchor3D, _tracker_name: StringName) -> void:
	_lost_since_sec = -1.0
	_hide_instruction_sign()
	_set_state(DemoState.ANCHORED, "Marker anchored. Sphere and cube attached to QR")

func _on_marker_anchor_removed(_tracker_name: StringName) -> void:
	if qr_manager.get_active_marker_count() > 0:
		return
	_lost_since_sec = Time.get_ticks_msec() / 1000.0
	_set_state(DemoState.TRACKING_LOST, "Marker lost. Waiting before returning to search...")

func _on_marker_tracker_detected(_tracker_name: StringName, marker_type: int, marker_data: Variant) -> void:
	if qr_manager.get_active_marker_count() > 0:
		return
	var info := "Type %d" % marker_type
	if typeof(marker_data) == TYPE_STRING:
		info = marker_data
	elif typeof(marker_data) == TYPE_PACKED_BYTE_ARRAY:
		info = marker_data.hex_encode()
	_hide_instruction_sign()
	_set_state(DemoState.DETECTED, "Marker detected: %s" % info)

func _hide_instruction_sign() -> void:
	if instruction_sign:
		instruction_sign.visible = false

func _set_state(new_state: DemoState, _detail: String = "") -> void:
	_state = new_state

func _setup_passthrough(xr: XRInterface) -> void:
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		xr.start_passthrough()

	get_viewport().transparent_bg = true
	$WorldEnvironment.environment.background_mode = Environment.BG_COLOR
	$WorldEnvironment.environment.background_color = Color(0, 0, 0, 0)
