extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func skin_point(mesh: MeshInstance3D,rig: Skeleton3D,index: int) -> Vector3:
	var a:=mesh.mesh.surface_get_arrays(0);var point:=Vector3.ZERO
	for slot in 8:
		var bind: int=a[Mesh.ARRAY_BONES][index*8+slot];var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		point+=(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*a[Mesh.ARRAY_VERTEX][index])*float(a[Mesh.ARRAY_WEIGHTS][index*8+slot])
	return rig.to_global(point)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func run() -> void:
	Registry.load_index();var candidate_path:="res://Art/Creatures/index.json" if not Registry.entry(779).is_empty() and Registry.asset_path(Registry.entry(779)).begins_with("res://Art/") else "res://local-art/bogling/candidate.json"
	var entry: Dictionary=Registry.entry(779) if candidate_path=="res://Art/Creatures/index.json" else JSON.parse_string(FileAccess.get_file_as_string(candidate_path));Registry.entries[779]=entry
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/bogling-trial"));var asset:=Registry.asset_path(entry)
	var actor:=Avatar.new();actor.initial_body=779;root.add_child(actor);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var arrays:=mesh.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	check(rig.get_bone_count()==33 and bones.size()==vertices.size()*8,"Actual imported original rig and eight-weight skin retained")
	for vertex in vertices.size():
		var total:=0.
		for slot in 8:
			var weight:=weights[vertex*8+slot];total+=weight
			check(weight>=0. and weight<=1. and bones[vertex*8+slot]>=0 and bones[vertex*8+slot]<mesh.skin.get_bind_count(),"Every real skin influence is finite, positive and in range")
		check(absf(total-1.)<.0001,"Every fitted skin is normalized")
	var material:=mesh.get_active_material(0) as ShaderMaterial
	check(bool(material.get_shader_parameter("use_normal")) and material.get_shader_parameter("normal_texture")!=null,"Actual source normal map is bound")
	check(is_equal_approx(float(material.get_shader_parameter("normal_strength")),.65),"Original normal strength survives conversion")
	var motion: Array=[]
	for category in ["Walk","Run"]:
		var expected:=1.8 if category=="Walk" else 5.5;var stance:=.62 if category=="Walk" else .28;var samples: Array=[]
		visual.play(category,0.)
		var anchors: Array[int]=[]
		for foot_index in 2:
			visual.animator.seek(float(visual.animator.current_animation_length)*fmod(stance*.5+.5*foot_index,1.),true);rig.force_update_all_bone_transforms()
			var foot: Dictionary=visual.contact.feet[foot_index];var best:=-1;var lowest:=INF
			for vertex: int in foot.vertices:
				var score:=0.
				for slot in 8:
					var bind:=bones[vertex*8+slot];var bone:=mesh.skin.get_bind_bone(bind)
					if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
					var ancestor:=bone
					while ancestor>=0:
						if ancestor==int(foot.end):score+=weights[vertex*8+slot];break
						ancestor=rig.get_bone_parent(ancestor)
				var point:=skin_point(mesh,rig,vertex)
				if score>.9999 and point.y<lowest:lowest=point.y;best=vertex
			check(best>=0,"A fixed real sole vertex belongs wholly to the foot subtree")
			anchors.append(best)
		for step in 257:
			var phase:=float(step)/256.;visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();rig.force_update_all_bone_transforms()
			var soles: Array=[]
			for index in 2:
				var p:=skin_point(mesh,rig,anchors[index]);soles.append([p.x,p.y,p.z])
			samples.append({"phase":phase,"soles":soles})
		var errors: Array[float]=[];var measured: Array=[]
		for step in range(1,samples.size()-1):
			for foot in 2:
				var phase:=fmod(float(samples[step].phase)+.5*foot,1.)
				if phase<.04 or phase>stance-.04:continue
				var speed: float=-(float(samples[step+1].soles[foot][2])-float(samples[step-1].soles[foot][2]))/(float(visual.animator.current_animation_length)/128.)
				var error:=absf(speed-expected);errors.append(error);measured.append({"phase":phase,"foot":foot,"speed":speed})
				check(error<.15,"A fixed actual eight-weight sole vertex follows declared physical stance speed")
		check(errors.size()>60,"Both real source feet contribute stance velocity samples")
		for foot in 2:
			var first: Array=samples[0].soles[foot];var last: Array=samples[256].soles[foot]
			check(Vector3(first[0],first[1],first[2]).distance_to(Vector3(last[0],last[1],last[2]))<.001,"Actual saved foot skin closes the gait loop within 1mm")
		motion.append({"category":category,"expected_mps":expected,"max_speed_error_mps":errors.max(),"fixed_sole_vertices":anchors,"samples":measured})
	var file:=FileAccess.open("res://../outputs/creatures/bogling-trial/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"gaits":motion,"asset_sha256":FileAccess.get_sha256(asset),"candidate_sha256":FileAccess.get_sha256(candidate_path),"preparation_sha256":FileAccess.get_sha256("res://local-art/bogling/preparation.json"),"import_sha256":FileAccess.get_sha256(asset+".import"),"test_sha256":FileAccess.get_sha256("res://Presentation/BoglingMotionTests.gd"),"scope":"Actual imported normalized eight-weight skin, original normal map and measured planted sole velocities. No native server acceptance."},"  "));file.close();actor.free();print("TREE MOTION: ",checks," / ",failures," failures");quit(1 if failures else 0)
