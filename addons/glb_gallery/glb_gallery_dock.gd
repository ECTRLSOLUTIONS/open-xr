@tool
extends VBoxContainer

const OUTPUT_SCENE_PATH := "res://glb_gallery.tscn"

var folder_line: LineEdit
var cols_spin: SpinBox
var spacing_spin: SpinBox
var y_offset_spin: SpinBox
var label_size_spin: SpinBox
var status_label: Label

func _ready() -> void:
	name = "GLB Gallery"

	var row1 := HBoxContainer.new()
	add_child(row1)

	folder_line = LineEdit.new()
	folder_line.placeholder_text = "res://path/to/folder"
	folder_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(folder_line)

	var pick_btn := Button.new()
	pick_btn.text = "Scegli…"
	pick_btn.pressed.connect(_on_pick_folder)
	row1.add_child(pick_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	add_child(grid)

	cols_spin = _add_spin(grid, "Colonne", 1, 50, 6, 1)
	spacing_spin = _add_spin(grid, "Spaziatura", 0.1, 50.0, 3.0, 0.1)
	y_offset_spin = _add_spin(grid, "Altezza label", -10.0, 50.0, 1.5, 0.1)
	label_size_spin = _add_spin(grid, "Dimensione label", 0.1, 10.0, 0.6, 0.1)

	var row2 := HBoxContainer.new()
	add_child(row2)

	var build_btn := Button.new()
	build_btn.text = "Crea/Aggiorna scena"
	build_btn.pressed.connect(_on_build)
	row2.add_child(build_btn)

	var open_btn := Button.new()
	open_btn.text = "Apri scena"
	open_btn.pressed.connect(_on_open_scene)
	row2.add_child(open_btn)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(status_label)
	_set_status("Pronto.")

func _add_spin(parent: GridContainer, title: String, minv: float, maxv: float, defv: float, step: float) -> SpinBox:
	var l := Label.new()
	l.text = title
	parent.add_child(l)

	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.value = defv
	s.step = step
	parent.add_child(s)
	return s

func _on_pick_folder() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.title = "Seleziona cartella con .glb"
	add_child(fd)
	fd.dir_selected.connect(func(dir: String) -> void:
		folder_line.text = dir
		fd.queue_free()
	)
	fd.canceled.connect(func() -> void:
		fd.queue_free()
	)
	fd.popup_centered_ratio(0.6)

func _on_open_scene() -> void:
	if ResourceLoader.exists(OUTPUT_SCENE_PATH):
		EditorInterface.open_scene_from_path(OUTPUT_SCENE_PATH)
		_set_status("Aperta: " + OUTPUT_SCENE_PATH)
	else:
		_set_status("Non trovo " + OUTPUT_SCENE_PATH + " (creala prima).")

func _on_build() -> void:
	var folder := folder_line.text.strip_edges()
	if folder.is_empty():
		_set_status("Inserisci una cartella tipo res://models")
		return
	if not DirAccess.dir_exists_absolute(folder):
		_set_status("Cartella non valida: " + folder)
		return

	var glbs := _list_glbs(folder)
	if glbs.is_empty():
		_set_status("Nessun .glb trovato in: " + folder)
		return

	var root := Node3D.new()
	root.name = _folder_name(folder)

	# Luce e camera base
	var light := DirectionalLight3D.new()
	light.name = "Light"
	light.rotation_degrees = Vector3(-55, 35, 0)
	root.add_child(light)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 8, 12)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	root.add_child(cam)

	var cols := int(cols_spin.value)
	var spacing := float(spacing_spin.value)
	var label_y := float(y_offset_spin.value)
	var label_size := float(label_size_spin.value)

	for i in glbs.size():
		var path: String = glbs[i]
		var n := _make_entry(path, label_y, label_size)
		root.add_child(n)

		var c := i % cols
		var r := i / cols
		n.position = Vector3(c * spacing, 0, r * spacing)

	# Centra la griglia intorno allo zero
	_center_children(root)

	# Salva scena
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		_set_status("Errore pack scena: " + str(err))
		root.free()
		return

	var save_err := ResourceSaver.save(packed, OUTPUT_SCENE_PATH)
	if save_err != OK:
		_set_status("Errore salvataggio: " + str(save_err))
		root.free()
		return

	_set_status("Creato: %s (%d file)".format([OUTPUT_SCENE_PATH, glbs.size()]))
	root.free()

func _list_glbs(folder: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(folder)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var f := d.get_next()
		if f == "":
			break
		if d.current_is_dir():
			continue
		if f.to_lower().ends_with(".glb"):
			out.append(folder.path_join(f))
	d.list_dir_end()
	out.sort()
	return out

func _make_entry(glb_path: String, label_y: float, label_size: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = _safe_name(glb_path.get_file().get_basename())

	var inst := _instantiate_glb(glb_path)
	if inst:
		holder.add_child(inst)

	# Label 3D sopra
	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.text = glb_path.get_file()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = label_size
	lbl.position = Vector3(0, label_y, 0)
	holder.add_child(lbl)

	return holder

func _instantiate_glb(path: String) -> Node:
	var res := ResourceLoader.load(path)
	if res == null:
		return null

	# In Godot 4, un .glb importato spesso diventa PackedScene.
	if res is PackedScene:
		var n := (res as PackedScene).instantiate()
		n.name = "Model"
		# Normalizza a origine per comodità
		if n is Node3D:
			(n as Node3D).position = Vector3.ZERO
		return n

	# Fallback: se per qualche motivo non è PackedScene
	if res is Node:
		return res

	return null

func _center_children(root: Node3D) -> void:
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	var any := false
	for ch in root.get_children():
		if ch is Node3D and ch.name != "Light" and ch.name != "Camera":
			var p := (ch as Node3D).position
			min_v.x = min(min_v.x, p.x)
			min_v.z = min(min_v.z, p.z)
			max_v.x = max(max_v.x, p.x)
			max_v.z = max(max_v.z, p.z)
			any = true

	if not any:
		return

	var center := Vector3((min_v.x + max_v.x) * 0.5, 0, (min_v.z + max_v.z) * 0.5)
	for ch in root.get_children():
		if ch is Node3D and ch.name != "Light" and ch.name != "Camera":
			(ch as Node3D).position -= center

func _folder_name(path: String) -> String:
	var parts := path.split("/", false)
	return parts[parts.size() - 1] if parts.size() > 0 else "GLBGallery"

func _safe_name(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			out += c
		else:
			out += "_"
	return out

func _set_status(t: String) -> void:
	status_label.text = t
