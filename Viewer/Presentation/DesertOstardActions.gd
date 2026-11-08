extends RefCounted
## Body 210 uses its original rig with a separate local animation library.

const Fall := preload("res://Presentation/CreatureFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CLIPS := {4: "Alert", 6: "Peck", 9: "CrestDip", 10: "CrestTwitch", 11: "LieDown", 12: "Death2"}
const MARKER := "res://local-art/ostards/desert-actions-active.json"
const TREATMENTS := ["original", "rounded", "modern"]

static var trial := false
var fall := Fall.new()
var live_shift := Vector3.ZERO

static func asset_path(treatment: String) -> String:
	return "res://local-art/ostards/desert-actions-%s.res" % treatment

static func available() -> bool:
	return (trial or FileAccess.file_exists(MARKER)) and TREATMENTS.all(
		func(treatment: String) -> bool: return ResourceLoader.exists(asset_path(treatment)))

func install(actor: Node3D) -> bool:
	var additions := load(asset_path(actor.treatment)) as AnimationLibrary
	if additions == null or not CLIPS.values().all(additions.has_animation):
		return false
	var library: AnimationLibrary = actor.animator.get_animation_library("")
	for clip: String in CLIPS.values():
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, additions.get_animation(clip))
	actor.animator.mixer_applied.connect(settle.bind(actor))
	return true

func accept(actor: Node3D) -> void:
	if actor.dead:
		actor.reins.hide()
		fall.accept_action(actor)
	actor.contact.active = not actor.dead and not CLIPS.values().has(actor.current_clip)
	if not actor.dead and not CLIPS.values().has(actor.current_clip):
		clear_live_shift(actor)

func clear_live_shift(actor: Node3D) -> void:
	if live_shift != Vector3.ZERO:
		actor.model.position -= live_shift
		live_shift = Vector3.ZERO

func settle(actor: Node3D) -> void:
	clear_live_shift(actor)
	if actor.dead:
		fall.settle(actor)
		return
	if not CLIPS.values().has(actor.current_clip):
		return
	var support := fall.floor_under(actor)
	if fall.skin.is_empty():
		fall.remember_floor(actor, support)
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fall.skin, rig, rig.global_transform, support.position, support.normal)
	var before: Vector3 = actor.model.position
	actor.model.global_position += Vector3.UP * maxf(0.0, (0.003 - gap) / float(support.normal.y))
	live_shift = actor.model.position - before

func begin_death_from(actor: Node3D, source: Node3D) -> float:
	var prior: RefCounted = source.desert_actions
	actor.model.position -= prior.live_shift
	actor.dead = true
	actor.reins.hide()
	actor.contact.enabled = false
	actor.contact.active = false
	var continuing: bool = source.dead and source.current_clip in Fall.FALLS
	var remaining := fall.begin_from(actor, source, prior.fall)
	if not continuing:
		fall.blend_start = 0.0
		fall.blend_length = minf(0.08, remaining)
		for bone: int in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		fall.settle(actor)
	return remaining
