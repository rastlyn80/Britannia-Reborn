extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
var checks:=0
var failures:=0
const CELL:=.001
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func cloud(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
	var a:=mesh.mesh.surface_get_arrays(0);var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result:=PackedVector3Array()
	for vertex in a[Mesh.ARRAY_VERTEX].size():
		var p:=Vector3.ZERO
		for slot in 8:p+=(matrices[a[Mesh.ARRAY_BONES][vertex*8+slot]]*a[Mesh.ARRAY_VERTEX][vertex])*float(a[Mesh.ARRAY_WEIGHTS][vertex*8+slot])
		result.append(p)
	return result
func key(p: Vector3) -> Vector3i:return Vector3i(floor(p.x/CELL),floor(p.y/CELL),floor(p.z/CELL))
func directed(a: PackedVector3Array,b: PackedVector3Array) -> float:
	var grid: Dictionary={}
	for p in b:
		var k:=key(p)
		if not grid.has(k):grid[k]=[]
		grid[k].append(p)
	var worst:=0.
	for p in a:
		var k:=key(p);var nearest:=INF
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for q: Vector3 in grid.get(k+Vector3i(x,y,z),[]):nearest=minf(nearest,p.distance_to(q))
		worst=maxf(worst,nearest)
	return worst
func run() -> void:
	Registry.load_index();var candidate_path:="res://Art/Creatures/index.json" if not Registry.entry(779).is_empty() and Registry.asset_path(Registry.entry(779)).begins_with("res://Art/") else "res://local-art/bogling/candidate.json"
	var entry: Dictionary=Registry.entry(779) if candidate_path=="res://Art/Creatures/index.json" else JSON.parse_string(FileAccess.get_file_as_string(candidate_path));Registry.entries[779]=entry
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/bogling-trial"));var asset:=Registry.asset_path(entry)
	var actor:=Avatar.new();actor.initial_body=779;root.add_child(actor);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/bogling/source-reference/reference.json"));var binary:=FileAccess.open("res://../work/creatures/bogling/source-reference/skins.bin",FileAccess.READ);var rows: Array=[];var maximum:=0.
	check(FileAccess.get_sha256("res://../work/creatures/bogling/source-reference/skins.bin")==reference.binary_sha256,"Independent original source-skin reference pin")
	for sample: Dictionary in reference.samples:
		visual.play(sample.clip,0.);visual.animator.seek(float(visual.animator.current_animation_length)*float(sample.phase),true);visual.animator.pause();rig.force_update_all_bone_transforms()
		check(absf(float(visual.animator.current_animation_length)-float(sample.duration))<.0001,"Imported original duration retained")
		binary.seek(int(sample.byte_offset));var source:=PackedVector3Array()
		for vertex in int(sample.vertices):source.append(Vector3(binary.get_float(),binary.get_float(),binary.get_float()))
		var imported:=cloud(mesh,rig);var forward:=directed(source,imported);var backward:=directed(imported,source);var error:=maxf(forward,backward);maximum=maxf(maximum,error)
		check(error<.0005,"Every original and imported surface point matches within 0.5mm")
		rows.append({"clip":sample.clip,"phase":sample.phase,"source_vertices":source.size(),"imported_vertices":imported.size(),"symmetric_max_error_m":error})
	binary.close();actor.free()
	var result:={"checks":checks,"failures":failures,"maximum_surface_error_m":maximum,"samples":rows,"reference_sha256":FileAccess.get_sha256("res://../work/creatures/bogling/source-reference/reference.json"),"asset_sha256":FileAccess.get_sha256(asset),"candidate_sha256":FileAccess.get_sha256(candidate_path),"preparation_sha256":FileAccess.get_sha256("res://local-art/bogling/preparation.json"),"import_sha256":FileAccess.get_sha256(asset+".import"),"test_sha256":FileAccess.get_sha256("res://Presentation/BoglingSourceTests.gd"),"scope":"Independent evaluated original-FBX full-influence skins against actual imported eight-weight skins; bidirectional point-cloud coverage, not per-vertex identity or gameplay proof."}
	FileAccess.open("res://../outputs/creatures/bogling-trial/source.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TREE SOURCE: ",checks," / ",failures," failures; maximum ",maximum);quit(1 if failures else 0)
