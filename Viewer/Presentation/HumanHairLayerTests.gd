extends SceneTree
## GPU depth test: compare tail pixels with garments present/hidden on one pose.
## Scalp pixels are excluded because headwear deliberately covers the scalp.
var viewport: SubViewport
var rows: Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func capture_tail() -> int:
	await process_frame
	RenderingServer.force_draw(false)
	var picture:=viewport.get_texture().get_image()
	var count:=0
	# Camera covers world heights 0.8..2.0 m. Count only below the neck.
	for y in range(214,512):
		for x in 512:
			var colour:=picture.get_pixel(x,y)
			if colour.r>.8 and colour.g<.1 and colour.b<.1:count+=1
	return count
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.2
	viewport.add_child(camera);camera.position=Vector3(0,1.4,4);camera.look_at(Vector3(0,1.4,0))
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D source_texture; uniform bool has_texture; void fragment(){if(has_texture && texture(source_texture,UV).a<.35){discard;} ALBEDO=vec3(1.,0.,0.);}"
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanVisual.gd").new();actor.female=female;viewport.add_child(actor);actor.rotation.y=PI
		for hair in [0x203c,0x203d]:
			var outfits: Array=[["robe",[0x1f03]],["cloak",[0x1515,0x1517,0x1f7b]],["hood",[0x2687]],["hat",[0x1715,0x1517]],["helmet",[0x1412,0x1fa1]],["cloak-hood",[0x1515,0x2687]],["cloak-helmet",[0x1515,0x1412,0x1fa1]]]
			if ResourceLoader.exists(actor.folder+"/coverage/plate_torso.glb"):
				outfits.append(["plate",[0x1415,0x1410,0x1413]])
				outfits.append(["cloak-plate",[0x1515,0x1415,0x1410]])
				outfits.append(["wizard-plate",[0x1718,0x1415]])
			for outfit in outfits:
				var worn: Array=[{"id":hair,"layer":11,"hue":1118}]
				for id in outfit[1]:worn.append({"id":id})
				actor.set_equipment(worn)
				# Keep the complete body in both renders. Clothing masks remove
				# hidden torso triangles; using those masks in the unclothed
				# reference would count inside/front hair through the absent back.
				actor.model.find_children("Body*","MeshInstance3D",true,false)[0].visible=true
				var garments: Array=[]
				for mesh: MeshInstance3D in actor.parts:
					if mesh.name.begins_with("Extra_hair_"):
						for surface in mesh.mesh.get_surface_count():
							var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
							var material:=ShaderMaterial.new();material.shader=shader
							material.set_shader_parameter("source_texture",source.albedo_texture)
							material.set_shader_parameter("has_texture",source.albedo_texture!=null)
							mesh.set_surface_override_material(surface,material)
					elif not mesh.name.begins_with("Body"):garments.append(mesh)
				var clips: Array=["Idle","Walk","Cast"]
				if actor.animator.has_animation("Bow_Attack"):clips.append_array(["Bow_Attack","Salute"])
				for clip in clips:
					for phase in [.23,.62]:
						actor.current_clip="";actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
						for mesh in garments:mesh.visible=true
						var clothed:=await capture_tail()
						for mesh in garments:mesh.visible=false
						var reference:=await capture_tail()
						var ratio:=float(clothed)/maxi(1,reference)
						var passed:=reference>=8 and ratio>=.98
						rows.append({"female":female,"hair_id":hair,"outfit":outfit[0],"clip":clip,"phase":phase,"tail_pixels":clothed,"reference_pixels":reference,"visible_fraction":ratio,"passed":passed})
						if not passed:failures+=1;push_error("Hair tail occluded: "+str(rows[-1]))
				for mesh in garments:mesh.visible=true
		actor.queue_free();await process_frame
	var file:=FileAccess.open("res://../outputs/human-wardrobe-2/hair-visibility.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":rows,"failures":failures,"scope":"Rear camera tail pixels with complete-body depth retained, two fixed bodies/styles, the installed clothing/armour combinations, Idle/Walk/Cast plus available ranged/salute actions at two phases. At least 98% of reference tail pixels retained. Scalp deliberately excluded. Finite view/pose check, not universal collision proof."},"\t"));file.close()
	print("HUMAN HAIR DEPTH: %d poses / %d failures" % [rows.size(),failures]);quit(0 if failures==0 else 1)
