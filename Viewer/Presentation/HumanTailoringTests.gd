extends SceneTree
## GPU garment occlusion against a complete-body reference, on both real rigs.
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
const ITEMS:={"bonnet":[0x1719,6],"feathered_hat":[0x171a,6],"tricorne_hat":[0x171b,6],"jester_hat":[0x171c,6],"chain_coif":[0x13bb,6],"spellbook":[0x0efa,1],"lantern":[0x0a25,2]}
var viewport: SubViewport
var camera: Camera3D
var checks:=0
var failures:=0
var samples: Array=[]
var prop_poses: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func solid(colour: String) -> ShaderMaterial:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO="+colour+";}"
	var material:=ShaderMaterial.new();material.shader=shader;return material
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image
func green(pixel: PackedByteArray,i: int) -> bool:return pixel[i]<25 and pixel[i+1]>230 and pixel[i+2]<25
func fingers(rig: Skeleton3D) -> Dictionary:
	var result:={}
	for side in ["l","r"]:
		var ratios: Array=[]
		for finger in ["index","middle","ring","pinky"]:
			var points: Array[Vector3]=[]
			for segment in ["01","02","03"]:points.append(rig.get_bone_global_pose(rig.find_bone(finger+"_"+segment+"_"+side)).origin)
			var last:=rig.get_bone_global_pose(rig.find_bone(finger+"_03_"+side));points.append(last.origin+last.basis.y.normalized()*points[1].distance_to(points[2])*.65)
			var length:=0.
			for i in 3:length+=points[i].distance_to(points[i+1])
			ratios.append(points[0].distance_to(points[-1])/length)
		result[side]=ratios
	return result
func bones(rig: Skeleton3D) -> Dictionary:
	var result:={}
	for i in rig.get_bone_count():
		var p:=rig.get_bone_global_pose(i)
		result[rig.get_bone_name(i)]=[p.basis.x.x,p.basis.y.x,p.basis.z.x,p.origin.x,p.basis.x.y,p.basis.y.y,p.basis.z.y,p.origin.y,p.basis.x.z,p.basis.y.z,p.basis.z.z,p.origin.z]
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/human-tailoring"))
	viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;viewport.add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.3;viewport.add_child(camera)
	var black:=solid("vec3(0.)");var visible:=solid("vec3(0.,1.,0.)")
	var selected:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--item="):selected=argument.substr(7)
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.foot_contact.active=false
		var human: Node3D=actor.human_visual;human.set_process(false)
		var folded:={}
		human.held_accessories.modification_processed.connect(func():folded.merge(fingers(human.skeleton),true))
		var posed:={}
		var watcher:=func():posed.merge(bones(human.skeleton),true)
		human.held_accessories.modification_processed.connect(watcher)
		for key: String in ITEMS:
			if not selected.is_empty() and selected!=key:continue
			for armoured in [false]:
				for mounted in [false,true]:
					var worn: Array=[{"id":0x1539,"layer":4},{"id":0x170b,"layer":3},{"id":0x13c6,"layer":7},{"id":0x203c,"layer":11,"hue":1147},{"id":int(ITEMS[key][0]),"layer":int(ITEMS[key][1]),"hue":53}]
					worn.append({"id":0x1415,"layer":13} if armoured else {"id":0x1517,"layer":5})
					if mounted:worn.append({"id":0x3e9f,"layer":25})
					# Seed each snapshot directly; a repeated mount must not turn this
					# deterministic seated-pose test into a transition-frame test.
					if not mounted and actor.horse_visual!=null:actor._finish_dismount()
					actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn);actor.animate(false,0.,.1,0.)
					if mounted:
						actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.
						if not actor.rider_contact.modification_processed.is_connected(watcher):actor.rider_contact.modification_processed.connect(watcher)
					check(human.missing_art.is_empty() and human.unsupported_items.is_empty(),"Native IDs/art "+key)
					var target: MeshInstance3D
					for mesh: MeshInstance3D in human.parts:
						if mesh.name.begins_with("Extra_"+key):target=mesh
					check(target!=null,"Real distinct garment "+key)
					if target==null:continue
					for surface in target.mesh.get_surface_count():
						var dyed:=target.get_active_material(surface) as ShaderMaterial
						check(dyed!=null and bool(dyed.get_shader_parameter("use_hue")),"Native hue palette "+key)
					check(human.native_cosmetics.hair_id==0x203c and human.native_cosmetics.hair_hue==1147,"Independent hair type/hue "+key)
					var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
					var base: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
					for mesh: MeshInstance3D in meshes:states[mesh]={"visible":mesh.visible,"material":mesh.material_override}
					for motion in ["Walk","Run"]:
						for phase in [.23,.62]:
							human.cancel_action();human.play("Rider_"+motion if mounted else motion,0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
							if mounted:
								actor.horse_visual.animator.play("walk" if motion=="Walk" else "canter",0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
							for angle in [0,90,180,270]:
								actor.rotation_degrees.y=angle
								var centre:=Vector3(0,1.9 if mounted else 1.,0)
								camera.position=centre+Vector3(0,0,5);camera.look_at(centre)
								for mesh: MeshInstance3D in meshes:
									mesh.material_override=visible if mesh==target else black
									var underlayer: bool=key not in ["spellbook","lantern"] and (mesh.name.begins_with("Extra_shirt") or mesh.name.begins_with("Free_pants"))
									mesh.visible=states[mesh].visible and not underlayer
								base.visible=true
								var reference:=await capture()
								for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible
								var clothed:=await capture()
								if angle==0 and key in ["spellbook","lantern"]:prop_poses.append({"female":female,"item":key,"mounted":mounted,"motion":motion,"phase":phase,"bones":posed.duplicate(true)})
								if key in ["spellbook","lantern"]:
									var side: String="r" if key=="spellbook" else "l"
									check(folded.has(side) and folded.get(side,[]).all(func(ratio: float):return ratio<.83),"Actual closed holding fingers "+key)
								var a:=reference.get_data();var b:=clothed.get_data();var expected:=0;var missing:=0
								for pixel in 384*384:
									var i:=pixel*4
									if green(a,i):
										expected+=1
										if not green(b,i):missing+=1
								var fraction:=1.-float(missing)/maxi(1,expected)
								# A held item can be hidden by the body/horse at an
								# angle. Check every nontrivial projection.
								var passed:=expected<12 or fraction>=.98
								samples.append({"female":female,"item":key,"armoured":armoured,"mounted":mounted,"motion":motion,"phase":phase,"angle":angle,"reference_pixels":expected,"occluded_pixels":missing,"visible_fraction":fraction,"passed":passed})
								check(passed,"Clipping "+str(samples[-1]))
								if not passed and failures<12:clothed.save_png("res://../outputs/human-tailoring/failure-%d.png"%failures)
								if mounted:check(actor.rider_contact.seat_error<=.002 and actor.rider_contact.stirrup_errors.all(func(error: float):return error<=.025),"Actual saddle/stirrups "+key)
					for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=states[mesh].material
				print("TAILORING GPU ",female," ",key," armour=",armoured)
		for id in [0x0a15,0x0a17,0x0a18,0x0a22,0x0a25]:
			for hue in [0,53,0x8035]:
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[{"id":id,"layer":2,"hue":hue},{"id":0x3e9f,"layer":25}])
				var lit: bool=id in [0x0a15,0x0a17,0x0a22];var emitting:=0
				for mesh: MeshInstance3D in human.parts:
					if not mesh.name.begins_with("Extra_lantern"):continue
					for surface in mesh.mesh.get_surface_count():
						var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
						if source.emission_enabled and source.emission.get_luminance()>.05:
							emitting+=1
							if hue!=0:
								var material:=mesh.get_active_material(surface) as ShaderMaterial
								var emission: Color=material.get_shader_parameter("emission_colour")
								check(emission.get_luminance()>.05,"Native dye preserves lantern emission")
				check((emitting>0)==lit and human.held_accessories.lantern and human.grip.left_holding,"Native lit/unlit lantern identity %04x hue %d"%[id,hue])
		actor.free()
	var resolved:=Wardrobe.resolve([{"id":0x13c0,"layer":6}])
	check(resolved.bits==0 and resolved.pieces.head.asset=="coverage/chain_coif","Flipped coif is headwear, not a tunic")
	var file:=FileAccess.open("res://../outputs/human-tailoring/gpu-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Both native human bodies; seven categories walking/running and horse riding at two phases/four angles. Actual completed frames: >=98% retained headwear pixels against complete body/hair reference. Held props retain sleeve/trouser occluders in both frames because ordinary line-of-sight occlusion is legitimate; direct posed geometry is separately validated. Actual saddle/stirrup contact, closed fingers, native lit/unlit identities and independent hue/hair checks. Rejected apron/sash experiments excluded. Finite samples, no live server/world-entry claim."},"\t"));file.close()
	file=FileAccess.open("res://../outputs/human-tailoring/prop-poses.json",FileAccess.WRITE);file.store_string(JSON.stringify({"poses":prop_poses}));file.close()
	print("HUMAN TAILORING: ",checks," checks, ",samples.size()," GPU views, ",failures," failures");quit(1 if failures else 0)
