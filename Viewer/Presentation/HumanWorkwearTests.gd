extends SceneTree
## Real rendered poses, native layering/dyes and final modifier pose evidence.
const ITEMS:={"body_sash":[0x1541,17]}
var viewport: SubViewport
var camera: Camera3D
var checks:=0
var failures: Array=[]
var samples: Array=[]
var poses: Array=[]
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func probe(original: StandardMaterial3D=null,highlight: bool=true) -> ShaderMaterial:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,"+("cull_back" if highlight and original!=null else "cull_disabled")+";uniform sampler2D source;uniform bool textured=false;void fragment(){if(textured && texture(source,UV).a<.35){discard;}ALBEDO="+("vec3(0.,1.,0.)" if original!=null and highlight else "vec3(0.)")+";}"
	var mat:=ShaderMaterial.new();mat.shader=shader
	if original!=null:mat.set_shader_parameter("source",original.albedo_texture);mat.set_shader_parameter("textured",original.albedo_texture!=null)
	return mat
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var im:=viewport.get_texture().get_image();im.convert(Image.FORMAT_RGBA8);return im
func green(data: PackedByteArray,i: int) -> bool:return data[i]<25 and data[i+1]>230 and data[i+2]<25
func run() -> void:
	for key: String in ITEMS:
		for id in [int(ITEMS[key][0]),int(ITEMS[key][0])+1]:
			var worn: Array=[{"id":0x1517,"layer":5},{"id":0x1fa1,"layer":17},{"id":id,"layer":int(ITEMS[key][1]),"hue":53}]
			var resolved:=Wardrobe.resolve(worn)
			check(resolved.unsupported.is_empty(),"Both native orientations "+key)
			check(resolved.pieces.has("middle"),"Native wearable slot "+key)
			check(not (int(resolved.bits)&1) and resolved.pieces.has("shirt"),"Middle layer replaces tunic, retains shirt "+key)
			worn.append({"id":0x1f03,"layer":22});resolved=Wardrobe.resolve(worn)
			check(not resolved.pieces.has("middle"),"Outer robe obscures workwear "+key)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/human-workwear"))
	viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.2;viewport.add_child(camera)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;viewport.add_child(environment)
	var black:=probe()
	var reference_shader:=Shader.new();reference_shader.code="shader_type spatial;render_mode unshaded,cull_disabled;varying float occluder;void vertex(){occluder=COLOR.r;}void fragment(){if(FRONT_FACING && occluder<.001){discard;}ALBEDO=vec3(0.);}"
	var reference_body:=ShaderMaterial.new();reference_body.shader=reference_shader

	for female in [false,true]:
		for mounted in [false,true]:
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.foot_contact.active=false
			var human: Node3D=actor.human_visual;human.set_process(false)
			var posed:={}
			var watcher:=func():posed.merge(bones(human.skeleton),true)
			if not mounted:human.held_accessories.modification_processed.connect(watcher)
			for key: String in ITEMS:
				for armoured in [false,true]:
					var worn: Array=[{"id":0x1539,"layer":4},{"id":0x170b,"layer":3},{"id":0x203c,"layer":11,"hue":1147},{"id":int(ITEMS[key][0]),"layer":int(ITEMS[key][1]),"hue":53}]
					worn.append({"id":0x1415,"layer":13} if armoured else {"id":0x1517,"layer":5})
					if mounted:worn.append({"id":0x3e9f,"layer":25})
					actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
					if mounted:
						actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.
						if not actor.rider_contact.modification_processed.is_connected(watcher):actor.rider_contact.modification_processed.connect(watcher)
					check(human.missing_art.is_empty() and human.unsupported_items.is_empty(),"Native identity/art "+key)
					var target: MeshInstance3D
					for part: MeshInstance3D in human.parts:
						if part.name.begins_with("Extra_"+key):target=part
					check(target!=null,"Distinct workwear "+key)
					if target==null:continue
					check(target.name.contains("_armour")==armoured,"Selected envelope "+key)
					for raw_hue in [0,53,0x8035]:
						human._shade(target,raw_hue)
						for surface in target.mesh.get_surface_count():
							var original:=target.mesh.surface_get_material(surface) as StandardMaterial3D
							var active:=target.get_active_material(surface)
							if raw_hue==0:check(active==original,"Default linen retains original mask")
							else:
								var hue_material:=active as ShaderMaterial
								check(hue_material!=null and bool(hue_material.get_shader_parameter("cutout")) and is_equal_approx(float(hue_material.get_shader_parameter("cutout_threshold")),original.alpha_scissor_threshold),"Full/partial hue preserves alpha threshold")
								check(bool(hue_material.get_shader_parameter("partial_hue"))==((raw_hue&0x8000)!=0) and is_equal_approx(float(hue_material.get_shader_parameter("roughness")),original.roughness) and is_zero_approx(float(hue_material.get_shader_parameter("metalness"))),"Native partial flag and woven material")
						human._shade(target,53)
					for surface in target.mesh.get_surface_count():
						var dyed:=target.get_active_material(surface) as ShaderMaterial
						check(dyed!=null and bool(dyed.get_shader_parameter("use_hue")) and bool(dyed.get_shader_parameter("cutout")),"Native dye preserves stencil "+key)
						target.set_surface_override_material(surface,probe(target.mesh.surface_get_material(surface)))
					check(human.native_cosmetics.hair_id==0x203c and human.native_cosmetics.hair_hue==1147,"Independent native hair "+key)
					var meshes:=actor.find_children("*","MeshInstance3D",true,false);var visibility:={};var underlayers: Array=[];var references:={};var originals:={}
					for mesh: MeshInstance3D in meshes:
						visibility[mesh]=mesh.visible
						if mesh!=target:mesh.material_override=black
						if mesh.name.begins_with("Extra_shirt") or mesh.name.begins_with("Free_pants") or mesh.name.begins_with("Extra_plate_torso") or mesh.name.begins_with("Extra_armour_undercoat"):underlayers.append(mesh)
					for mesh: MeshInstance3D in underlayers:
						originals[mesh]=mesh.mesh
						var replacement:=ArrayMesh.new()
						for surface in mesh.mesh.get_surface_count():
							var arrays:=mesh.mesh.surface_get_arrays(surface);var colours:=PackedColorArray();var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=joints.size()/points.size()
							for vertex in points.size():
								var keep:=false
								for j in stride:
									var bone:=str(mesh.skin.get_bind_name(joints[vertex*stride+j]))
									if weights[vertex*stride+j]>.02 and (bone.contains("arm_") or bone.contains("hand_") or bone.contains("clavicle_")):keep=true
								colours.append(Color(1,0,0) if keep else Color(0,0,0))
							arrays[Mesh.ARRAY_COLOR]=colours;replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
						references[mesh]=replacement
					for motion in ["Walk","Run"]:
						for phase in [.23,.62]:
							human.cancel_action();human.play("Rider_"+motion if mounted else motion,0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
							if mounted:
								actor.horse_visual.animator.play("walk" if motion=="Walk" else "canter",0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
							for angle in [0,90,180,270]:
								actor.rotation_degrees.y=angle;var centre:=Vector3(0,1.95 if mounted else 1.05,0);camera.position=centre+Vector3(0,0,5);camera.look_at(centre)
								for mesh: MeshInstance3D in meshes:mesh.visible=visibility[mesh]
								for component in ["torso"]:
									for surface in target.mesh.get_surface_count():target.set_surface_override_material(surface,probe(target.mesh.surface_get_material(surface)))
									var matching: Array=[]
									for mesh: MeshInstance3D in underlayers:
										if (component=="lap" and mesh.name.begins_with("Free_pants")) or (component=="torso" and mesh.name.begins_with("Extra_plate_torso" if armoured else "Extra_shirt")):matching.append(mesh)
									var actual:=await capture()
									for mesh: MeshInstance3D in matching:mesh.mesh=references[mesh];mesh.material_override=reference_body
									var reference:=await capture()
									for mesh: MeshInstance3D in matching:mesh.mesh=originals[mesh];mesh.material_override=black
									var a:=actual.get_data();var b:=reference.get_data();var wanted:=0;var retained:=0
									for i in range(0,b.size(),4):
										if green(b,i):wanted+=1;retained+=int(green(a,i))
									var ratio:=float(retained)/maxi(1,wanted)
									check(wanted<15 or ratio>=.98 or wanted-retained<=4,"Outside cloth %.4f %s %s %s %s %s %s %s"%[ratio,key,female,armoured,mounted,motion,phase,str(angle)+" "+component])
									var data:=actual.get_data();var pixels:=0
									for i in range(0,data.size(),4):pixels+=int(green(data,i))
									# A side-on sash can be fully hidden by its wearer. Front/rear
									# visibility is aggregated across the four views of each pose.
									samples.append({"component":component,"item":key,"female":female,"plate":armoured,"riding":mounted,"motion":motion,"actual_clip":str(human.animator.current_animation),"phase":phase,"angle":angle,"visible_pixels":pixels,"reference_pixels":wanted,"retained":ratio})
									if angle==0 and component=="torso":poses.append({"component":component,"item":key,"female":female,"plate":armoured,"riding":mounted,"motion":motion,"actual_clip":str(human.animator.current_animation),"phase":phase,"bones":posed.duplicate(true)})
									if wanted>=15 and ratio<.98 and wanted-retained>4 and failures.size()<12:
										actual.save_png("res://../outputs/human-workwear/component-fail-%s.png"%failures.size());reference.save_png("res://../outputs/human-workwear/component-ref-%s.png"%failures.size())
							var total:=0
							for i in range(samples.size()-4,samples.size()):total+=int(samples[i].visible_pixels)
							check(total>120,"Visible workwear across pose views "+key)
					check(int(human.get_meta("body_mask_bits"))==6,"Workwear retains original body mask "+key)

			actor.free();await process_frame
	var file:=FileAccess.open("res://../outputs/human-workwear/gpu-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"views":samples},"  "));file.close()
	file=FileAccess.open("res://../outputs/human-workwear/poses.json",FileAccess.WRITE);file.store_string(JSON.stringify({"poses":poses}));file.close()
	print("WORKWEAR GPU ",checks," checks, ",samples.size()," views, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

func bones(rig: Skeleton3D) -> Dictionary:
	var result:={}
	for i in rig.get_bone_count():
		var p:=rig.get_bone_global_pose(i)
		result[rig.get_bone_name(i)]=[p.basis.x.x,p.basis.y.x,p.basis.z.x,p.origin.x,p.basis.x.y,p.basis.y.y,p.basis.z.y,p.origin.y,p.basis.x.z,p.basis.y.z,p.basis.z.z,p.origin.z]
	return result
