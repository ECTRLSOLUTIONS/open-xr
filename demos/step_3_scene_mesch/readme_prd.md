# Room Scanning & Physics Integration PRD

## 1. Analisi del Progetto Esistente
Il progetto `demo_2` implementa il "Room Scanning" (o Scene Understanding) utilizzando le API specifiche di Meta Quest (Facebook) tramite il plugin `godotopenxrvendors`.

### Architettura Attuale
Il flusso logico è gestito principalmente in `main.gd` e nella scena `xr_origin_3d.tscn`.

1.  **Nodi Chiave (`xr_origin_3d.tscn`)**:
    *   `SceneManager` (Tipo: `OpenXRFbSceneManager`): È il nodo che gestisce la comunicazione con il sistema operativo del visore per ottenere i dati della stanza.
    *   `OpenXRFbSpatialAnchorManager`: Gestisce gli "ancoraggi" spaziali (punti fissi nello spazio reale).
    *   `SpatialEntity.tscn`: È il "prefab" che viene istanziato per ogni oggetto rilevato (muro, pavimento, tavolo).

2.  **Il Flusso (`main.gd`)**:
    *   **Inizializzazione**: All'avvio, `main.gd` chiama `_rescan_room()`.
    *   **Richiesta Scansione**: Chiama `sm.request_scene_capture()`. Questo apre l'interfaccia di sistema del Quest se la stanza non è ancora stata scansionata.
    *   **Ricezione Dati**: Quando la scansione è completa (segnale `openxr_fb_scene_capture_completed`), chiama `sm.create_scene_anchors()`.
    *   **Istanziazione**: Il nodo `OpenXRFbSceneManager` itera automaticamente su tutti gli elementi rilevati e istanzia `SpatialEntity.tscn` per ognuno.

3.  **La Fisica (`SpatialEntity.gd`)**:
    *   Questo script è attaccato a un `StaticBody3D`.
    *   Quando viene istanziato, il manager chiama `setup_scene(entity)`.
    *   Lo script chiama `entity.create_collision_shape()` che genera automaticamente un `ConcavePolygonShape3D` (mesh collider) basato sulla geometria reale.
    *   Risultato: Il mondo virtuale ha collisioni invisibili che corrispondono esattamente ai mobili e ai muri reali.

---

## 2. Come Implementare in un Nuovo Progetto (Clean Architecture)

Per evitare di "sporcare" il `main.gd` con logica di gestione della stanza, la soluzione migliore è creare un componente autonomo (es. `RoomManager`) che puoi trascinare in qualsiasi scena.

### Prerequisiti
1.  Installare **Godot OpenXR Vendors** plugin (Asset Library).
2.  In `Project Settings` -> `XR` -> `OpenXR` -> `Extensions`, abilitare:
    *   `Meta Scene API`
    *   `Meta Anchor API`
    *   `Meta Passthrough` (opzionale, ma consigliato per AR)

### Passo A: Creare il Prefab "SpatialEntity"
Questo sarà l'oggetto "muro/tavolo".
1.  Crea una Nuova Scena -> Radice: `StaticBody3D`.
2.  Salva come `SpatialEntity.tscn`.
3.  Attacca uno script `SpatialEntity.gd`:

```gdscript
extends StaticBody3D

# Chiamato automaticamente da OpenXRFbSceneManager
func setup_scene(entity: OpenXRFbSpatialEntity):
	# Imposta i layer di collisione (es. layer 1 per ambiente)
	collision_layer = 1
	collision_mask = 1
	
	# Crea la forma di collisione dalla geometria reale
	var collider = entity.create_collision_shape()
	if collider:
		add_child(collider)
		# Opzionale: Se vuoi vedere il wireframe per debug, rendilo visibile
		# collider.visible = false 
```

### Passo B: Creare il "RoomManager" (Componente Separato)
Invece di scrivere codice nel Main, creiamo una scena dedicata.

1.  Crea una Nuova Scena -> Radice: `Node3D`. Chiamala `RoomManager`.
2.  Aggiungi un nodo figlio: `OpenXRFbSceneManager`.
3.  Aggiungi un nodo figlio: `OpenXRFbSpatialAnchorManager`.
4.  Seleziona `OpenXRFbSceneManager` e nell'Inspector, imposta `Default Scene` caricando il tuo `SpatialEntity.tscn`.
5.  Attacca questo script alla radice `RoomManager`:

```gdscript
class_name RoomManager
extends Node3D

signal room_loaded
signal scan_started
signal scan_failed

@onready var scene_manager: OpenXRFbSceneManager = $OpenXRFbSceneManager

var _anchors_created := false

func _ready():
	# Collega i segnali del plugin Meta
	scene_manager.openxr_fb_scene_data_missing.connect(_on_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_on_capture_completed)

# Funzione pubblica da chiamare per avviare tutto
func initialize_room():
	print("RoomManager: Controllo dati stanza...")
	# Prova a caricare gli anchor esistenti
	scene_manager.create_scene_anchors()
	
	# Nota: create_scene_anchors è asincrono nel backend, ma non ha un segnale diretto di "finito"
	# se i dati ci sono. Se mancano, scatterà openxr_fb_scene_data_missing.
	
	# Un piccolo hack per verificare se abbiamo caricato qualcosa è attendere un frame
	# o controllare se scene_manager ha figli dopo un po', ma per ora ci fidiamo del flusso standard.
	
	# Se vogliamo forzare una scansione fresca:
	# request_new_scan()

func request_new_scan():
	print("RoomManager: Richiesta nuova scansione...")
	emit_signal("scan_started")
	scene_manager.request_scene_capture()

func _on_data_missing():
	print("RoomManager: Dati mancanti, avvio scansione automatica.")
	request_new_scan()

func _on_capture_completed(success: bool):
	if success:
		print("RoomManager: Scansione completata. Creazione collisioni...")
		scene_manager.create_scene_anchors()
		# Attendiamo che gli anchor siano processati
		await _wait_for_anchors()
		emit_signal("room_loaded")
	else:
		push_error("RoomManager: Scansione fallita.")
		emit_signal("scan_failed")

func _wait_for_anchors():
	# Loop semplice per attendere che il sistema popoli la scena
	# OpenXRFbSceneManager non ha un segnale "AllAnchorsCreated", quindi spesso si usa un timer o si controlla lo stato
	# In questo esempio semplice, aspettiamo un attimo.
	await get_tree().create_timer(0.5).timeout
	return
```

### Passo C: Usarlo nel Main
Ora il tuo `main.gd` diventa pulitissimo.

1.  Istanzia la scena `RoomManager.tscn` dentro la tua scena principale.
2.  Nel `main.gd`:

```gdscript
extends Node3D

@onready var room_manager = $RoomManager

func _ready():
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		# ... setup passthrough ...
		
		# Avvia la gestione della stanza
		room_manager.room_loaded.connect(_on_room_ready)
		room_manager.initialize_room()

func _on_room_ready():
	print("Tutto pronto! Posso spawnare oggetti che interagiscono con i muri.")
	# Qui puoi attivare la logica del gioco, spawnare nemici, ecc.
```

## 3. Vantaggi di questo approccio
1.  **Disaccoppiamento**: La logica di scansione è isolata. Se cambi plugin o logica, non rompi il gioco.
2.  **Riutilizzabilità**: Puoi copiare `RoomManager.tscn` e `SpatialEntity.tscn` in qualsiasi altro progetto VR e funzionerà subito.
3.  **Pulizia**: Il `main.gd` si occupa solo del flusso di gioco, non della gestione hardware della stanza.
