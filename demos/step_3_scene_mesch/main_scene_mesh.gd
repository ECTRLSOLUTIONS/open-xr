extends XROrigin3D

@onready var cam := $XRCamera3D
@onready var sm := $OpenXRFbSceneManager # Riferimento diretto al SceneManager

@export var pickables_container: Node3D
@export var hand_path    := "/user/hand_tracker/right"

# Variabili per interazione (ereditate dallo step 2)
const FREEZE_KIN  := RigidBody3D.FreezeMode.FREEZE_MODE_KINEMATIC
var current_grabbed_object: RigidBody3D = null
var grabbed = false
var grab_off = Vector3.ZERO
var anchors_ready = false

func _init():
	print("Main: _init chiamato. L'applicazione sta partendo.")

func _ready():
	print("Main: _ready chiamato.")
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		_setup_passthrough(xr_interface)
		
		# Logica copiata da main_working.gd
		_rescan_room()
		sm.openxr_fb_scene_data_missing.connect(sm.request_scene_capture)
		sm.openxr_fb_scene_capture_completed.connect(_on_scan_done)
	else:
		_setup_pickables()

func _rescan_room():
	print("Main: Rescan room...")
	if sm.has_method("destroy_scene_anchors"): 
		sm.destroy_scene_anchors()
	elif sm.has_method("remove_scene_anchors"):
		sm.remove_scene_anchors()
		
	sm.request_scene_capture()

func _on_scan_done(ok):
	print("Main: Scan done. Success: ", ok)
	if ok and !anchors_ready:
		anchors_ready = true
		sm.create_scene_anchors()
		await _anchors_created()
		_on_room_ready()

func _anchors_created():
	while !sm.are_scene_anchors_created():
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
		_release_grab(tip, dt) # Passiamo tip e dt per calcolare velocità lancio

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

func _release_grab(tip_pos: Vector3 = Vector3.ZERO, dt: float = 0.0):
	if grabbed:
		print("Main: Rilasciato oggetto")
	grabbed = false
	if current_grabbed_object:
		current_grabbed_object.freeze = false # Riattiva fisica
		# La velocità è già stata impostata nel physics_process, quindi l'oggetto dovrebbe conservare il momento
		current_grabbed_object = null
		# Opzionale: dare un impulso basato sulla velocità della mano qui
		current_grabbed_object = null

func _setup_passthrough(xr):
	# Setup base passthrough
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		xr.start_passthrough()
	get_viewport().transparent_bg = true
	$WorldEnvironment.environment.background_mode = Environment.BG_COLOR
	$WorldEnvironment.environment.background_color = Color(0,0,0,0)
