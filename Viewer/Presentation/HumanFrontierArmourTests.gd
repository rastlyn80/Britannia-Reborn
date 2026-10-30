extends "res://Presentation/HorseClothingTests.gd"
## Every new torso/arm/leg/glove derivative in a complete outfit, real frames.
var batch_kind:="expansion35"
var output_folder:="human-frontier"
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;viewport.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.3;viewport.add_child(camera)
	var white:=solid("vec3(1.)");var pink:=solid("COLOR.rgb")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/human-coverage-recipes.json"))
	var definitions: Array=data.assets.filter(func(row: Dictionary):return row.kind==batch_kind and row.slot in ["torso","arms","legs","hands","outer","middle","outer_legs","feet"])
	var defaults:={"torso":0x1415,"arms":0x1410,"legs":0x1411,"hands":0x1414,"gorget":0x1413,"boots":0x170b}
	for female in [false,true]:
		for mounted in [false,true]:
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.foot_contact.active=false
			var human: Node3D=actor.human_visual;human.set_process(false)
			for row: Dictionary in definitions:
				var worn: Array=[]
				for slot: String in defaults:worn.append({"id":int(row.graphics[0]) if slot==row.slot else int(defaults[slot]),"hue":53})
				if not defaults.has(row.slot):worn.append({"id":int(row.graphics[0]),"hue":53})
				if mounted:worn.append({"id":0x3e9f,"layer":25})
				actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				if mounted:actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.
				assert(human.missing_art.is_empty())
				var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
				var base: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
				for mesh: MeshInstance3D in meshes:states[mesh]={"visible":mesh.visible,"material":mesh.material_override,"mesh":mesh.mesh,"probe":preload("res://Presentation/HumanArmourCoverageTests.gd").skin_probe(mesh,human.skeleton) if mesh.name.begins_with("Body") else mesh.mesh}
				for motion in ["Walk","Run"]:
					for phase in [.23,.62]:
						human.cancel_action();human.play("Rider_"+motion if mounted else motion,0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
						if mounted:actor.horse_visual.animator.play("walk" if motion=="Walk" else "canter",0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for angle in [0,90,180,270]:
							actor.rotation_degrees.y=angle;var centre:=Vector3(0,1.9 if mounted else 1.,0);camera.position=centre+Vector3(0,0,5);camera.look_at(centre)
							for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=pink if mesh.name.begins_with("Body") else white;mesh.mesh=states[mesh].probe
							var skin:=await capture()
							for mesh: MeshInstance3D in meshes:mesh.visible=mesh==base;mesh.material_override=white;mesh.mesh=states[mesh].mesh
							var reference:=await capture()
							for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=white
							var covered:=await capture()
							var a:=skin.get_data();var b:=reference.get_data();var c:=covered.get_data();var exposed:=0;var count:=0;var missing:=0;var seat_count:=0;var seat_missing:=0
							var saddle: Vector3=actor.horse_visual.seat().origin if mounted else Vector3(0,.86,0)
							var seat_top:=roundi(camera.unproject_position(saddle+Vector3.UP*.22).y);var seat_bottom:=roundi(camera.unproject_position(saddle-Vector3.UP*.23).y)
							for y in 256:
								for x in 256:
									var i:=(y*256+x)*4
									if a[i]>230 and a[i+1]<35 and a[i+2]>230:exposed+=1
									if b[i]>240 and b[i+1]>240 and b[i+2]>240:
										count+=1;var opaque: bool=c[i]>240 and c[i+1]>240 and c[i+2]>240
										if not opaque:missing+=1
										if y>=seat_top and y<=seat_bottom:seat_count+=1;seat_missing+=0 if opaque else 1
							var body_fraction:=1.-float(missing)/maxi(1,count);var seat_fraction:=1.-float(seat_missing)/maxi(1,seat_count)
							var passed:=exposed<=4 and body_fraction>=.98 and seat_fraction>=.995
							rows.append({"female":female,"item":row.key,"mounted":mounted,"motion":motion,"phase":phase,"angle":angle,"skin_pixels":exposed,"body_occupancy":body_fraction,"seat_occupancy":seat_fraction,"passed":passed})
							if not passed:
								failures+=1
								if failures<=8:push_error(str(rows[-1]));skin.save_png("res://../outputs/"+output_folder+"/armour-failure-%d.png"%failures)
				for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=states[mesh].material;mesh.mesh=states[mesh].mesh
				print("FRONTIER ARMOUR ",female," mounted=",mounted," ",row.key)
			actor.free()
	var file:=FileAccess.open("res://../outputs/"+output_folder+"/armour-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":rows,"failures":failures,"scope":"Every new torso/arm/leg/glove model in a complete outfit. Both bodies, Walk/Run, two phases/four angles, foot and actual seated horse. Completed rendered frames, no force_draw. Visible masked skin marked magenta; independent complete unmasked body provides opacity/seat reference. Head/neck excluded by original bone weights; <=4 skin pixels, >=98% total and >=99.5% seat opacity. Finite visual samples, not universal collision or art-direction approval."},"\t"));file.close()
	print("HUMAN FRONTIER ARMOUR: ",rows.size()," views / ",failures," failures");quit(1 if failures else 0)
