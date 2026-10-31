extends RefCounted
## Bind local acceptance reports to the actual asset and presentation code.
const INPUTS=["BirdEvidence.gd","BirdMotionTests.gd","BirdPresentationTests.gd","BirdGroundSupport.gd","CreatureFeatherMaterial.gd","CreatureFeatherSurface.gdshader","CreatureRegistry.gd","CreatureVisual.gd","OstardVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","SourceMountContact.gd","MountVisual.gd","FootContact.gd","AnimalPoseLibrary.gd","SkinGeometry.gd","CorpseModels.gd","HumanHue.gd","HumanActions.gd","ItemStudio.gd"]
static func capture(asset: String,record: Dictionary={}) -> Dictionary:
	var hashes: Dictionary={}
	for file in INPUTS:
		var path: String="res://Presentation/"+file
		hashes[path]=FileAccess.get_sha256(path)
	var preparation:=asset.get_base_dir()+"/preparation.json"
	return {"asset":asset,"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"preparation_sha256":FileAccess.get_sha256(preparation),"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-bird.py"),"runtime_sha256":hashes,"record":record}
static func output(name: String,report: Dictionary) -> void:
	var folder:="res://../outputs/creatures/bird-trial"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file:=FileAccess.open(folder+"/"+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
