# Godot Engine XR: Passthrough & Interaction Workshop 🥽

![Godot XR](https://img.shields.io/badge/Godot-4.6.1-blue?logo=godotengine)
![OpenXR](https://img.shields.io/badge/XR-OpenXR-red)
![Vendors Plugin](https://img.shields.io/badge/godotopenxrvendors-4.3.0-green)

This repository contains a progressive workshop for Mixed Reality (MR) development with **Godot Engine 4.6.1**, focused on **OpenXR**, passthrough, scene understanding, and spatial interaction.

The project is designed to stay **vendor-neutral** as much as possible, while still using vendor extensions where needed through **godotopenxrvendors 4.3.0**.

## 🚀 Project goals

1. **Standard OpenXR workflow:** avoid lock-in to a single proprietary SDK.
2. **Mixed Reality:** blend virtual objects with the physical world (passthrough + spatial context).
3. **Future-proof architecture:** target Quest today and remain ready for Android XR and upcoming OpenXR spatial features.

## 📂 Demo overview

Current demos are in `demos/`:

### 1. 🟢 Demo 1: Hello Passthrough
- **Goal:** base setup.
- **Features:**
  - `XROrigin3D` passthrough configuration.
  - A first static virtual object in real space.

### 2. 🟡 Demo 2: Hand interaction
- **Goal:** hand-based interaction + physics.
- **Features:**
  - Hands without controllers.
  - Custom pinch-to-grab logic.
  - Basic rigidbody handling (freeze/unfreeze during grab).

### 3. 🔴 Demo 3: Scene understanding
- **Goal:** interact with the physical environment.
- **Features:**
  - Room scan / scene mesh usage.
  - Objects aligned with real-world floors/tables.
  - Initial integration of physical collisions with room data.

### 4. 🧭 Demo 4: Spatial entities + QR anchor
- **Goal:** detect a marker and anchor one or more 3D models to it.
- **Requirements draft:** `demos/step_4_spatial_entities/requirements.md`.
- **Current implementation scene:** `demos/step_4_spatial_entities/main_spatial_entities.tscn`.

## 🛠️ Prerequisites & installation

IMPORTANT: this repo does not include all required plugins to keep the project lightweight.

### 1. Requirements
- **Godot Engine:** `4.6.1`
- **godotopenxrvendors:** `4.3.0`
- **Hardware:** Meta Quest 3 (or compatible Android XR device).
- **Android toolchain:** SDK/NDK installed (Android Studio is fine).
- **Connection:** USB-C or wireless debugging.

### 2. Setup steps
1. Clone this repository.
2. Open the project in Godot.
3. Install from AssetLib (or release zip):
   - **Godot XR Tools**: https://github.com/GodotVR/godot-xr-tools/releases
   - **Godot OpenXR Vendors**: https://github.com/GodotVR/godot_openxr_vendors/releases
4. Enable `Godot XR Tools` from `Project -> Project Settings -> Plugins`.
5. Reload project.
6. Install Android build templates (`Project -> Install Android Build Template...`).
7. Verify action map in `Project Settings -> XR -> OpenXR`:
   - `res://xr_config/openxr_action_map.tres`

Note: `godotopenxrvendors` is a GDExtension, so it is not enabled through the Plugins tab.

### 3. Android / Quest export
1. Open `Project -> Export`.
2. Use Android preset (already present in the project).
3. Ensure **XR Mode = OpenXR**.
4. Under OpenXR vendor options, select the runtime target you want for that export.

## 🔭 Current baseline

- Engine baseline: **Godot 4.6.1**
- Vendors plugin baseline: **godotopenxrvendors 4.3.0**
- Plugin changelog snapshot: `addons/godotopenxrvendors/GodotOpenXRVendors_CHANGES.md`

## 📄 Resources & credits

- **Presentation slides:** [Download PDF](./docs/presentation-sfscon-openxr-godot.pdf)
- **3D assets:** [Kenney.nl](https://kenney.nl/) (CC0 License)
- **Original code:** Suggesto S.r.l.

For more information on Godot XR, see the official docs: https://docs.godotengine.org/en/stable/tutorials/xr/index.html
