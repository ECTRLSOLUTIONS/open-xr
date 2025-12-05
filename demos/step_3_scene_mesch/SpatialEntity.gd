extends StaticBody3D

# Versione semplificata e allineata a SpatialEntity_working.gd
# Rimosso tutto il codice di debug e le variabili statiche per evitare crash.

func setup_scene(entity: OpenXRFbSpatialEntity):
	# print("SpatialEntity: Setup scene per ", entity.uuid)
	
	# Imposta i layer di collisione
	collision_layer = 1
	collision_mask = 1
	
	# Crea la forma di collisione
	var collider = entity.create_collision_shape()
	if collider:
		# Nascondi il collider (invisibile, solo fisica)
		collider.visible = false
		
		# Abilita collisione backface per evitare problemi con oggetti che escono dal mondo
		if collider.shape is ConcavePolygonShape3D:
			collider.shape.backface_collision = true
			
		add_child(collider)
	else:
		push_error("SpatialEntity: Impossibile creare il collider")
