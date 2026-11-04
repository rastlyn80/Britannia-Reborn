extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const ROOT := "res://local-art/creatures/"
const RATE := 960.0

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func():quit(2))
	call_deferred("run")

func run() -> void:
	var original := ROOT+"walking_dead_mummy-ground.json"
	var report := {"sample_rate": int(RATE), "treatments": {}}
	report.predecessor_sha256 = FileAccess.get_sha256(original)
	report.overlay_recipe_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var measured := 0
	for treatment: String in ["original","rounded","modern"]:
		var path := ROOT+"mummy-distinct-actions-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh,rig)
		var entry := {"overlay_asset_sha256": FileAccess.get_sha256(path), "clips": {}}
		report.treatments[treatment] = entry
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in ["MummyRecoil","MummyCurl"]:
			assert(not entry.clips.has(clip))
			player.stop()
			player.play(clip,0.0)
			player.advance(0.0)
			var intervals := ceili(player.current_animation_length*RATE)
			var curve: Array = []
			for index in intervals+1:
				var time := player.current_animation_length*float(index)/float(intervals)
				player.seek(time,true)
				rig.force_update_all_bone_transforms()
				var gap := Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
				assert(is_finite(gap) and absf(gap)<0.01)
				curve.append([time,-gap])
				measured+=1
			entry.clips[clip] = curve
		model.free()
	var output := FileAccess.open(ROOT+"mummy-distinct-actions-ground-measured.json",FileAccess.WRITE)
	assert(output!=null)
	output.store_string(JSON.stringify(report, "", true, true))
	output.close()
	print("MUMMY GESTURES: ",measured," fitted-clip samples measured at 960 Hz")
	quit()
