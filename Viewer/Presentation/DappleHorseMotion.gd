# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## First fit to the five-direction body-226 AMOU references. Existing clips
## stay in the library for the Classic routes and the other horse identities.

const FITS := {
	2: ["DappleFoldFall", 10],
	3: ["DappleOverturnFall", 12],
	4: ["DappleStrikingRear", 10],
	10: ["DappleHeadToss", 10],
	12: ["DappleLongRear", 14],
	15: ["DappleShortBound", 10],
	26: ["DappleHeadDip", 10],
	27: ["DappleWarningRear", 10],
	28: ["DappleQuietReset", 8],
}

const FORELEGS := ["upperarm_L", "forearm_L", "hand_L", "upperarm_R", "forearm_R", "hand_R"]
const HINDLEGS := ["thigh_L", "calf_L", "foot_L", "thigh_R", "calf_R", "foot_R"]
const NECK := ["neck_01", "neck_02", "neck_03"]
const BODIES := [200, 204, 226, 228]
const COMBAT_GROUPS := {
	0: [4], 2: [15], 3: [2, 3], 4: [10], 8: [28], 14: [25], 15: [25],
}


static func select_action(request: Dictionary, body: int, flags: int) -> Dictionary:
	if body not in BODIES or flags < 0 or int(request.get("body", -1)) != body \
			or request.get("protocol") != "new":
		return {}
	var variant := int(request.get("variation", -1))
	if variant < 0 or variant > 127:
		return {}
	var type := int(request.get("type", -1))
	var groups: Array = COMBAT_GROUPS.get(type, [])
	match type:
		1:
			if body == 226:
				groups = [15]
		5:
			var combat := (flags & 0x40) != 0
			if body == 226:
				groups = [27] if combat else [1, 1, 26]
			else:
				groups = [26, 27] if combat else [26]
		11:
			groups = [12] if body in [200, 226] else [4]
	if groups.is_empty():
		return {}
	var group: int = groups[variant % groups.size()]
	# Groups 1 and 25 have 99.98% mean registered silhouette overlap.
	return {"group": group, "clip": FITS[group][0] if FITS.has(group) else "idle", "death": type == 3}


static func install(player: AnimationPlayer, rig: Skeleton3D) -> void:
	var library := player.get_animation_library("")
	var idle := library.get_animation("idle")
	var root_track := idle.find_track(NodePath("Warhorse_Rig/Skeleton3D:root"), Animation.TYPE_POSITION_3D)
	var skeleton_path := String(idle.track_get_path(0).get_concatenated_names())
	assert(root_track >= 0)
	var root_position := idle.position_track_interpolate(root_track, 0.)
	var hind_support := (rig.get_bone_global_rest(rig.find_bone("toe_L")).origin
		+ rig.get_bone_global_rest(rig.find_bone("toe_R")).origin) * .5
	hind_support.y -= .17
	for group: int in FITS:
		var name: StringName = FITS[group][0]
		if library.has_animation(name):
			continue
		var frame_count: int = FITS[group][1]
		var clip := Animation.new()
		clip.length = float(frame_count) * .1
		var position_track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(position_track, idle.track_get_path(root_track))
		for bone in rig.get_bone_count():
			var joint := String(rig.get_bone_name(bone))
			var path := NodePath(skeleton_path + ":" + joint)
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			var idle_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
			var rotation := rig.get_bone_rest(bone).basis.orthonormalized().get_rotation_quaternion()
			if idle_track >= 0:
				rotation = idle.rotation_track_interpolate(idle_track, 0.)
			clip.track_set_path(track, path)
			var rest := rig.get_bone_global_rest(bone).basis.orthonormalized()
			for frame in range(frame_count + 1):
				var phase := float(mini(frame, frame_count - 1)) / float(frame_count - 1)
				var pose := action_pose(group, phase)
				var time := float(frame) * .1
				if bone == 0:
					var turning := Quaternion(Vector3.UP, pose.yaw)
					var pitching := Quaternion(Vector3.LEFT, pose.pitch)
					var rolling := Quaternion(Vector3.FORWARD, pose.roll)
					var orient := turning * pitching * rolling
					var pivot := hind_support.lerp(root_position, pose.pivot_blend)
					var position := pivot + orient * (root_position - pivot)
					position += Vector3(0., pose.lift, pose.advance)
					clip.position_track_insert_key(position_track, time, position)
					clip.rotation_track_insert_key(track, time, orient * rotation)
				else:
					var angles := joint_angles(joint, pose)
					var offset := Quaternion(rest.inverse() * Vector3.RIGHT, angles.x) \
						* Quaternion(rest.inverse() * Vector3.UP, angles.y) \
						* Quaternion(rest.inverse() * Vector3.FORWARD, angles.z)
					clip.rotation_track_insert_key(track, time, rotation * offset)
		library.add_animation(name, clip)


static func action_pose(group: int, phase: float) -> Dictionary:
	var pose := {"pitch": 0., "roll": 0., "yaw": 0., "lift": 0., "advance": 0., "pivot_blend": 0.,
		"fore": 0., "hind": 0., "neck": 0., "toss": 0., "jaw": 0., "tail": 0., "strike": 0.}
	if group in [2, 3]:
		var fall := smoothstep(.36, .82, phase)
		var rear := smoothstep(0., .28, phase) * (1. - fall)
		pose.pitch = (.57 if group == 2 else .75) * rear + (-.08 if group == 2 else 2.80) * fall
		pose.roll = (-1.45 if group == 2 else 1.02) * fall
		pose.yaw = (-.14 if group == 2 else .35) * fall
		pose.advance = -.19 * rear + (-.10 if group == 2 else .28) * fall
		pose.pivot_blend = (.10 if group == 2 else .57) * fall
		pose.fore = .8 * rear + .75 * fall
		pose.hind = .2 * rear + .77 * fall
		pose.neck = -.27 * rear + (.43 if group == 2 else .37) * fall
		pose.jaw = .22 * rear + .1 * fall
		pose.tail = .32 * rear + .16 * fall
		return pose
	if group in [4, 12, 27]:
		var down := .63 if group == 12 else .81
		var rear := smoothstep(0., .32, phase) * (1. - smoothstep(.55, down, phase))
		var thrust := smoothstep(.27, .43, phase) * (1. - smoothstep(.61, down, phase))
		pose.pitch = (.55 if group == 27 else .66) * rear
		pose.fore = .77 * rear
		pose.strike = thrust * (.60 if group == 27 else .90)
		pose.hind = .24 * rear
		pose.neck = -.23 * rear + .08 * sin(PI * phase)
		pose.jaw = .36 * rear
		pose.tail = .48 * rear * sin(TAU * phase)
		pose.advance = .09 * sin(PI * phase) * thrust
		return pose
	var pulse := pow(sin(PI * phase), 2.)
	if group == 15:
		pose.pitch = .24 * sin(TAU * phase) + .17 * pulse
		pose.fore = .87 * pulse
		pose.hind = .16 * pulse
		pose.strike = .56 * smoothstep(.20, .50, phase) * (1. - smoothstep(.55, .86, phase))
		pose.lift = .11 * pulse
		pose.neck = -.18 * pulse
	elif group == 10:
		pose.neck = -.46 * pulse + .18 * sin(TAU * phase)
		pose.toss = .38 * pulse * sin(TAU * phase + .9)
		pose.fore = .14 * pulse
		pose.jaw = .20 * pulse
	elif group == 26:
		pose.neck = .24 * pulse
		pose.toss = .14 * pulse
		pose.tail = .12 * sin(TAU * phase)
	else:
		pose.neck = .085 * pulse
		pose.toss = -.13 * pulse
		pose.tail = .15 * pulse
	return pose


static func joint_angles(joint: String, pose: Dictionary) -> Vector3:
	if joint in NECK:
		return Vector3(pose.neck * .58, pose.toss * .38, 0.)
	if joint == "head":
		return Vector3(pose.neck * -.37, pose.toss * .65, pose.toss * -.27)
	if joint == "jaw":
		return Vector3(pose.jaw, 0., 0.)
	if joint.begins_with("tail_"):
		return Vector3(-pose.tail * .38, pose.tail * .24, 0.)
	var side := 1. if joint.ends_with("_L") else -.88
	var fore := FORELEGS.find(joint)
	if fore >= 0:
		var strength := .95 + .05 * side
		return Vector3(([-.86, 1.62, .26][fore % 3] * pose.fore
			+ [-.34, -1.25, -.14][fore % 3] * pose.strike) * strength, 0., .075 * pose.fore * side)
	var hind := HINDLEGS.find(joint)
	if hind >= 0:
		return Vector3([-.71, 1.33, -.85][hind % 3] * pose.hind, 0., .08 * pose.hind * side)
	return Vector3.ZERO
