# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Grounding := preload("res://../scripts/CreatureMeshBindingFloor.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const OUTPUT := "res://local-art/creatures/next-spell-forms/"
const TREATMENTS := ["original", "rounded", "modern"]
const RING_POINTS := 10
const REAPER_SCALE := Vector3(.93, 1.10, .80)
const POSE_JOINTS := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 l thigh", "bip01 r thigh",
	"bip01 l calf", "bip01 r calf", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand", "bip01 l foot", "bip01 r foot"]

func _initialize() -> void:
	create_timer(220.).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if Registry.entry(285).has("fitted_spell_form_source") or Registry.entry(705).has("fitted_spell_form_source"):
		push_error("Bake the fitted spell forms in a staging viewer with only the donor assets registered")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var preview := "--preview" in OS.get_cmdline_user_args()
	var treatments := ["modern"] if preview else TREATMENTS
	for body: int in [285, 705]:
		var donor := Registry.entry(301 if body == 285 else 14)
		for treatment: String in treatments:
			var model: Node3D = load(donor.assets[treatment]).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var original := mesh.mesh as ArrayMesh
			rig.reset_bone_poses()
			rig.force_update_all_bone_transforms()
			mesh.mesh = copy_body(original, mesh, rig, body == 285)
			var shell := SurfaceTool.new()
			shell.begin(Mesh.PRIMITIVE_TRIANGLES)
			shell.set_smooth_group(0)
			if body == 285:
				fit_boughs(shell, mesh, rig)
				model.scale = REAPER_SCALE
			else:
				fit_stone_joints(shell, mesh, rig)
				model.scale = Vector3(0.88, 0.90, 1.05)
			shell.generate_normals()
			shell.generate_tangents()
			shell.set_material(original.surface_get_material(0))
			shell.commit(mesh.mesh)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			if body == 285:
				fit_reaper_actions(player, rig, mesh)
			else:
				fit_stone_actions(player, rig, mesh)
			if not preview: Grounding.fit_source_floor(model)
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := OUTPUT + "%d-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			print("FORM FIT ", body, " ", treatment, " ", mesh.mesh.get_surface_count(), " surfaces ", output)
			model.free()
	quit()

func fit_reaper_actions(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D) -> void:
	# anim5 group 2 falls back after both branches lift. Group 3
	# goes forward with the roots visibly raised at impact.
	bake_pose(player, rig, mesh, "ReaperFallBack", "Idle", .72,
		func(phase: float) -> void: fall_pose(rig, phase, -1.55, true), true)
	bake_pose(player, rig, mesh, "ReaperFallForward", "Idle", .72,
		func(phase: float) -> void: fall_pose(rig, phase, 1.63, true), true)
	bake_pose(player, rig, mesh, "ReaperSideRake", "Attack2", .74,
		func(phase: float) -> void: reaper_rake(rig, phase, false))
	bake_pose(player, rig, mesh, "ReaperDownRake", "Attack2", .68,
		func(phase: float) -> void: reaper_rake(rig, phase, true))
	bake_pose(player, rig, mesh, "ReaperLowGuard", "Idle", .54,
		func(phase: float) -> void:
			var dip := action_peak(phase, .39)
			rotate_world(rig, "bip01 spine1", Vector3.RIGHT, .16 * dip)
			rotate_world(rig, "bip01 l upperarm", Vector3.RIGHT, .20 * dip)
			rotate_world(rig, "bip01 r upperarm", Vector3.RIGHT, .27 * dip))
	# The death presenter and standalone corpse resolve the default fall
	# by this animation name. Keep the alternative as its own Classic route.
	var library := player.get_animation_library("")
	library.remove_animation("Death")
	library.rename_animation("ReaperFallBack", "Death")
	library.rename_animation("ReaperFallForward", "Death2")

func fit_stone_actions(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D) -> void:
	# The stone caster opens both arms in group 12. The donor's Assemble
	# starts as dispersed stones and would break the connected silhouette.
	bake_pose(player, rig, mesh, "StoneFormCast", "Idle", 1.18,
		func(phase: float) -> void:
			var spread := action_peak(phase, .55)
			var rise := action_peak(phase, .28)
			rotate_world(rig, "bip01 spine1", Vector3.RIGHT, -.13 * spread)
			for side: String in ["l", "r"]:
				var sign := 1.0 if side == "l" else -1.0
				var prefix := "bip01 " + side
				rotate_world(rig, prefix + " upperarm", Vector3.BACK, sign * .92 * spread)
				rotate_world(rig, prefix + " upperarm", Vector3.RIGHT, -.44 * rise)
				rotate_world(rig, prefix + " forearm", Vector3.RIGHT, -.28 * rise))

func action_peak(phase: float, peak: float) -> float:
	return smoothstep(0.0, peak, phase) * (1.0 - smoothstep(peak, 1.0, phase))

func reaper_rake(rig: Skeleton3D, phase: float, down: bool) -> void:
	var pull := action_peak(phase, .55 if down else .36)
	var wind := action_peak(phase, .22)
	rotate_world(rig, "bip01 spine1", Vector3.RIGHT, (.43 if down else .19) * pull)
	rotate_world(rig, "bip01 spine2", Vector3.UP, (.10 if down else -.48) * pull)
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side
		var sign := 1.0 if side == "l" else -1.0
		rotate_world(rig, prefix + " upperarm", Vector3.RIGHT, -.56 * wind + .48 * pull)
		rotate_world(rig, prefix + " upperarm", Vector3.BACK, sign * (.11 if down else .38) * pull)
		rotate_world(rig, prefix + " forearm", Vector3.RIGHT, -.24 * wind + .16 * pull)

func fall_pose(rig: Skeleton3D, phase: float, angle: float, wood: bool) -> void:
	var fall := smoothstep(.12, .82, phase)
	var lift := action_peak(phase, .28)
	var strike := action_peak(phase, .70)
	var face_down := angle > 0.0
	rotate_world(rig, "bip01 pelvis", Vector3.RIGHT, angle * fall)
	rotate_world(rig, "bip01 pelvis", Vector3.UP, (.14 if face_down else -.24) * fall)
	rotate_world(rig, "bip01 spine1", Vector3.RIGHT, -.19 * lift + .11 * strike)
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side
		var sign := 1.0 if side == "l" else -1.0
		rotate_world(rig, prefix + " thigh", Vector3.RIGHT, .26 * strike - sign * .10 * fall)
		rotate_world(rig, prefix + " calf", Vector3.RIGHT, -.29 * strike - .13 * fall)
		rotate_world(rig, prefix + " upperarm", Vector3.BACK, sign * (.83 * lift + .34 * fall))
		rotate_world(rig, prefix + " upperarm", Vector3.RIGHT, -.62 * lift + (.35 if face_down else -.10) * fall)
		rotate_world(rig, prefix + " forearm", Vector3.RIGHT, -.20 * lift - sign * .12 * fall)
		if wood:
			var rest := smoothstep(.58, .94, phase)
			lay_branch(rig, prefix, sign, rest)
			lay_chain(rig, prefix, ["thigh", "calf", "foot", "toe0"], rest)
	var hip := rig.find_bone("bip01 pelvis")
	var pose := rig.get_bone_global_pose(hip)
	pose.origin += rig.global_basis.inverse() * Vector3(0.0, 0.0, (.34 if wood else .21) * signf(angle) * fall)
	rig.set_bone_global_pose(hip, pose)

func lay_branch(rig: Skeleton3D, prefix: String, sign: float, amount: float) -> void:
	if amount <= 0.0: return
	lay_chain(rig, prefix, ["upperarm", "forearm", "hand"], amount)
	var wrist := rig.find_bone(prefix + " hand")
	# The added terminal branch extends beyond the palm. Lay its actual
	# bind-space direction down too, so the body cannot rest on a branch tip.
	var tip := REAPER_SCALE * Vector3(1.07 * sign, -.92, .32)
	var local := rig.get_bone_global_rest(wrist).basis.inverse() * (rig.global_basis.inverse() * tip)
	flatten_axis(rig, wrist, rig.get_bone_global_pose(wrist).basis * local, amount)

func lay_chain(rig: Skeleton3D, prefix: String, parts: Array, amount: float) -> void:
	if amount <= 0.0: return
	for index in parts.size() - 1:
		var start := rig.find_bone(prefix + " " + str(parts[index]))
		var end := rig.find_bone(prefix + " " + str(parts[index + 1]))
		assert(start >= 0 and end >= 0)
		var line := rig.get_bone_global_pose(end).origin - rig.get_bone_global_pose(start).origin
		flatten_axis(rig, start, line, amount)

func flatten_axis(rig: Skeleton3D, bone: int, axis: Vector3, amount: float) -> void:
	var up := (rig.global_basis.inverse() * Vector3.UP).normalized()
	var flat := axis.slide(up)
	if flat.length_squared() < 1e-6: return
	var rotation := Quaternion(axis.normalized(), flat.normalized())
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion.IDENTITY.slerp(rotation, amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func rotate_world(rig: Skeleton3D, joint_name: String, axis: Vector3, angle: float) -> void:
	var index := rig.find_bone(joint_name)
	assert(index >= 0, joint_name)
	var pose := rig.get_bone_global_pose(index)
	var rotation := Basis((rig.global_basis.inverse() * axis).normalized(), angle)
	pose.basis = rotation * pose.basis
	rig.set_bone_global_pose(index, pose)
	rig.force_update_all_bone_transforms()

func bake_pose(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D, name: String,
		base: String, duration: float, pose: Callable, ground_fall := false) -> void:
	var original := player.get_animation(base)
	var clip := original.duplicate(true) as Animation
	clip.length = duration
	clip.loop_mode = Animation.LOOP_NONE
	var rotations := {}
	var hip := rig.find_bone("bip01 pelvis")
	var hip_track := -1
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var index := rig.find_bone(str(path.get_concatenated_subnames()))
		if index < 0:
			for key in range(clip.track_get_key_count(track) - 1, 0, -1):
				clip.track_remove_key(track, key)
			continue
		var type := clip.track_get_type(track)
		if type == Animation.TYPE_ROTATION_3D: rotations[track] = index
		if type == Animation.TYPE_POSITION_3D and index == hip: hip_track = track
		if rotations.has(track) or track == hip_track:
			for key in range(clip.track_get_key_count(track) - 1, -1, -1):
				clip.track_remove_key(track, key)
	var rig_path := str(player.get_node(player.root_node).get_path_to(rig))
	for name_at_joint: String in POSE_JOINTS:
		var index := rig.find_bone(name_at_joint)
		if index < 0 or index in rotations.values(): continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(rig_path + ":" + name_at_joint))
		rotations[track] = index
	if hip_track < 0:
		hip_track = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(hip_track, NodePath(rig_path + ":" + rig.get_bone_name(hip)))
	var skin := Ground.skin_points(mesh, rig) if ground_fall else {}
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(base, 0.0)
	player.advance(0.0)
	var frames := ceili(duration * 60.0)
	for frame in frames + 1:
		var phase := float(frame) / frames
		rig.reset_bone_poses()
		player.seek(0.0 if base == "Idle" else original.length * phase, true)
		rig.force_update_all_bone_transforms()
		pose.call(phase)
		if ground_fall:
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			var hips := rig.get_bone_global_pose(hip)
			hips.origin += rig.global_basis.inverse() * Vector3.UP * (.004 - gap)
			rig.set_bone_global_pose(hip, hips)
		var time := duration * phase
		clip.position_track_insert_key(hip_track, time, rig.get_bone_pose_position(hip))
		for track: int in rotations:
			clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(rotations[track]))
	player.stop()
	assert(player.get_animation_library("").add_animation(name, clip) == OK)

func copy_body(original: ArrayMesh, instance: MeshInstance3D, rig: Skeleton3D, wood: bool) -> ArrayMesh:
	var result := ArrayMesh.new()
	var to_world := instance.global_transform
	var from_world := to_world.affine_inverse()
	assert(original.get_blend_shape_count() == 0)
	var binding_bones: Array[int] = []
	for index in instance.skin.get_bind_count():
		var bone := instance.skin.get_bind_bone(index)
		if bone < 0:
			bone = rig.find_bone(instance.skin.get_bind_name(index))
		assert(bone >= 0)
		binding_bones.append(bone)
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var stride := indices.size() / points.size()
		if wood:
			for index in points.size():
				var point := to_world * points[index]
				var normal := (to_world.basis.inverse().transposed() * normals[index]).normalized()
				var anchor := point
				var axes := Vector3.ZERO
				for slot in stride:
					var influence := index * stride + slot
					var weight := weights[influence]
					if weight <= 0.0: continue
					var bone := binding_bones[indices[influence]]
					var name := rig.get_bone_name(bone)
					var center := joint(rig, name)
					var factor := Vector3(.63, .98, .63)
					if name.contains("upperarm") or name.contains("forearm") or name.contains("hand") or name.contains("finger"):
						factor = Vector3(.78, .92, .56)
					elif name.contains("foot") or name.contains("toe") or name.contains("calf"):
						factor = Vector3(.78, 1.0, .72)
					elif name.contains("spine") or name.contains("pelvis") or name.contains("neck") or name.contains("head"):
						center.x = 0.0
						center.z = 0.0
						factor = Vector3(.53, .98, .60)
					anchor += weight * ((point - center) * (factor - Vector3.ONE))
					axes += weight * factor
				points[index] = from_world * anchor
				normals[index] = (to_world.basis.transposed() * (normal / axes.max(Vector3.ONE * .1))).normalized()
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			remove_bird(arrays, indices, weights, stride, binding_bones, rig)
		var source_flags := original.surface_get_format(surface)
		var flags := source_flags & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,
			Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
			flags |= source_flags & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
		result.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays, [], {}, flags)
		result.surface_set_material(surface, original.surface_get_material(surface))
	return result

func remove_bird(arrays: Array, indices: PackedInt32Array, weights: PackedFloat32Array,
		stride: int, binding_bones: Array[int], rig: Skeleton3D) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if source.is_empty():
		source.resize(points.size())
		for index in points.size(): source[index] = index
	var accessory := PackedByteArray()
	accessory.resize(points.size())
	for vertex in points.size():
		var amount := 0.0
		for slot in stride:
			var index := vertex * stride + slot
			var name := rig.get_bone_name(binding_bones[indices[index]])
			if name in ["box01", "box02", "box05"]:
				amount += weights[index]
		accessory[vertex] = int(amount > .98)
	var output := PackedInt32Array()
	var retained := PackedInt32Array()
	var remap := {}
	for face in range(0, source.size(), 3):
		if accessory[source[face]] and accessory[source[face + 1]] and accessory[source[face + 2]]:
			continue
		for corner in 3:
			var index := source[face + corner]
			if not remap.has(index):
				remap[index] = retained.size()
				retained.append(index)
			output.append(int(remap[index]))
	assert(output.size() < source.size(), "The donor's bird must be removed without changing the skeleton")
	for stream in Mesh.ARRAY_INDEX:
		if arrays[stream] == null: continue
		var old: Variant = arrays[stream]
		var width: int = old.size() / points.size()
		var filtered: Variant = old.duplicate()
		filtered.resize(retained.size() * width)
		for index in retained.size():
			for part in width:
				filtered[index * width + part] = old[retained[index] * width + part]
		arrays[stream] = filtered
	arrays[Mesh.ARRAY_INDEX] = output

func fit_boughs(shell: SurfaceTool, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	for side: String in ["l", "r"]:
		var wrist := "bip01 " + side + " hand"
		var sign := 1.0 if side == "l" else -1.0
		var center := joint(rig, wrist)
		var curve: Array[Vector3] = [center, center + Vector3(.46 * sign, -.10, .10),
			center + Vector3(.86 * sign, -.42, .27), center + Vector3(1.07 * sign, -.92, .32)]
		tube(shell, mesh, curve, [.155, .10, .055, .012], wrist, wrist)
		var branch: Array[Vector3] = [curve[1], curve[1] + Vector3(.28 * sign, .29, -.10),
			curve[1] + Vector3(.45 * sign, .54, -.12)]
		tube(shell, mesh, branch, [.088, .050, .010], wrist, wrist)
		var thigh := "bip01 " + side + " thigh"
		var foot := "bip01 " + side + " foot"
		var trunk: Array[Vector3] = [Vector3(.12 * sign, 1.66, .025), Vector3(.22 * sign, 1.16, .10),
			Vector3(.33 * sign, .58, .20), Vector3(.56 * sign, -.11, .29)]
		tube(shell, mesh, trunk, [.24, .25, .29, .27], thigh, foot)

func fit_stone_joints(shell: SurfaceTool, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var torso: Array[Vector3] = [Vector3(.02, 1.60, .01), Vector3(.02, 1.86, -.05),
		Vector3(.02, 2.12, -.06), Vector3(.02, 2.53, -.08)]
	tube(shell, mesh, torso, [.23, .36, .40, .28], "bip01 pelvis", "bip01 spine1")
	var head: Array[Vector3] = [Vector3(.015, 2.60, -.12), Vector3(.02, 2.77, .01),
		Vector3(.01, 2.94, .02), Vector3(.005, 3.075, .01)]
	tube(shell, mesh, head, [.18, .25, .22, .055], "bip01 spine1", "bip01 spine1")
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side + " "
		joint_bridge(shell, mesh, rig, "bip01 spine1", prefix + "upperarm", .31, .23)
		joint_bridge(shell, mesh, rig, prefix + "upperarm", prefix + "forearm", .23, .20)
		joint_bridge(shell, mesh, rig, "bip01 pelvis", prefix + "thigh", .26, .23)
		joint_bridge(shell, mesh, rig, prefix + "thigh", prefix + "foot", .24, .24)
	joint_bridge(shell, mesh, rig, "bip01 r forearm", "bip01 r hand", .19, .18)

func joint_bridge(shell: SurfaceTool, mesh: MeshInstance3D, rig: Skeleton3D,
		first: String, last: String, start_radius: float, end_radius: float) -> void:
	var start := joint(rig, first)
	var end := joint(rig, last)
	var direction := (end - start).normalized()
	var overlap := minf(.16, start.distance_to(end) * .32)
	var curve: Array[Vector3] = [start, start.lerp(end, .35), start.lerp(end, .75), end, end + direction * overlap]
	tube(shell, mesh, curve, [start_radius, start_radius, end_radius, end_radius, end_radius * .84], first, last)

func tube(shell: SurfaceTool, mesh: MeshInstance3D, centers: Array[Vector3], radii: Array,
		first: String, last: String) -> void:
	var bindings := PackedInt32Array([bind_slot(mesh, first), bind_slot(mesh, last), 0, 0])
	var inverse := mesh.global_transform.affine_inverse()
	var rings: Array[PackedVector3Array] = []
	for row in centers.size():
		var direction := (centers[mini(row + 1, centers.size() - 1)] - centers[maxi(0, row - 1)]).normalized()
		var axis := (Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .88 else Vector3.UP).cross(direction).normalized()
		var tangent := direction.cross(axis).normalized()
		var ring := PackedVector3Array()
		for i in RING_POINTS:
			var angle := TAU * float(i) / RING_POINTS
			var grain := 1.0 + .095 * sin(3.0 * angle + .58 * row) + .065 * cos(5.0 * angle - row)
			ring.append(inverse * (centers[row] + (axis * cos(angle) + tangent * sin(angle)) * radii[row] * grain))
		rings.append(ring)
	for row in rings.size() - 1:
		for i in RING_POINTS:
			for vertex: Vector2i in [Vector2i(i,row), Vector2i(i,row+1), Vector2i(i+1,row),
				Vector2i(i+1,row), Vector2i(i,row+1), Vector2i(i+1,row+1)]:
				var progress := float(vertex.y) / (rings.size() - 1)
				shell.set_bones(bindings)
				shell.set_weights(PackedFloat32Array([1.0 - progress, progress, 0.0, 0.0]))
				shell.set_uv(Vector2(float(vertex.x) / RING_POINTS, progress))
				shell.add_vertex(rings[vertex.y][vertex.x % RING_POINTS])

func bind_slot(mesh: MeshInstance3D, name: String) -> int:
	var rig := mesh.get_node(mesh.skeleton) as Skeleton3D
	var bone := rig.find_bone(name)
	assert(bone >= 0, name)
	for slot in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(slot) == bone or mesh.skin.get_bind_name(slot) == name:
			return slot
	assert(false, "No skin slot for " + name)
	return 0

func joint(rig: Skeleton3D, name: String) -> Vector3:
	var bone := rig.find_bone(name)
	assert(bone >= 0, name)
	return rig.global_transform * rig.get_bone_global_rest(bone).origin
