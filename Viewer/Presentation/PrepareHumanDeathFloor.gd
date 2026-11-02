extends SceneTree
## Bake body-floor compensation offline; live deaths never scan/bake a full clip.
const Human=preload("res://Presentation/HumanVisual.gd")
const Ground=preload("res://Presentation/HumanDeathFloor.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Human death-floor preparation deadline");quit(1));call_deferred("run")
func run() -> void:
	var folder:="res://local-art/human-npcs/shared/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var records: Array=[];var inputs: Dictionary={}
	for name in ["PrepareHumanDeathFloor.gd","HumanDeathFloor.gd","HumanVisual.gd","HumanMotion.gd","SkinGeometry.gd"]:inputs[name]=FileAccess.get_sha256("res://Presentation/"+name)
	for female in [false,true]:
		var human:=Human.new();human.female=female;human.use_grounded_death=false;root.add_child(human);human.set_process(false)
		var player: AnimationPlayer=human.animator;var rig: Skeleton3D=human.skeleton;var original:=player.get_animation("Death")
		var digest:=Ground.signature(human,original);var animation:=original.duplicate(true) as Animation
		var track:=animation.find_track(NodePath(str(player.get_node(player.root_node).get_path_to(rig))+":pelvis"),Animation.TYPE_POSITION_3D)
		assert(track>=0,"Complete modern death requires an explicit pelvis position stream")
		var times: Array[float]=[]
		for i in ceili(original.length*240.)+1:times.append(minf(original.length,float(i)/240.))
		for i in original.track_get_key_count(track):
			var t:=original.track_get_key_time(track,i)
			if not times.has(t):times.append(t)
		times.sort()
		for i in range(animation.track_get_key_count(track)-1,-1,-1):animation.track_remove_key(track,i)
		animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
		var mesh: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
		var maximum:=0.;var positions: Array=[];player.play("Death",0.)
		for time: float in times:
			player.seek(time,true);rig.force_update_all_bone_transforms()
			var minimum:=Geometry.deformed_bounds(mesh,rig).position.y
			var shift:=maxf(0.,-minimum);maximum=maxf(maximum,shift)
			var pelvis:=rig.find_bone("pelvis");var pose:=rig.get_bone_global_pose(pelvis);pose.origin+=rig.global_basis.inverse()*Vector3.UP*shift
			rig.set_bone_global_pose(pelvis,pose);animation.position_track_insert_key(track,time,rig.get_bone_pose_position(pelvis))
			positions.append({"time":time,"raw_minimum_m":minimum,"correction_m":shift})
		animation.set_meta("human_death_floor_version",Ground.VERSION);animation.set_meta("human_death_source_signature",digest)
		var path:=folder+("female" if female else "male")+"-grounded-death.res";assert(ResourceSaver.save(animation,path)==OK)
		records.append({"female":female,"asset":path,"asset_sha256":FileAccess.get_sha256(path),"source_signature":digest,"maximum_floor_compensation_m":maximum,"samples":positions})
		print("HUMAN DEATH FLOOR prepared ",female," samples",positions.size()," maximumCompensation",maximum);human.free()
	for name: String in inputs:assert(inputs[name]==FileAccess.get_sha256("res://Presentation/"+name))
	var f:=FileAccess.open(folder+"death-preparation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"models":records,"runtime_sha256":inputs,"scope":"Grounded original modern human death: pelvis-only negative-body-floor compensation at240Hz; source rotations/cloth scales/duration and positive rise retained. Body/rig/clip signature checked at runtime without developer files. Derived art stays private; full GPU/native/death transition proof separate."},"\t"));f.close();quit()
