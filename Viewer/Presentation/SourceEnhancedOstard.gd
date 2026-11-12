# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OstardMount.gd"

const Forms := {210: {"kind": "desert", "item": 0x3ea3}, 219: {"kind": "forest", "item": 0x3ea5}}
const Art := "res://local-art/ostards/"
const Manifest := Art + "enhanced-ostards.json"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Timing := preload("res://Presentation/HumanActions.gd")
const Treatments := ["original", "rounded", "modern"]
const Gaits := [
	["Idle", "Walk", "Run"],
	["OstardPeaceIdle", "OstardPeaceWalk", "Run"],
	["OstardSeatedIdle", "OstardSeatedWalk", "OstardSeatedRun"],
]
const Groups := {
	2: "Death", 3: "Death2", 4: "OstardForwardStrike", 5: "OstardLeapingKick",
	10: "OstardHeadRecoil", 15: "OstardCrouchAndRise", 23: "OstardWakeAndCall",
	25: "OstardPeaceIdle", 26: "OstardHeadAndTailCheck", 27: "OstardHighCall",
	28: "OstardCombatReady", 31: "OstardSeatedIdle",
}

static var active: Dictionary = {}
var source_body: int
var combat := false
var flags_known := false
var readying := false
var fall := Fall.new()
var action_ground: Dictionary = {}
var action_shift := Vector3.ZERO
var action_airborne := false
var classic_falls: Dictionary = {}
var using_classic_fall := false


static func scene_path(body: int, style: String) -> String:
	return Art + "enhanced-%d-%s.scn" % [body, style]


static func configure(enabled: bool) -> void:
	active.clear()
	if not enabled or not FileAccess.file_exists(Manifest):
		return
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	if not record is Dictionary or int(record.get("schema", 0)) != 1 or not record.get("bodies") is Dictionary:
		return
	for body: int in Forms:
		var hashes: Dictionary = record.bodies.get(str(body), {})
		if Treatments.all(func(style: String) -> bool: return has_verified_scene(body, style, str(hashes.get(style, "")))):
			active[body] = true


static func has_verified_scene(body: int, style: String, digest: String) -> bool:
	var path := scene_path(body, style)
	return digest.length() == 64 and FileAccess.get_sha256(path) == digest and ResourceLoader.exists(path, "PackedScene")


static func selected(body: int, item: int) -> bool:
	return active.has(body) and (item == 0 or item == Forms[body].item)


static func create(body: int) -> Node3D:
	var actor := new()
	actor.source_body = body
	actor.kind = Forms[body].kind
	return actor


func model_resource_path(_folder: String, _asset_kind: String) -> String:
	return scene_path(source_body, treatment)


func _ready() -> void:
	super._ready()
	var library := animator.get_animation_library("")
	for clip: String in Fall.FALLS:
		if library.has_animation(clip):
			classic_falls[clip] = library.get_animation(clip)
	if desert_actions != null:
		animator.mixer_applied.disconnect(desert_actions.settle.bind(self))
	replace_fall("Death", library.get_animation("OstardRollFall"))
	replace_fall("Death2", library.get_animation("OstardForwardFall"))
	fall.skin = Ground.skin_points(model.find_children("*", "MeshInstance3D", true, false)[0], skeleton)
	animator.mixer_applied.connect(settle_pose)


func apply_identity(body: int, value: int, item: int = 0) -> void:
	super.apply_identity(body, value, item)
	reins.visible = item == int(Forms[source_body].item) and not dead


func rein_grip_target(left: bool) -> Vector3:
	return Vector3(.15 if left else -.15, .28, .34)


func set_native_combat_flags(flags: int) -> void:
	if flags < 0:
		return
	var armed := (flags & 0x40) != 0
	if armed != combat:
		readying = armed and flags_known and native_mount_item == 0
	combat = armed
	flags_known = true


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == "LieDown":
		action_remaining = 0.0
	if dead or action_remaining > 0.0 or current_clip == "LieDown" and not moving:
		return
	clear_action_ground()
	if readying:
		readying = false
		if not moving:
			play_group(28, {})
			return
	var mode := 2 if native_mount_item != 0 else 0 if combat else 1
	var stage := 0 if not moving else 2 if speed > 3.6 else 1
	var clip: String = Gaits[mode][stage]
	contact.enabled = true
	contact.active = true
	if current_clip != clip or animator.assigned_animation != clip:
		current_clip = clip
		play(clip, .18)
	animator.speed_scale = clampf(speed / (5.5 if stage == 2 else 1.8), .65, 1.65) if moving else 1.0


static func action_group(mode: int, type: int, subaction: int, variation: int) -> int:
	if mode < 0 or mode > 2 or variation < 0 or variation > 127:
		return -1
	if mode == 2:
		return 31 if type == 5 else -1
	if mode == 1 and type == 5:
		return 26
	var choices: Array
	match type:
		0:
			choices = [4, 5, 4] if subaction == 0 else [4] if subaction in [1, 2, 9] else [4, 5, 4, 4, 4, 4]
		2:
			choices = [15]
		3:
			choices = [2, 3]
		4:
			choices = [10]
		5:
			choices = [26, 27]
		8:
			choices = [28]
		11:
			choices = [4]
		14:
			choices = [25]
		15:
			choices = [23]
		_:
			return -1
	return choices[variation % choices.size()]


func receive_action(request: Dictionary) -> bool:
	if not dead:
		clear_action_ground()
		var action := int(request.get("action", -1))
		if (request.get("protocol") == "classic" and action in [8, 12]) \
				or (request.get("protocol") == "new" and int(request.get("type", -1)) == 3):
			select_classic_falls()
	var accepted := super.receive_action(request)
	if accepted and dead:
		reins.hide()
		fall.accept_action(self)
	return accepted


func replace_fall(clip: String, animation: Animation) -> void:
	var library := animator.get_animation_library("")
	if library.has_animation(clip):
		library.remove_animation(clip)
	assert(library.add_animation(clip, animation) == OK)


func select_classic_falls() -> void:
	if using_classic_fall:
		return
	using_classic_fall = true
	for clip: String in classic_falls:
		replace_fall(clip, classic_falls[clip])


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if dead or flags < 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != native_body:
		return false
	set_native_combat_flags(flags)
	var mode := 2 if native_mount_item != 0 else 0 if combat else 1
	var group := action_group(mode, int(request.get("type", -1)), int(request.get("subaction", -1)),
		int(request.get("variation", -1)))
	if group < 0:
		return false
	clear_action_ground()
	play_group(group, request)
	return true


func play_group(group: int, request: Dictionary) -> void:
	readying = false
	var clip: String = Groups[group]
	dead = clip in Fall.FALLS
	if dead:
		reins.hide()
		current_clip = clip
		fall.accept_action(self)
	else:
		action_ground = fall.floor_under(self)
	action_airborne = group == 5
	contact.enabled = false
	contact.active = false
	start_action(clip, request)


func start_action(clip: String, request: Dictionary) -> void:
	current_clip = clip
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.0
	animator.play(clip, .10, length / action_remaining)
	animator.seek(0.0, false)
	if not request.is_empty():
		set_meta("native_action", request.duplicate(true))


func clear_action_ground() -> void:
	model.position -= action_shift
	if desert_actions != null:
		desert_actions.clear_live_shift(self)
	action_shift = Vector3.ZERO
	action_ground.clear()
	action_airborne = false


func settle_pose() -> void:
	if dead:
		fall.settle(self)
	elif not action_ground.is_empty():
		model.position -= action_shift
		var before := model.position
		var normal: Vector3 = action_ground.normal
		var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, action_ground.position, normal)
		var lift := .004 - gap
		if action_airborne:
			lift = maxf(0.0, lift)
		model.global_position.y += lift / normal.y
		action_shift = model.position - before
	elif desert_actions != null:
		desert_actions.settle(self)


func begin_source_death(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	reins.hide()
	if source.using_classic_fall:
		select_classic_falls()
	var live_shift: Vector3 = source.action_shift
	if source.desert_actions != null:
		live_shift += source.desert_actions.live_shift
	return fall.begin_from_source(self, source, source.fall, live_shift)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
