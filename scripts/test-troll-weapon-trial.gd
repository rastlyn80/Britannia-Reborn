extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const FORMS := {53: "Axe", 55: "FrostClub"}

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var unarmed := Registry.entry(54).duplicate(true)
	for body in FORMS:
		var name: String = FORMS[body]
		var record := Registry.entry(body).duplicate(true)
		record.assets = {"modern": "res://local-art/creatures/troll-%d-armed-trial.scn" % body}
		Registry.entries[body] = record
		var actor := Registry.create(body)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(body, 0)
		check_motion(actor, name)
		actor.free()
		for hue in [0, 53, 0x8035]:
			check_corpse(body, hue, name)
	assert(Registry.entry(54) == unarmed)
	quit()

func check_motion(actor: Node3D, name: String) -> void:
	var weapon := actor.find_child(name, true, false) as MeshInstance3D
	assert(weapon != null and weapon.mesh.get_surface_count() == (2 if name == "FrostClub" else 1))
	var rig := weapon.get_parent() as Skeleton3D
	var joint := weapon.skin.get_bind_bone(0)
	assert(rig.get_bone_name(joint) == "troll weapon")
	assert(rig.get_bone_name(rig.get_bone_parent(joint)) == "cp_grasp_rhand")
	var player: AnimationPlayer = actor.animator
	var data := Ground.skin_points(weapon, rig)
	var floors: Dictionary = {}
	var worst_socket_error := 0.0
	for clip in ["Idle", "Walk", "Run", "Attack", "KneelingSwing", "Death"]:
		player.play(clip, 0.0)
		player.advance(0.0)
		var floor := INF
		for i in 61:
			player.seek(player.get_animation(clip).length * float(i) / 60.0, true)
			rig.force_update_all_bone_transforms()
			var grip := rig.get_bone_global_pose(rig.get_bone_parent(joint))
			var pose := rig.get_bone_global_pose(joint)
			worst_socket_error = maxf(worst_socket_error, (grip * rig.get_bone_rest(joint).origin).distance_to(pose.origin))
			floor = minf(floor, Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		floors[clip] = floor
		if clip != "Death":
			assert(floor > 0.25)
	assert(worst_socket_error < 0.0001)
	print(name, " weapon clearance by clip ", floors)

func check_corpse(body: int, hue: int, name: String) -> void:
	var posed := Corpses.posed(body, hue)
	assert(posed != null)
	var weapon := posed.find_child(name, true, false) as MeshInstance3D
	var rig := weapon.get_parent() as Skeleton3D
	var expected := posed.global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_pose(weapon.skin.get_bind_bone(0))
	var corpse := Corpses.freeze(posed)
	assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006)
	assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
	var frozen := corpse.get_node(name) as MeshInstance3D
	assert(frozen != null and frozen.mesh.get_surface_count() == weapon.mesh.get_surface_count())
	var first: PackedVector3Array = frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var source_first: PackedVector3Array = weapon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lift := (frozen.transform * first[0]).y - (expected * source_first[0]).y
	for surface in weapon.mesh.get_surface_count():
		var source: PackedVector3Array = weapon.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var output: PackedVector3Array = frozen.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		assert(source.size() == output.size())
		for i in output.size():
			assert((frozen.transform * output[i]).distance_to(expected * source[i] + Vector3.UP * lift) < 0.0001)
	corpse.free()
	posed.queue_free()
	print(body, " hue ", hue, ": static weapon geometry matches final pose")
