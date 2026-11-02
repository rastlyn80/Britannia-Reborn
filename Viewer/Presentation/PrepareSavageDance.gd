extends SceneTree
## Offline candidate generation, deliberately separate from runtime acceptance.
const Human=preload("res://Presentation/HumanVisual.gd")
const Retarget=preload("res://Presentation/SavageDanceRetarget.gd")
const INPUTS=["PrepareSavageDance.gd","SavageDanceRetarget.gd","HumanVisual.gd","HumanMotion.gd","HumanWardrobe.gd","HumanActions.gd","SkinGeometry.gd"]
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Savage dance preparation deadline");quit(1))
	call_deferred("run")
func run() -> void:
	var reference:="res://../work/creatures/savages/dance-reference/"
	if not FileAccess.file_exists(reference+"preparation.json"):
		push_error("Prepare the exact source dance references first");quit(1);return
	var preparation_sha:=FileAccess.get_sha256(reference+"preparation.json")
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference+"preparation.json"))
	var runtime: Dictionary={}
	for name in INPUTS:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var output:="res://local-art/human-npcs/savages/dance/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var models: Array=[]
	for row: Dictionary in prep.models:
		var source_path:=reference+str(row.output)
		assert(FileAccess.get_sha256(source_path)==str(row.sha256),"Original reference changed before retarget")
		var human:=Human.new();human.female=str(row.gender)=="female";root.add_child(human);human.set_process(false)
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(source_path),state)==OK,"Original dance reference did not load")
		var source:=document.generate_scene(state);root.add_child(source)
		var value:=Retarget.build(source,human)
		var asset:=output+str(row.gender)+"-tribal-dance.res"
		assert(ResourceSaver.save(value.animation,asset)==OK,"Could not save prepared modern dance")
		var record: Dictionary=value.report
		record.gender=row.gender;record.asset=asset;record.asset_sha256=FileAccess.get_sha256(asset)
		record.source_reference_sha256=row.sha256;record.status="prepared"
		models.append(record);source.free();human.free()
	for name in INPUTS:assert(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Retarget runtime changed during generation")
	assert(preparation_sha==FileAccess.get_sha256(reference+"preparation.json"),"Reference preparation changed during generation")
	var report:={"models":models,"runtime_sha256":runtime,"reference_preparation_sha256":preparation_sha,"scope":"Prepared original tribal dance on modern humans; root/garment controls at rest. No accepted body/action/native111/terrain or clothing proof."}
	var file:=FileAccess.open(output+"preparation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SAVAGE DANCE PREPARED: two modern clips/52 mapped body joints each; no runtime route activated");quit()
