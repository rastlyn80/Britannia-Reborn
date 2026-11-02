extends "res://Presentation/SavageActionIntegrationTests.gd"
## Real finite collision/raycast contacts and actual avatar/modifier, headless only.
var pose_cases:=0
func _initialize() -> void:
	create_timer(240.).timeout.connect(func():push_error("Human NPC ground integration deadline");quit(1))
	call_deferred("run")
func independent_gap(mesh: MeshInstance3D,rig: Skeleton3D,origin: Vector3,normal: Vector3) -> float:
	var transforms: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var minimum:=INF
	# Deliberately inspect every original split vertex, independently of the support cache.
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var stride:=bones.size()/points.size()
		for index in points.size():
			var point:=Vector3.ZERO
			for slot in stride:
				var offset:=index*stride+slot
				if weights[offset]>0.:point+=(transforms[bones[offset]]*points[index])*weights[offset]
			minimum=minf(minimum,normal.dot(point-origin))
	return minimum
func run() -> void:
	Profiles.load_index();var saved:=Profiles.entries.duplicate(true)
	var accepted_path:="res://local-art/human-npcs/accepted-index.json"
	var accepted_sha:=FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent"
	var prep_path:="res://local-art/human-npcs/savages/dance/preparation.json"
	var prep_sha:=FileAccess.get_sha256(prep_path)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	var records: Array=[];var inputs: Dictionary={}
	for name in ["HumanNPCGroundTests.gd","HumanNPCFootContact.gd","FootContact.gd","SourceGroundLookup.gd","HumanNPCMotion.gd","HumanNPCProfiles.gd","HumanAvatar.gd","HumanVisual.gd","HumanMotion.gd","HumanActions.gd","SavageDanceRetarget.gd"]:inputs[name]=FileAccess.get_sha256("res://Presentation/"+name)
	for body: int in [183,184]:
		var gender:="female" if body==184 else "male";var source: Dictionary={}
		for row: Dictionary in prep.models:
			if row.gender==gender:source=row
		Profiles.entries[body]={"body":body,"female":body==184,"skin":"savage","status":"prepared","tribal_dance":{"asset":source.asset,"sha256":source.asset_sha256}}
		for plane: Dictionary in [{"name":"flat","height":0.,"tilt":Vector3.ZERO},{"name":"raised_forward","height":.25,"tilt":Vector3(.16,0.,0.)},{"name":"cross_slope","height":-.15,"tilt":Vector3(0.,0.,-.14)}]:
			var basis:=Basis.from_euler(plane.tilt);var normal:=basis.y;var origin:=Vector3(11.,plane.height,-7.)
			var platform:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.,.1,3.);collider.shape=box;platform.add_child(collider);root.add_child(platform)
			platform.global_transform=Transform3D(basis,origin-normal*.05)
			await physics_frame;await physics_frame
			for from: String in ["Idle","Walk","Run","Sword_Walk"]:
				for fps: int in [30,90]:
					var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.position=origin
					actor.apply_server_appearance({"body":body,"hue":0,"flags":0},[])
					var human: Node3D=actor.human_visual;human.set_process(false);var rig: Skeleton3D=human.skeleton
					check(actor.foot_contact.get_meta("native_complete_skin_support",false),"Actual gated NPC avatar installs its complete-skin support")
					human.animator.play(from,0.);human.animator.advance(.3)
					var space:=actor.get_world_3d().direct_space_state
					# Let real contacts acquire their normal stance weights; do not inject hits/weights.
					for warm in 12:
						human.animator.advance(1./60.);rig.force_update_all_bone_transforms()
						actor.foot_contact.sample(space,actor.global_position.y);actor.foot_contact._process_modification_with_delta(1./60.)
					var request:={"protocol":"classic","body":body,"action":111,"frames":5,"delay":0,"repeat_count":1,"repeat":false,"reverse":false}
					check(actor.receive_native_action(request),"Actual avatar starts the exact prepared tribal action")
					var maximum_error:=0.;var minimum:=INF;var maximum_correction:=0.;var frames:=0;var airborne:=0;var phase_time:=0.
					var pairs: Array=[]
					for side: String in ["l","r"]:
						for pair in [["thigh_","calf_"],["calf_","foot_"]]:
							var a:=rig.find_bone(str(pair[0])+side);var b:=rig.find_bone(str(pair[1])+side)
							pairs.append([a,b,rig.get_bone_global_rest(a).origin.distance_to(rig.get_bone_global_rest(b).origin)])
					for step in ceili(1.1*fps):
						var dt:=1./fps;actor.animate(false,0.,dt);human.animator.advance(dt);human._process(dt);phase_time+=dt;rig.force_update_all_bone_transforms()
						actor.foot_contact.sample(space,actor.global_position.y)
						check(actor.foot_contact.contacts.size()==2,"Both soles raycast the actual finite platform")
						var dancing: bool=human.action_clip=="Savage_Dance";var rotations: Array[Quaternion]=[]
						if dancing:
							for bone in rig.get_bone_count():rotations.append(rig.get_bone_pose_rotation(bone))
						actor.foot_contact._process_modification_with_delta(dt);rig.force_update_all_bone_transforms()
						var gap:=independent_gap(Dance.body(human),rig,origin,normal)
						var wanted:=expected_lift(source.samples,human.animator.current_animation_position) if dancing else 0.
						minimum=minf(minimum,gap);maximum_error=maxf(maximum_error,absf(gap-wanted));maximum_correction=maxf(maximum_correction,absf(float(actor.foot_contact.get("correction_m"))))
						check(gap>=-.004 and absf(gap-wanted)<.004,"Complete actual skin preserves source rise and ground clearance through entry and exit")
						check(not actor.foot_contact.has_meta("unsupported_support_gap_m"),"Measured support remains within declared correction reach")
						check(actor.position==origin,"No terrain/dance correction changes the authoritative root")
						for pair: Array in pairs:check(absf(rig.get_bone_global_pose(pair[0]).origin.distance_to(rig.get_bone_global_pose(pair[1]).origin)-float(pair[2]))<.00001,"Leg IK and support preserve each fixed segment length")
						if dancing:
							for bone in rig.get_bone_count():check(1.-absf(rotations[bone].normalized().dot(rig.get_bone_pose_rotation(bone).normalized()))<.000001,"Slope support retains every authored dance joint rotation")
						if wanted>.02:airborne+=1
						frames+=1;pose_cases+=1
					check(airborne>0,"Timed source hop survives real finite-plane support")
					records.append({"body":body,"from":from,"plane":plane.name,"fps":fps,"frames":frames,"minimum_gap_m":minimum,"maximum_reference_error_m":maximum_error,"maximum_support_shift_m":maximum_correction,"airborne_frames":airborne})
					# Finite platform boundaries must not turn into an infinite support plane.
					actor.position=origin+Vector3.RIGHT*4.;human.animator.play("Idle",0.);human.animator.advance(.1);rig.force_update_all_bone_transforms();actor.foot_contact.sample(space,actor.global_position.y)
					check(actor.foot_contact.contacts.is_empty(),"Moving beyond the platform loses real support contacts")
					actor.foot_contact._process_modification_with_delta(.016)
					check(float(actor.foot_contact.get("correction_m"))==0.,"Missing contacts never extend the platform mathematically")
					actor.apply_server_appearance({"body":401 if body==184 else 400,"hue":1002,"flags":0},[])
					check(actor.foot_contact.get_script()==load("res://Presentation/FootContact.gd") and not actor.foot_contact.has_meta("native_complete_skin_support"),"Ordinary human restores its original contact implementation")
					actor.free()
				print("NPC GROUND sampled ",body," ",plane.name," ",from," at30/90Hz; cumulative failures",failures)
			platform.free();await physics_frame
	Profiles.entries=saved
	check((FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent")==accepted_sha,"Prepared ground trials do not alter acceptance")
	check(FileAccess.get_sha256(prep_path)==prep_sha,"Ground preparation remains unchanged during trials")
	for name: String in inputs:check(inputs[name]==FileAccess.get_sha256("res://Presentation/"+name),"Ground runtime input remains unchanged: "+name)
	var report:={"checks":checks,"failures":failures,"pose_cases":pose_cases,"cases":records,"runtime_sha256":inputs,"preparation_sha256":prep_sha,"scope":"Headless actual male/female avatars, real finite collision platforms/foot raycasts, timed111entry/exit at30/90Hz, independent complete-skin plane distances, fixed segment lengths/native roots, source rotation preservation and unsupported-edge/ordinary-human reversion. AI, native server, graphics/materials, equipment, split treads and family acceptance are separate."}
	var f:=FileAccess.open("res://../work/creatures/savages/ground-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("HUMAN NPC GROUND: ",checks," checks / ",failures," failures / ",pose_cases," poses");quit(1 if failures else 0)
