@tool
extends EditorPlugin

var dock
var _fs_dock: Object
var _fs_tree: Tree
var _last_selected_path: String = ""
var _connected_any: bool = false
var _last_debug_no_path_key: String = ""

func _enter_tree():
	# istanzia il dock
	# In alcune build/setting dell'Editor, instanziare una .tscn può produrre un "placeholder instance".
	# Istanzio direttamente lo script per ottenere un Control reale (tool) e chiamabile.
	var dock_script := preload("res://addons/glb_viewer/glb_viewer_dock.gd")
	dock = dock_script.new()
	add_control_to_bottom_panel(dock, "GLB Viewer")
	
	# connetti al FileSystemDock
	_fs_dock = get_editor_interface().get_file_system_dock()
	_connect_fs_signals()
	set_process(true)
	call_deferred("_late_setup")

func _exit_tree():
	_disconnect_fs_signals()
	_disconnect_fs_tree()
	set_process(false)
	
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.free()
		dock = null

func _connect_fs_signals() -> void:
	if _fs_dock == null:
		return
	if _fs_dock.has_signal("file_selected") and not _fs_dock.is_connected("file_selected", Callable(self, "_on_file_selected")):
		_fs_dock.connect("file_selected", Callable(self, "_on_file_selected"))
		_connected_any = true
	if _fs_dock.has_signal("files_selected") and not _fs_dock.is_connected("files_selected", Callable(self, "_on_files_selected")):
		_fs_dock.connect("files_selected", Callable(self, "_on_files_selected"))
		_connected_any = true


func _disconnect_fs_signals() -> void:
	if _fs_dock == null:
		return
	if _fs_dock.has_signal("file_selected") and _fs_dock.is_connected("file_selected", Callable(self, "_on_file_selected")):
		_fs_dock.disconnect("file_selected", Callable(self, "_on_file_selected"))
	if _fs_dock.has_signal("files_selected") and _fs_dock.is_connected("files_selected", Callable(self, "_on_files_selected")):
		_fs_dock.disconnect("files_selected", Callable(self, "_on_files_selected"))
	_fs_dock = null


func _late_setup() -> void:
	# Alcune versioni/skin dell'Editor inizializzano il FileSystemDock dopo i plugin.
	if _fs_dock == null:
		_fs_dock = get_editor_interface().get_file_system_dock()
	if _fs_dock == null:
		var base := get_editor_interface().get_base_control()
		var matches := base.find_children("*", "FileSystemDock", true, false)
		if matches.size() > 0:
			_fs_dock = matches[0]
	_connect_fs_signals()
	_hook_fs_tree()
	_debug_fs_dock()
	if not _connected_any:
		print("GLB Viewer: nessun segnale dal FileSystemDock; uso fallback polling.")


func _process(_delta: float) -> void:
	var selected := _get_fs_selected_path()
	if selected != "" and selected != _last_selected_path:
		_last_selected_path = selected
		_handle_path(selected)


func _get_fs_selected_path() -> String:
	# Preferisci il Tree interno se disponibile (più stabile tra versioni).
	if _fs_tree != null:
		var item := _fs_tree.get_selected()
		if item != null:
			var path := _extract_path_from_tree_item(_fs_tree, item)
			if path != "":
				return path

	if _fs_dock == null:
		return ""
	if _fs_dock.has_method("get_selected_paths"):
		var paths = _fs_dock.call("get_selected_paths")
		var first := _extract_first_string(paths)
		if first != "":
			return first
	if _fs_dock.has_method("get_selected_files"):
		var files = _fs_dock.call("get_selected_files")
		var first := _extract_first_string(files)
		if first != "":
			return first
	if _fs_dock.has_method("get_selected_path"):
		var path = _fs_dock.call("get_selected_path")
		if path != null:
			return str(path)
	return ""


func _extract_first_string(value) -> String:
	if value is PackedStringArray:
		var psa := value as PackedStringArray
		return psa[0] if psa.size() > 0 else ""
	if value is Array:
		var arr := value as Array
		if arr.size() == 0:
			return ""
		return str(arr[0])
	return ""


func _hook_fs_tree() -> void:
	if _fs_dock == null:
		return
	if not (_fs_dock is Node):
		return
	var dock_node := _fs_dock as Node
	var trees := dock_node.find_children("*", "Tree", true, false)
	if trees.size() == 0:
		print("GLB Viewer: nessun Tree trovato nel FileSystemDock.")
		return
	# Heuristica: preferisci alberi con nome legato al file tree.
	var chosen: Tree = null
	for t in trees:
		if t is Tree:
			var tn := t as Tree
			var name_l := tn.name.to_lower()
			if name_l.find("file") != -1 or name_l.find("filesystem") != -1:
				chosen = tn
				break
	if chosen == null:
		chosen = trees[0] as Tree

	if _fs_tree == chosen:
		return
	_disconnect_fs_tree()
	_fs_tree = chosen
	print("GLB Viewer: fs_tree=%s path=%s" % [_fs_tree.name, str(_fs_tree.get_path())])

	if _fs_tree.has_signal("item_selected") and not _fs_tree.is_connected("item_selected", Callable(self, "_on_fs_tree_item_selected")):
		_fs_tree.connect("item_selected", Callable(self, "_on_fs_tree_item_selected"))
	if _fs_tree.has_signal("item_activated") and not _fs_tree.is_connected("item_activated", Callable(self, "_on_fs_tree_item_activated")):
		_fs_tree.connect("item_activated", Callable(self, "_on_fs_tree_item_activated"))
	if _fs_tree.has_signal("multi_selected") and not _fs_tree.is_connected("multi_selected", Callable(self, "_on_fs_tree_multi_selected")):
		_fs_tree.connect("multi_selected", Callable(self, "_on_fs_tree_multi_selected"))


func _disconnect_fs_tree() -> void:
	if _fs_tree == null:
		return
	if _fs_tree.has_signal("item_selected") and _fs_tree.is_connected("item_selected", Callable(self, "_on_fs_tree_item_selected")):
		_fs_tree.disconnect("item_selected", Callable(self, "_on_fs_tree_item_selected"))
	if _fs_tree.has_signal("item_activated") and _fs_tree.is_connected("item_activated", Callable(self, "_on_fs_tree_item_activated")):
		_fs_tree.disconnect("item_activated", Callable(self, "_on_fs_tree_item_activated"))
	if _fs_tree.has_signal("multi_selected") and _fs_tree.is_connected("multi_selected", Callable(self, "_on_fs_tree_multi_selected")):
		_fs_tree.disconnect("multi_selected", Callable(self, "_on_fs_tree_multi_selected"))
	_fs_tree = null


func _on_fs_tree_item_selected() -> void:
	var path := _get_fs_selected_path()
	if path != "":
		_handle_path(path)


func _on_fs_tree_item_activated() -> void:
	var path := _get_fs_selected_path()
	if path != "":
		_handle_path(path)


func _on_fs_tree_multi_selected(_item: TreeItem, _column: int, selected: bool) -> void:
	if not selected:
		return
	var path := _get_fs_selected_path()
	if path != "":
		_handle_path(path)


func _extract_path_from_tree_item(tree: Tree, item: TreeItem) -> String:
	var cols := tree.columns
	for col in range(cols):
		var meta = item.get_metadata(col)
		if meta is String:
			var s := meta as String
			if s.begins_with("res://"):
				return s
		elif meta is Dictionary:
			var d := meta as Dictionary
			if d.has("path"):
				var p := str(d["path"])
				if p.begins_with("res://"):
					return p

	for col in range(cols):
		var tip := item.get_tooltip_text(col)
		if tip != null:
			var t := str(tip)
			if t.begins_with("res://"):
				return t

	# Debug (una tantum per combinazione testo/tooltip) se non riusciamo a estrarre il path.
	var key := "%s|%s" % [str(item.get_text(0)), str(item.get_tooltip_text(0))]
	if key != _last_debug_no_path_key:
		_last_debug_no_path_key = key
		print("GLB Viewer: TreeItem senza path. text0=%s tooltip0=%s meta0=%s" % [str(item.get_text(0)), str(item.get_tooltip_text(0)), str(item.get_metadata(0))])
	return ""


func _debug_fs_dock() -> void:
	if _fs_dock == null:
		print("GLB Viewer: FileSystemDock non trovato.")
		return
	print("GLB Viewer: fs_dock class=%s" % _fs_dock.get_class())
	if _fs_dock.has_method("get_signal_list"):
		var signals = _fs_dock.get_signal_list()
		var names: Array = []
		for s in signals:
			if s is Dictionary and s.has("name"):
				names.append(str(s["name"]))
		print("GLB Viewer: fs_dock signals=", names)
	print("GLB Viewer: has file_selected=%s files_selected=%s" % [_fs_dock.has_signal("file_selected"), _fs_dock.has_signal("files_selected")])
	print("GLB Viewer: has get_selected_paths=%s get_selected_files=%s get_selected_path=%s" % [_fs_dock.has_method("get_selected_paths"), _fs_dock.has_method("get_selected_files"), _fs_dock.has_method("get_selected_path")])

func _on_files_selected(paths: PackedStringArray) -> void:
	if paths.size() > 0:
		_handle_path(paths[0])


func _on_file_selected(path: String) -> void:
	_handle_path(path)


func _handle_path(path: String) -> void:
	if path == "" or dock == null:
		return
	var ext := path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		print("GLB Viewer: selezionato %s" % path)
		# Safety: se per qualche motivo fosse un placeholder, ricrea il dock.
		if dock is Node and (dock as Node).has_method("is_placeholder_instance") and (dock as Node).call("is_placeholder_instance"):
			print("GLB Viewer: dock placeholder rilevato; ricreo.")
			_recreate_dock()
		dock.show_glb(path)


func _recreate_dock() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
	var dock_script := preload("res://addons/glb_viewer/glb_viewer_dock.gd")
	dock = dock_script.new()
	add_control_to_bottom_panel(dock, "GLB Viewer")
