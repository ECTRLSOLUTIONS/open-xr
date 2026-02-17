extends XRAnchor3D

@onready var info_label: Label3D = $InfoLabel
@onready var anchored_content: Node3D = $AnchoredContent

var marker_tracker: OpenXRMarkerTracker

func _ready() -> void:
	marker_tracker = XRServer.get_tracker(tracker) as OpenXRMarkerTracker
	if not marker_tracker:
		info_label.text = "Marker tracker unavailable"
		return

	_apply_marker_info()

func set_models_visible(visible: bool) -> void:
	anchored_content.visible = visible

func _apply_marker_info() -> void:
	var label_text := "Marker"
	match marker_tracker.marker_type:
		OpenXRSpatialComponentMarkerList.MARKER_TYPE_QRCODE:
			label_text = "QR code"
			var data: Variant = marker_tracker.get_marker_data()
			if typeof(data) == TYPE_STRING:
				label_text += "\n" + data
			elif typeof(data) == TYPE_PACKED_BYTE_ARRAY:
				label_text += "\n" + data.hex_encode()
		OpenXRSpatialComponentMarkerList.MARKER_TYPE_MICRO_QRCODE:
			label_text = "Micro QR"
		OpenXRSpatialComponentMarkerList.MARKER_TYPE_ARUCO:
			label_text = "Aruco ID: %d" % marker_tracker.marker_id
		OpenXRSpatialComponentMarkerList.MARKER_TYPE_APRIL_TAG:
			label_text = "AprilTag ID: %d" % marker_tracker.marker_id
		_:
			label_text = "Marker type: %d" % marker_tracker.marker_type

	info_label.text = label_text
