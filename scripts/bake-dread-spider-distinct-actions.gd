extends "res://../scripts/bake-giant-spider-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")

func run() -> void:
	var row := Registry.entry(11)
	assert(row.kind == "arachnids_spider_dread")
	var scenes := {}
	for treatment: String in ["original","rounded","modern"]:
		var source := Registry.asset_path(row,treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh,rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("",library)
		assert(library.add_animation("Death2",fit_death(player,rig,skin)) == OK)
		assert(library.add_animation("DreadReach",fit(player,rig,skin,15,0.42)) == OK)
		assert(library.add_animation("DreadRock",fit(player,rig,skin,18,0.72)) == OK)
		Exact.check_earlier_keys(player,source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model)==OK)
		var target := "res://local-art/creatures/dread-spider-distinct-actions-%s.scn" % treatment
		assert(ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source":FileAccess.get_sha256(source), "scene":FileAccess.get_sha256(target)}
		model.free()
		print("DREAD SPIDER ",treatment,": three fitted motions with retained earlier keys")
	var inputs := {}
	for file: String in ["bake-dread-spider-distinct-actions.gd", "bake-giant-spider-actions.gd", "bake-quadruped-actions.gd"]:
		inputs[file] = FileAccess.get_sha256("res://../scripts/" + file)
	inputs["SourceGroundLookup.gd"] = FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")
	var receipt := FileAccess.open("res://local-art/creatures/dread-spider-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs":inputs, "scenes":scenes}))
	receipt.close()
	quit()

func pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04,0.33,phase)*(1.0-smoothstep(0.51,1.0,phase))
	var settle := smoothstep(0.22,0.59,phase)*(1.0-smoothstep(0.71,1.0,phase))
	if slot == 15:
		turn(rig,"bone01",Vector3.RIGHT,0.16*pulse)
		turn(rig,"bone20",Vector3.RIGHT,0.55*pulse)
		turn(rig,"bone16",Vector3.RIGHT,0.37*pulse)
		turn(rig,"bone21",Vector3.RIGHT,-0.35*pulse)
		turn(rig,"bone17",Vector3.RIGHT,-0.20*pulse)
	else:
		turn(rig,"bone01",Vector3.FORWARD,0.13*pulse-0.13*settle)
		turn(rig,"bone02",Vector3.RIGHT,-0.24*pulse+0.21*settle)
		turn(rig,"bone24",Vector3.RIGHT,-0.24*pulse)
		turn(rig,"bone25",Vector3.RIGHT,0.16*pulse)
		turn(rig,"bone12",Vector3.RIGHT,-0.23*settle)
		turn(rig,"bone13",Vector3.RIGHT,0.14*settle)
