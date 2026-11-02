extends SceneTree
## Preserve source motion only for these six private original warrior assets.
## Godot's documented animation optimizer removes keys with bounded error:
## https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html
const FOLDER="res://local-art/creatures/"
const TEXTURE_OPTIONS={"compress/mode":0,"detect_3d/compress_to":0,"process/fix_alpha_border":false,"process/premult_alpha":false,"process/size_limit":0,"mipmaps/generate":true}
func _initialize() -> void:
	create_timer(30.).timeout.connect(func():push_error("Warrior import configuration deadline");quit(1));call_deferred("run")
func run() -> void:
	var path:=FOLDER+"solen_warriors/preparation.json";var pin:=FileAccess.get_sha256(path);var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var kinds: Dictionary={};var records: Array=[];var textures: Dictionary={};var changed:=0
	for row: Dictionary in prep.models:
		var kind:=str(row.kind);assert(kind in ["fire_ant_warrior","black_ant_warrior"] and not kinds.has(kind) and int(row.max_influences)==8);kinds[kind]=true
		for treatment: String in ["original","rounded","modern"]:
			var asset:=FOLDER+kind+"-"+treatment+".gltf";var asset_pin:=FileAccess.get_sha256(asset)
			assert(asset_pin==str(prep.assets_sha256[asset.get_file()]),"Warrior import must use the exact prepared source asset")
			var config:=ConfigFile.new();assert(config.load(asset+".import")==OK,"Run the ordinary headless asset import first")
			var sub: Dictionary=config.get_value("params","_subresources",{});var nodes: Dictionary=sub.get("nodes",{});var options: Dictionary=nodes.get("PATH:AnimationPlayer",{})
			var edited: bool=options.get("optimizer/enabled",true)!=false or options.get("compression/enabled",true)!=false
			options["optimizer/enabled"]=false;options["compression/enabled"]=false;nodes["PATH:AnimationPlayer"]=options;sub["nodes"]=nodes
			if edited:
				config.set_value("params","_subresources",sub);assert(config.save(asset+".import")==OK);changed+=1
			records.append({"asset":asset,"asset_sha256":asset_pin,"import_settings_sha256":FileAccess.get_sha256(asset+".import"),"player_import_id":"PATH:AnimationPlayer","optimizer":false,"compression":false,"changed":edited})
			var scene: Node3D=load(asset).instantiate();var mesh: MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0];var material:=mesh.mesh.surface_get_material(0) as StandardMaterial3D
			assert(material!=null and material.albedo_texture!=null)
			var texture:=material.albedo_texture.resource_path;assert(texture==FOLDER+kind+"-"+treatment+"_0.png");textures[texture]=true;scene.free()
		var atlas:=FOLDER+str(row.source_atlas_texture);assert(atlas==FOLDER+kind+"-original-albedo.png" and FileAccess.get_sha256(atlas)==str(prep.assets_sha256[atlas.get_file()]));textures[atlas]=true
	var texture_records: Array=[]
	for texture: String in textures:
		var config:=ConfigFile.new();assert(config.load(texture+".import")==OK);var edited:=false
		for option: String in TEXTURE_OPTIONS:
			if config.get_value("params",option,null)!=TEXTURE_OPTIONS[option]:edited=true;config.set_value("params",option,TEXTURE_OPTIONS[option])
		if edited:assert(config.save(texture+".import")==OK);changed+=1
		texture_records.append({"asset":texture,"asset_sha256":FileAccess.get_sha256(texture),"import_settings_sha256":FileAccess.get_sha256(texture+".import"),"changed":edited})
	assert(kinds.size()==2 and records.size()==6 and texture_records.size()==8 and pin==FileAccess.get_sha256(path))
	var report:={"changed":changed,"records":records,"textures":texture_records,"preparation_sha256":pin,"recipe_sha256":FileAccess.get_sha256("res://Presentation/ConfigureSolenWarriorImport.gd"),"godot_version":Engine.get_version_info().string,"scope":"Two prepared warrior forms/three treatments only. Exact source GLTF/PNG untouched; disable animation key reduction/lossy compression on AnimationPlayer. Preserve base RGBA with lossless imports/no alpha-border repaint or premultiplication on six extracted atlases/two originals; keep mipmaps. Reimport changed settings, independently compare actual saved inputs."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work/creatures/solen-warriors"));FileAccess.open("res://../work/creatures/solen-warriors/import-settings.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WARRIOR IMPORT CONTRACT:6checked/",changed,"changed; reimport changed assets");quit()
