@tool
extends Control

var subviewport: SubViewport
var subviewport_container: SubViewportContainer
var current_scene: Node3D
var camera: Camera3D

func _ready() -> void:
	# Crea il SubViewport
	subviewport = SubViewport.new()
	subviewport.own_world_3d = true
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Crea il container per mostrarlo nel Dock
	subviewport_container = SubViewportContainer.new()
	# Compatibilità: alcune versioni espongono la property come "subviewport" o "sub_viewport".
	_set_container_subviewport(subviewport_container, subviewport)
	# In alcune versioni il SubViewport deve anche essere child del container.
	if subviewport.get_parent() == null:
		subviewport_container.add_child(subviewport)
	subviewport_container.stretch = true
	add_child(subviewport_container)

	# Occupa tutto lo spazio del dock
	subviewport_container.anchor_left = 0.0
	subviewport_container.anchor_top = 0.0
	subviewport_container.anchor_right = 1.0
	subviewport_container.anchor_bottom = 1.0
	subviewport_container.offset_left = 0.0
	subviewport_container.offset_top = 0.0
	subviewport_container.offset_right = 0.0
	subviewport_container.offset_bottom = 0.0
	subviewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Camera
	camera = Camera3D.new()
	subviewport.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(0.0, 1.5, 4.0), Vector3(0.0, 1.0, 0.0), Vector3.UP)

	# Luce
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	subviewport.add_child(light)

func _set_container_subviewport(container: SubViewportContainer, viewport: SubViewport) -> void:
	var has_subviewport := false
	var has_sub_viewport := false
	for p in container.get_property_list():
		if p is Dictionary and p.has("name"):
			var n := str(p["name"])
			if n == "subviewport":
				has_subviewport = true
			elif n == "sub_viewport":
				has_sub_viewport = true
	if has_subviewport:
		container.set("subviewport", viewport)
	elif has_sub_viewport:
		container.set("sub_viewport", viewport)

func show_glb(path: String) -> void:
	# Cancella il modello precedente
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

	if path == "":
		return

	var res: Resource = ResourceLoader.load(path)
	if res == null:
		push_warning("GLB Viewer: impossibile caricare: %s" % path)
		return
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		if not (inst is Node3D):
			push_warning("GLB Viewer: root non Node3D (%s) per: %s" % [inst.get_class(), path])
			inst.queue_free()
			return
		current_scene = inst as Node3D
		subviewport.add_child(current_scene)
		_frame_and_center_model()
	else:
		push_warning("GLB Viewer: risorsa non supportata (%s) per: %s" % [res.get_class(), path])

func _frame_and_center_model() -> void:
	if current_scene == null:
		return

	var root_inv := current_scene.global_transform.affine_inverse()
	var aabb: AABB = _get_aabb_recursive(current_scene, root_inv)
	if aabb.size == Vector3.ZERO:
		return

	var center: Vector3 = aabb.position + aabb.size * 0.5
	current_scene.translate(-center)

	# Posiziona la camera in base alla dimensione del modello.
	if camera != null:
		var max_extent := max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		var radius := max(0.01, max_extent * 0.5)
		camera.near = max(0.01, radius / 100.0)
		camera.far = max(50.0, radius * 50.0)
		var cam_pos := Vector3(0.0, radius * 0.8, radius * 3.0)
		camera.look_at_from_position(cam_pos, Vector3.ZERO, Vector3.UP)

func _center_model() -> void:
	if current_scene == null:
		return

	var aabb: AABB = _get_aabb_recursive(current_scene)
	if aabb.size == Vector3.ZERO:
		return

	var center: Vector3 = aabb.position + aabb.size * 0.5
	current_scene.translate(-center)


func _get_aabb_recursive(node: Node, root_inverse: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result: AABB = AABB()
	var first: bool = true

	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mesh: Mesh = mi.mesh
			if mesh != null:
				var local_xform: Transform3D = root_inverse * mi.global_transform
				var aabb: AABB = _transform_aabb(mesh.get_aabb(), local_xform)

				if first:
					result = aabb
					first = false
				else:
					result = result.merge(aabb)

		if child is Node:
			var sub_aabb: AABB = _get_aabb_recursive(child as Node, root_inverse)
			if sub_aabb.size != Vector3.ZERO:
				if first:
					result = sub_aabb
					first = false
				else:
					result = result.merge(sub_aabb)

	if first:
		return AABB(Vector3.ZERO, Vector3.ZERO)

	return result


func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	# Compatibile con versioni dove AABB.transformed() non esiste.
	if aabb.size == Vector3.ZERO:
		return aabb

	var p := aabb.position
	var s := aabb.size
	var corners := [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s,
	]

	var min_v: Vector3 = xform * corners[0]
	var max_v: Vector3 = min_v
	for i in range(1, corners.size()):
		var v: Vector3 = xform * corners[i]
		min_v = min_v.min(v)
		max_v = max_v.max(v)
	return AABB(min_v, max_v - min_v)
