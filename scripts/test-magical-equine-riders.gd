# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Mounts := preload("res://Presentation/MountVisual.gd")
const Magical := preload("res://Presentation/SourceMagicalEquine.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Outfits := [
	[],
	[{"id": 0x1f03}, {"id": 0x1539}, {"id": 0x170b}],
	[{"id": 0x1415}, {"id": 0x1410}, {"id": 0x1411}, {"id": 0x1414}, {"id": 0x170b}],
]
const Motions := [["Rider_Idle", "Idle"], ["Rider_Walk", "Walk"], ["Rider_Run", "Run"],
	["Rider_Attack", "Idle"], ["Rider_Bow", "Idle"], ["Rider_Crossbow", "Idle"]]

var checks := 0
var poses := 0
var max_seat := 0.
var max_foot := 0.
var back_gap := Vector2(INF, -INF)
var max_mouth := 0.
var elbow_range := Vector2(INF, -INF)


func _initialize() -> void:
	create_timer(85.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	Magical.configure(true)
	var spectral := "--magical-spectral" in OS.get_cmdline_user_args()
	if not expect(Magical.available_forms.size() == 2, "both original mounts load from the manifest"):
		return
	for body: int in Magical.Forms:
		var form: Dictionary = Magical.Forms[body]
		var ethereal_item: int = Magical.SpectralForms[body].item
		var opposite := 0x3e9b if body == 132 else 0x3e9c
		if not expect(Mounts.supports_body(body) and Mounts.horse_body(form.item) == body
				and Magical.selected(body, ethereal_item) == spectral and not Magical.selected(body, opposite)
				and not Magical.selected(0, ethereal_item),
				"living and ethereal identities remain distinct"):
			return
		var loose := Mounts.create(body) as Magical
		root.add_child(loose)
		loose.apply_identity(body, 0)
		if not expect(loose.contact.feet.size() == 4 and not loose.reins.visible and not loose.harness.visible,
				"loose animals have four contact chains and no riding tack"):
			return
		loose.free()
		var actor := Avatar.new()
		actor.initial_body = 401 if body == 122 else 400
		root.add_child(actor)
		actor.set_physics_process(false)
		for outfit: Array in Outfits:
			var worn := outfit.duplicate(true)
			worn.append({"id": form.item, "layer": 25, "hue": 0x8455})
			actor.apply_server_appearance({"body": actor.initial_body, "hue": 1002}, worn)
			var mount := actor.horse_visual as Magical
			if not expect(mount != null and mount.native_body == body and mount.native_hue == 0x8455
					and mount.harness.visible and mount.reins.visible, "normal worn item shows the original dyed mount and tack"):
				return
			actor.rider_contact.begin_mount(false)
			actor.human_visual.set_process(false)
			mount.set_physics_process(false)
			mount.contact.enabled = false
			for pair: Array in Motions:
				actor.human_visual.cancel_action()
				actor.human_visual.play(pair[0], 0.)
				var gait: String = "Mounted" + pair[1] if mount.fitted and body == 132 else pair[1]
				mount.animator.play(gait, 0.)
				actor.animator.advance(0.)
				mount.animator.advance(0.)
				for phase: float in [0., .25, .5, .75]:
					actor.animator.seek(actor.animator.current_animation_length * phase, true)
					mount.animator.seek(mount.animator.current_animation_length * phase, true)
					actor.animator.pause()
					mount.animator.pause()
					for frame in 3:
						await process_frame
					if not verify_pose(actor, mount, pair[1] in ["Walk", "Run"] or pair[0] == "Rider_Idle"):
						return
			if not expect(actor.human_visual.missing_art.is_empty(), "nude, robe and plate outfits are prepared"):
				return
		actor.free()
		var corpse := Corpses.posed(body, 0x8455)
		if not expect(corpse != null and corpse is Magical and not corpse.harness.visible,
				"the normal static corpse uses the original animal without tack"):
			return
		var frozen := Corpses.freeze(corpse)
		if not expect(frozen != null and frozen.get_meta("native_hue") == 0x8455
				and frozen.find_children("*", "Skeleton3D").is_empty(), "static corpse keeps server dye and the mesh"):
			return
		frozen.free()
		corpse.free()
		if spectral and not await verify_spectral_riders(body):
			return
	print("MAGICAL EQUINE RIDERS: ", checks, " checks, ", poses, " mounted poses, max seat ", max_seat,
		" m, max foot ", max_foot, " m, back clearance ", back_gap, " m, max mouth distance ", max_mouth,
		" m, gripping elbow range ", elbow_range, " radians")
	quit()


func verify_spectral_riders(body: int) -> bool:
	var item: int = Magical.SpectralForms[body].item
	for female: bool in [false, true]:
		var actor := Avatar.new()
		actor.initial_body = 401 if female else 400
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.apply_server_appearance({"body": actor.initial_body, "hue": 1002}, [
			{"id": item, "layer": 25, "hue": 0x4001}])
		var mount := actor.horse_visual as Magical
		if not expect(mount != null and not mount.fitted and mount.get_meta("equine_profile").ethereal
				and mount.native_mount_item == item, "the exact item selects the original spectral rig"):
			return false
		actor.rider_contact.begin_mount(false)
		actor.human_visual.set_process(false)
		mount.set_physics_process(false)
		mount.contact.enabled = false
		for pair: Array in Motions.slice(0, 3):
			actor.human_visual.play(pair[0], 0.)
			mount.animator.play(pair[1], 0.)
			actor.animator.advance(0.)
			mount.animator.advance(0.)
			for phase: float in [.11, .42, .73]:
				actor.animator.seek(actor.animator.current_animation_length * phase, true)
				mount.animator.seek(mount.animator.current_animation_length * phase, true)
				actor.animator.pause()
				mount.animator.pause()
				for frame in 3:
					await process_frame
				if not verify_pose(actor, mount, true):
					return false
		actor.free()
	return true


func verify_pose(actor: Node3D, mount: Magical, check_surface: bool) -> bool:
	var rider: SkeletonModifier3D = actor.rider_contact
	var feet: Array[float] = rider.stirrup_errors
	var seat := mount.seat()
	if not expect(rider.seat_error < .003 and feet.size() == 2 and feet.max() < .025, "rider pelvis and boots fit the measured fittings"):
		print(mount.kind, " seat ", rider.seat_error, " feet ", feet)
		return false
	max_seat = maxf(max_seat, rider.seat_error)
	max_foot = maxf(max_foot, feet.max())
	for side: String in ["Left", "Right"]:
		var fitting := mount.harness.get_node(side + "Stirrup") as MeshInstance3D
		if not expect(fitting.global_position.distance_to(mount.stirrup(side == "Left")) < .003,
				"visible stirrup follows the foot target"):
			return false
	if not expect(actor.transform.is_equal_approx(Transform3D.IDENTITY), "the rider presentation leaves the mobile root in place"):
		return false
	if not verify_grip(actor, rider):
		return false
	if check_surface:
		var results := surface_clearances(mount, seat)
		var gap: float = results.x
		var mouth: float = results.y
		if not expect(is_finite(gap) and gap > -.04 and gap < .17 and mouth < .18,
				"the saddle and bit are beside the animated skin"):
			print(mount.kind, " ", mount.animator.assigned_animation, " gap ", gap, " mouth distance ", mouth)
			return false
		back_gap.x = minf(back_gap.x, gap)
		back_gap.y = maxf(back_gap.y, gap)
		max_mouth = maxf(max_mouth, mouth)
	poses += 1
	return true


func verify_grip(actor: Node3D, contact: SkeletonModifier3D) -> bool:
	var rig: Skeleton3D = actor.human_visual.skeleton
	var displayed: Skeleton3D = contact.rendered_pose.source(rig)
	var good := true
	for left: bool in [true, false]:
		if not (actor.human_visual.grip.left_reins_holding if left else actor.human_visual.grip.reins_holding):
			continue
		var side := "l" if left else "r"
		var shoulder := displayed.get_bone_global_pose(displayed.find_bone("upperarm_" + side)).origin
		var elbow := displayed.get_bone_global_pose(displayed.find_bone("lowerarm_" + side)).origin
		var hand := displayed.get_bone_global_pose(displayed.find_bone("hand_" + side)).origin
		var bend := (elbow - shoulder).angle_to(hand - elbow)
		elbow_range.x = minf(elbow_range.x, bend)
		elbow_range.y = maxf(elbow_range.y, bend)
		good = good and bend > .27 and bend < 2.55
		if not good:
			print("GRIP FIT ", actor.horse_visual.kind, " ", actor.animator.assigned_animation, " ", side,
				" elbow ", bend, " rad, displayed ", displayed != rig, " segments ",
				elbow.distance_to(shoulder), "/", hand.distance_to(elbow))
	if displayed != rig:
		displayed.free()
	return expect(good, "a rein-holding arm keeps a bent elbow")


func surface_clearances(mount: Magical, seat: Transform3D) -> Vector2:
	var mesh: MeshInstance3D = mount.contact.surface
	var rig := mount.skeleton
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var transforms: Array[Transform3D] = []
	var barrel_joints := PackedByteArray()
	rig.force_update_all_bone_transforms()
	for index in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(index)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(index))
		transforms.append(rig.global_transform * rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
		barrel_joints.append(int(rig.get_bone_name(bone) in ["bip01 spine", "bip01 spine1", "bip01 pelvis", "bip01"]))
	var posed := PackedVector3Array()
	var barrel := PackedByteArray()
	var bit := mount.socket("mouth").origin
	var mouth := INF
	for vertex in vertices.size():
		var point := Vector3.ZERO
		var weight_on_back := 0.
		for slot in 4:
			var offset := vertex * 4 + slot
			if weights[offset] > 0.:
				point += transforms[bones[offset]] * vertices[vertex] * weights[offset]
				weight_on_back += weights[offset] * barrel_joints[bones[offset]]
		posed.append(point)
		barrel.append(int(weight_on_back > .45))
		mouth = minf(mouth, bit.distance_to(point))
	var upward := seat.basis.y.normalized()
	var ray := seat.origin + upward * .20
	var closest := INF
	for triangle in range(0, indices.size(), 3):
		if barrel[indices[triangle]] + barrel[indices[triangle + 1]] + barrel[indices[triangle + 2]] < 2:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(ray, -upward, posed[indices[triangle]],
			posed[indices[triangle + 1]], posed[indices[triangle + 2]])
		if hit != null:
			closest = minf(closest, ray.distance_to(hit) - .20)
	return Vector2(closest, mouth)


func expect(valid: bool, message: String) -> bool:
	checks += 1
	if not valid:
		printerr("MAGICAL EQUINE RIDERS FAIL: ", message)
		quit(1)
	return valid
