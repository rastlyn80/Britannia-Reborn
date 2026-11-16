# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Donor := 149
const Fitted := {
	"MedusaIdle": [1.58, 1], "Death": [1.20, 2], "Death2": [1.38, 3],
	"MedusaShot": [.80, 4], "MedusaHighShot": [.96, 5], "MedusaRecoil": [.58, 10],
	"MedusaStare": [1.44, 12], "MedusaGuard": [.84, 15], "MedusaSurvey": [1.0, 26],
}
const Joints := ["bip01", "bip01 spine2", "bip01 neck", "bip01 head", "bip01 l upperarm",
	"bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 l thigh", "bip01 r thigh"]
var snakes: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var target := OS.get_environment("BR_MEDUSA_OUTPUT")
	assert(not target.is_empty() and DirAccess.dir_exists_absolute(target))
	var row := Registry.entry(Donor)
	var proof := {}
	for style: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, style)
		var source_hash := FileAccess.get_sha256(source)
		assert(source_hash == row.asset_sha256[style])
		var actor := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(actor)
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 52 and rig.get_bone_name(26) == "box07")
		add_grasp(rig, "l")
		add_grasp(rig, "r")
		refit(mesh, rig, style == "original")
		var skin := Ground.skin_points(mesh, rig)
		var lib := player.get_animation_library("")
		for name: String in Fitted:
			var options: Array = Fitted[name]
			var motion := fit_grounded(player, rig, [skin], options[0], "bip01", Joints, pose_medusa.bind(options[1]))
			put(lib, name, motion)
		var compatibility := {"Idle":"MedusaIdle","ReadyStance":"MedusaIdle","Attack":"MedusaShot",
			"Attack2":"MedusaHighShot","Hit":"MedusaRecoil","Cast":"MedusaStare","Fidget":"MedusaSurvey"}
		for name: String in compatibility:
			put(lib, name, lib.get_animation(compatibility[name]).duplicate(true))
		for name: String in lib.get_animation_list():
			animate_snakes(player, rig, lib.get_animation(name), name)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var file := target.path_join("728-%s.scn" % style)
		assert(packed.pack(actor) == OK and ResourceSaver.save(packed, file, ResourceSaver.FLAG_COMPRESS) == OK)
		proof[style] = {"donor": source_hash, "scene": FileAccess.get_sha256(file), "bones": rig.get_bone_count(),
			"vertices": skin.source_vertices, "snake_locks": snakes.size() / 3}
		print("MEDUSA FIT: ", style, " / ", proof[style])
		actor.free()
	var receipt := FileAccess.open(target.path_join("fitted-scenes.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify(proof, "\t"))
	receipt.close()
	quit()


func put(library: AnimationLibrary, key: String, clip: Animation) -> void:
	if library.has_animation(key):
		library.remove_animation(key)
	assert(library.add_animation(key, clip) == OK)


func add_grasp(rig: Skeleton3D, side: String) -> void:
	var parent := rig.find_bone("bip01 %s hand" % side)
	var finger := rig.find_bone("bip01 %s finger1" % side)
	var hand := rig.get_bone_global_rest(parent)
	var grip := hand.origin.lerp(rig.get_bone_global_rest(finger).origin, .48)
	var bone := rig.get_bone_count()
	rig.add_bone("cp_grasp_%shand" % side)
	rig.set_bone_parent(bone, parent)
	rig.set_bone_rest(bone, hand.affine_inverse() * Transform3D(hand.basis, grip))


func refit(mesh: MeshInstance3D, rig: Skeleton3D, low: bool) -> void:
	snakes.clear()
	mesh.skin = mesh.skin.duplicate() as Skin
	var old := mesh.mesh
	var fitted := ArrayMesh.new()
	for surface in old.get_surface_count():
		var arrays := old.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var stride := weights.size() / vertices.size()
		var trimmed := PackedInt32Array()
		var is_wing := PackedByteArray()
		var colours := PackedColorArray()
		colours.resize(vertices.size())
		is_wing.resize(vertices.size())
		for i in vertices.size():
			var wing := 0.0
			for n in stride:
				var slot := i * stride + n
				var bone := mesh.skin.get_bind_bone(binds[slot])
				if bone < 0:
					bone = rig.find_bone(mesh.skin.get_bind_name(binds[slot]))
				if bone >= 26 and bone <= 31:
					wing += weights[slot]
			is_wing[i] = int(wing >= .46)
			var point := vertices[i]
			var centre := 1.0 - smoothstep(.18, .32, absf(point.x))
			var armour := smoothstep(.99, 1.13, point.z) * (1.0 - smoothstep(1.27, 1.42, point.z)) * centre
			var boot := 1.0 - smoothstep(.26, .49, point.z)
			var belt := (1.0 - smoothstep(.026, .070, absf(point.z - .94))) * centre
			var blue := Color(.13, .22, .41).lerp(Color(.23, .46, .52), armour)
			colours[i] = blue.lerp(Color(.65, .53, .25), maxf(boot, belt))
			vertices[i].x *= 1.0 + .085 * armour
			normals[i] = (normals[i] / Vector3(1.0 + .085 * armour, 1.0, 1.0)).normalized()
		for i in range(0, indices.size(), 3):
			if is_wing[indices[i]] + is_wing[indices[i + 1]] + is_wing[indices[i + 2]] >= 2:
				continue
			for corner in 3:
				trimmed.append(indices[i + corner])
		assert(trimmed.size() < indices.size() and not trimmed.is_empty())
		arrays[Mesh.ARRAY_INDEX] = trimmed
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var material := old.surface_get_material(surface).duplicate() as StandardMaterial3D
		material.albedo_texture = luminance_atlas(material.albedo_texture)
		configure_colour(material, .76)
		fitted.surface_set_material(fitted.get_surface_count() - 1, material)
	var sculpt := SurfaceTool.new()
	sculpt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 9:
		snake(sculpt, mesh.skin, rig, index, low)
	gear(sculpt)
	sculpt.index()
	sculpt.commit(fitted)
	var accent := StandardMaterial3D.new()
	var pixel := Image.create(2, 2, false, Image.FORMAT_RGB8)
	pixel.fill(Color(.91, .91, .91))
	accent.albedo_texture = ImageTexture.create_from_image(pixel)
	configure_colour(accent, .66)
	fitted.surface_set_material(fitted.get_surface_count() - 1, accent)
	mesh.mesh = fitted
	rig.reset_bone_poses()


func configure_colour(material: StandardMaterial3D, roughness: float) -> void:
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = roughness


func luminance_atlas(texture: Texture2D) -> ImageTexture:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var p := image.get_pixel(x, y)
			var tone := .06 + .90 * pow(maxf(p.r, maxf(p.g, p.b)), .73)
			image.set_pixel(x, y, Color(tone, tone, tone, p.a))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func snake(out: SurfaceTool, skin: Skin, rig: Skeleton3D, index: int, low: bool) -> void:
	var angle := float(index) * TAU / 9.0
	var radial := Vector3(cos(angle), sin(angle), .0)
	var sideways := Vector3(-radial.y, radial.x, .0) * (.09 if index % 2 else -.11)
	var curve := Curve3D.new()
	curve.bake_interval = .012
	curve.add_point(Vector3(.0, .016, 1.53) + radial * .088, Vector3.ZERO, radial * .060 + Vector3.BACK * .095)
	curve.add_point(Vector3(.0, .016, 1.75 + .055 * cos(angle * 2.0)) + radial * .24, -radial * .079, radial * .062 + sideways)
	curve.add_point(Vector3(.0, .016, 1.62 + .10 * sin(angle * 2.0)) + radial * .34 + sideways, -radial * .040 - sideways)
	var parent := rig.find_bone("bip01 head")
	var binding := PackedInt32Array()
	for joint in 3:
		var frame := Transform3D(Basis.IDENTITY, curve.sample_baked(curve.get_baked_length() * float(joint) / 2.0, true))
		var name := "medusa_snake_%d_%d" % [index, joint]
		var bone := rig.get_bone_count()
		rig.add_bone(name)
		rig.set_bone_parent(bone, parent)
		rig.set_bone_rest(bone, rig.get_bone_global_rest(parent).affine_inverse() * frame)
		skin.add_named_bind(name, frame.affine_inverse())
		binding.append(skin.get_bind_count() - 1)
		snakes.append({"joint": bone, "phase": float(index) * .79 + float(joint) * .45, "strength": .035 + float(joint) * .087})
		parent = bone
	tube(out, curve, binding, .025, Color(.055, .15, .29), Color(.12, .49, .60), 11 if low else 20, 7 if low else 10, true)


func tube(out: SurfaceTool, curve: Curve3D, binding: PackedInt32Array, thickness: float, dark: Color,
		light: Color, rings: int, sides: int, head: bool = false) -> void:
	var length := curve.get_baked_length()
	for ring in rings:
		for side in sides:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var phase := float(ring + corner.x) / rings
				var UV := Vector2(float(side + corner.y) / sides, phase)
				var point := curve.sample_baked(phase * length, true)
				var axis := (curve.sample_baked(minf(1.0, phase + .024) * length, true)
					- curve.sample_baked(maxf(.0, phase - .024) * length, true)).normalized()
				var across := axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < .8 else Vector3.RIGHT).normalized()
				var normal := across.rotated(axis, UV.x * TAU)
				var ratio := (1.0 - .42 * phase + .56 * exp(-pow((phase - .90) / .078, 2.0))) if head else 1.0
				ratio *= 1.0 - .94 * smoothstep(.96, 1.0, phase) if head else 1.0
				var progress := phase * (binding.size() - 1)
				var joint := mini(binding.size() - 1, floori(progress))
				var next := mini(binding.size() - 1, joint + 1)
				var blend := progress - joint
				var pigment := dark.lerp(light, .46 + normal.z * .30 + .12 * sin(phase * TAU * 7.0))
				if head and ring >= rings - 3 and side in [1, sides - 2]:
					pigment = Color(.61, .69, .32)
				vertex(out, point + normal * thickness * ratio, normal, pigment, UV, binding[joint], binding[next], blend)


func gear(out: SurfaceTool) -> void:
	var gold := Color(.63, .53, .29)
	var patina := Color(.24, .31, .27)
	var back := Vector3(-.13, .182, 1.11)
	var shield := [Vector2(-.19,.29),Vector2(.19,.29),Vector2(.19,-.025),Vector2(.12,-.17),
		Vector2(.0,-.29),Vector2(-.12,-.17),Vector2(-.19,-.025)]
	for i in shield.size():
		var a: Vector2 = shield[i]
		var b: Vector2 = shield[(i + 1) % shield.size()]
		plate(out, back + Vector3(.0,.059,.0), back + Vector3(a.x,.0,a.y), back + Vector3(b.x,.0,b.y), patina, 6)
		var sa := a * .86
		var sb := b * .86
		plate(out, back + Vector3(a.x,.008,a.y), back + Vector3(sa.x,.012,sa.y), back + Vector3(b.x,.008,b.y), gold, 6)
		plate(out, back + Vector3(sa.x,.012,sa.y), back + Vector3(sb.x,.012,sb.y), back + Vector3(b.x,.008,b.y), gold, 6)
	var quiver := Curve3D.new()
	var belt := Vector3(.11, .125, .90)
	var opening := Vector3(.23, .18, 1.43)
	quiver.add_point(belt)
	quiver.add_point(opening)
	tube(out, quiver, PackedInt32Array([6]), .078, Color(.18,.105,.07), gold, 9, 11)
	for index in 5:
		var radial := Vector3(cos(float(index)*TAU/5.0), sin(float(index)*TAU/5.0), .0)
		var arrow := Curve3D.new()
		var offset := radial * .044
		var end := opening + offset * 1.45 + Vector3(.024, .018, .14 + float(index % 3) * .025)
		arrow.add_point(opening - Vector3.BACK * .12 + offset)
		arrow.add_point(end)
		tube(out, arrow, PackedInt32Array([6]), .006, Color(.20,.15,.08), gold, 3, 4)
		plate(out, end - Vector3.BACK * .105, end + Vector3(.031,.002,-.024), end, Color(.54,.106,.070), 6)
		plate(out, end - Vector3.BACK * .105, end - Vector3(.031,-.002,.024), end, Color(.54,.106,.070), 6)


func plate(out: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, bone: int) -> void:
	var normal := (c - a).cross(b - a).normalized()
	vertex(out, a, normal, colour, Vector2(.5,.0), bone, bone, .0)
	vertex(out, b, normal, colour, Vector2(.0,1.0), bone, bone, .0)
	vertex(out, c, normal, colour, Vector2(1.0,1.0), bone, bone, .0)


func vertex(out: SurfaceTool, point: Vector3, normal: Vector3, colour: Color, uv: Vector2, a: int, b: int, blend: float) -> void:
	out.set_normal(normal)
	out.set_color(colour)
	out.set_uv(uv)
	out.set_bones(PackedInt32Array([a,b,a,a]))
	out.set_weights(PackedFloat32Array([1.0-blend,blend,.0,.0]))
	out.add_vertex(point)


func pose_medusa(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 1:
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, .037 * sin(phase * TAU))
		return
	if group in [2, 3]:
		var fall := smoothstep(.19, .99, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, fall * (1.41 if group == 2 else -.92))
		turn_world(rig, "bip01", Vector3.RIGHT, fall * (.40 if group == 2 else -1.22))
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, .35 * fall)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -.47 * fall)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.63 * fall)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.42 * fall)
		return
	var force := smoothstep(.09, .41, phase) * (1.0 - smoothstep(.60, .97, phase))
	turn_world(rig, "bip01 spine2", Vector3.UP, (.51 if group in [4, 5] else -.38) * force)
	turn_world(rig, "bip01 neck", Vector3.UP, -.41 * force if group in [4, 5] else .25 * force)
	turn_world(rig, "bip01 head", Vector3.RIGHT, (-.29 if group == 12 else .18) * force)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, (-1.32 if group in [4, 5] else -.66) * force)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, (-.72 if group in [4, 5] else -.43) * force)
	turn_world(rig, "bip01 r forearm", Vector3.UP, -.93 * force if group in [4, 5] else -.18 * force)
	if group == 5:
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, .36 * force)


func animate_snakes(player: AnimationPlayer, rig: Skeleton3D, clip: Animation, label: String) -> void:
	var prefix := player.get_node(player.root_node).get_path_to(rig)
	var death := label in ["Death", "Death2"]
	for row: Dictionary in snakes:
		var joint: int = row.joint
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("%s:%s" % [prefix, rig.get_bone_name(joint)]))
		var rest := rig.get_bone_rest(joint).basis.get_rotation_quaternion()
		for frame in 27:
			var phase := float(frame) / 26.0
			var strength: float = row.strength
			var offset: float = row.phase
			var still := 1.0 - smoothstep(.45, .96, phase) if death else 1.0
			var focus := 1.0 + .65 * sin(PI * phase) if label in ["MedusaStare", "Cast"] else 1.0
			var bend := sin(phase * TAU + offset) * strength * still * focus
			clip.rotation_track_insert_key(track, clip.length * phase,
				rest * Quaternion(Vector3.UP, bend) * Quaternion(Vector3.RIGHT, .65 * bend))
