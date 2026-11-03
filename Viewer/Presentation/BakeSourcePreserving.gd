extends SceneTree
## Candidate-only bake: original rigs/clips, shared dense mesh and inverse binds.
const Refine=preload("res://Presentation/SourcePoseSubdivision.gd")
const INPUT="res://../work/creatures/source-preserving/preparation.json"
const OUTPUT="res://local-art/creatures/source_preserving/preparation.json"
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Source-preserving bake deadline");quit(1))
	call_deferred("run")
func run() -> void:
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	for record: Dictionary in report.models:
		var results: Dictionary={}
		for treatment: String in ["original","rounded","modern"]:
			var input: Dictionary=record.bake_inputs[treatment]
			var path:="res://../"+str(input.path)
			assert(FileAccess.get_sha256(path)==input.sha256,"Changed source bake input")
			var document:=GLTFDocument.new();var state:=GLTFState.new()
			assert(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK,"Source candidate import failed")
			var model:=document.generate_scene(state)
			var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
			var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
			if treatment=="original":
				var material:=mesh.mesh.surface_get_material(0) as StandardMaterial3D
				var image:=material.albedo_texture.get_image();var transparent:=0
				for y in image.get_height():
					for x in image.get_width():
						if image.get_pixel(x,y).a<.12:transparent+=1
				assert(transparent==0 if record.source_opacity=="opaque" else transparent>0,"Declared original atlas opacity must match actual source pixels")
			if treatment!="original":
				results[treatment]=Refine.apply(mesh,rig,int(record.pose_subdivision.levels),float(record.pose_subdivision.normal_offset_source_units))
				assert(int(results[treatment].maximum_influences)<=8,"Source subdivision must retain every influence")
				assert(int(results[treatment].triangles)==int(record.stats.original.triangles)*pow(4,int(record.pose_subdivision.levels)),"Incomplete dense skin")
			var packed:=PackedScene.new()
			assert(packed.pack(model)==OK,"Candidate pack failed")
			assert(ResourceSaver.save(packed,str(record.assets[treatment]),ResourceSaver.FLAG_COMPRESS)==OK,"Candidate save failed")
			model.free()
			results[treatment]=results.get(treatment,{})
			results[treatment]["scene_sha256"]=FileAccess.get_sha256(str(record.assets[treatment]))
		record["saved_scenes"]=results
		record["refinement"]={"method":"SourcePoseSubdivision conditional inverse binds, baked once; complete source rig/UV/skin retained", "triangles_before":record.stats.original.triangles,"triangles_after":results.rounded.triangles}
		record.stats.rounded.triangles=results.rounded.triangles
		record.erase("bake_inputs")
	report["baker_sha256"]=FileAccess.get_sha256("res://Presentation/BakeSourcePreserving.gd")
	report["subdivision_sha256"]=FileAccess.get_sha256("res://Presentation/SourcePoseSubdivision.gd")
	report["scope"]="Saved private candidate scenes use original source clips and eight-slot dense skins. Source geometry import uses an explicit 30Hz scene bake. No raw-source interpolation, terrain/riding/native behaviour or accepted route certificate."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SOURCE PRESERVING BAKE: ",report.models.size()," private forms; accepted index unchanged")
	quit()
