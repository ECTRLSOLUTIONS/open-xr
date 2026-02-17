# PRD - Demo 3 Scene Mesh + Physics

## Obiettivo
Dimostrare una demo MR in cui oggetti virtuali dinamici interagiscono con la geometria reale della stanza tramite Scene Understanding.

## Ambito
- Scena target: `demos/step_3_scene_mesch/main_scene_mesh.tscn`
- Runtime target: Meta Quest con OpenXR Vendors
- Input: hand tracking (pinch)

## Requisiti funzionali
1. All'avvio, la demo deve inizializzare OpenXR e passthrough.
2. La demo deve richiedere/scansionare la stanza e creare scene anchors.
3. Ogni anchor deve generare collider fisici usando `SpatialEntity.tscn`.
4. Gli oggetti in `Pickable` devono essere afferrabili e rilasciabili.
5. Gli oggetti rilasciati devono collidere con pavimento/muri reali.
6. Deve essere possibile tornare al launcher con bottone 3D `Main Menu`.

## Architettura attuale
- `main_scene_mesh.gd` gestisce:
  - bootstrap XR/passthrough;
  - richiesta scan stanza;
  - creazione anchor;
  - setup fisica oggetti pickable;
  - logica pinch grab/release.
- `OpenXRFbSceneManager` usa `default_scene = SpatialEntity.tscn`.
- `SpatialEntity.gd` crea collision shape runtime da entita reali.

## Criteri di accettazione
- CA1: dopo la scansione, almeno un collider ambiente viene creato senza errori.
- CA2: un oggetto rilasciato cade e si ferma su una superficie reale.
- CA3: un oggetto lanciato rimbalza/impatta contro almeno una superficie reale.
- CA4: il ritorno al launcher funziona dalla demo.

## Limiti noti
- La qualita fisica dipende dalla qualita della scansione stanza lato sistema operativo.
- Se il runtime non concede dati scena/permessi, i collider non vengono creati.
- La demo usa API Meta scene understanding, quindi non e completamente vendor-neutral.

## Fuori ambito (per questo step)
- Persistenza cross-session di anchor custom.
- UI avanzata in-world per diagnostica scene mesh.
- Authoring semantico avanzato (classificazione tavolo, sedia, ecc.).
