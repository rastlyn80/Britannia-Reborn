extends SceneTree
const Game=preload("res://Network/GameSession.gd")
const Wire=preload("res://Network/LoginProtocol.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Deaths=preload("res://Presentation/CreatureDeaths.gd")
var checks:=0
var failures:=0
class Arena extends Node3D:
	var avatars: Dictionary={}
class Avatar extends Node3D:
	var horse_visual: Node3D
class Items extends Node:
	var nodes: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func packet(killed: int,corpse: int) -> PackedByteArray:
	var value:=PackedByteArray([0xaf]);value.append_array(Wire.uint_be(killed,4));value.append_array(Wire.uint_be(corpse,4));value.append_array(Wire.uint_be(0,4));return value
func skinned(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
	var transforms: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var a:=mesh.mesh.surface_get_arrays(0);var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var b: PackedInt32Array=a[Mesh.ARRAY_BONES];var w: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=b.size()/p.size();var result:=PackedVector3Array()
	for vertex in p.size():
		var point:=Vector3.ZERO
		for slot in stride:point+=(transforms[b[vertex*stride+slot]]*p[vertex])*w[vertex*stride+slot]
		result.append(point)
	return result

const BODY:=778
func run() -> void:
	Registry.load_index()
	if "--active" not in OS.get_cmdline_user_args():
		Registry.entries[BODY]=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/gazer_larva/preparation.json")).models[0]
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();root.add_child(arena);var items:=Items.new();arena.add_child(items)
	var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items);deaths.set_process(false)
	var plate:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6.,.1,6.);collider.shape=box
	plate.add_child(collider);arena.add_child(plate);plate.position=Vector3(1.,.5,-2.);plate.rotation.z=.2
	await physics_frame;await physics_frame
	var samples: Array=[]
	for pose in ["Idle","Walk","Attack3"]:
		var killed:=10000+BODY;var corpse:=0x40010000+BODY
		var avatar:=Avatar.new();arena.add_child(avatar);avatar.horse_visual=Registry.create(BODY)
		avatar.add_child(avatar.horse_visual);avatar.horse_visual.apply_identity(BODY,0x8035)
		avatar.position=Vector3(1.,.8,-2.);arena.avatars[killed]=avatar
		var source_visual: Node3D=avatar.horse_visual
		source_visual.rotation.y=PI-5.*PI/4.
		source_visual.set_physics_process(false);source_visual.set_process(false)
		var model_pose: Transform3D=source_visual.model.transform
		for i in 12:source_visual._physics_process(1./60.)
		check(source_visual.model.transform==model_pose and source_visual.contact.contacts.is_empty(),"Native-hover source ignores a tilted ground collider")
		source_visual.animator.play(pose,0.);source_visual.animator.seek(source_visual.animator.get_animation(pose).length*.4321,true)
		source_visual.animator.pause();source_visual.skeleton.force_update_all_bone_transforms()
		var before: Array=[]
		for mesh: MeshInstance3D in source_visual.model.find_children("*","MeshInstance3D",true,false):
			before.append(skinned(mesh,source_visual.skeleton))
		game.entities[killed]={"serial":killed,"body":BODY,"hue":0x8035,"x":100,"y":200,"z":16,"direction":5}
		var holder:=Node3D.new();items.add_child(holder);items.nodes[corpse]=holder
		game._handle(packet(killed,corpse))
		check(deaths.active.has(killed),"Decoded native death starts a transition")
		if not deaths.active.has(killed):quit(1);return
		var visual: Node3D=deaths.active[killed].visual
		var player: AnimationPlayer=visual.animator
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		visual.skeleton.force_update_all_bone_transforms()
		var after: Array=[]
		for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
			after.append(skinned(mesh,visual.skeleton))
		check(before.size()==2 and after.size()==2,"Both original cards and refined body enter death")
		var error:=0.
		for part in before.size():
			for index in before[part].size():error=maxf(error,before[part][index].distance_to(after[part][index]))
		samples.append({"pose":pose,"first_frame_error_m":error})
		check(error<.001,pose+" displayed first death frame must preserve every posed point: "+str(error))
		check(visual.native_hue==0x8035 and not holder.visible and not avatar.visible,"Death preserves native hue and holds static corpse")
		player.advance(.081);player.advance(.001)
		check(player.assigned_animation=="Death","Original exact-clock death follows the short entry clip")
		var original_anim: Animation=source_visual.animator.get_animation("Death")
		var death_anim:=player.get_animation("Death")
		var clocks_match:=original_anim.get_track_count()==death_anim.get_track_count() and original_anim.length==death_anim.length
		for track in original_anim.get_track_count():
			var key: String="tracks/"+str(track)+"/keys"
			clocks_match=clocks_match and original_anim.get(key)==death_anim.get(key)
		check(clocks_match,"Original Death packed key times and values remain unchanged")
		var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(killed,4));game._handle(remove);arena.avatars.erase(killed)
		for mesh: MeshInstance3D in source_visual.model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,null)
		avatar.free()
		deaths._process(float(deaths.active[killed].remaining)+.1)
		check(holder.visible and deaths.active.is_empty(),"Native static corpse becomes visible after playback")
		var cadaver:=preload("res://Presentation/CorpseModels.gd").build(BODY,0x8035)
		check(cadaver!=null and cadaver.get_meta("static_cadaver",false) and int(cadaver.get_meta("vertices",0))==before[0].size()+before[1].size(),"Static corpse preserves body and card corner counts")
		if cadaver!=null:cadaver.free()
		holder.free();items.nodes.erase(corpse)
		await process_frame
	FileAccess.open("res://../work/creatures/gazer-larva/owned-source/hover-death.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"renderer_sha256":FileAccess.get_sha256("res://Presentation/SourceGazerLarvaVisual.gd")}, "\t"))
	print("GAZER DECODED DEATH AND HOVER: ",checks," checks / ",failures," failures ",samples)
	quit(1 if failures else 0)
