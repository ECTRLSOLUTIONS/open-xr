extends XROrigin3D

@onready var sm := $OpenXRFbSceneManager # Riferimento diretto al SceneManager

@export var pickables_container: Node3D
@export var hand_path    := "/user/hand_tracker/right"
@export var force_scene_capture_on_start := false
@export var animated_model_path: NodePath = NodePath("Pickable/pp_stag")
@export var animated_model_idle_animation := "Idle"
@export var animated_model_loop := true

# Variabili per interazione (ereditate dallo step 2)
const FREEZE_KIN  := RigidBody3D.FreezeMode.FREEZE_MODE_KINEMATIC
const ROOM_LOAD_TIMEOUT_SEC := 1.5
const CAPTURE_ANCHOR_TIMEOUT_SEC := 3.0
var current_grabbed_object: RigidBody3D = null
var grabbed = false
var grab_off = Vector3.ZERO
var anchors_ready = false
var scan_requested = false

func _init():
	print("Main: _init chiamato. L'applicazione sta partendo.")

func _ready():
	print("Main: _ready chiamato.")
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
		_start_model_idle_animation()
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
		_release_grab()
		return

	# Ottieni posizioni locali (rispetto a XROrigin)
	var tip_local   := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var thumb_local := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_THUMB_TIP).origin
	
	# Converti in globali per interagire con gli oggetti nel mondo
	var tip = to_global(tip_local)
	var thumb = to_global(thumb_local)
	
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

func _start_model_idle_animation() -> void:
	var model := get_node_or_null(animated_model_path)
	if not model:
		return

	var anim_player := _find_animation_player(model)
	if not anim_player:
		return

	var animation_name := animated_model_idle_animation
	if not anim_player.has_animation(animation_name):
		var animations := anim_player.get_animation_list()
		if animations.is_empty():
			return
		animation_name = animations[0]

	var anim := anim_player.get_animation(animation_name)
	if anim and animated_model_loop:
		anim.loop_mode = Animation.LOOP_LINEAR

	anim_player.play(animation_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found

	return null
