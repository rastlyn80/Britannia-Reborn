extends SceneTree
## Tail visibility with depth testing on the actual two human/rider rigs.
var batch_kind:="expansion35"
var output_folder:="human-frontier"
var viewport: SubViewport
var failures:=0
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func capture() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();var count:=0
	for y in image.get_height():
		for x in image.get_width():
			var colour:=image.get_pixel(x,y)
			if colour.r>.85 and colour.g<.1 and colour.b<.1:count+=1
	return count
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.1;viewport.add_child(camera)
	var black_shader:=Shader.new();black_shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(0.);}"
	var black:=ShaderMaterial.new();black.shader=black_shader
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D source_texture;uniform bool has_texture;void fragment(){if(COLOR.r<.5 || (has_texture && texture(source_texture,UV).a<.35)){discard;} ALBEDO=vec3(1.,0.,0.);}"
	var items: Dictionary={}
	var item_slots: Dictionary={}
	var selected:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--item="):selected=arg.substr(7)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/human-coverage-recipes.json"))
	for row: Dictionary in data.assets:
		if row.kind!=batch_kind:continue
		if not selected.is_empty() and row.key!=selected:continue
		if row.slot in ["head","torso","arms","outer","middle","outer_legs","cloak","waist","gorget"]:
			items[row.key]=[int(row.graphics[0]),0];item_slots[row.key]=row.slot
	for female in [false,true]:
		for mounted in [false,true]:
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.foot_contact.active=false
			var human: Node3D=actor.human_visual;human.set_process(false);actor.rotation.y=PI
			for hair in [0x203c,0x203d]:
				for key: String in items:
					var item: Array=items[key]
					var worn: Array=[{"id":0x1517,"layer":5},{"id":0x1539,"layer":4},{"id":hair,"layer":11,"hue":1147},{"id":int(item[0]),"hue":53}]
					if item_slots[key]!="cloak":worn.append({"id":0x1515,"layer":20})
					if mounted:worn.append({"id":0x3e9f,"layer":25})
					actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
					if mounted:actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.
					var garment: MeshInstance3D
					for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
						mesh.material_override=black
						if mesh.name.begins_with("Extra_"+key.trim_suffix("_cloak")):garment=mesh
						if not mesh.name.begins_with("Extra_hair_"):continue
						mesh.material_override=null
						var source:=mesh.mesh;var probe:=ArrayMesh.new()
						for surface in source.get_surface_count():
							var arrays:=source.surface_get_arrays(surface);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var colours:=PackedColorArray()
							var neck_y: float=human.skeleton.get_bone_global_rest(human.skeleton.find_bone("neck_01")).origin.y
							var head_y: float=human.skeleton.get_bone_global_rest(human.skeleton.find_bone("head")).origin.y
							for point in points:
								# Low draped hair and the rear ponytail shaft count as
								# tails. Short scalp wisps belong beneath the headwear.
								var tail: bool=point.y<neck_y+.025 or (point.z<-.105 and point.y<head_y+.095)
								colours.append(Color.RED if tail else Color.BLACK)
							arrays[Mesh.ARRAY_COLOR]=colours;probe.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
							var original:=source.surface_get_material(surface) as StandardMaterial3D;var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("source_texture",original.albedo_texture);material.set_shader_parameter("has_texture",original.albedo_texture!=null);probe.surface_set_material(surface,material)
							mesh.set_surface_override_material(surface,null)
						mesh.mesh=probe
					assert(garment!=null)
					garment.material_override=black
					# Full body stays in both images so absent clothing masks cannot
					# expose front/inside strands through a missing torso.
					human.model.find_children("Body*","MeshInstance3D",true,false)[0].visible=true
					for motion in ["Walk","Run"]:
						for phase in [.23,.62]:
							human.cancel_action();human.play("Rider_"+motion if mounted else motion,0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
							if mounted:actor.horse_visual.animator.play("walk" if motion=="Walk" else "canter",0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
							var centre:=Vector3(0,2.3 if mounted else 1.4,0);camera.position=centre+Vector3(0,0,5);camera.look_at(centre)
							garment.visible=false;var reference:=await capture();garment.visible=true;var clothed:=await capture()
							var fraction:=float(clothed)/maxi(1,reference);var passed:=reference>=8 and fraction>=.98
							samples.append({"female":female,"hair":hair,"item":key,"mounted":mounted,"motion":motion,"phase":phase,"reference":reference,"clothed":clothed,"visible_fraction":fraction,"passed":passed})
							if not passed:failures+=1;push_error("Tail occluded "+str(samples[-1]))
			actor.free()
	var file:=FileAccess.open("res://../outputs/"+output_folder+"/hair-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"samples":samples,"failures":failures,"scope":"Both bodies, long hair and ponytail, every new headwear, torso and arm family with a cape, walking/running and actual horse rider poses at two independent phases. Rear depth-tested tails: draped vertices below neck+25 mm or posterior shaft behind z=-105 mm below head+95 mm in the fixed bind. >=98% retained compared with only the new garment hidden, complete body retained in both images. Scalp wisps intentionally covered by headwear; finite views, no strand simulation."},"\t"));file.close()
	print("FRONTIER HAIR: ",samples.size()," views, ",failures," failures");quit(1 if failures else 0)
