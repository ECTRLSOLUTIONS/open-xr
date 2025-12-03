extends XROrigin3D

func _ready():
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		_setup_passthrough(xr_interface)

func _setup_passthrough(xr):
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in xr.get_supported_environment_blend_modes():
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		xr.start_passthrough()

	get_viewport().transparent_bg = true
	
	if has_node("WorldEnvironment"):
		$WorldEnvironment.environment.background_mode = Environment.BG_COLOR
		$WorldEnvironment.environment.background_color = Color(0,0,0,0)
