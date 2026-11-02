extends SceneTree
## Source-free GLTF import proves the second joint set changes real skin/corpses.
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var path:="res://local-art/diagnostics/eight-skin/five.gltf";var pin:=FileAccess.get_sha256(path)
	var document:=GLTFDocument.new();var state:=GLTFState.new();var error:=document.append_from_file(ProjectSettings.globalize_path(path),state)
	check(error==OK,"Source-free GLTF with two joint/weight sets imports")
	if error!=OK:quit(1);return
	var model:=document.generate_scene(state);root.add_child(model)
	var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var a:=mesh.mesh.surface_get_arrays(0);var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride: int=bones.size()/points.size()
	check(stride==8 and bool(mesh.mesh.surface_get_format(0)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS),"Actual imported mesh uses eight slots")
	var selected:=-1
	for vertex in points.size():
		var nonzero:=0
		for slot in stride:
			if weights[vertex*stride+slot]>.0001:nonzero+=1
		if nonzero==5:selected=vertex
	check(selected>=0,"All five real influences survive the actual importer")
	if selected<0:model.free();quit(1);return
	player.play("Probe",0.);var samples: Array=[]
	for phase: float in [0.,.37,1.]:
		player.seek(phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
		var point:=Vector3.ZERO
		for slot in stride:
			var offset:=selected*stride+slot;var bind:=bones[offset];var bone:=mesh.skin.get_bind_bone(bind)
			if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
			point+=(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*points[selected])*weights[offset]
		point=rig.to_global(point)
		var angle:=phase*PI*.5;var expected:=Vector3(.8+.2*cos(angle),1.,-.2*sin(angle))
		check(point.distance_to(expected)<.00001,"Fifth-joint deformation matches independent analytic reference")
		samples.append({"phase":phase,"point":point,"expected":expected})
	model.set_meta("corpse_body",0);model.set_meta("native_hue",0);model.set_meta("death_clip","Source-free probe")
	var frozen:=Corpses.freeze(model);root.add_child(frozen);var found:=false
	for part: MeshInstance3D in frozen.find_children("*","MeshInstance3D",true,false):
		var arrays:=part.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Static fixture keeps no animated skin arrays")
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if part.to_global(vertex).distance_to(Vector3(.8,1.,-.2))<.00001:found=true
	check(found,"Static corpse preserves the fifth joint's final deformation")
	check(pin==FileAccess.get_sha256(path),"Fixture input unchanged during actual engine test")
	frozen.free();model.free()
	var report:={"checks":checks,"failures":failures,"fixture_sha256":pin,"samples":samples,"test_sha256":FileAccess.get_sha256("res://Presentation/EightInfluenceImportTests.gd"),"scope":"Source-free actual headless Godot GLTF eight-slot import, five retained influences, analytic fifth-joint deformation and static corpse. No source creature/GPU/gameplay acceptance."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work/eight-skin-tests"));FileAccess.open("res://../work/eight-skin-tests/godot.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("EIGHT INFLUENCE IMPORT: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
