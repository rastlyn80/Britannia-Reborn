extends SceneTree

const BASE := "res://local-art/creatures/khaldun_doom/"
const OUTPUT := "res://local-art/creatures/khaldun_actions/"
const GHOST := ["GhostSlashOneHand", "GhostBashTwoHand", "GhostSlashTwoHand", "GhostPierceTwoHand",
	"GhostCastDirected", "GhostCastArea", "GhostTurn", "GhostBow", "GhostSalute"]

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK)
	var sword := (load(BASE + "spectral-reconstruction-trial.scn") as PackedScene).instantiate()
	var sword_clips := {}
	for slot in [6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34]:
		var label := "Reconstructed%d" % slot
		sword_clips["Death2" if slot == 22 else label] = label
	copy_clips(sword, BASE + "spectral-scimitar.gltf", "spectral-scimitar.scn", sword_clips)
	sword.free()
	if "--spectral-only" in OS.get_cmdline_user_args():
		print("KHALDUN BAKE: 26 fitted sword slots")
		quit()
		return

	var ghost := import_donor("restless-soul-recovered-trial.gltf")
	var original_ghost := import_donor("restless-soul-recovered-original-trial.gltf")
	var ghost_clips := {}
	for label: String in GHOST:
		ghost_clips[label] = label
	for treatment: String in ["original", "rounded", "modern"]:
		var name := "restless-soul-" + treatment
		copy_clips(original_ghost if treatment == "original" else ghost, BASE + name + ".gltf", name + ".scn", ghost_clips)
	ghost.free()
	original_ghost.free()
	print("KHALDUN BAKE: 26 fitted sword slots and nine ghost donor clips across all treatments")
	quit()

func import_donor(name: String) -> Node:
	var importer := GLTFDocument.new()
	var state := GLTFState.new()
	assert(importer.append_from_file(BASE + name, state) == OK)
	return importer.generate_scene(state)

func copy_clips(donor: Node3D, source: String, output: String, clips: Dictionary) -> void:
	var model := (load(source) as PackedScene).instantiate()
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(rig.get_bone_count() == donor_rig.get_bone_count())
	for bone in rig.get_bone_count():
		assert(rig.get_bone_name(bone) == donor_rig.get_bone_name(bone))
		assert(rig.get_bone_parent(bone) == donor_rig.get_bone_parent(bone))
		assert(rig.get_bone_rest(bone).is_equal_approx(donor_rig.get_bone_rest(bone)))
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	for label: String in clips:
		var clip := donor_player.get_animation(clips[label]).duplicate(true) as Animation
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			var target := player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			assert(target != null)
			if path.get_subname_count() > 0:
				assert(target == rig and rig.find_bone(path.get_subname(0)) >= 0)
		assert(library.add_animation(label, clip) == OK)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, OUTPUT + output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
