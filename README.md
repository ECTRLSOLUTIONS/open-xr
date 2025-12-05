# Godot Engine XR: Passthrough & Interaction Workshop 🥽

![Godot XR](https://img.shields.io/badge/Godot-4.5+-blue?logo=godotengine)
![OpenXR](https://img.shields.io/badge/XR-OpenXR-red)
![Platform](https://img.shields.io/badge/Platform-Quest%20%7C%20AndroidXR-green)

This repository contains a progressive workshop to learn Mixed Reality (MR) development with **Godot Engine 4.5+**, focusing on **OpenXR**, Passthrough, and spatial interaction.

The project is designed to be **vendor-neutral**, leveraging the official OpenXR standard to ensure compatibility with Meta Quest, Pico 4, and the upcoming **Android XR ecosystem** (Samsung Galaxy XR, Project Aura).

## 🚀 Project Goals

1.  **Standard OpenXR Workflow:** Avoid proprietary SDKs where possible.
2.  **Mixed Reality:** Learn to blend virtual objects with the real world (Passthrough).
3.  **Future-Proofing:** Prepare for the upcoming Android XR devices by using the latest Godot 4.5 OpenXR Vendors plugin.

## 📂 Demo Overview

The project is a single Godot project divided into 3 progressive scenes located in the `demos/` folder:

### 1. 🟢 Demo 1: Hello Passthrough
*   **Goal:** Basic Setup.
*   **Features:**
	*   Configuring `XROrigin3D` for Passthrough (transparent background).
	*   Placing a simple static virtual object in the real world.
	*   No complex interactions.

### 2. 🟡 Demo 2: Hand Interaction
*   **Goal:** Physics and Hand Tracking.
*   **Features:**
	*   Visualizing hands without controllers.
	*   **Custom Pinch-to-Grab logic:** Interact with a floating sphere using your thumb and index finger.
	*   Physics manipulation (kinematic freezing/unfreezing).

### 3. 🔴 Demo 3: Scene Understanding (Spatial Awareness)
*   **Goal:** Interacting with the Physical Environment.
*   **Features:**
	*   Scanning the room (Mesh/Scene API).
	*   Placing virtual furniture (KenneyNL assets) that snaps to real-world floors or tables.
	*   Demonstrating how digital content persists in the physical space.

---

## 🛠️ Prerequisites & Installation

**⚠️ IMPORTANT:** To keep this repository lightweight, the required plugins are NOT included in the repo. You must download them manually.

### 1. Requirements
*   **Godot Engine 4.5** 
*   **Hardware:** Meta Quest 3 (or an Android XR compatible device).
*   **Connection:** USB-C cable for debugging or AirLink.
*   **Android Environment:** Android SDK/NDK installed (or Android Studio).

### 2. Mandatory Setup Steps
1.  Clone or download this repository.
2.  Open the project in Godot Engine.
3.  Open the **AssetLib** tab (top of the editor) and search for/install:
	*   **Godot XR Tools** (Essential XR utilities).
	*   **Godot OpenXR Vendors** (Critical for Meta/Pico/AndroidXR specific features).
4.  Go to `Project` -> `Project Settings` -> `Plugins` and **Enable** the **Godot XR Tools** plugin.
	*   *Note: The **Godot OpenXR Vendors** plugin is a GDExtension and is loaded automatically; it does not appear in the plugins list.*
5.  Go to `Project` -> `Reload Current Project`.
6.  Go to `Project` -> `Install Android Build Template...`.
7.  Check the Action Map: Go to `Project Settings` -> `XR` -> `OpenXR` and ensure the **Default Action Map** is set to `res://xr_config/openxr_action_map.tres`.

### 3. Exporting to Android / Quest
1.  Go to `Project` -> `Export`.
2.  An Android preset is already configured.
3.  Ensure **XR Mode** is set to **OpenXR**.
4.  Under the **OpenXR** section, select your target vendor (e.g., *Meta Quest*).
	*   *Note: As Android XR devices (Samsung) become available, simply switch the vendor target here without rewriting the code.*

---

## 🤖 The Future: Android XR & Galaxy XR

With the release of Godot 4.5, support for **Android XR** has been integrated into the OpenXR Vendors plugin.

This workshop demonstrates an architecture that is not "locked" to a single headset. The demo scenes use standard OpenXR nodes. This means that as Samsung releases the **Galaxy XR** and Google pushes the **Project Aura** ecosystem, this project can be deployed to those devices with minimal configuration changes, ensuring your XR skills remain relevant across the entire industry.

## 📄 Resources & Credits
*   **Presentation Slides:** [Download PDF](./docs/presentation.pdf)
*   **3D Assets:** [Kenney.nl](https://kenney.nl/) (CC0 License).
*   **Original Code:** Developed by Suggesto S.r.l.

---
*For more information on Godot XR, visit the [Official Documentation](https://docs.godotengine.org/en/stable/tutorials/xr/index.html).*
