# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BovineActionsVisual.gd"

const Fall := preload("res://Presentation/CreatureFallPlayback.gd")
const FittedFall := "BovineEnhancedFall"
const Grazing := "BovineGrazingIdle"
const Alert := "BovineGrazeAlert"
const AssetRoot := "res://local-art/animals/enhanced-cattle/"
const Bodies := {216: "bovine_cow_spotted", 231: "bovine_cow_brown", 232: "bovine_bull_brown", 233: "bovine_bull_spotted"}
const Treatments := ["original", "rounded", "modern"]
const Clips := {1: "Idle", 2: FittedFall, 10: "BovineHeadRecoil", 15: "BovineShortNudge",
	25: Grazing, 26: "BovineGrazeTailFlick", 28: Alert}
const CommonActions := {2: [15], 4: [10], 8: [28], 11: [1, 25, 25], 14: [25], 15: [25]}

static var enabled := false
var native_flags := -1
var fitted_fall := Fall.new()
var classic_death: Animation


static func enable() -> bool:
	if enabled:
		return true
	var manifest := AssetRoot + "manifest.json"
	if not FileAccess.file_exists(manifest):
		return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not value is Dictionary or int(value.get("schema", -1)) != 1 or not value.get("scenes") is Dictionary:
		return false
	var hashes: Dictionary = value.scenes
	if hashes.size() != Bodies.size() * Treatments.size():
		return false
	for body: int in Bodies:
		for treatment: String in Treatments:
			var name := "%d-%s.scn" % [body, treatment]
			var digest: String = hashes.get(name, "")
			if digest.length() != 64 or FileAccess.get_sha256(AssetRoot + name) != digest:
				return false
	enabled = true
	return true


static func group_for(request: Dictionary, body: int, flags: int) -> int:
	if not Bodies.has(body) or flags < 0 or int(request.get("body", -1)) != body \
			or request.get("protocol") != "new":
		return -1
	var variant := int(request.get("variation", -1))
	if variant < 0 or variant > 127:
		return -1
	var type := int(request.get("type", -1))
	var options: Array = CommonActions.get(type, [])
	match type:
		0:
			var subaction := int(request.get("subaction", -1)) & 0xff
			match subaction:
				0: options = [25, 1, 1]
				1, 2, 9: options = [1]
				_: options = [25, 1, 1, 1, 1, 1]
		3:
			options = [2, 1] if body in [232, 233] else [2]
		5:
			options = [26, 25] if (flags & 0x40) != 0 else [26]
	return -1 if options.is_empty() else int(options[variant % options.size()])


func model_resource_path(_folder: String, asset_kind: String) -> String:
	var body: int = Bodies.find_key(asset_kind)
	return AssetRoot + "%d-%s.scn" % [body, treatment]


func _ready() -> void:
	super._ready()
	reins.hide()
	var library := animator.get_animation_library("")
	classic_death = library.get_animation("Death")
	library.remove_animation("Death")
	library.add_animation("Death", library.get_animation(FittedFall))


func select_classic_fall() -> void:
	var library := animator.get_animation_library("")
	if library.get_animation("Death") != classic_death:
		library.remove_animation("Death")
		library.add_animation("Death", classic_death)


func receive_action(request: Dictionary) -> bool:
	var classic: bool = request.get("protocol") == "classic" and int(request.get("action", -1)) == 8
	var fallback: bool = request.get("protocol") == "new" and int(request.get("type", -1)) == 3
	if classic or fallback:
		select_classic_fall()
	return super.receive_action(request)


func set_native_combat_flags(value: int) -> void:
	var entering := native_flags >= 0 and (native_flags & 0x40) == 0 and (value & 0x40) != 0
	native_flags = value
	if entering and not dead and not recovering_tip and action_remaining <= 0. and current_clip == Grazing:
		play_group(28, {})


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.:
		return
	if moving or native_flags < 0 or (native_flags & 0x40) != 0 or current_clip == "LieDown":
		super.play_gait(moving, speed)
		return
	contact.enabled = true
	animator.speed_scale = 1.
	if current_clip != Grazing:
		current_clip = Grazing
		play(Grazing, .18)


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	var group := group_for(request, native_body, flags)
	if group < 0 or (dead and group != 2):
		return false
	play_group(group, request)
	set_meta("native_action", request.duplicate(true))
	return true


func play_group(group: int, request: Dictionary) -> void:
	recovering_tip = false
	current_clip = Clips[group]
	dead = group == 2
	contact.enabled = not dead
	if dead:
		fitted_fall.remember_floor(self, support_plane().duplicate())
	var length := animator.get_animation(current_clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(current_clip, .12, length / action_remaining)
	animator.seek(0., false)
	set_meta("enhanced_bovine_group", group)


func settle_collapse() -> void:
	if current_clip == FittedFall and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	else:
		super.settle_collapse()


func begin_death_from(source: Node3D) -> float:
	if source.dead and source.current_clip != FittedFall:
		if source.current_clip == "Death":
			select_classic_fall()
		return super.begin_death_from(source)
	global_transform = source.global_transform
	model.transform = source.model.transform
	model.position -= source.fitted_fall.shift
	recovering_tip = false
	dead = true
	contact.enabled = false
	reins.visible = false
	current_clip = FittedFall
	var continued: bool = source.dead
	var plane: Dictionary = source.fitted_fall.plane if continued else source.support_plane()
	fitted_fall.remember_floor(self, plane.duplicate())
	var time: float = source.animator.current_animation_position if continued else 0.
	var speed: float = absf(source.animator.get_playing_speed()) if continued else 1.
	if is_zero_approx(speed):
		speed = 1.
	var length := animator.get_animation(current_clip).length
	fitted_fall.blend_start = time
	fitted_fall.blend_length = minf(.12 * speed, length - time)
	if fitted_fall.blend_length > 0.:
		for bone in source.skeleton.get_bone_count():
			fitted_fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		var root_bone := skeleton.find_bone("__root")
		var root_pose := fitted_fall.blend_pose[root_bone]
		var displayed_shift: Vector3 = source.skeleton.global_position - skeleton.global_position
		root_pose.origin += skeleton.global_basis.inverse() * displayed_shift
		fitted_fall.blend_pose[root_bone] = root_pose
	animator.play(current_clip, 0., speed)
	animator.advance(0.)
	animator.seek(time, true)
	settle_collapse()
	action_remaining = maxf(0., length - time) / speed
	return action_remaining


func corpse_snapshot_floor() -> float:
	return fitted_fall.snapshot_floor(self) if current_clip == FittedFall else super.corpse_snapshot_floor()
