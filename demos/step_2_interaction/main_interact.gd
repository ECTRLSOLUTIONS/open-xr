extends XROrigin3D

@onready var cam := $XRCamera3D

@export var pickables_container: Node3D
@export var hand_path    := "/user/hand_tracker/right"
@export_range(0.05, 2.0, 0.05) var object_scale := 1.0

const FREEZE_KIN  := RigidBody3D.FreezeMode.FREEZE_MODE_KINEMATIC

var current_grabbed_object: RigidBody3D = null
var grabbed = false
var grab_off = Vector3.ZERO

func _ready():
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		_setup_passthrough(xr_interface)
	
	# Initialize pickables
	if pickables_container:
		for child in pickables_container.get_children():
			if child is RigidBody3D:
				child.scale = Vector3.ONE * object_scale
				child.gravity_scale = 0
				child.freeze_mode = FREEZE_KIN
				child.freeze = true

func _physics_process(_dt: float) -> void:
	var tracker := XRServer.get_tracker(hand_path) as XRHandTracker
	if !tracker or !tracker.has_tracking_data:
		_release_grab()
		return

	var tip   := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_INDEX_FINGER_TIP).origin
	var thumb := tracker.get_hand_joint_transform(XRHandTracker.HandJoint.HAND_JOINT_THUMB_TIP).origin
	var pinch := tip.distance_to(thumb) < 0.035

	if pinch and !grabbed:
		var closest_obj = _get_closest_pickable(tip)
		if closest_obj:
			_grab_object(closest_obj, tip)

	elif !pinch and grabbed:
		_release_grab()

	if grabbed and current_grabbed_object:
		current_grabbed_object.global_transform.origin = tip + grab_off

func _get_closest_pickable(tip_pos: Vector3) -> RigidBody3D:
	if !pickables_container:
		return null
		
	var closest: RigidBody3D = null
	var min_dist := 1000.0
	
	for child in pickables_container.get_children():
		if child is RigidBody3D:
			var rad = _get_radius(child)
			var dist = child.global_transform.origin.distance_to(tip_pos)
			if dist <= rad + 0.05 and dist < min_dist:
				min_dist = dist
				closest = child
	return closest

func _get_radius(body: RigidBody3D) -> float:
	var radius = 0.1 # Default fallback
	
	for child in body.get_children():
		if child is CollisionShape3D and child.shape:
			var shape = child.shape
			if shape is SphereShape3D:
				radius = shape.radius
			elif shape is BoxShape3D:
				radius = max(shape.size.x, max(shape.size.y, shape.size.z)) * 0.5
			elif shape is CapsuleShape3D:
				radius = max(shape.radius, shape.height * 0.5)
			elif shape is CylinderShape3D:
				radius = max(shape.radius, shape.height * 0.5)
			break
			
	# Apply object scale (assuming uniform scale for simplicity)
	return radius * body.scale.x

func _grab_object(obj: RigidBody3D, tip_pos: Vector3):
	grabbed = true
	current_grabbed_object = obj
	grab_off = obj.global_transform.origin - tip_pos
	obj.freeze_mode = FREEZE_KIN
	obj.freeze = true
	obj.gravity_scale = 0
	obj.linear_velocity = Vector3.ZERO
	obj.angular_velocity = Vector3.ZERO

func _release_grab():
	grabbed = false
	if current_grabbed_object:
		current_grabbed_object.freeze = true
		current_grabbed_object.linear_velocity = Vector3.ZERO
		current_grabbed_object.angular_velocity = Vector3.ZERO
		current_grabbed_object = null

func _setup_passthrough(xr):
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		xr.start_passthrough()

	get_viewport().transparent_bg = true
	$WorldEnvironment.environment.background_mode  = Environment.BG_COLOR
	$WorldEnvironment.environment.background_color = Color(0,0,0,0)

	var fb = Engine.get_singleton("OpenXRFbPassthroughExtensionWrapper")
	if fb:
		fb.set_edge_color(Color(0,0,0,0))
		fb.set_texture_opacity_factor(1.0)
