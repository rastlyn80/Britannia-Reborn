# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Segments := 10
const Sides := 20
const Clips := {"Idle": 1.70, "Walk": 1.05, "Run": .72, "Attack": .68, "Attack2": .87, "Hit": .51,
	"Fidget": 1.38, "Death": 1.00, "Death2": 1.14, "ReadyStance": 1.45, "RotwormPeaceWalk": 1.34,
	"RotwormDuck": .65, "RotwormScan": 1.32, "RotwormReach": .92, "RotwormInspect": 1.30, "RotwormRise": .92}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var model := Node3D.new()
	var rig := Skeleton3D.new()
	rig.name = "Rig"
	model.add_child(rig)
	rig.owner = model
	var skin := Skin.new()
	var points := PackedVector3Array([Vector3.ZERO])
	var names := PackedStringArray(["__root"])
	var parents := PackedInt32Array([-1])
	for ring in Segments + 1:
		points.append(Vector3(0, .265 - .20 * pow(ring / float(Segments), 1.6), -.49 + .105 * ring))
		names.append("Mantle%d" % ring)
		parents.append(0 if ring == 0 else ring)
	for arm in 4:
		var start := points.size()
		var across := -.106 + arm * .071
		for joint in 5:
			var position: Vector3 = points[1] + Vector3(across * (1.0 + .12 * joint),
				-.005 - .015 * joint + .006 * joint * joint, -.031 - joint * (.070 + .011 * (arm % 2)))
			points.append(position)
			names.append("Tendril%d_%d" % [arm, joint])
			parents.append(1 if joint == 0 else start + joint - 1)
	for bone in points.size():
		rig.add_bone(names[bone])
		rig.set_bone_parent(bone, parents[bone])
		var rest := Transform3D(Basis.IDENTITY, points[bone])
		rig.set_bone_rest(bone, rest if bone == 0 else
			Transform3D(Basis.IDENTITY, points[bone] - points[parents[bone]]))
		skin.add_bind(bone, rest.affine_inverse())
	rig.reset_bone_poses()
	var mesh := MeshInstance3D.new()
	mesh.name = "Rotworm"
	mesh.skin = skin
	mesh.skeleton = NodePath("../Rig")
	model.add_child(mesh)
	mesh.owner = model
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.owner = model
	var library := AnimationLibrary.new()
	for clip: String in Clips:
		assert(library.add_animation(clip, motion(clip, Clips[clip], rig)) == OK)
	player.add_animation_library("", library)
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		mesh.mesh = geometry(points, style)
		var result := PackedScene.new()
		var path := folder.path_join("732-%s.scn" % style)
		assert(result.pack(model) == OK and ResourceSaver.save(result, path, ResourceSaver.FLAG_COMPRESS) == OK)
		print("ROTWORM FIT: ", style, ", ", rig.get_bone_count(), " bones, ", Clips.size(), " motions, ", FileAccess.get_sha256(path))
	model.free()
	quit(0)


func geometry(points: PackedVector3Array, style: String) -> ArrayMesh:
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	shell.set_material(material(false, style))
	for ring in Segments:
		for side in Sides:
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var section := ring + offset.x
				var fraction := section / float(Segments)
				var angle := (side + offset.y) * TAU / Sides
				var radius := (.05 + .22 * pow(1.0 - fraction, .84)) * (.96 + .04 * cos(section * PI))
				if section == 0:
					radius *= .62
				elif section == Segments:
					radius *= .15
				var normal := Vector3(cos(angle), sin(angle), .2 * fraction).normalized()
				var point := points[section + 1] + Vector3(normal.x * radius, normal.y * radius * .70, 0)
				vertex(shell, point, normal, Vector2((side + offset.y) / float(Sides), fraction), section + 1)
	close_end(shell, points[1], (.05 + .22) * 1.0 * .62, 1, 0.0, true)
	close_end(shell, points[Segments + 1], .05 * .15, Segments + 1, 1.0, false)
	shell.index()
	var output := shell.commit()
	var arms := SurfaceTool.new()
	arms.begin(Mesh.PRIMITIVE_TRIANGLES)
	arms.set_material(material(true, style))
	for arm in 4:
		for section in 4:
			for side in 8:
				for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
						Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
					var joint := section + offset.x
					var angle := (side + offset.y) * TAU / 8
					var radius := lerpf(.030, .007, joint / 4.0)
					var normal := Vector3(cos(angle), sin(angle), 0)
					var bone := Segments + 2 + arm * 5 + joint
					vertex(arms, points[bone] + normal * radius, normal,
						Vector2((side + offset.y) / 8.0, joint / 4.0), bone)
	arms.index()
	arms.commit(output)
	return output


func close_end(surface: SurfaceTool, center: Vector3, radius: float, bone: int, uv_y: float, mouth: bool) -> void:
	var normal := Vector3.FORWARD if mouth else Vector3.BACK
	for side in Sides:
		vertex(surface, center + normal * radius * .27, normal, Vector2(.5, uv_y), bone)
		for index: int in ([side, side + 1] if mouth else [side + 1, side]):
			var fraction := index / float(Sides)
			var angle := fraction * TAU
			var point := center + Vector3(cos(angle) * radius, sin(angle) * radius * .70, 0)
			vertex(surface, point, normal, Vector2(fraction, uv_y), bone)


func vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, uv: Vector2, binding: int) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.set_bones(PackedInt32Array([binding, 0, 0, 0]))
	surface.set_weights(PackedFloat32Array([1, 0, 0, 0]))
	surface.add_vertex(point)


func material(flesh: bool, style: String) -> StandardMaterial3D:
	var texture := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 732
	noise.frequency = .105
	for y in texture.get_height():
		for x in texture.get_width():
			var angle := x * TAU / texture.get_width()
			var belly := smoothstep(.15, .94, -sin(angle))
			var tint := Color("#625a4b").lerp(Color("#d9aa8b"), belly)
			if flesh:
				tint = Color("#b76558").lerp(Color("#e9aa8c"), (.5 + .5 * cos(angle)) * .6)
			var strength := .30 if style == "modern" else .19
			var fleck := noise.get_noise_3d(cos(angle) * 19, sin(angle) * 19, y)
			var rib := .92 + .08 * cos(y * TAU * Segments / texture.get_height())
			var multiplier := rib * (1.0 + strength * fleck)
			texture.set_pixel(x, y, Color(tint.r * multiplier, tint.g * multiplier, tint.b * multiplier))
	texture.generate_mipmaps()
	var result := StandardMaterial3D.new()
	result.albedo_texture = ImageTexture.create_from_image(texture)
	result.roughness = .89
	return result


func motion(clip: String, duration: float, rig: Skeleton3D) -> Animation:
	var anim := Animation.new()
	anim.length = duration
	anim.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Walk", "Run", "ReadyStance", "RotwormPeaceWalk"] else Animation.LOOP_NONE
	for bone in rig.get_bone_count():
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("Rig:" + rig.get_bone_name(bone)))
		var position := -1
		if bone == 0:
			position = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(position, NodePath("Rig:__root"))
		for frame in 61:
			var phase := frame / 60.0
			var time := phase * duration
			var shape := pose(clip, bone, phase)
			anim.rotation_track_insert_key(track, time, Quaternion.from_euler(shape.rotation))
			if position >= 0:
				anim.position_track_insert_key(position, time, Vector3(0, shape.lift, 0))
	return anim


func pose(clip: String, bone: int, phase: float) -> Dictionary:
	var rhythm := phase * TAU
	var pulse := smoothstep(.11, .40, phase) * (1.0 - smoothstep(.53, .94, phase))
	var falling := clip in ["Death", "Death2"]
	var roll := smoothstep(.17, .80, phase) if falling else 0.0
	var advancing := clip in ["Walk", "Run", "RotwormPeaceWalk"]
	var reach := pulse if clip in ["Attack", "Attack2", "RotwormReach"] else 0.0
	var snap := pulse if clip in ["Hit", "RotwormDuck"] else 0.0
	var lift := 0.0
	var rotation := Vector3.ZERO
	if bone == 0:
		rotation.z = 2.6 * roll if clip == "Death" else -.62 * roll
		rotation.x = .085 * pulse if clip in ["RotwormRise", "RotwormScan"] else 0.0
		lift = .011 * sin(rhythm * 2.0) if advancing else .0
	elif bone < Segments + 2:
		var segment := float(bone - 1)
		var amplitude := (.14 if clip == "Run" else .09) if advancing else .032
		rotation.y = amplitude * sin(rhythm - .57 * segment)
		rotation.x = sin(rhythm - .43 * segment) * amplitude * .54 - .09 * snap
		if bone < 4:
			rotation.x += (-.21 if clip == "Attack" else -.10) * reach
		rotation.y += roll * (.05 if clip == "Death" else -.13)
	else:
		var index := bone - (Segments + 2)
		var arm := floori(index / 5.0)
		var joint := index % 5
		rotation.x = .17 * sin(rhythm + .62 * joint + .71 * arm) * (0.3 if falling else 1.0)
		rotation.x -= reach * (.58 if clip == "Attack" else -.51)
		rotation.x += .45 * snap + .28 * roll
		rotation.y = (.12 * sin(rhythm + arm) + reach * .28) * (1.0 if arm < 2 else -1.0)
		if clip == "Death2":
			rotation.x -= .40 * roll
		elif clip == "RotwormInspect":
			rotation.y += (1.0 if arm < 2 else -1.0) * .45 * pulse
	return {"rotation": rotation, "lift": lift}
