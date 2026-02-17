# Demo 4 - Spatial Entities + QR Anchor

This demo anchors two 3D objects (cube + sphere) to a detected QR code using OpenXR spatial entities marker tracking.

## Scene
Run:
- `res://demos/step_4_spatial_entities/main_spatial_entities.tscn`

## What this demo does
- Detects marker trackers (`OpenXRMarkerTracker`) exposed by runtime.
- Instantiates an `XRAnchor3D` scene for each detected marker.
- Attaches a cube and sphere to that anchor.
- Shows a 3D instruction sign in world space.
- Hides the 3D sign as soon as a marker is detected/anchored.

## Controls
- Use the `Main Menu` 3D button to go back to the launcher.

## Required project settings
Already configured in `project.godot`:
- `xr/openxr/extensions/spatial_entity/enabled = true`
- `enable_marker_tracking = true`
- `enable_builtin_marker_tracking = true`

## What you need to do
1. Use a headset/runtime that supports OpenXR marker tracking.
2. Grant requested permissions on first run.
3. Print or show a QR code.
4. Start the scene and point the headset camera to the QR code.
5. When detected, cube and sphere will appear anchored on top of it.

## Suggested QR test payload
A simple string is enough, for example:
- `openxr-demo-qr-anchor`

## Which marker should you use?
- Start with a standard **QR code** (best compatibility).
- Print it on paper (recommended size: at least 8-10 cm).
- Keep good lighting and avoid reflections.
- After app start, look at the marker with the headset camera until state changes to `DETECTED` / `ANCHORED`.

If tracking never starts, verify runtime support for marker tracking (some runtimes only support specific marker types or need additional permissions).
