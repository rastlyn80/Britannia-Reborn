extends SceneTree
## Reuse saved donor skins/clocks only after exact original geometry/UV contract.
const INPUT="res://../work/creatures/source-variants/preparation.json"
const OUTPUT="res://local-art/creatures/source_variants/preparation.json"
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Source variant bake deadline");quit(1))
	call_deferred("run")
func run() -> void:
	if not FileAccess.file_exists(INPUT):push_error("Run prepare-source-variants.py first");quit(1);return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	for record: Dictionary in report.models:
		var image:=Image.load_from_file(ProjectSettings.globalize_path("res://local-art/creatures/"+str(record.source_atlas_texture)))
		assert(image!=null)
		image.generate_mipmaps()
		var texture:=ImageTexture.create_from_image(image)
		var receipts: Dictionary={}
		for treatment: String in record.assets:
			var donor: Dictionary=record.donor_assets[treatment]
			var path:="res://"+str(donor.path).trim_prefix("Viewer/")
			assert(FileAccess.get_sha256(path)==donor.sha256 and FileAccess.get_sha256(path+".import")==record.donor_imports[treatment].sha256,"Donor asset/import changed")
			var model:=load(path).instantiate() as Node3D
			var rigs:=model.find_children("*","Skeleton3D",true,false)
			assert(rigs.size()==1)
			for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				mesh.mesh=mesh.mesh.duplicate()
				for surface in mesh.mesh.get_surface_count():
					var material:=mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
					assert(material!=null)
					material.albedo_texture=texture
					mesh.mesh.surface_set_material(surface,material)
			var packed:=PackedScene.new()
			assert(packed.pack(model)==OK)
			var output:=str(record.assets[treatment])
			assert(ResourceSaver.save(packed,output,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK)
			var dependencies:=ResourceLoader.get_dependencies(output)
			for dependency in dependencies:assert(not dependency.contains(".godot/imported"),"Saved variants must not depend on transient donor import caches")
			receipts[treatment]={"asset_sha256":FileAccess.get_sha256(output),"donor_asset_sha256":donor.sha256,"donor_import_sha256":record.donor_imports[treatment].sha256,"dependencies":dependencies,"bones":(rigs[0] as Skeleton3D).get_bone_count()}
			model.free()
		record["saved_scenes"]=receipts
	report["baker_sha256"]=FileAccess.get_sha256("res://Presentation/BakeSourceVariants.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SOURCE VARIANT BAKE: ",report.models.size()," variants / six self-contained saved scenes; no accepted index change")
	quit()
