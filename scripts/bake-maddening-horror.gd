# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Donor := 24
const Styles := ["original", "rounded", "modern"]
const Gestures := {
	"HorrorReach": [.78, 4], "HorrorSweep": [.90, 5], "HorrorDrain": [1.24, 12],
	"HorrorGuard": [.70, 15], "HorrorTurn": [.88, 26], "HorrorThreat": [.86, 27],
	"HorrorRecoil": [.58, 10], "HorrorIdle": [1.75, 1],
	"Death": [1.35, 2], "Death2": [1.55, 3],
}
const BodyJoints := [
	"bip01", "bip01 spine1", "bip01 spine2", "bip01 head", "bip01 l upperarm",
	"bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
]
var tendrils: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var folder := OS.get_environment("BR_MADDENING_HORROR_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	var donor := Registry.entry(Donor)
	var proofs := {}
	for style: String in Styles:
		var path := Registry.asset_path(donor, style)
		var input := FileAccess.get_sha256(path)
		assert(input == donor.asset_sha256[style])
		var host := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(host)
		var rig := host.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := host.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var animator := host.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 36 and mesh.mesh.get_surface_count() == 1)
		refit_model(mesh, rig, style == "original")
		var skin := Ground.skin_points(mesh, rig)
		var library := animator.get_animation_library("")
		for name: String in Gestures:
			var options: Array = Gestures[name]
			var motion := fit_grounded(animator, rig, [skin], options[0], "bip01", BodyJoints, pose_body.bind(options[1]))
			put(library, name, motion)
		put(library, "Idle", library.get_animation("HorrorIdle").duplicate(true))
		put(library, "ReadyStance", library.get_animation("HorrorIdle").duplicate(true))
		for name: String in ["Walk", "Run"]:
			var motion := library.get_animation(name).duplicate(true) as Animation
			ground_gait(animator, rig, skin, motion, name)
			put(library, name, motion)
		for name: String in ["Attack", "Attack2", "Hit", "Fidget", "Cast", "Pillage"]:
			var fitted: String = {"Attack":"HorrorReach","Attack2":"HorrorSweep","Hit":"HorrorRecoil",
				"Fidget":"HorrorTurn","Cast":"HorrorDrain","Pillage":"HorrorThreat"}[name]
			put(library, name, library.get_animation(fitted).duplicate(true))
		for name: String in library.get_animation_list():
			animate_tendrils(animator, rig, library.get_animation(name), name)
		animator.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("721-%s.scn" % style)
		assert(packed.pack(host) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		proofs[style] = {"donor": input, "scene": FileAccess.get_sha256(target),
			"donor_bones": 36, "bones": rig.get_bone_count(), "tendrils": tendrils.size() / 4, "vertices": skin.source_vertices}
		print("HORROR FIT: ", style, " / ", proofs[style])
		host.free()
	var report := FileAccess.open(folder.path_join("fitted-scenes.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(proofs, "\t"))
	report.close()
	quit()


func put(library: AnimationLibrary, name: String, motion: Animation) -> void:
	if library.has_animation(name):
		library.remove_animation(name)
	assert(library.add_animation(name, motion) == OK)


func refit_model(mesh: MeshInstance3D, rig: Skeleton3D, low: bool) -> void:
	tendrils.clear()
	mesh.skin = mesh.skin.duplicate() as Skin
	var original := mesh.mesh
	var fitted := ArrayMesh.new()
	var arrays := original.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var colours := PackedColorArray()
	colours.resize(positions.size())
	var head_piece := PackedByteArray()
	head_piece.resize(positions.size())
	for i in positions.size():
		var point := positions[i]
		var head := smoothstep(1.48, 1.70, point.z) * (1.0 - smoothstep(.26, .47, absf(point.x)))
		var crown := smoothstep(1.64, 1.75, point.z) * head
		head_piece[i] = int(point.z > 1.635 and absf(point.x) < .43)
		var hem := (1.0 - smoothstep(.08, .69, point.z)) * (1.0 - smoothstep(.29, .46, absf(point.x)))
		var modifier := Vector3(1.0 + .12 * head - .22 * crown + .24 * hem, 1.0 - .5 * crown, 1.0)
		point *= modifier
		point.z -= maxf(0.0, point.z - 1.62) * .93 * crown
		point.z += .14 * (1.0 - smoothstep(.04, .25, point.z))
		positions[i] = point
		normals[i] = (normals[i] / modifier).normalized()
		if not tangents.is_empty():
			var at := i * 4
			var tangent := Vector3(tangents[at], tangents[at + 1], tangents[at + 2]) * modifier
			tangent = (tangent - normals[i] * tangent.dot(normals[i])).normalized()
			tangents[at] = tangent.x
			tangents[at + 1] = tangent.y
			tangents[at + 2] = tangent.z
		var hand := smoothstep(.62, .90, absf(point.x))
		var trim := (1.0 - smoothstep(.10, .29, point.z)) * (1.0 - smoothstep(.33, .55, absf(point.x)))
		var robe := Color(.49, .14, .116).lerp(Color(.79, .72, .63), trim * .87)
		colours[i] = robe.lerp(Color(.79, .80, .64), maxf(head * .95, hand * .94))
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colours
	var robe_triangles := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		if head_piece[indices[i]] or head_piece[indices[i + 1]] or head_piece[indices[i + 2]]:
			continue
		robe_triangles.append(indices[i])
		robe_triangles.append(indices[i + 1])
		robe_triangles.append(indices[i + 2])
	arrays[Mesh.ARRAY_INDEX] = robe_triangles
	fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var fabric := original.surface_get_material(0).duplicate() as StandardMaterial3D
	fabric.albedo_texture = diffuse_atlas(fabric.albedo_texture)
	fabric.vertex_color_use_as_albedo = true
	fabric.vertex_color_is_srgb = true
	fabric.albedo_color = Color.WHITE
	fabric.roughness = .89
	fitted.surface_set_material(0, fabric)

	var tubes := SurfaceTool.new()
	tubes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var radial := Vector3(cos(angle), sin(angle), .0)
		var swing := Vector3(-sin(angle), cos(angle), .0) * (.18 if i % 2 == 0 else -.22)
		var path := Curve3D.new()
		path.add_point(radial * .17 + Vector3(0, 0, .31), Vector3.ZERO, radial * .18 - Vector3.UP * .07)
		path.add_point(radial * .44 + Vector3(0, 0, .13), -radial * .13, radial * .14 + swing)
		path.add_point(radial * (.75 if i % 2 == 0 else .65) + swing + Vector3(0, 0, .14), -radial * .10 - swing, Vector3.ZERO)
		add_tube(tubes, mesh.skin, rig, path, 3, .073, i, false, low)
	for i in 6:
		var spread := (float(i) - 2.5) / 2.5
		var path := Curve3D.new()
		path.add_point(Vector3(spread * .061, -.125, 1.68), Vector3.ZERO, Vector3(spread * .05, -.08, -.08))
		path.add_point(Vector3(spread * .16, -.24, 1.43), Vector3(-spread * .05, .03, .05), Vector3(spread * .05, -.02, -.07))
		path.add_point(Vector3(spread * .25, -.26 + absf(spread) * .11, 1.24 + absf(spread) * .12))
		add_tube(tubes, mesh.skin, rig, path, 8, .032, i, true, low)
	tubes.index()
	tubes.commit(fitted)
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = white_texture()
	skin.vertex_color_use_as_albedo = true
	skin.vertex_color_is_srgb = true
	skin.roughness = .76
	fitted.surface_set_material(1, skin)
	var skull := SurfaceTool.new()
	skull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 18:
		for side in 24:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var latitude := (float(ring + corner.x) / 18.0 - .5) * PI
				var longitude := TAU * float(side + corner.y) / 24.0
				var outward := Vector3(cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
				var size := Vector3(.119, .137, .153)
				var bone_tint := Color(.71, .76, .63).lerp(Color(.86, .86, .73), pow(maxf(0.0, outward.z), .6))
				var socket := smoothstep(.35, .73, -outward.y) * (1.0 - smoothstep(.12, .31, absf(outward.z - .05)))
				socket *= 1.0 - smoothstep(.15, .41, absf(absf(outward.x) - .37))
				skull.set_normal((outward / size).normalized())
				skull.set_color(bone_tint.lerp(Color(.30, .33, .25), socket * .72))
				skull.set_uv(Vector2(float(side + corner.y) / 24.0, float(ring + corner.x) / 18.0))
				skull.set_bones(PackedInt32Array([8, 8, 8, 8]))
				skull.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				skull.add_vertex(Vector3(.0, -.051, 1.652) + outward * size)
	skull.index()
	skull.commit(fitted)
	fitted.surface_set_material(2, skin)
	mesh.mesh = fitted
	rig.reset_bone_poses()


func add_tube(surface: SurfaceTool, skin: Skin, rig: Skeleton3D, curve: Curve3D, parent: int,
		radius: float, index: int, face: bool, low: bool) -> void:
	curve.bake_interval = .018
	var chain := PackedInt32Array()
	var parent_joint := parent
	var stem := "face" if face else "hem"
	for joint in 4:
		var at := curve.sample_baked(curve.get_baked_length() * float(joint) / 3.0, true)
		var wanted := Transform3D(Basis.IDENTITY, at)
		var name := "horror_%s_%d_%d" % [stem, index, joint]
		rig.add_bone(name)
		var bone := rig.get_bone_count() - 1
		rig.set_bone_parent(bone, parent_joint)
		rig.set_bone_rest(bone, rig.get_bone_global_rest(parent_joint).affine_inverse() * wanted)
		skin.add_named_bind(name, wanted.affine_inverse())
		chain.append(skin.get_bind_count() - 1)
		tendrils.append({"joint": bone, "phase": float(index) * .86 + float(joint) * .39,
			"amplitude": float(joint) / 3.0 * (.16 if face else .24), "face": face})
		parent_joint = bone
	var sides := 7 if low else 10
	var rings := 14 if low else 22
	for ring in rings:
		for side in sides:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				tube_vertex(surface, curve, chain, radius, float(ring + corner.x) / rings,
					float(side + corner.y) / sides, face, index)


func tube_vertex(surface: SurfaceTool, curve: Curve3D, bends: PackedInt32Array, width: float,
		fraction: float, angle: float, face: bool, index: int) -> void:
	var length := curve.get_baked_length()
	var position := curve.sample_baked(fraction * length, true)
	var axis := (curve.sample_baked(minf(1.0, fraction + .02) * length, true)
		- curve.sample_baked(maxf(.0, fraction - .02) * length, true)).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.UP)) > .8 else Vector3.UP).normalized()
	var normal := side.rotated(axis, angle * TAU)
	var radius := width * lerpf(.95, .04, pow(fraction, 1.5))
	var progress := fraction * 3.0
	var bone := mini(2, floori(progress))
	var fade := progress - bone
	var underside := .5 + normal.z * .5
	var pigment := Color(.28, .34, .20).lerp(Color(.63, .67, .38), underside * .45 + .47 * fraction)
	if face:
		pigment = pigment.lightened(.12)
	var bands := .93 + .07 * sin(fraction * 54.0 + index * 1.8)
	surface.set_normal(normal)
	surface.set_color(Color(pigment.r * bands, pigment.g * bands, pigment.b * bands))
	surface.set_uv(Vector2(angle, fraction))
	surface.set_bones(PackedInt32Array([bends[bone], bends[bone + 1], bends[bone], bends[bone]]))
	surface.set_weights(PackedFloat32Array([1.0 - fade, fade, .0, .0]))
	surface.add_vertex(position + normal * radius)


func diffuse_atlas(texture: Texture2D) -> ImageTexture:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var source := image.get_pixel(x, y)
			var gain := .10 + pow(maxf(source.r, maxf(source.g, source.b)), .72) * .87
			image.set_pixel(x, y, Color(gain, gain, gain, source.a))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func white_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color(.9, .9, .9))
	return ImageTexture.create_from_image(image)


func pose_body(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 1:
		var breathe := sin(phase * TAU)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, .045 * breathe)
		turn_world(rig, "bip01 head", Vector3.UP, .07 * breathe)
		return
	if group in [2, 3]:
		var lean := smoothstep(.19, .93, phase)
		var facing := 1.0 if group == 2 else -1.0
		turn_world(rig, "bip01", Vector3.FORWARD, facing * (1.44 if group == 2 else .87) * lean)
		turn_world(rig, "bip01", Vector3.RIGHT, (.36 if group == 2 else -1.13) * lean)
		turn_world(rig, "bip01 head", Vector3.RIGHT, .30 * lean)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.48 * lean)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.74 * lean)
		return
	var effort := smoothstep(.12, .41, phase) * (1.0 - smoothstep(.55, .98, phase))
	var windup := .16 * sin(phase * TAU)
	var direction := -1.0 if group in [5, 10, 26] else 1.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (.32 if group == 10 else -.24) * effort)
	turn_world(rig, "bip01 spine2", Vector3.UP, .38 * direction * effort)
	turn_world(rig, "bip01 head", Vector3.UP, -.24 * direction * effort)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -(1.08 if group in [4, 12, 15] else .57) * effort + windup)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -(1.12 if group in [5, 12, 27] else .51) * effort - windup)
	turn_world(rig, "bip01 l forearm", Vector3.UP, .27 * effort)
	turn_world(rig, "bip01 r forearm", Vector3.UP, -.34 * effort)


func ground_gait(animator: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, motion: Animation, name: String) -> void:
	var path := NodePath("%s:bip01" % animator.get_node(animator.root_node).get_path_to(rig))
	var track := motion.find_track(path, Animation.TYPE_POSITION_3D)
	if track < 0:
		track = motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(track, path)
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
	var joint := rig.find_bone("bip01")
	animator.play(name, .0)
	animator.advance(.0)
	for frame in 41:
		var time := motion.length * float(frame) / 40.0
		animator.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var hip := rig.get_bone_global_pose(joint)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (.005 - gap)
		rig.set_bone_global_pose(joint, hip)
		motion.position_track_insert_key(track, time, rig.get_bone_pose_position(joint))


func animate_tendrils(animator: AnimationPlayer, rig: Skeleton3D, motion: Animation, label: String) -> void:
	var prefix := animator.get_node(animator.root_node).get_path_to(rig)
	var falling := label in ["Death", "Death2"]
	var walking := label in ["Walk", "Run"]
	for tendril: Dictionary in tendrils:
		var joint: int = tendril.joint
		var track := motion.add_track(Animation.TYPE_ROTATION_3D)
		motion.track_set_path(track, NodePath("%s:%s" % [prefix, rig.get_bone_name(joint)]))
		var rest := rig.get_bone_rest(joint).basis.get_rotation_quaternion()
		for frame in 25:
			var phase := float(frame) / 24.0
			var power: float = tendril.amplitude
			var offset: float = tendril.phase
			var still := 1.0 - smoothstep(.42, 1.0, phase) if falling else 1.0
			var wave := sin(phase * TAU + offset) * power * still
			var surge := sin(PI * phase) * power * .55 if walking else .0
			var twist := Quaternion(Vector3.FORWARD, wave + surge) * Quaternion(Vector3.UP, wave * .58)
			motion.rotation_track_insert_key(track, motion.length * phase, rest * twist)
