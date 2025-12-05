@tool
extends EditorPlugin

func _enter_tree():
    # Aggiunge una voce al menu contestuale del FileSystem
    add_tool_menu_item("Crea Pickable da GLB", _convert_selected)

func _exit_tree():
    remove_tool_menu_item("Crea Pickable da GLB")

func _convert_selected():
    var editor_interface = get_editor_interface()
    var selected_paths = editor_interface.get_selected_paths()
    
    if selected_paths.is_empty():
        print("Nessun file selezionato.")
        return

    var path = selected_paths[0]
    if not path.ends_with(".glb") and not path.ends_with(".gltf"):
        print("Per favore seleziona un file .glb o .gltf")
        return
        
    _create_pickable_scene(path)

func _create_pickable_scene(glb_path: String):
    # 1. Carica il GLB
    var glb_scene = load(glb_path)
    if not glb_scene:
        return

    # 2. Crea la radice RigidBody3D
    var root = RigidBody3D.new()
    root.name = glb_path.get_file().get_basename()
    
    # Imposta i parametri che usi nel tuo script main_interact
    root.freeze = true
    root.freeze_mode = RigidBody3D.FreezeMode.FREEZE_MODE_KINEMATIC
    # root.collision_layer = 1 # Imposta se necessario
    
    # 3. Istanzia il GLB come figlio
    var mesh_instance = glb_scene.instantiate()
    root.add_child(mesh_instance)
    mesh_instance.owner = root # Necessario per salvarlo nella scena
    
    # 4. Genera una collisione approssimativa (Box)
    # Nota: Calcolare l'AABB esatto senza aggiungere alla scena è tricky, 
    # qui creiamo un box generico di 10cm che l'utente poi aggiusterà.
    var col_shape = CollisionShape3D.new()
    col_shape.name = "CollisionShape3D"
    var box = BoxShape3D.new()
    box.size = Vector3(0.1, 0.1, 0.1) # Default 10cm
    col_shape.shape = box
    
    root.add_child(col_shape)
    col_shape.owner = root
    
    # 5. Salva la nuova scena
    var save_path = glb_path.get_base_dir() + "/" + root.name + "_pickable.tscn"
    var packed_scene = PackedScene.new()
    packed_scene.pack(root)
    
    var err = ResourceSaver.save(packed_scene, save_path)
    if err == OK:
        print("Pickable creato con successo: " + save_path)
        get_editor_interface().get_resource_filesystem().scan() # Aggiorna il filesystem
    else:
        print("Errore nel salvataggio della scena.")
    
    # Pulizia memoria immediata (non strettamente necessaria per script brevi ma buona prassi)
    root.free()