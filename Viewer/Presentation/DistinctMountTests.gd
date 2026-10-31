extends SceneTree
const Mounts=preload("res://Presentation/MountVisual.gd")
const Bounds=preload("res://Presentation/OstardTests.gd")
var checks:=0
var failures:=0
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	for entry in [[0xd2,0x3ea3],[0xda,0x3ea4],[0xdb,0x3ea5],[0xd2,0x3eac],[0x84,0x3ead],[0x84,0x3e9c],[0xdc,0x3ea6],[0xdc,0x3eab],[0x124,0],[0x319,0x3ebb]]:
		var body: int=entry[0];var item: int=entry[1]
		var actor: Node3D=Mounts.create(body,item);root.add_child(actor);actor.apply_identity(body,0x4001 if item in [0x3eac,0x3eab,0x3e9c] else 53,item)
		var skeleton: Skeleton3D=actor.skeleton
		var source_root:=actor.transform
		var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		for clip in (["idle","walk","gallop","rear","hit","death"] if body==0x319 else ["Idle","Walk","Run","Attack","Hit","Death","Fidget"]):
			actor.current_clip=clip
			actor.animator.play(clip,0.)
			for phase in [0.,.125,.25,.375,.5,.625,.75,.875,.99]:
				actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
				for frame in 2:await process_frame
				var bounds:=Bounds.deformed_bounds(mesh,skeleton)
				var finite_pose:=bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.4 and bounds.size.length()<5.
				check(finite_pose,"Actual source skin stays finite/bounded: "+str([body,clip,phase,bounds]))
				check(actor.transform.is_equal_approx(source_root),"Action never changes authoritative actor root")
				if body==0x319 and clip in ["rear","hit","death"]:check(absf(bounds.position.y)<.035,"Skeletal reactions / death rest on actual skinned floor")
				samples.append({"body":body,"item":item,"clip":clip,"phase":phase,"lowest_vertex_m":bounds.position.y,"size_m":[bounds.size.x,bounds.size.y,bounds.size.z],"finite":finite_pose})
		for hue in [0,53,0x8000|53,0x4001]:
			var id:=skeleton.get_instance_id();actor.apply_identity(body,hue,item)
			check(actor.native_hue==hue and actor.native_mount_item==item and actor.skeleton.get_instance_id()==id,"Raw hue flags / mount identity survive without rig rebuild")
		actor.free()
	var view:=preload("res://Presentation/WorldItems.gd").new();root.add_child(view)
	for body in [0xd2,0xda,0xdb,0x84,0xdc,0x124,0x319]:
		var corpse_root:=Node3D.new();root.add_child(corpse_root)
		check(view._equine_corpse(corpse_root,{"amount":body,"hue":53},0x40012345),"Native corpse amount routes to actual creature body")
		var corpse: Node3D=corpse_root.get_node("CorpseVisual")
		check(corpse.dead and not corpse.animator.is_playing() and not corpse.reins.visible,"Corpse retains final death pose, hue and no reins")
		corpse_root.free()
	view.hint.free();view.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/ostard-riding"))
	var file:=FileAccess.open("res://../outputs/ostard-riding/skin-actions.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Offline actual skin vertices, original source action clips, raw appearance identity and native corpse presentation. World permission/replication evidence is separate."},"\t"));file.close()
	print("DISTINCT MOUNT SKINS: ",checks-failures," / ",checks,"; ",samples.size()," deformed poses");quit(1 if failures else 0)
