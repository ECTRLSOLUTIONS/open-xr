# Demo 3 - Room Scan + Physics (current state)

This file describes the demo currently in use: `main_scene_mesh.tscn`.

## Demo goal
- Use `OpenXRFbSceneManager` to create colliders for the real room.
- Let `RigidBody3D` objects interact with real walls/floor.
- Keep hand-tracking interaction (pinch grab) as in step 2.

## Main files used
- Scene: `demos/step_3_scene_mesch/main_scene_mesh.tscn`
- Main script: `demos/step_3_scene_mesch/main_scene_mesh.gd`
- Room collider prefab: `demos/step_3_scene_mesch/SpatialEntity.tscn`
- Room collider script: `demos/step_3_scene_mesch/SpatialEntity.gd`

Note: this demo does NOT use `RoomManager.tscn`.

## Runtime flow
1. XR startup + passthrough.
2. Try loading existing room anchors with `create_scene_anchors()`.
3. Only if room data is missing, request a new capture with `request_scene_capture()`.
4. Once capture is completed: `create_scene_anchors()`.
5. Each anchor instantiates `SpatialEntity.tscn`, which creates the real `CollisionShape3D`.
6. Objects in `Pickable` become dynamic and collide with the room.

## Capture behavior
- If no anchors are loaded within a short timeout, the demo now requests scene capture as fallback.
- You can force capture on every start from Inspector:
  - `force_scene_capture_on_start = true` on the root `XROrigin3D`.

## Requirements
- Meta Quest with a configured room (Room Setup completed).
- OpenXR extensions enabled in the project:
  - Meta Scene API
  - Meta Anchor API
  - Meta Passthrough 
- App permissions accepted on the headset.

## Quick debugging
- If objects pass through everything:
  - verify room scan data is available in the Quest system;
  - verify `OpenXRFbSceneManager` is creating anchors;
  - check that `SpatialEntity.gd` is not printing errors on `create_collision_shape()`.
- If you do not see differences between step 2 and step 3:
  - room anchors were probably not created.

## Demo controls
- Pinch near an object to grab it.
- Release pinch to drop the object.
- Use the 3D `Main Menu` button to return to the launcher.
