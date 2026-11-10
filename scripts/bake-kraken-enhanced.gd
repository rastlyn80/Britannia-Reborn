# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const CompactOutput := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/kraken-compact-%s.scn"
const Actions := {23: "KrakenSurface", 25: "KrakenPoise", 26: "KrakenScan", 27: "KrakenFinThrust", 28: "KrakenAlert"}
const FrameCounts := {23: 11, 25: 11, 26: 11, 27: 10, 28: 11}
const RingCount := 18
const Sides := 12

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(77)
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		bake(source, treatment)
	quit()

func bake(source: String, treatment: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	if treatment == "modern":
		compact_skin(mesh, rig)
		compact_clips(library)
		var result := mesh.mesh as ArrayMesh
		var mantle := membrane_material(false)
		var fins := membrane_material(true)
		add_mantle(result, mesh.skin, rig, mantle)
		for side: String in ["l", "r"]:
			add_fin(result, mesh.skin, rig, side, ["thigh", "calf", "foot"], false)
			add_fin(result, mesh.skin, rig, side, ["toe0", "toe01", "toe02"], true)
			add_fin(result, mesh.skin, rig, side, ["toe1", "toe11", "toe12"], true)
		for surface in range(2, result.get_surface_count()):
			result.surface_set_material(surface, fins)
	for group: int in Actions:
		fit_action(player, rig, group)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, CompactOutput % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	print("KRAKEN COMPACT ", treatment, ": ", rig.get_bone_count(), " retained bones, ", mesh.mesh.get_surface_count(), " surfaces, ", Actions.size(), " fitted clips")
	model.free()

func length_factor(name: String) -> float:
	if name.ends_with(" calf"):
		return .73
	if name.ends_with(" foot"):
		return .67
	if name.ends_with(" toe01") or name.ends_with(" toe11"):
		return .54
	if name.ends_with(" toe02") or name.ends_with(" toe12"):
		return .49
	return 1.0

func compact_position(name: String, position: Vector3) -> Vector3:
	if name.ends_with(" thigh"):
		position.x += .38
	return position * length_factor(name)

func compact_skin(mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var prior: Array[Vector3] = []
	for bone in rig.get_bone_count():
		prior.append(rig.get_bone_global_rest(bone).origin)
	for bone in rig.get_bone_count():
		var rest := rig.get_bone_rest(bone)
		var position := compact_position(rig.get_bone_name(bone), rest.origin)
		if position != rest.origin:
			rest.origin = position
			rig.set_bone_rest(bone, rest)
	var skin := mesh.skin.duplicate() as Skin
	var changes: Array[Vector3] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(skin.get_bind_name(bind))
		assert(bone >= 0)
		var shift := rig.get_bone_global_rest(bone).origin - prior[bone]
		changes.append(shift)
		skin.set_bind_pose(bind, skin.get_bind_pose(bind) * Transform3D(Basis.IDENTITY, -shift))
	mesh.skin = skin
	var remapped := ArrayMesh.new()
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := joints.size() / points.size()
		assert(stride == 4)
		for point in points.size():
			var displacement := Vector3.ZERO
			for slot in stride:
				var offset := point * stride + slot
				displacement += changes[joints[offset]] * weights[offset]
			points[point] += displacement
		arrays[Mesh.ARRAY_VERTEX] = points
		remapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		remapped.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
	mesh.mesh = remapped

func compact_clips(library: AnimationLibrary) -> void:
	for name in library.get_animation_list():
		var clip := library.get_animation(name)
		for track in clip.get_track_count():
			if clip.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var bone := str(clip.track_get_path(track).get_subname(0))
			for key in clip.track_get_key_count(track):
				var value: Vector3 = clip.track_get_key_value(track, key)
				var position := compact_position(bone, value)
				if position != value:
					clip.track_set_key_value(track, key, position)

func add_mantle(mesh: ArrayMesh, skin: Skin, rig: Skeleton3D, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := find_bind(skin, rig, "bip01 pelvis")
	var front := find_bind(skin, rig, "bip01 spine1")
	for ring in RingCount + 1:
		var t := float(ring) / RingCount
		var center := Vector3(0.0, lerpf(.73, -1.84, t), -.66 + .11 * t)
		var fullness := 1.0 - pow(t, 2.1)
		var width := .035 + .47 * fullness
		var depth := .018 + .28 * fullness
		var mix := 1.0 - smoothstep(0.0, .48, t)
		for sector in Sides + 1:
			var angle := TAU * sector / Sides
			var ribs := 1.0 + .032 * sin(t * 16.0 * PI) * sin(t * PI)
			var dorsal := maxf(0.0, sin(angle)) ** 12.0
			var ridge := .24 * dorsal * fullness * pow(maxf(0.0, sin(t * 10.0 * PI)), .65)
			tool.set_bones(PackedInt32Array([front, back, 0, 0]))
			tool.set_weights(PackedFloat32Array([mix, 1.0 - mix, 0.0, 0.0]))
			tool.set_normal(Vector3(cos(angle) / width, 0.0, sin(angle) / depth).normalized())
			tool.set_uv(Vector2(.346 + t * .15, .16 + float(sector) / Sides * .28))
			tool.add_vertex(center + Vector3(cos(angle) * width * ribs, 0.0, sin(angle) * depth * ribs + ridge))
	stitch(tool)
	tool.set_material(material)
	tool.commit(mesh)

func add_fin(mesh: ArrayMesh, skin: Skin, rig: Skeleton3D, side: String, names: Array, blade: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var binds := PackedInt32Array()
	var points := PackedVector3Array()
	for label: String in names:
		var bind := find_bind(skin, rig, "bip01 %s %s" % [side, label])
		binds.append(bind)
		points.append(skin.get_bind_pose(bind).affine_inverse().origin)
	var tail := (points[2] - points[1]).normalized()
	var end := points[2] + tail * (.21 if blade else .05)
	var axis := (end - points[0]).normalized()
	var broad := axis.cross(Vector3.FORWARD).normalized()
	var normal := broad.cross(axis).normalized()
	for ring in RingCount + 1:
		var t := float(ring) / RingCount
		var center := points[0].bezier_interpolate(points[1], points[2] - tail * .19, end, t)
		var flare := smoothstep(.19, .67, t) * (1.0 - smoothstep(.72, 1.0, t))
		var width := lerpf(.11, .008, t) + (.32 if blade else .11) * flare
		var depth := lerpf(.090, .007, t) + (.018 if blade else .081) * sin(PI * t)
		var joint := 0 if t < .47 else 1
		var mix := smoothstep(0.0, .47, t) if joint == 0 else smoothstep(.47, .95, t)
		for sector in Sides + 1:
			var angle := TAU * sector / Sides
			var rib := 1.0 + .12 * cos(3.0 * angle) * flare if blade else 1.0
			var rake := -absf(cos(angle)) * flare * .15 if blade else 0.0
			tool.set_bones(PackedInt32Array([binds[joint], binds[joint + 1], 0, 0]))
			tool.set_weights(PackedFloat32Array([1.0 - mix, mix, 0.0, 0.0]))
			tool.set_normal((broad * cos(angle) / width + normal * sin(angle) / depth).normalized())
			tool.set_uv(Vector2(.346 + t * .15, .16 + float(sector) / Sides * .28))
			tool.add_vertex(center + broad * cos(angle) * width * rib + normal * sin(angle) * depth + axis * rake)
	stitch(tool)
	tool.commit(mesh)

func find_bind(skin: Skin, rig: Skeleton3D, name: String) -> int:
	var joint := rig.find_bone(name)
	assert(joint >= 0)
	for bind in skin.get_bind_count():
		if skin.get_bind_bone(bind) == joint or skin.get_bind_name(bind) == name:
			return bind
	assert(false, "Missing skin bind: " + name)
	return -1

func stitch(tool: SurfaceTool) -> void:
	for ring in RingCount:
		for sector in Sides:
			var a := ring * (Sides + 1) + sector
			var b := a + Sides + 1
			for index: int in [a, a + 1, b, b, a + 1, b + 1]:
				tool.add_index(index)
	tool.generate_tangents()

func membrane_material(fin: bool) -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = .10
	var dark := Color("483429") if fin else Color("423b2e")
	var pale := Color("9bada1") if fin else Color("677b66")
	for y in 128:
		for x in 128:
			var t := smoothstep(.33, .48, float(x) / 128.0)
			var grain := noise.get_noise_2d(float(x), float(y))
			var rib := sin(float(y) * .35 + 1.8 * grain)
			var colour := dark.lerp(pale, clampf(t * .73 + .15 * grain + .07 * rib, 0.0, 1.0))
			image.set_pixel(x, y, colour)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = .59
	return material

func fit_action(player: AnimationPlayer, rig: Skeleton3D, group: int) -> void:
	var library := player.get_animation_library("")
	var idle := library.get_animation("Idle")
	var action := Animation.new()
	action.length = float(FrameCounts[group] - 1) * .10
	var positions: Array[int] = []
	var rotations: Array[int] = []
	var path := player.get_node(player.root_node).get_path_to(rig)
	for bone in rig.get_bone_count():
		var channel := NodePath("%s:%s" % [path, rig.get_bone_name(bone)])
		var position := action.add_track(Animation.TYPE_POSITION_3D)
		action.track_set_path(position, channel)
		positions.append(position)
		var rotation := action.add_track(Animation.TYPE_ROTATION_3D)
		action.track_set_path(rotation, channel)
		rotations.append(rotation)
	player.play("Idle", 0.0)
	for i in FrameCounts[group]:
		var time := float(i) * .10
		player.seek(minf(time, idle.length), true)
		rig.force_update_all_bone_transforms()
		fit_pose(rig, group, float(i) / float(FrameCounts[group] - 1))
		for bone in rig.get_bone_count():
			action.position_track_insert_key(positions[bone], time, rig.get_bone_pose_position(bone))
			action.rotation_track_insert_key(rotations[bone], time, rig.get_bone_pose_rotation(bone))
	assert(library.add_animation(Actions[group], action) == OK)

func fit_pose(rig: Skeleton3D, group: int, phase: float) -> void:
	var spread := .65
	var lift := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var roll := 0.0
	var kick := 0.0
	var stagger := 0.0
	var pulse := sin(PI * phase)
	match group:
		23:
			var opening := smoothstep(.14, .76, phase)
			var rise := smoothstep(.25, .79, phase)
			spread = lerpf(.06, 1.0, opening)
			pitch = lerpf(-.40, .19, rise) - smoothstep(.81, 1.0, phase) * .11
			lift = lerpf(-.65, .28, rise)
			kick = .58 * sin(TAU * (phase - .35)) * opening
		25:
			lift = .035 * sin(TAU * phase)
			spread -= .06 * pulse
		26:
			yaw = .28 * pulse
			pitch = .13 * pulse
			stagger = .13 * pulse
		27:
			var thrust := smoothstep(.23, .64, phase) * (1.0 - smoothstep(.69, 1.0, phase))
			pitch = .24 * thrust
			kick = .84 * thrust
			spread = .54 + .47 * thrust
			lift = .22 * thrust
		28:
			stagger = .43 * sin(TAU * phase)
			roll = .18 * pulse
			pitch = -.09 * pulse
			kick = .23 * pulse
			spread = .65 + .18 * pulse
	var body := rig.find_bone("bip01")
	var pose := rig.get_bone_global_pose(body)
	pose.origin.z += lift
	pose.basis = Basis.from_euler(Vector3(pitch, roll, yaw)) * pose.basis
	rig.set_bone_global_pose(body, pose)
	rig.force_update_all_bone_transforms()
	for side: String in ["l", "r"]:
		var sign_side := -1.0 if side == "l" else 1.0
		var side_kick := kick + stagger * sign_side
		aim(rig, side, "thigh", "calf", Vector3(sign_side * (.20 + .66 * spread), .25 - .20 * spread, -.93))
		aim(rig, side, "calf", "foot", Vector3(sign_side * (.08 + .52 * spread), .28 + side_kick, -.85 + .62 * side_kick))
		aim(rig, side, "toe0", "toe01", Vector3(sign_side * (.10 + .49 * spread), -.88 + .24 * side_kick, -.16))
		aim(rig, side, "toe1", "toe11", Vector3(sign_side * (.04 + .23 * spread), -.91 - .24 * side_kick, .12))
		aim(rig, side, "toe01", "toe02", Vector3(sign_side * (.14 + .54 * spread), -.75, .19 + .18 * side_kick))
		aim(rig, side, "toe11", "toe12", Vector3(sign_side * (.06 + .21 * spread), -.87, .23 + .21 * side_kick))

func aim(rig: Skeleton3D, side: String, joint: String, child: String, direction: Vector3) -> void:
	var bone := rig.find_bone("bip01 %s %s" % [side, joint])
	var endpoint := rig.find_bone("bip01 %s %s" % [side, child])
	var pose := rig.get_bone_global_pose(bone)
	var ahead := (rig.get_bone_global_pose(endpoint).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(ahead, direction.normalized())) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
