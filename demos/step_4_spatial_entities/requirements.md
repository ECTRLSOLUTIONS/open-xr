# Demo 4 Requirements - Spatial Entities + QR Anchor

Date: 2026-02-17
Project baseline:
- Godot: 4.6.1
- godotopenxrvendors: 4.3.0

## 1. Objective
Implement a new demo that uses a QR code as a real-world anchor and spawns one or more 3D models attached to that anchor in stable world space.

## 2. Scope
In scope:
- Detect one supported marker (QR code first).
- Create or resolve a persistent anchor/entity from marker pose.
- Attach one or more 3D models to the anchor root.
- Keep anchored models stable while user moves around.
- Provide simple UX feedback (searching marker, marker found, anchor active, marker lost).

Out of scope (first version):
- Multi-user shared anchor sync.
- Cloud anchor sync.
- Full authoring UI.

## 3. Functional requirements
FR-1 Marker detection
- System must detect QR marker and expose marker pose in world space.
- Minimum supported content: one printed QR code.

FR-2 Anchor creation and binding
- On first valid detection, create an anchor entity (or equivalent spatial entity) at marker pose.
- Anchor node becomes parent for all content models.

FR-3 Anchored content
- Spawn at least 1 model; target is up to 3 models configurable in inspector.
- Each model must keep relative transform to anchor.

FR-4 Tracking states
- Show states: `Searching`, `Detected`, `Anchored`, `TrackingLost`.
- If tracking is lost temporarily, do not immediately destroy content; use timeout (e.g. 3 seconds).

FR-5 Reacquisition
- If marker is re-detected, rebind to existing anchor when possible.
- Allow manual reset action to drop and recreate anchor.

FR-6 Demo controls
- Add basic controls for `Reset Anchor` and `Spawn/Hide Models`.

## 4. Non-functional requirements
NFR-1 Performance
- Keep frame time XR-safe on target headset (no heavy per-frame allocations).

NFR-2 Reliability
- Avoid anchor jitter by smoothing only visual content, not raw tracking source.

NFR-3 Debuggability
- Add debug logs for marker detected/lost, anchor create/restore, model spawn.

NFR-4 Offline readiness
- Demo must work offline after app install.

## 5. Technical requirements and APIs
Primary path (recommended):
- Godot OpenXR Spatial Entities workflow, including marker tracking capability and marker trackers.
- Use capability checks at runtime before enabling Demo 4 flow.

Platform-specific options:
- Android XR path: `XR_ANDROID_trackables_qr_code` extension for QR trackables.
- Magic Leap path: marker understanding APIs available in vendors docs/classes.
- Meta path: verify actual runtime support for needed spatial marker capabilities on target firmware.

Permissions and runtime setup:
- Request required scene/spatial permissions for target runtime.
- Fail gracefully with a clear message if permission or extension is unavailable.

## 6. Proposed scene architecture
Suggested files for demo implementation:
- `demos/step_4_spatial_entities/main_spatial_entities.tscn`
- `demos/step_4_spatial_entities/main_spatial_entities.gd`
- `demos/step_4_spatial_entities/qr_anchor_manager.gd`
- `demos/step_4_spatial_entities/anchored_content_root.tscn`

Node-level idea:
- `XROrigin3D`
- `QRAnchorManager` (owns marker tracker lifecycle)
- `AnchorRoot` (`Node3D`, driven by spatial entity pose)
- `AnchoredContent` (one or more model instances)
- `CanvasLayer` debug/status UI

## 7. Acceptance criteria
- AC-1: With a supported QR in view, app transitions from `Searching` to `Anchored` in <= 2 seconds.
- AC-2: At least one model remains stably anchored while user walks around it.
- AC-3: Temporary marker loss (< 3 seconds) does not despawn content.
- AC-4: Manual reset removes previous anchor and creates a new one on next detection.
- AC-5: On unsupported runtime, demo shows explicit "feature not supported" message and does not crash.

## 8. Research summary (online)
What exists today:
- Godot has official stable docs for OpenXR Spatial Entities and marker tracking classes.
- Godot OpenXR Vendors provides spatial anchor and scene samples (closest public Godot sample).
- Android XR docs include QR trackables extension support and sample references.

Inference:
- There is a public Godot sample with marker tracking flow: BastiaanOlij `spatial-entities-demo`.
- It uses `XRAnchor3D` + `OpenXRMarkerTracker`, and resolves QR payload to spawn marker-bound scenes.
- It is a strong technical reference, but this project still needs a custom implementation aligned with our scene structure, UX states, and acceptance criteria.

## 9. External references
- Godot OpenXR Spatial Entities tutorial:
  - https://docs.godotengine.org/en/stable/tutorials/xr/openxr_spatial_entities.html
- Godot marker tracker class:
  - https://docs.godotengine.org/en/stable/classes/class_openxrspatialmarkertracker.html
- Android XR QR extension docs:
  - https://developer.android.com/develop/xr/openxr/extensions/XR_ANDROID_trackables_qr_code
- Godot OpenXR Vendors Meta spatial anchors manual:
  - https://godotvr.github.io/godot_openxr_vendors/manual/meta/spatial_anchors.html
- Godot OpenXR Vendors Meta scene sample (linked from official vendors docs):
  - https://github.com/GodotVR/godot_openxr_vendors/tree/master/samples/meta-scene-sample
- Godot Asset Library listing: Meta Scene XR Sample (version 4.3.0):
  - https://godotengine.org/asset-library/asset/4296
- Android XR samples repository (contains MarkerMaze QR-tracking sample):
  - https://github.com/android/xr-unity-samples
- BastiaanOlij spatial entities demo (includes marker scene `spatial_entities_marker.tscn`):
  - https://github.com/BastiaanOlij/spatial-entities-demo
  - https://github.com/BastiaanOlij/spatial-entities-demo/blob/master/spatial_entities/spatial_entities_marker.tscn
