extends XROrigin3D

@onready var sm := $OpenXRFbSceneManager # Riferimento diretto al SceneManager

@export var pickables_container: Node3D
@export var hand_path    := "/user/hand_tracker/right"
@export var force_scene_capture_on_start := false
@export var animated_model_path: NodePath = NodePath("Pickable/pp_stag")
@export var animated_model_idle_animation := "Idle"
@export var animated_model_loop := true
@export_range(0.05, 0.8, 0.01) var animated_model_touch_distance := 0.18
@export_range(1, 10, 1) var animated_model_random_plays := 3
@export_range(0.0, 3.0, 0.1) var animated_model_trigger_cooldown_sec := 0.8

# Variabili per interazione (ereditate dallo step 2)
const FREEZE_KIN  := RigidBody3D.FreezeMode.FREEZE_MODE_KINEMATIC
const ROOM_LOAD_TIMEOUT_SEC := 1.5
const CAPTURE_ANCHOR_TIMEOUT_SEC := 3.0
var current_grabbed_object: RigidBody3D = null
var grabbed = false
var grab_off = Vector3.ZERO
var anchors_ready = false
var scan_requested = false
var _animated_model: Node3D = null
var _animated_model_anim_player: AnimationPlayer = null
var _idle_animation_name := ""
var _random_animation_names: Array[String] = []
var _pending_random_animations: Array[String] = []
var _animated_model_mesh_nodes: Array[MeshInstance3D] = []
var _animation_sequence_running := false
var _is_touching_animated_model := false
var _next_animation_trigger_sec := 0.0
var _last_random_animation := ""
var _rng := RandomNumberGenerator.new()

func _init():
	print("Main: _init chiamato. L'applicazione sta partendo.")

func _ready():
	print("Main: _ready chiamato.")
	_rng.randomize()
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		get_viewport().physics_object_picking = false
		_setup_passthrough(xr_interface)
		
		sm.openxr_fb_scene_data_missing.connect(_on_scene_data_missing)
		sm.openxr_fb_scene_capture_completed.connect(_on_scan_done)
		if force_scene_capture_on_start:
			_request_scene_capture("forced on start")
		else:
			_try_load_existing_room()
		_setup_animated_model()
	else:
		_setup_pickables()

func _try_load_existing_room() -> void:
	print("Main: Trying to load existing room data...")
	var result = sm.create_scene_anchors()
	print("Main: create_scene_anchors result: ", result)
	
	if result == ERR_ALREADY_EXISTS:
		anchors_ready = true
		_on_room_ready()
		return
	
	await _wait_for_anchors_or_timeout(ROOM_LOAD_TIMEOUT_SEC)
	if sm.are_scene_anchors_created():
		anchors_ready = true
		_on_room_ready()
	else:
		print("Main: No anchors after timeout.")
		_request_scene_capture("no anchors loaded")

func _request_scene_capture(reason: String) -> void:
	if anchors_ready or scan_requested:
		return
	scan_requested = true
	print("Main: Requesting scene capture (%s)..." % reason)
	sm.request_scene_capture()

func _on_scene_data_missing() -> void:
	_request_scene_capture("room data missing")

func _on_scan_done(ok):
	print("Main: Scan done. Success: ", ok)
	scan_requested = false
	if not ok:
		push_warning("Main: Scene capture failed or canceled.")
		return
	
	sm.create_scene_anchors()
	await _wait_for_anchors_or_timeout(CAPTURE_ANCHOR_TIMEOUT_SEC)
	if sm.are_scene_anchors_created() and !anchors_ready:
		anchors_ready = true
		_on_room_ready()
	else:
		push_warning("Main: Capture completed, but scene anchors are not ready yet.")

func _wait_for_anchors_or_timeout(timeout_sec: float) -> void:
	var start_sec := Time.get_ticks_msec() / 1000.0
	while !sm.are_scene_anchors_created():
		var elapsed := (Time.get_ticks_msec() / 1000.0) - start_sec
		if elapsed >= timeout_sec:
			return
		await get_tree().process_frame

func _on_room_ready():
	print("Main: Stanza caricata! Gli oggetti ora rimbalzeranno sui muri reali.")
	_setup_pickables()

func _setup_pickables():
	if pickables_container:
		for child in pickables_container.get_children():
			if child is RigidBody3D:
				child.gravity_scale = 1.0 # Riattiviamo la gravità per vedere le collisioni
				child.freeze = false      # Lasciamoli cadere (se non sono presi)
				child.continuous_cd = true # Evita che passino attraverso i muri veloci

func _physics_process(dt: float) -> void:
	# --- Logica di interazione (identica allo step 2) ---
	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if !tracker or !tracker.has_tracking_data:
		_is_touching_animated_model = false
		_release_grab()
		return

	# Ottieni posizioni locali (rispetto a XROrigin)
	var tip_local   := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var thumb_local := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_THUMB_TIP).origin
	
	# Converti in globali per interagire con gli oggetti nel mondo
	var tip = to_global(tip_local)
	var thumb = to_global(thumb_local)
	_handle_animated_model_touch(tip)
	
	var pinch_dist = tip.distance_to(thumb)
	var pinch: bool = pinch_dist < 0.035

	if pinch and !grabbed:
		var closest_obj = _get_closest_pickable(tip)
		if closest_obj:
			_grab_object(closest_obj, tip)

	elif !pinch and grabbed:
		_release_grab()

	if grabbed and current_grabbed_object:
		# Calcola velocità istantanea per il lancio
		var prev_pos = current_grabbed_object.global_transform.origin
		
		# Muoviamo l'oggetto con la mano
		current_grabbed_object.global_transform.origin = tip + grab_off
		
		# Salviamo la velocità lineare stimata nel corpo stesso (utile se rilasciato)
		var velocity = (current_grabbed_object.global_transform.origin - prev_pos) / max(dt, 0.001)
		current_grabbed_object.linear_velocity = velocity
		current_grabbed_object.angular_velocity = Vector3.ZERO

# --- Helper Functions (Interazione) ---
func _get_closest_pickable(tip_pos: Vector3) -> RigidBody3D:
	if !pickables_container: return null
	var closest: RigidBody3D = null
	var min_dist := 1000.0
	for child in pickables_container.get_children():
		if child is RigidBody3D:
			var dist = child.global_transform.origin.distance_to(tip_pos)
			if dist < 0.15 and dist < min_dist: # Soglia semplice
				min_dist = dist
				closest = child
	return closest

func _grab_object(obj: RigidBody3D, tip_pos: Vector3):
	print("Main: Preso oggetto ", obj.name)
	grabbed = true
	current_grabbed_object = obj
	grab_off = obj.global_transform.origin - tip_pos
	
	# Usa modalità Kinematic per collisioni migliori mentre si tiene l'oggetto
	obj.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	obj.freeze = true 

func _release_grab():
	if grabbed:
		print("Main: Rilasciato oggetto")
	grabbed = false
	if current_grabbed_object:
		current_grabbed_object.freeze = false # Riattiva fisica
		# La velocità è già stata impostata nel physics_process, quindi l'oggetto dovrebbe conservare il momento
		current_grabbed_object = null
		# Opzionale: dare un impulso basato sulla velocità della mano qui

func _setup_passthrough(xr):
	# Setup base passthrough
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		xr.start_passthrough()
	get_viewport().transparent_bg = true
	$WorldEnvironment.environment.background_mode = Environment.BG_COLOR
	$WorldEnvironment.environment.background_color = Color(0,0,0,0)

func _setup_animated_model() -> void:
	_animated_model = get_node_or_null(animated_model_path) as Node3D
	if not _animated_model:
		push_warning("Main: Animated model not found at path %s" % animated_model_path)
		return

	_animated_model_anim_player = _find_animation_player(_animated_model)
	if not _animated_model_anim_player:
		push_warning("Main: AnimationPlayer not found under animated model.")
		return
	
	_animated_model_mesh_nodes.clear()
	_collect_mesh_instances(_animated_model, _animated_model_mesh_nodes)

	var animations: PackedStringArray = _animated_model_anim_player.get_animation_list()
	if animations.is_empty():
		push_warning("Main: Animated model has no animations.")
		return

	_idle_animation_name = animated_model_idle_animation
	if not _animated_model_anim_player.has_animation(_idle_animation_name):
		_idle_animation_name = String(animations[0])

	_random_animation_names.clear()
	for animation_name in animations:
		var name := String(animation_name)
		if name != _idle_animation_name:
			_random_animation_names.append(name)
	
	print("Main: Animated model ready. Idle=", _idle_animation_name, " Random animations=", _random_animation_names)

	_play_idle_animation()

func _handle_animated_model_touch(tip_position: Vector3) -> void:
	if not _animated_model_anim_player or not _animated_model:
		return

	var is_touching_now := _is_tip_near_animated_model(tip_position)
	if is_touching_now and not _is_touching_animated_model:
		var now_sec := Time.get_ticks_msec() / 1000.0
		if now_sec >= _next_animation_trigger_sec and not _animation_sequence_running:
			_trigger_random_animation_sequence()

	_is_touching_animated_model = is_touching_now

func _trigger_random_animation_sequence() -> void:
	if _random_animation_names.is_empty():
		print("Main: No random animations available (only idle or single animation).")
		return

	_animation_sequence_running = true
	_next_animation_trigger_sec = Time.get_ticks_msec() / 1000.0 + animated_model_trigger_cooldown_sec
	_pending_random_animations = _build_random_animation_sequence(maxi(animated_model_random_plays, 1))
	_play_next_random_animation()

func _build_random_animation_sequence(count: int) -> Array[String]:
	var sequence: Array[String] = []
	var previous: String = _last_random_animation
	var pool: Array[String] = _random_animation_names.duplicate()

	for i in range(count):
		if pool.is_empty():
			pool = _random_animation_names.duplicate()
		if pool.is_empty():
			break

		var candidates: Array[String] = []
		for name in pool:
			if pool.size() == 1 or name != previous:
				candidates.append(name)

		if candidates.is_empty():
			candidates = pool.duplicate()
		if candidates.is_empty():
			break

		var selected_index: int = _rng.randi_range(0, candidates.size() - 1)
		var selected_name: String = candidates[selected_index]
		sequence.append(selected_name)
		previous = selected_name
		pool.erase(selected_name)

	return sequence

func _play_next_random_animation() -> void:
	if not _animated_model_anim_player:
		_animation_sequence_running = false
		return

	if _pending_random_animations.is_empty():
		_play_idle_animation()
		_animation_sequence_running = false
		return

	var animation_name: String = _pending_random_animations[0]
	_pending_random_animations.remove_at(0)
	_last_random_animation = animation_name

	if not _animated_model_anim_player.has_animation(animation_name):
		_play_next_random_animation()
		return

	var animation: Animation = _animated_model_anim_player.get_animation(animation_name)
	if not animation:
		_play_next_random_animation()
		return

	animation.loop_mode = Animation.LOOP_NONE
	_animated_model_anim_player.play(animation_name)

	var wait_time: float = maxf(animation.length, 0.05)
	var timer: SceneTreeTimer = get_tree().create_timer(wait_time)
	timer.timeout.connect(_on_random_animation_step_finished, CONNECT_ONE_SHOT)

func _on_random_animation_step_finished() -> void:
	_play_next_random_animation()

func _play_idle_animation() -> void:
	if not _animated_model_anim_player:
		return
	if _idle_animation_name == "":
		return
	if not _animated_model_anim_player.has_animation(_idle_animation_name):
		return

	var animation: Animation = _animated_model_anim_player.get_animation(_idle_animation_name)
	if animation and animated_model_loop:
		animation.loop_mode = Animation.LOOP_LINEAR
	_animated_model_anim_player.play(_idle_animation_name)

func _is_tip_near_animated_model(tip_position: Vector3) -> bool:
	if not _animated_model:
		return false

	if tip_position.distance_to(_animated_model.global_transform.origin) <= animated_model_touch_distance:
		return true

	for mesh in _animated_model_mesh_nodes:
		if mesh and tip_position.distance_to(mesh.global_transform.origin) <= animated_model_touch_distance:
			return true

	return false

func _collect_mesh_instances(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node as MeshInstance3D)

	for child in node.get_children():
		_collect_mesh_instances(child, out_meshes)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found

	return null
