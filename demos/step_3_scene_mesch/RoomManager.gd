class_name RoomManager
extends Node3D

signal room_loaded
signal scan_started
signal scan_failed

# Questo nodo deve essere figlio nella scena, o assegnato via inspector
@export var scene_manager: OpenXRFbSceneManager
@export var show_debug_walls: bool = true

var _is_scanning = false

func _ready():
	if not scene_manager:
		push_error("RoomManager: OpenXRFbSceneManager non assegnato!")
		return
	
	# Imposta la variabile statica per le entità che verranno create
	# Nota: Assumiamo che la classe SpatialEntity sia caricata
	# var spatial_script = load("res://demos/step_3_scene_mesch/SpatialEntity.gd")
	# if spatial_script:
	# 	spatial_script.show_debug_mesh = show_debug_walls
		
	# Collega i segnali del plugin Meta
	scene_manager.openxr_fb_scene_data_missing.connect(_on_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_on_capture_completed)
	
	# DEBUG: Vediamo se crea qualcosa
	if scene_manager.has_signal("openxr_fb_scene_anchor_created"):
		scene_manager.connect("openxr_fb_scene_anchor_created", _on_anchor_created)

func _on_anchor_created(anchor, _event=null):
	if "uuid" in anchor:
		print("RoomManager: ANCHOR CREATO! ID: ", anchor.uuid)
	else:
		print("RoomManager: ANCHOR CREATO! (Nessun UUID disponibile)")

# Funzione pubblica da chiamare per avviare tutto
func initialize_room():
	# Attendiamo che la sessione XR sia stabile
	await get_tree().create_timer(2.0).timeout
	
	print("RoomManager: Controllo dati stanza...")
	
	# FIX: Resettiamo lo stato del manager per evitare ERR_ALREADY_EXISTS
	# Se ci sono vecchi anchor o stati sporchi, li rimuoviamo prima di ricreare.
	print("RoomManager: Reset stato manager...")
	if scene_manager.has_method("destroy_scene_anchors"):
		scene_manager.destroy_scene_anchors()
	elif scene_manager.has_method("remove_scene_anchors"):
		scene_manager.remove_scene_anchors()
	
	# Attendiamo un attimo che la pulizia avvenga
	await get_tree().process_frame
	
	# Prova a caricare gli anchor esistenti
	var result = scene_manager.create_scene_anchors()
	print("RoomManager: create_scene_anchors result: ", result)
	
	if result == ERR_ALREADY_EXISTS:
		# Se ancora dice che esistono, proviamo comunque a procedere
		print("RoomManager: Dati già presenti in memoria (persistenti).")
		emit_signal("room_loaded")
		return
	
	# FIX: create_scene_anchors non avvisa se carica dati esistenti.
	# Attendiamo un secondo: se non scatta "data_missing", assumiamo che i dati ci siano.
	await get_tree().create_timer(1.0).timeout
	
	if not _is_scanning:
		print("RoomManager: Dati esistenti caricati (presumibilmente).")
		emit_signal("room_loaded")
		
		# DEBUG: Se non abbiamo visto nessun anchor creato, proviamo a forzare una scansione
		# Questo è utile se i dati sono "presenti" ma vuoti o corrotti
		# NOTA: Questo potrebbe causare un loop se non gestito, ma per ora serve per debug
		# print("RoomManager: DEBUG - Forzo richiesta scansione per sicurezza...")
		# request_new_scan()

func request_new_scan():
	print("RoomManager: Richiesta nuova scansione...")
	emit_signal("scan_started")
	scene_manager.request_scene_capture()

func _on_data_missing():
	_is_scanning = true
	print("RoomManager: Dati mancanti, avvio scansione automatica.")
	request_new_scan()

func _on_capture_completed(success: bool):
	_is_scanning = false
	if success:
		print("RoomManager: Scansione completata. Creazione collisioni...")
		scene_manager.create_scene_anchors()
		# Attendiamo un attimo che il sistema popoli la scena
		await get_tree().create_timer(0.5).timeout
		emit_signal("room_loaded")
	else:
		push_error("RoomManager: Scansione fallita.")
		emit_signal("scan_failed")
