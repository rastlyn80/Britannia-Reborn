# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-raptor-uop-actions.gd"

const Donor := "res://local-art/creatures/raptor/raptor.scn"
const Clips := {
	2: ["Death", 1.0], 3: ["Death2", .92], 4: ["ChickenLizardPeck", .55],
	5: ["ChickenLizardKick", .70], 10: ["ChickenLizardRecoil", .46],
	15: ["ChickenLizardDuck", .60], 23: ["ChickenLizardScan", 1.10],
	25: ["ReadyStance", 1.45], 26: ["ChickenLizardChirp", .74],
	27: ["ChickenLizardForage", 1.24], 28: ["ChickenLizardRise", .80],
}
const Joints := ["__root", "Body", "Torso", "Shoulders", "Neck", "Head", "Tail1", "Tail2",
	"Tail3", "BackUpLeg.L", "BackUpLeg.R", "FrontUpLeg.L", "FrontUpLeg.R", "BackFoot.L", "BackFoot.R"]


func run() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		var model := (load(Donor) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert(rig.get_bone_count() == 37 and mesh.mesh.get_surface_count() == 3)
		assert(player.has_animation("Walk") and player.has_animation("Death"))
		model.scale *= Vector3(.46, .47, .43)
		model.position *= .43
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		for surface: int in geometry.get_surface_count():
			var original := geometry.surface_get_material(surface) as StandardMaterial3D
			var base := original.albedo_texture.get_image().get_pixel(0, 0)
			var colour := Color("#6f8135")
			if base.r < .45:
				colour = Color("#3c4924")
			elif base.r > .73 and base.g > .63:
				colour = Color("#be8539")
			geometry.surface_set_material(surface, surface_material(colour, style))
		add_crest(geometry, mesh, rig, style)
		mesh.mesh = geometry
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		mesh.skin = mesh.skin.duplicate() as Skin
		normalize_root(rig, mesh.skin, library)
		var skin := Ground.skin_points(mesh, rig)
		if skin.is_empty():
			quit(1)
			return
		player.deterministic = true
		for group: int in Clips:
			var action: Array = Clips[group]
			if library.has_animation(action[0]):
				library.remove_animation(action[0])
			var fit := fit_grounded(player, rig, [skin], action[1], "__root", Joints, pose_chicken_lizard.bind(group))
			assert(library.add_animation(action[0], fit) == OK)
		var peaceful := peaceful_walk(player, rig)
		assert(library.add_animation("ChickenLizardPeaceWalk", peaceful) == OK)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var path := folder.path_join("716-%s.scn" % style)
		assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("CHICKEN LIZARD FIT: ", style, ", ", Clips.size() + 1, " crafted motions, hash ", FileAccess.get_sha256(path))
	quit(0)


func normalize_root(rig: Skeleton3D, skin: Skin, library: AnimationLibrary) -> void:
	var root_bone := rig.find_bone("root")
	assert(root_bone == 0 and rig.get_bone_parent(root_bone) < 0)
	rig.set_bone_name(root_bone, "__root")
	for binding in skin.get_bind_count():
		if skin.get_bind_name(binding) == "root":
			skin.set_bind_name(binding, "__root")
	for name: String in library.get_animation_list():
		var clip := library.get_animation(name)
		for track in clip.get_track_count():
			var path := str(clip.track_get_path(track))
			if path.ends_with(":root"):
				clip.track_set_path(track, NodePath(path.trim_suffix(":root") + ":__root"))


func surface_material(colour: Color, style: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var atlas := Image.create_empty(48, 48, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 716
	noise.frequency = .16
	for y in 48:
		for x in 48:
			var shade := 0.96 + noise.get_noise_2d(x, y) * (.23 if style == "modern" else .12)
			atlas.set_pixel(x, y, Color(colour.r * shade, colour.g * shade, colour.b * shade))
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = .85
	return material


func add_crest(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D, style: String) -> void:
	var head := rig.find_bone("Head")
	var binding := -1
	for candidate: int in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(candidate) == head or mesh.skin.get_bind_name(candidate) == "Head":
			binding = candidate
			break
	assert(binding >= 0)
	var crest := SurfaceTool.new()
	crest.begin(Mesh.PRIMITIVE_TRIANGLES)
	crest.set_material(surface_material(Color("#a66231"), style))
	# Coordinates follow the head surface in the imported mesh's bind space.
	var base := [Vector3(.0006, -.012, .0131), Vector3(.0009, -.0108, .0135),
		Vector3(.0011, -.0094, .0143), Vector3(.0008, -.0081, .0142), Vector3(.0004, -.0068, .0121)]
	var spines := [Vector3(0, -.0115, .0155), Vector3(0, -.0100, .0182),
		Vector3(0, -.0087, .0197), Vector3(0, -.0074, .0169)]
	for side: int in [-1, 1]:
		for index in spines.size():
			var left: Vector3 = base[index] * Vector3(side, 1, 1)
			var right: Vector3 = base[index + 1] * Vector3(side, 1, 1)
			var triangle: Array = [left, spines[index], right] if side == 1 else [right, spines[index], left]
			for offset: Vector3 in triangle:
				crest.set_bones(PackedInt32Array([binding, 0, 0, 0]))
				crest.set_weights(PackedFloat32Array([1, 0, 0, 0]))
				crest.set_uv(Vector2(.5 + offset.y * 36, offset.z * 65))
				crest.add_vertex(offset)
	crest.generate_normals()
	crest.commit(geometry)


func pose_chicken_lizard(rig: Skeleton3D, phase: float, slot: int) -> void:
	var thrust := smoothstep(.11, .43, phase) * (1.0 - smoothstep(.52, .95, phase))
	var flinch := smoothstep(0.0, .22, phase) * (1.0 - smoothstep(.34, .88, phase))
	match slot:
		2, 3:
			var side := -1.0 if slot == 2 else 1.0
			var collapse := smoothstep(.17, .77, phase)
			turn_world(rig, "__root", Vector3.FORWARD, side * 1.45 * collapse)
			turn_world(rig, "Neck", Vector3.RIGHT, .35 * collapse)
			turn_world(rig, "Tail2", Vector3.UP, -.52 * side * collapse)
			turn_world(rig, "BackUpLeg.L", Vector3.RIGHT, .22 * collapse)
			turn_world(rig, "BackUpLeg.R", Vector3.RIGHT, -.47 * collapse)
		4, 27:
			var peck := thrust if slot == 4 else pow(sin(phase * TAU), 2.0)
			turn_world(rig, "Torso", Vector3.RIGHT, .31 * peck)
			turn_world(rig, "Neck", Vector3.RIGHT, .59 * peck)
			turn_world(rig, "Head", Vector3.RIGHT, -.24 * peck)
			turn_world(rig, "Tail1", Vector3.RIGHT, -.18 * peck)
		5:
			turn_world(rig, "Torso", Vector3.RIGHT, -.22 * thrust)
			turn_world(rig, "BackUpLeg.L", Vector3.RIGHT, -.82 * thrust)
			turn_world(rig, "BackFoot.L", Vector3.RIGHT, -.43 * thrust)
			turn_world(rig, "Tail2", Vector3.UP, .45 * thrust)
		10, 15:
			var effort := flinch if slot == 10 else thrust
			turn_world(rig, "Torso", Vector3.RIGHT, .22 * effort)
			turn_world(rig, "Neck", Vector3.RIGHT, (.48 if slot == 15 else -.28) * effort)
			turn_world(rig, "Shoulders", Vector3.UP, -.31 * effort if slot == 10 else 0.0)
		23, 25, 26, 28:
			var scan := sin(phase * TAU)
			turn_world(rig, "Neck", Vector3.RIGHT, (-.42 if slot in [26, 28] else -.12) * thrust)
			turn_world(rig, "Head", Vector3.UP, scan * (.69 if slot == 23 else .11))
			turn_world(rig, "Head", Vector3.RIGHT, -.12 * thrust)
			turn_world(rig, "Tail2", Vector3.UP, scan * .17)
