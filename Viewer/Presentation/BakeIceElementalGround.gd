extends SceneTree
## Measure direct original/refined imports with every source skin influence.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const FOLDER="res://../work/creatures/ice-elemental/prepared/"
func _initialize() -> void:
	create_timer(600.).timeout.connect(func():push_error("Ice ground measurement deadline");quit(1));call_deferred("run")
func run() -> void:
	var prep_path:=FOLDER+"preparation.json";var prep_pin:=FileAccess.get_sha256(prep_path);var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	var recipe_pin:=FileAccess.get_sha256("res://Presentation/BakeIceElementalGround.gd");var geometry_pin:=FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")
	for record: Dictionary in prep.models:
		var treatments: Dictionary={}
		for treatment: String in ["original","rounded","modern"]:
			var path:=FOLDER+str(record.kind)+"-"+treatment+".gltf";var asset_pin:=FileAccess.get_sha256(path)
			var document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK);var model:=document.generate_scene(state);root.add_child(model)
			var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig);var clips: Dictionary={}
			player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.deterministic=true
			for clip: String in player.get_animation_list():
				if clip=="RESET":continue
				var length:=player.get_animation(clip).length;var count:=ceili(length*960.);var samples: Array=[];var maximum:=0.;player.get_animation(clip).loop_mode=Animation.LOOP_NONE;player.play(clip,0.)
				for sample in count+1:
					var time:=length*float(sample)/float(count);player.seek(time,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
					var gap:=Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP);assert(is_finite(gap));maximum=maxf(maximum,absf(gap));samples.append([time,-gap])
				if clip=="Run":
					# Source preparation already retains a constant whole-clip Run
					# anchor. Preserve its positive rise; no per-frame flattening.
					for sample: Array in samples:sample[1]=0.
				clips[clip]=samples;print("ICE SOURCE GROUND ",record.kind,"/",treatment,"/",clip," samples",samples.size()," residual",maximum)
			assert(asset_pin==FileAccess.get_sha256(path));treatments[treatment]={"asset_sha256":asset_pin,"clips":clips};model.free()
		var report:={"sample_rate":960,"treatments":treatments,"preparation_sha256":prep_pin,"recipe_sha256":recipe_pin,"geometry_sha256":geometry_pin,"scope":"Actual imported complete original/refined four-slot source skin residuals, without edits to source animation/rig. Model-only grounded-action floor lookup, unchanged source Run rise; separate off-grid/runtime/terrain/render/native proof required."}
		FileAccess.open(FOLDER+str(record.kind)+"-ground.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	assert(prep_pin==FileAccess.get_sha256(prep_path) and recipe_pin==FileAccess.get_sha256("res://Presentation/BakeIceElementalGround.gd") and geometry_pin==FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"));print("ICE SOURCE GROUND COMPLETE");quit()
