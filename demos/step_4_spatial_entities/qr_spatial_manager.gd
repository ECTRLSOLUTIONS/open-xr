class_name QRSpatialManager
extends Node3D

signal marker_anchor_added(anchor: XRAnchor3D, tracker_name: StringName)
signal marker_anchor_removed(tracker_name: StringName)
signal marker_tracker_detected(tracker_name: StringName, marker_type: int, marker_data: Variant)

@export var marker_tracker_scene: PackedScene

var _marker_nodes: Dictionary[StringName, XRAnchor3D] = {}
var _last_marker_seen_msec: int = 0

func _enter_tree() -> void:
	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_updated.connect(_on_tracker_updated)
	XRServer.tracker_removed.connect(_on_tracker_removed)
	_discover_existing_trackers()

func _exit_tree() -> void:
	if XRServer.tracker_added.is_connected(_on_tracker_added):
		XRServer.tracker_added.disconnect(_on_tracker_added)
	if XRServer.tracker_updated.is_connected(_on_tracker_updated):
		XRServer.tracker_updated.disconnect(_on_tracker_updated)
	if XRServer.tracker_removed.is_connected(_on_tracker_removed):
		XRServer.tracker_removed.disconnect(_on_tracker_removed)
	_clear_marker_nodes()

func get_active_marker_count() -> int:
	return _marker_nodes.size()

func get_last_marker_seen_msec() -> int:
	return _last_marker_seen_msec

func set_models_visible(visible: bool) -> void:
	for tracker_name in _marker_nodes:
		var anchor := _marker_nodes[tracker_name]
		if anchor and anchor.has_method("set_models_visible"):
			anchor.call("set_models_visible", visible)

func reset_marker_anchors() -> void:
	_clear_marker_nodes()
	# Re-check already active trackers after a manual reset.
	_discover_existing_trackers()

func _discover_existing_trackers() -> void:
	var trackers: Dictionary = XRServer.get_trackers(XRServer.TRACKER_ANCHOR)
	for tracker_name in trackers:
		var tracker: XRTracker = trackers[tracker_name]
		if tracker and tracker is OpenXRMarkerTracker:
			_add_marker_tracker(tracker as OpenXRMarkerTracker)

func _add_marker_tracker(tracker: OpenXRMarkerTracker) -> void:
	if _marker_nodes.has(tracker.name):
		_update_marker_tracker(tracker)
		return

	if not marker_tracker_scene:
		push_warning("QRSpatialManager: marker_tracker_scene is not assigned")
		return

	var instance := marker_tracker_scene.instantiate()
	if not (instance is XRAnchor3D):
		push_error("QRSpatialManager: marker_tracker_scene root must be XRAnchor3D")
		instance.queue_free()
		return

	var anchor := instance as XRAnchor3D
	anchor.tracker = tracker.name
	anchor.pose = "default"
	add_child(anchor)

	_marker_nodes[tracker.name] = anchor
	marker_anchor_added.emit(anchor, tracker.name)
	_update_marker_tracker(tracker)

func _update_marker_tracker(tracker: OpenXRMarkerTracker) -> void:
	_last_marker_seen_msec = Time.get_ticks_msec()
	marker_tracker_detected.emit(tracker.name, tracker.marker_type, tracker.get_marker_data())

func _remove_marker_tracker(tracker_name: StringName) -> void:
	if not _marker_nodes.has(tracker_name):
		return

	var anchor := _marker_nodes[tracker_name]
	if anchor:
		if anchor.get_parent() == self:
			remove_child(anchor)
		anchor.queue_free()

	_marker_nodes.erase(tracker_name)
	marker_anchor_removed.emit(tracker_name)

func _clear_marker_nodes() -> void:
	var names := _marker_nodes.keys()
	for tracker_name in names:
		_remove_marker_tracker(tracker_name)

func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	if type != XRServer.TRACKER_ANCHOR:
		return

	var tracker := XRServer.get_tracker(tracker_name)
	if tracker and tracker is OpenXRMarkerTracker:
		_add_marker_tracker(tracker as OpenXRMarkerTracker)

func _on_tracker_updated(tracker_name: StringName, type: int) -> void:
	if type != XRServer.TRACKER_ANCHOR:
		return

	var tracker := XRServer.get_tracker(tracker_name)
	if tracker and tracker is OpenXRMarkerTracker:
		if not _marker_nodes.has(tracker_name):
			_add_marker_tracker(tracker as OpenXRMarkerTracker)
		else:
			_update_marker_tracker(tracker as OpenXRMarkerTracker)

func _on_tracker_removed(tracker_name: StringName, type: int) -> void:
	if type != XRServer.TRACKER_ANCHOR:
		return
	_remove_marker_tracker(tracker_name)
