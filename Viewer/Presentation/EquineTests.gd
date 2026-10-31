extends SceneTree
const Horse=preload("res://Presentation/HorseVisual.gd")
const Registry=preload("res://Presentation/EquineRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
var checks:=0
var failures:=0
var poses:=0
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func fittings(horse: Node3D) -> Array:
	return horse.skeleton.get_children().filter(func(node: Node):return node.has_meta("equine_fitting"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/equines"))
	check(Registry.BODIES.size()==15 and Registry.COMPATIBILITY.size()==9 and Registry.DISTINCT.size()==2 and Registry.DEFERRED.is_empty(),"The 26 indexed identities distinguish native, compatibility and distinct-rig routes")
	for body: int in Registry.DISTINCT:check(not Horse.supports_body(body),"Distinct geometry stays outside the ordinary horse renderer")
	for item in [0,0x3e90,0x3eab,0x3eac,0x3e9c,0x3ead,0x3ebb]:check(Horse.horse_body(item)==0,"Unknown, non-equine, ki-rin and skeletal mount items remain deferred")
	var mount_items: Array=[]
	for body: int in Registry.BODIES:
		var loose:=Avatar.new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false)
		loose.apply_server_appearance({"body":body,"hue":53},[])
		check(loose.horse_visual!=null and loose.human_visual==null and loose.horse_visual.native_body==body and loose.horse_visual.native_hue==53,"Actual loose avatar routing preserves native identity and hue")
		var horse: Node3D=loose.horse_visual
		check(horse.model.scale.is_equal_approx(Registry.profile(body).get("scale",Vector3.ONE)),"Profile proportions apply to the visual model")
		check(is_equal_approx(horse.contact.hoof_height,.17*horse.model.scale.y),"Hoof support uses the scaled visual hoof height")
		for clip in ["walk","gallop","rear"]:
			horse.animator.play(clip,0.);horse.animator.seek(horse.animator.get_animation(clip).length*.37,true);horse.animator.pause()
			for frame in 3:await process_frame
			for socket in fittings(horse):
				var expected: Transform3D=horse.skeleton.global_transform*horse.skeleton.get_bone_global_pose(socket.get_bone_idx())
				check(socket.global_transform.origin.distance_to(expected.origin)<.001,"Accessory attachment follows its real animated bone")
			check(horse.seat().origin.is_finite() and horse.stirrup(true).is_finite(),"Shared rig sockets remain finite on all new profiles")
		var style:=str(Registry.BODIES[body][1])
		check(fittings(horse).size()==({"nightmare":2,"fire":3,"unicorn":1,"pack":2}.get(style,0)),"Profile builds exactly its own horn, eyes, bags or emitter")
		var item:=int(Registry.BODIES[body][2])
		if item!=0:
			check(Horse.horse_body(item)==body,"Audited mobile body/mount pairing round-trips");mount_items.append(item)
		else:check(body==291,"Pack horse has no invented ridden item")
		loose.free()
	for item: int in Registry.ETHEREALS:mount_items.append(item)
	for female in [false,true]:
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_physics_process(false)
		for item: int in mount_items:
			for outfit in [[],[{"id":0x1f03},{"id":0x1539},{"id":0x170b}],[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}]]:
				var worn: Array=outfit.duplicate(true);worn.append({"id":item,"layer":25,"hue":0x4001 if Registry.ETHEREALS.has(item) else 1153})
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				check(actor.horse_visual!=null and actor.human_visual.mounted_live_enabled and actor.horse_visual.native_mount_item==item,"Native layer 25 selects profile; exact item identity survives")
				actor.rider_contact.begin_mount(false);actor.human_visual.set_process(false)
				var horse: Node3D=actor.horse_visual
				var rig_id: int=horse.skeleton.get_instance_id()
				for pair in [["Rider_Walk","walk"],["Rider_Run","gallop"],["Rider_Idle","rear"]]:
					actor.human_visual.cancel_action();actor.human_visual.play(pair[0],0.);horse.animator.play(pair[1],0.)
					for phase in [.0,.25,.5,.75]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();horse.animator.seek(horse.animator.current_animation_length*phase,true);horse.animator.pause()
						for frame in 3:await process_frame
						var feet: Array=actor.rider_contact.stirrup_errors
						check(actor.rider_contact.seat_error<.002 and feet.size()==2 and feet[0]<.025 and feet[1]<.025,"Both riders / three outfits / all supported equines retain animated saddle and stirrup contact")
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Presentation never changes authoritative position")
						check(actor.human_visual.missing_art.is_empty(),"Existing robe and armour resources remain available")
						poses+=1
				for hue in [53,0x8000|53,0,0x4001]:
					horse.apply_identity(Horse.horse_body(item),hue,item)
					check(horse.native_hue==hue and horse.skeleton.get_instance_id()==rig_id,"Full raw native hue changes preserve the rig and rider sockets")
					var mesh: MeshInstance3D=horse.model.find_children("*","MeshInstance3D",true,false)[0]
					var mat: ShaderMaterial=mesh.get_surface_override_material(0)
					check(mat.shader==load("res://Presentation/HorseEthereal.gdshader") if Registry.ETHEREALS.has(item) else mat.shader==load("res://Presentation/HorseSurface.gdshader"),"Ethereal transparency is isolated from opaque horses")
					if Registry.ETHEREALS.has(item) and hue==0x4001:check(not mat.get_shader_parameter("use_hue"),"Server spectral marker is not treated as a hues.mul dye")
				records.append({"female":female,"item":item,"style":horse.get_meta("equine_profile").style,"outfit":outfit})
		actor.free()
	var floor_body:=StaticBody3D.new();root.add_child(floor_body)
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12.,.1,12.);collider.shape=box;collider.position.y=-.05;floor_body.add_child(collider)
	var support_samples: Array=[]
	for body in [0x74,0x75,0xbe,0x7a,0x123]:
		var horse:=Horse.new();root.add_child(horse);horse.apply_identity(body,0)
		for tilt in [Vector2.ZERO,Vector2(.12,0),Vector2(0,.10)]:
			floor_body.rotation=Vector3(tilt.x,0,tilt.y)
			horse.animator.play("idle");horse.animator.seek(0.,true);horse.animator.pause()
			for frame in 25:await physics_frame;await process_frame
			check(horse.contact.contacts.size()==4,"Every scaled profile finds four real flat/slope support surfaces")
			var errors: Array=horse.contact.hoof_errors
			var good:=not errors.is_empty()
			for error: float in errors:good=good and error<.045
			check(good and absf(horse.model.rotation.x)<.27 and absf(horse.model.rotation.z)<.18,"Scaled stance hooves and body tilt remain within existing support bounds")
			support_samples.append({"body":body,"tilt":str(tilt),"hoof_errors_m":errors.duplicate()})
		horse.free()
	floor_body.free()
	var report:={"checks":checks,"failures":failures,"contact_poses":poses,"loose_bodies":Registry.BODIES.keys(),"mount_items":mount_items,"outfits":records,"scaled_support_samples":support_samples,"scope":"Offline actual avatars, animated sockets, accessories, scaled proportions/support and native hue retention. Visual fixtures do not grant server riding permissions."}
	var file:=FileAccess.open("res://../outputs/equines/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EQUINE TESTS: ",checks-failures," / ",checks," passed; ",poses," contact poses");quit(1 if failures else 0)
