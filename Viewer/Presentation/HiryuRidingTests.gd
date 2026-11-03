extends SceneTree
## Finite client-only mounted-appearance proof; native permissions stay separate.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var clearance_hits:=0
var clearance_poses:=0
var failures:=0
var rows: Array=[]
var output:="res://../work/creatures/late-client-inputs/hiryu-wing-clearance-dense"
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":output="res://../work/creatures/late-client-inputs/hiryu-wing-clearance-dense-contact"
	create_timer(180.).timeout.connect(func():push_error("Hiryu rider deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(label)
func wing_crossings(mount: Node3D, segments: Array) -> int:
	var mesh: MeshInstance3D = mount.model.find_children("*", "MeshInstance3D", true, false)[0]
	var rig: Skeleton3D = mount.skeleton
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bindings.size() / vertices.size()
	var wing: Dictionary = {}
	var transforms: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(bind)
		if bone < 0: bone = rig.find_bone(mesh.skin.get_bind_name(bind))
		wing[bind] = "wing" in rig.get_bone_name(bone)
		transforms.append(rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var points := PackedVector3Array()
	var is_wing := PackedByteArray()
	for vertex in vertices.size():
		var p := Vector3.ZERO
		var influence := 0.0
		for slot in stride:
			var index := vertex * stride + slot
			var weight := weights[index]
			p += (transforms[bindings[index]] * vertices[vertex]) * weight
			if wing[bindings[index]]: influence += weight
		points.append(rig.to_global(p))
		is_wing.append(1 if influence > 0.5 else 0)
	var hits := 0
	var corner_count := vertices.size() if indices.is_empty() else indices.size()
	for corner in range(0, corner_count, 3):
		var a := corner if indices.is_empty() else indices[corner]
		var b := corner + 1 if indices.is_empty() else indices[corner + 1]
		var c := corner + 2 if indices.is_empty() else indices[corner + 2]
		if is_wing[a] + is_wing[b] + is_wing[c] < 2: continue
		for pair: Array in segments:
			if Geometry3D.segment_intersects_triangle(pair[0], pair[1], points[a], points[b], points[c]) != null:
				hits += 1
	return hits

func leg_segments(rig: Skeleton3D) -> Array:
	var segments := []
	for side in ["l", "r"]:
		var positions := []
		for joint in ["thigh_", "calf_", "foot_"]:
			positions.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint + side)).origin))
		segments.append([positions[0], positions[1]])
		segments.append([positions[1], positions[2]])
	return segments

func run() -> void:
	Registry.load_index();var accepted:="res://local-art/creatures/accepted-index.json";var accepted_pin:=FileAccess.get_sha256(accepted)
	var path:="res://local-art/creatures/hiryu_mount/preparation.json";var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var entries: Dictionary={}
	for entry: Dictionary in preparation.models:
		if entry.kind != "hai_riyo":continue
		var body:=int(entry.bodies[0].body)
		if "--active" in OS.get_cmdline_user_args():
			var active := Registry.entry(body).duplicate(true)
			active.status = "prepared"
			check(active == entry, "Normal registry loads the exact prepared mount")
		else:
			Registry.entries[body] = entry
		entries[body]=entry
	check(entries.size()==1,"Original Hiryu source form prepared")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1200,900);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	for female in [false,true]:
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false)
		for body: int in [243]:
			var entry: Dictionary=entries[body];var item:=int(entry.mount_item)
			check(Mounts.horse_body(item)==body and Mounts.mount_available(body,item),"Prepared source registry maps exact native mount item")
			for outfit: Array in [[],[{"id":0x1f03},{"id":0x170b}],[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}]]:
				var worn: Array=outfit.duplicate(true);worn.append({"id":item,"layer":25,"hue":0})
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				check(actor.horse_visual!=null and actor.horse_visual.native_body==body and actor.horse_visual.native_mount_item==item,"Layer25 selects exact source form/item")
				if actor.horse_visual == null or actor.rider_contact == null:
					quit(1)
					return
				check(actor.human_visual.missing_art.is_empty(),"Prepared riding garments retained")
				actor.rider_contact.begin_mount(false);actor.human_visual.set_process(false);actor.horse_visual.set_physics_process(false);actor.horse_visual.contact.active=false
				for pair: Array in [["Rider_Idle","Idle"],["Rider_Walk","Walk"],["Rider_Run","Run"]]:
					actor.human_visual.cancel_action();actor.human_visual.play(pair[0],0.);actor.horse_visual.play(pair[1],0.)
					for phase: float in [.04,.17,.33,.52,.68,.83,.96]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						var leg_sample := []
						var capture := func(): leg_sample.assign(leg_segments(actor.human_visual.skeleton))
						actor.rider_contact.modification_processed.connect(capture)
						for frame in 4:await process_frame
						actor.rider_contact.modification_processed.disconnect(capture)
						assert(leg_sample.size() == 4)
						var crossings := wing_crossings(actor.horse_visual, leg_sample)
						check(crossings == 0, "Rider leg centerlines clear the animated wing triangles")
						if crossings > 0: clearance_poses += 1
						clearance_hits += crossings
						var contact: SkeletonModifier3D=actor.rider_contact;var feet: Array=contact.stirrup_errors
						var good: bool=contact.seat_error<.002 and feet.size()==2 and feet[0]<.025 and feet[1]<.025
						check(good,"Both genders and all outfits retain saddle and reachable stirrups: "+str([female,body,pair,phase,contact.seat_error,feet]))
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Mounted presentation preserves authoritative actor root")
						check(actor.human_visual.grip.reins_holding and actor.human_visual.grip.left_reins_holding,"Both empty hands use closed rein grips")
						rows.append({"female":female,"body":body,"outfit":outfit,"clip":pair[0],"phase":phase,"seat_error_m":contact.seat_error,"stirrup_errors_m":feet.duplicate(),"passed":good})
						if outfit.size()==2 and phase<.5 and DisplayServer.get_name()!="headless":
							var mesh: MeshInstance3D=actor.horse_visual.model.find_children("*","MeshInstance3D",true,false)[0]
							var box:=Geometry.deformed_bounds(mesh,actor.horse_visual.skeleton);box=box.expand(actor.horse_visual.seat().origin+Vector3.UP*1.1)
							camera.size=box.size.length()*.9;camera.position=box.get_center()+Vector3(-1.,.50,1.)*box.size.length();camera.look_at(box.get_center())
							for frame in 3:await process_frame
							await RenderingServer.frame_post_draw
							viewport.get_texture().get_image().save_png(output+"/"+str(body)+("-female-" if female else "-male-")+str(pair[1])+".png")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[])
		check(actor.retiring_horse and actor.rider_contact.mode=="dismount" and not actor.horse_visual.visible,"Dismount uses hidden source sockets without duplicate loose mount")
		actor._finish_dismount();check(actor.horse_visual==null and actor.rider_contact==null and not actor.human_visual.mounted_live_enabled,"Dismount removes mount/rider adapter")
		actor.free()
	check(FileAccess.get_sha256(accepted)==accepted_pin,"Client-only test leaves persistent accepted catalogue unchanged")
	var runtime: Dictionary={}
	for file in ["HiryuRidingTests.gd","SourceHiryuMountVisual.gd","SourceRigMountVisual.gd","SourcePreservingCreatureVisual.gd","SourcePlaneSoleSupport.gd","HumanAvatar.gd","HumanVisual.gd","HorseRider.gd","MountVisual.gd","CreatureRegistry.gd"]:runtime[file]=FileAccess.get_sha256("res://Presentation/"+file)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"wing_centerline_crossings":clearance_hits,"preparation_sha256":FileAccess.get_sha256(path),"runtime_sha256":runtime,"scope":"Actual layer 25 appearance dispatch for body 243, both riders, three outfits and seven phases each of Idle, Walk and Run. Seat, stirrups, rein grips, dismount and leg centerlines against animated wing triangles. Full garment clearance is separate."},"\t"))
	print("WING CENTERLINE: ", clearance_hits, " intersections in ", clearance_poses, " poses")
	print("HIRYU RIDING: ",checks," checks / ",failures," failures / ",rows.size()," poses");quit(1 if failures else 0)
