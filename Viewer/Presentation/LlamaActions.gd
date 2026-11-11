# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Animation and terrain support for the two native uses of llama body 220.

const Art := "res://local-art/mounts/"
const Manifest := Art + "llama-enhanced.json"
const Source := Art + "llama-modern.gltf"
const Library := Art + "llama-enhanced.res"
const PackScene := Art + "pack-llama-modern.scn"
const Body := 220
const PackBody := 292
const RidingItem := 0x3ea6
const Quiet := "LlamaQuietIdle"
const CombatWalk := "LlamaCombatWalk"
const Strike := "LlamaRearStrike"
const Recoil := "LlamaHeadRecoil"
const Watch := "LlamaForwardCheck"
const Alert := "LlamaPawAlert"
const FittedFall := "LlamaRearAndFall"
const Additions := [Quiet, CombatWalk, Strike, Recoil, Watch, Alert, FittedFall]
const Grounded := [Strike, Recoil, Watch, Alert]
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")

static var active_library: AnimationLibrary
static var active_pack := false
var fall := Fall.new()
var live_shift := Vector3.ZERO
var original_death: Animation
var combat := false
var source_pack := false


static func configure(enhanced: bool) -> void:
	active_library = null
	active_pack = false
	if not enhanced or not FileAccess.file_exists(Manifest):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	if not manifest is Dictionary or int(manifest.get("schema", 0)) != 1:
		return
	for path: String in [Source, Library]:
		var expected := str(manifest.get(path.get_file(), ""))
		if expected.length() != 64 or FileAccess.get_sha256(path) != expected:
			return
	var candidate := load(Library) as AnimationLibrary
	if candidate != null and Additions.all(candidate.has_animation):
		active_library = candidate
	var pack_hash := str(manifest.get(PackScene.get_file(), ""))
	active_pack = pack_hash.length() == 64 and FileAccess.get_sha256(PackScene) == pack_hash \
		and ResourceLoader.exists(PackScene, "PackedScene")


static func applies(kind: String, treatment: String, body: int, item: int) -> bool:
	return active_library != null and kind == "llama" and treatment == "modern" and body == Body \
		and (item == 0 or item == RidingItem)


func install(actor: Node3D) -> void:
	var library: AnimationLibrary = actor.animator.get_animation_library("")
	original_death = library.get_animation("Death")
	for clip: String in Additions:
		library.add_animation(clip, active_library.get_animation(clip))
	library.remove_animation("Death")
	library.add_animation("Death", active_library.get_animation(FittedFall))
	library.add_animation("Death2", original_death)
	actor.animator.mixer_applied.connect(settle.bind(actor))


func install_pack(actor: Node3D) -> void:
	source_pack = true
	actor.animator.mixer_applied.connect(settle.bind(actor))


func uninstall(actor: Node3D) -> void:
	actor.animator.mixer_applied.disconnect(settle.bind(actor))
	var library: AnimationLibrary = actor.animator.get_animation_library("")
	library.remove_animation("Death")
	library.remove_animation("Death2")
	library.add_animation("Death", original_death)
	for clip: String in Additions:
		library.remove_animation(clip)
	actor.model.position -= live_shift + fall.shift
	actor.contact.enabled = true
	actor.contact.active = true
	actor.dead = false
	actor.action_remaining = 0.0
	actor.current_clip = "Idle"
	actor.play("Idle", 0.0)


func gait(actor: Node3D, moving: bool, speed: float) -> bool:
	if source_pack:
		return false
	if actor.dead or actor.action_remaining > 0.0:
		return true
	if actor.current_clip == "LieDown":
		return false
	var in_combat: bool = combat and actor.native_mount_item == 0
	var clip := ("Idle" if in_combat else Quiet) if not moving else (
		"Run" if speed > 3.6 else CombatWalk if in_combat else "Walk")
	actor.contact.enabled = true
	actor.contact.active = true
	if actor.current_clip != clip:
		actor.current_clip = clip
		actor.play(clip, 0.18)
	actor.animator.speed_scale = clampf(speed / (5.5 if clip == "Run" else 1.8), 0.65, 1.65) if moving else 1.0
	return true


static func select(request: Dictionary, flags: int) -> String:
	if request.get("protocol", "") != "new" or int(request.get("body", 0)) != Body or flags < 0:
		return ""
	var variation := int(request.get("variation", -1))
	if variation < 0 or variation > 127:
		return ""
	var alternate := (variation & 1) != 0
	match int(request.get("type", -1)):
		0, 11: return Strike
		2: return "Idle" if alternate else Quiet
		3: return "Death"
		4: return Recoil
		5: return Quiet if (flags & 0x40) != 0 and alternate else Watch
		8: return Alert
		14, 15: return Quiet
	return ""


func receive_classic_fall(actor: Node3D, request: Dictionary) -> bool:
	if request.get("protocol", "") != "classic" or int(request.get("action", -1)) not in [8, 12]:
		return false
	return play_action(actor, "Death" if source_pack else "Death2", request)


func receive_enhanced(actor: Node3D, request: Dictionary, flags: int) -> bool:
	if source_pack:
		if request.get("protocol") != "new" or int(request.get("body", 0)) != PackBody:
			return false
		var clip := str({3: "Death"}.get(int(request.get("type", -1)), ""))
		return play_action(actor, clip, request)
	return play_action(actor, select(request, flags), request)


func play_action(actor: Node3D, clip: String, request: Dictionary) -> bool:
	if clip.is_empty() or actor.dead:
		return false
	actor.current_clip = clip
	actor.dead = clip in ["Death", "Death2"]
	actor.contact.enabled = not actor.dead
	actor.contact.active = not actor.dead and not clip in Grounded
	if actor.dead:
		fall.accept_action(actor)
	var length: float = actor.animator.get_animation(clip).length
	actor.action_remaining = preload("res://Presentation/HumanActions.gd").duration(request, length)
	actor.animator.speed_scale = 1.0
	actor.animator.play(clip, 0.12, length / actor.action_remaining)
	actor.animator.seek(0.0, false)
	actor.set_meta("native_action", request.duplicate(true))
	return true


func settle(actor: Node3D) -> void:
	actor.model.position -= live_shift
	live_shift = Vector3.ZERO
	if actor.dead:
		fall.settle(actor)
		return
	if actor.current_clip not in Grounded:
		return
	var plane := fall.floor_under(actor)
	if fall.skin.is_empty():
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		fall.skin = Ground.skin_points(mesh, actor.skeleton)
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var clearance := Ground.minimum_plane_gap(fall.skin, rig, rig.global_transform, plane.position, plane.normal)
	var prior: Vector3 = actor.model.position
	actor.model.global_position.y += maxf(0.0, (0.002 - clearance) / float(plane.normal.y))
	live_shift = actor.model.position - prior


func begin_death_from(actor: Node3D, source: Node3D) -> float:
	var previous: RefCounted = source.llama_actions
	actor.dead = true
	actor.contact.enabled = false
	actor.contact.active = false
	actor.reins.hide()
	return fall.begin_from_source(actor, source, previous.fall, previous.live_shift)


func snapshot_floor(actor: Node3D) -> float:
	return INF if fall.skin.is_empty() else fall.snapshot_floor(actor)
