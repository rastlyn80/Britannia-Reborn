extends "res://Presentation/HumanTailoringTests.gd"
## Finite native appearance and actual completed GPU frames for every new model.
var batch_kind:="expansion35"
var output_folder:="human-frontier"
func definitions() -> Array:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/human-coverage-recipes.json"))
	var selected:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--item="):selected=arg.substr(7)
	return data.assets.filter(func(row: Dictionary):return row.kind==batch_kind and (selected.is_empty() or row.key==selected))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/"+output_folder))
	viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;viewport.add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var black:=solid("vec3(0.)");var visible:=solid("vec3(0.,1.,0.)")
	for female in [false,true]:
		for mounted in [false,true]:
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.foot_contact.active=false
			var human: Node3D=actor.human_visual;human.set_process(false)
			var folded:={};var posed:={}
			var watcher:=func():folded.merge(fingers(human.skeleton),true);posed.merge(bones(human.skeleton),true)
			human.held_accessories.modification_processed.connect(watcher)
			for row: Dictionary in definitions():
				var worn: Array=[{"id":0x1539},{"id":0x170b},{"id":0x1517},{"id":0x203c,"layer":11,"hue":1147}]
				if row.slot!="hands":worn.append({"id":0x13c6})
				if mounted:worn.append({"id":0x3e9f,"layer":25})
				# Every indexed ID, both native bodies, default/full/partial dye.
				for id: int in row.graphics:
					for hue in [0,53,0x8035]:
						actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn+[{"id":id,"hue":hue}])
						check(human.missing_art.is_empty() and human.unsupported_items.is_empty(),"Native ID/hue "+row.key+" %04x/%04x"%[id,hue])
						check(human.native_cosmetics.hair_id==0x203c and human.native_cosmetics.hair_hue==1147,"Independent native hair "+row.key)
						for mesh: MeshInstance3D in human.parts:
							if mesh.name!="Extra_"+row.key:continue
							for surface in mesh.mesh.get_surface_count():
								var original:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
								if original.resource_name.begins_with("Armour_Lining"):
									check(mesh.get_surface_override_material(surface)==null,"Neutral opaque backing "+row.key);continue
								var material:=mesh.get_active_material(surface) as ShaderMaterial
								if hue==0:check(material==null,"Original undyed material "+row.key);continue
								check(material!=null and bool(material.get_shader_parameter("use_hue")) and bool(material.get_shader_parameter("partial_hue"))==((hue&0x8000)!=0),"Native palette/partial flag "+row.key)
								if material!=null:check(is_equal_approx(float(material.get_shader_parameter("metalness")),original.metallic) and is_equal_approx(float(material.get_shader_parameter("roughness")),original.roughness),"Dye preserves physical material "+row.key)
				if mounted:
					actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.;actor.rider_contact.modification_processed.connect(watcher)
				check(human.held_accessories.book==(row.get("held_family","")=="book"),"Book grip family "+row.key)
				if row.get("stance","")=="bow":check(human.stance_clip("Idle")==("Rider_Idle" if mounted else "Bow_Idle") and human.grip.left_holding,"Ranged family "+row.key)
				var target: MeshInstance3D
				for mesh: MeshInstance3D in human.parts:
					if mesh.name=="Extra_"+row.key:target=mesh
				check(target!=null,"Distinct export "+row.key)
				if target==null:continue
				var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
				var base: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
				for mesh: MeshInstance3D in meshes:states[mesh]={"visible":mesh.visible,"material":mesh.material_override}
				for motion in ["Walk","Run"]:
					for phase in [.23,.62]:
						human.cancel_action();human.play("Rider_"+motion if mounted else human.stance_clip(motion),0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
						if mounted:actor.horse_visual.animator.play("walk" if motion=="Walk" else "canter",0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for angle in [0,90,180,270]:
							actor.rotation_degrees.y=angle;camera.size=3.4 if row.slot=="weapon" else 2.25
							var centre:=Vector3(0,1.9 if mounted else 1.,0);camera.position=centre+Vector3(0,0,5);camera.look_at(centre)
							for mesh: MeshInstance3D in meshes:
								mesh.visible=states[mesh].visible;mesh.material_override=visible if mesh==target else black
								# Body/horse/hair remain in both images. Opaque fitted
								# armour has a separate structural backing validator.
								if row.slot=="head" and (mesh.name.begins_with("Extra_shirt") or mesh.name.begins_with("Free_pants")):mesh.visible=false
							base.visible=true
							var reference:=await capture()
							for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible
							var clothed:=await capture();var a:=reference.get_data();var b:=clothed.get_data();var expected:=0;var missing:=0
							for pixel in 256*256:
								var i:=pixel*4
								if green(a,i):expected+=1;missing+=0 if green(b,i) else 1
							var fraction:=1.-float(missing)/maxi(1,expected);var passed:=expected<12 or missing<=4 or fraction>=.98
							samples.append({"female":female,"item":row.key,"mounted":mounted,"motion":motion,"clip":human.animator.current_animation,"phase":phase,"angle":angle,"reference_pixels":expected,"occluded_pixels":missing,"visible_fraction":fraction,"passed":passed})
							check(passed,"Headwear retention "+str(samples[-1]))
							if not passed and failures<12:clothed.save_png("res://../outputs/"+output_folder+"/failure-%d.png"%failures)
							if mounted:check(actor.rider_contact.seat_error<=.002 and actor.rider_contact.stirrup_errors.all(func(error: float):return error<=.025),"Saddle/stirrups "+row.key)
							if angle==0:
								prop_poses.append({"female":female,"item":row.key,"mounted":mounted,"motion":motion,"phase":phase,"bones":posed.duplicate(true)})
								if row.slot in ["weapon","shield"]:
									var side: String="l" if row.slot=="shield" or row.get("stance","")=="bow" else "r"
									check(folded.has(side) and folded[side].all(func(ratio: float):return ratio<.83),"Actual closed holding fingers "+row.key)
				for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=states[mesh].material
				if mounted:actor.rider_contact.modification_processed.disconnect(watcher)
				print("FRONTIER GPU ",female," mounted=",mounted," ",row.key)
			actor.free()
	var file:=FileAccess.open("res://../outputs/"+output_folder+"/gpu-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Every new model on both bodies, Walk/Run and actual seated horse poses, two phases/four angles. Every new indexed ID tested with default/full/partial native hues in each body/mount state. Headwear >=98% retention (or <=4 raster pixels) against full-body reference. Props retain legitimate body/sleeve/horse occluders in both images; images establish rendered presence, not a collision proof. Exact preserved armour backing is checked independently. Actual grips and saddle/stirrup contacts. Finite samples; no live world-entry claim."},"\t"));file.close()
	file=FileAccess.open("res://../outputs/"+output_folder+"/poses.json",FileAccess.WRITE);file.store_string(JSON.stringify({"poses":prop_poses}));file.close()
	print("HUMAN FRONTIER: ",checks," checks, ",samples.size()," views, ",failures," failures");quit(1 if failures else 0)
