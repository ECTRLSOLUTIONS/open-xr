# Demo 3 - Room Scan + Physics (stato attuale)

Questo file descrive la demo realmente in uso: `main_scene_mesh.tscn`.

## Scopo demo
- Usare `OpenXRFbSceneManager` per creare collider della stanza reale.
- Far interagire oggetti `RigidBody3D` con muri/pavimento reali.
- Mantenere interazione hand tracking (pinch grab) come nello step 2.

## File principali usati
- Scena: `demos/step_3_scene_mesch/main_scene_mesh.tscn`
- Script main: `demos/step_3_scene_mesch/main_scene_mesh.gd`
- Prefab collider stanza: `demos/step_3_scene_mesch/SpatialEntity.tscn`
- Script collider stanza: `demos/step_3_scene_mesch/SpatialEntity.gd`

Nota: la demo NON usa `RoomManager.tscn`.

## Flusso runtime
1. Avvio XR + passthrough.
2. Richiesta scansione stanza con `request_scene_capture()`.
3. A scansione completata: `create_scene_anchors()`.
4. Ogni anchor istanzia `SpatialEntity.tscn`, che crea la `CollisionShape3D` reale.
5. Gli oggetti in `Pickable` diventano dinamici e collidono con la stanza.

## Requisiti
- Meta Quest con stanza configurata (Room Setup completato).
- Estensioni OpenXR abilitate nel progetto:
  - Meta Scene API
  - Meta Anchor API
  - Meta Passthrough (consigliato)
- Permessi app accettati sul visore.

## Debug rapido
- Se gli oggetti attraversano tutto:
  - verifica che la scansione stanza sia disponibile nel sistema Quest;
  - verifica che `OpenXRFbSceneManager` crei anchor;
  - controlla che `SpatialEntity.gd` non stampi errori su `create_collision_shape()`.
- Se non vedi differenze tra step 2 e step 3:
  - probabilmente non sono stati creati gli anchor della stanza.

## Controlli in demo
- Pinch vicino a un oggetto per prenderlo.
- Rilascia il pinch per lasciare l'oggetto.
- Usa il pulsante 3D `Main Menu` per tornare al launcher.
