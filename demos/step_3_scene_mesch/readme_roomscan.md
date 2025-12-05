# Room Scanning & Physics Integration - Step 3

Questo documento spiega come configurare il progetto per utilizzare il "Scene Understanding" del Meta Quest, permettendo agli oggetti virtuali di collidere con muri e mobili reali.

## Prerequisiti Fondamentali

1.  **Plugin**: Assicurati che il plugin `Godot OpenXR Vendors` sia installato e attivo (Asset Library).
2.  **Impostazioni Progetto**:
    *   Vai su `Project` -> `Project Settings` -> `XR` -> `OpenXR`.
    *   Sotto `Extensions` (o Vendors), abilita:
        *   `Meta Scene API` (Fondamentale)
        *   `Meta Anchor API`
        *   `Meta Passthrough`

## Setup della Scena

Dovrai creare due scene separate e poi assemblarle.

### 1. Creazione del Prefab "SpatialEntity"
Questo è l'oggetto che verrà generato per ogni muro/tavolo rilevato.

1.  Crea una **Nuova Scena**.
2.  Nodo Radice: `StaticBody3D`.
3.  Rinomina la radice in `SpatialEntity`.
4.  Attacca lo script `SpatialEntity.gd` (fornito in questa cartella).
5.  Salva la scena come `SpatialEntity.tscn` dentro `demos/step_3_scene_mesch/`.
    *   *Nota*: Non aggiungere MeshInstance o CollisionShape manualmente. Verranno create via codice.

### 2. Creazione del Prefab "RoomManager"
Questo gestisce la logica di scansione.

1.  Crea una **Nuova Scena**.
2.  Nodo Radice: `Node3D`. Rinomina in `RoomManager`.
3.  Attacca lo script `RoomManager.gd`.
4.  Aggiungi un nodo figlio: `OpenXRFbSceneManager` (dal plugin Vendors).
5.  Aggiungi un nodo figlio: `OpenXRFbSpatialAnchorManager` (dal plugin Vendors).
6.  **Configurazione Inspector**:
    *   Seleziona il nodo `RoomManager` (radice).
    *   Assegna il nodo figlio `OpenXRFbSceneManager` alla variabile `Scene Manager` nello script.
    *   Seleziona il nodo figlio `OpenXRFbSceneManager`.
    *   Nella proprietà `Default Scene`, carica il file `SpatialEntity.tscn` creato al punto 1.
7.  Salva la scena come `RoomManager.tscn`.

### 3. Assemblaggio Scena Principale (Main)

1.  Apri (o crea) la tua scena principale (es. duplicando quella dello step 2).
2.  Attacca lo script `main_scene_mesh.gd` alla radice `XROrigin3D`.
3.  Trascina dentro la scena l'istanza di `RoomManager.tscn`.
4.  **Configurazione Inspector Main**:
    *   Assicurati che la variabile `Room Manager` nello script del Main punti al nodo `RoomManager` appena aggiunto.
    *   Assicurati che `Pickables Container` punti al nodo che contiene i tuoi cubi/sfere.

## Come rendere gli oggetti "Pickable" e Fisici

Affinché i tuoi oggetti interagiscano con la stanza reale:

1.  Gli oggetti devono essere `RigidBody3D`.
2.  Devono avere una `CollisionShape3D`.
3.  Nel `main_scene_mesh.gd`, la funzione `_setup_pickables` si assicura che:
    *   `gravity_scale` sia 1.0 (così cadono).
    *   `freeze` sia false (così si muovono).
4.  Quando la stanza viene caricata, vengono creati `StaticBody3D` invisibili. I tuoi `RigidBody3D` ci sbatteranno contro naturalmente grazie al motore fisico di Godot.

## Risoluzione Problemi Comuni

*   **Non succede nulla all'avvio**: Assicurati di aver fatto il Room Setup nel sistema operativo del Quest (Impostazioni -> Spazio fisico -> Configurazione spazio).
*   **Gli oggetti attraversano il pavimento**: Verifica che il pavimento sia stato scansionato correttamente e che `SpatialEntity.gd` stia effettivamente creando il collider (controlla i print nel debugger remoto).
*   **Errore "Data Missing"**: È normale la prima volta. Il codice dovrebbe lanciare<!-- filepath: /Users/dariocavada/WorkingDirectory/github/open-xr/demos/step_3_scene_mesch/readme_roomscan.md -->
# Room Scanning & Physics Integration - Step 3

Questo documento spiega come configurare il progetto per utilizzare il "Scene Understanding" del Meta Quest, permettendo agli oggetti virtuali di collidere con muri e mobili reali.

## Prerequisiti Fondamentali

1.  **Plugin**: Assicurati che il plugin `Godot OpenXR Vendors` sia installato e attivo (Asset Library).
2.  **Impostazioni Progetto**:
    *   Vai su `Project` -> `Project Settings` -> `XR` -> `OpenXR`.
    *   Sotto `Extensions` (o Vendors), abilita:
        *   `Meta Scene API` (Fondamentale)
        *   `Meta Anchor API`
        *   `Meta Passthrough`

## Setup della Scena

Dovrai creare due scene separate e poi assemblarle.

### 1. Creazione del Prefab "SpatialEntity"
Questo è l'oggetto che verrà generato per ogni muro/tavolo rilevato.

1.  Crea una **Nuova Scena**.
2.  Nodo Radice: `StaticBody3D`.
3.  Rinomina la radice in `SpatialEntity`.
4.  Attacca lo script `SpatialEntity.gd` (fornito in questa cartella).
5.  Salva la scena come `SpatialEntity.tscn` dentro `demos/step_3_scene_mesch/`.
    *   *Nota*: Non aggiungere MeshInstance o CollisionShape manualmente. Verranno create via codice.

### 2. Creazione del Prefab "RoomManager"
Questo gestisce la logica di scansione.

1.  Crea una **Nuova Scena**.
2.  Nodo Radice: `Node3D`. Rinomina in `RoomManager`.
3.  Attacca lo script `RoomManager.gd`.
4.  Aggiungi un nodo figlio: `OpenXRFbSceneManager` (dal plugin Vendors).
5.  Aggiungi un nodo figlio: `OpenXRFbSpatialAnchorManager` (dal plugin Vendors).
6.  **Configurazione Inspector**:
    *   Seleziona il nodo `RoomManager` (radice).
    *   Assegna il nodo figlio `OpenXRFbSceneManager` alla variabile `Scene Manager` nello script.
    *   Seleziona il nodo figlio `OpenXRFbSceneManager`.
    *   Nella proprietà `Default Scene`, carica il file `SpatialEntity.tscn` creato al punto 1.
7.  Salva la scena come `RoomManager.tscn`.

### 3. Assemblaggio Scena Principale (Main)

1.  Apri (o crea) la tua scena principale (es. duplicando quella dello step 2).
2.  Attacca lo script `main_scene_mesh.gd` alla radice `XROrigin3D`.
3.  Trascina dentro la scena l'istanza di `RoomManager.tscn`.
4.  **Configurazione Inspector Main**:
    *   Assicurati che la variabile `Room Manager` nello script del Main punti al nodo `RoomManager` appena aggiunto.
    *   Assicurati che `Pickables Container` punti al nodo che contiene i tuoi cubi/sfere.

## Come rendere gli oggetti "Pickable" e Fisici

Affinché i tuoi oggetti interagiscano con la stanza reale:

1.  Gli oggetti devono essere `RigidBody3D`.
2.  Devono avere una `CollisionShape3D`.
3.  Nel `main_scene_mesh.gd`, la funzione `_setup_pickables` si assicura che:
    *   `gravity_scale` sia 1.0 (così cadono).
    *   `freeze` sia false (così si muovono).
4.  Quando la stanza viene caricata, vengono creati `StaticBody3D` invisibili. I tuoi `RigidBody3D` ci sbatteranno contro naturalmente grazie al motore fisico di Godot.

## Risoluzione Problemi Comuni

*   **Non succede nulla all'avvio**: Assicurati di aver fatto il Room Setup nel sistema operativo del Quest (Impostazioni -> Spazio fisico -> Configurazione spazio).
*   **Gli oggetti attraversano il pavimento**: Verifica che il pavimento sia stato scansionato correttamente e che `SpatialEntity.gd` stia effettivamente creando il collider (controlla i print nel debugger remoto).
*   **Errore "Data Missing"**: È normale la prima volta. Il codice dovrebbe lanciare