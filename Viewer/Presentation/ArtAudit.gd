extends SceneTree

func _initialize() -> void:
	for path in ["Village/Wall_Plaster_Straight.gltf","Village/Floor_WoodDark.gltf","Village/Roof_Wooden_2x1.gltf","Village/Roof_Modular_RoundTiles.gltf","Nature/CommonTree_1.gltf","Nature/Pine_1.gltf","Nature/TwistedTree_1.gltf","Nature/Bush_Common.gltf","Character/Superhero_Male_FullBody.gltf","Animation/UAL1_Standard.glb"]:
		var scene: Node = load("res://Art/Quaternius/"+path).instantiate()
		root.add_child(scene)
		print("ART ",path," root ",scene.get_class())
		for node in scene.find_children("*","MeshInstance3D",true,false): print("MESH ",scene.get_path_to(node)," ",node.get_aabb()," transform ",node.transform)
		for node in [scene]+scene.find_children("*","MeshInstance3D",true,false):
			if not node is MeshInstance3D: continue
			for surface in node.mesh.get_surface_count():
				var mat: StandardMaterial3D = node.get_active_material(surface)
				print("MATERIAL override=",node.material_override," ",mat.resource_name," vertex_color=",mat.vertex_color_use_as_albedo," tint=",mat.albedo_color," texture=",mat.albedo_texture)
		for player in scene.find_children("*","AnimationPlayer",true,false):
			print("ANIM ROOT ",player.root_node," ",scene.get_path_to(player)," ",player.get_animation_list())
			var animation: Animation = player.get_animation("Walk") if player.has_animation("Walk") else null
			if animation:
				for i in mini(3,animation.get_track_count()): print("TRACK ",animation.track_get_path(i))
		scene.free()
	quit()
