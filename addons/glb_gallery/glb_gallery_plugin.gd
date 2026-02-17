@tool
extends EditorPlugin

var _dock: Control

func _enter_tree() -> void:
	_dock = preload("res://addons/glb_gallery/glb_gallery_dock.gd").new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.free()
