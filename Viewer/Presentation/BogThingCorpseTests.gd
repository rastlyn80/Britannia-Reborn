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
const WorldItems = preload("res://Presentation/WorldItems.gd")
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

const BODY:=780
func run() -> void:
	Registry.load_index()
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();root.add_child(arena);var items:=WorldItems.new();arena.add_child(items);items.add_child(items.hint)
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
		var slope := Basis(Quaternion(Vector3.UP, Vector3(-.12, 1.0, -.09).normalized()))
		source_visual.model.basis = slope * source_visual.model.basis
		source_visual.model.position.y += .09
		source_visual.rotation.y=PI-5.*PI/4.
		source_visual.set_physics_process(false);source_visual.set_process(false)
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
		check(before.size()==1 and after.size()==1,"Complete multipart mesh enters death")
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
		player.play("Death", 0.0)
		player.seek(death_anim.length, true)
		player.pause()
		visual.skeleton.force_update_all_bone_transforms()
		var animated := skinned(visual.model.find_children("*", "MeshInstance3D", true, false)[0], visual.skeleton)
		check(items._equine_corpse(holder, {"id": 0x2006, "amount": BODY, "hue": 0x8035, "direction": 5}, corpse), "WorldItems builds the matching corpse")
		var cadaver := holder.get_node("CorpseVisual") as Node3D
		check(cadaver!=null and cadaver.get_meta("static_cadaver",false) and int(cadaver.get_meta("vertices",0))==animated.size(),"Static corpse preserves all 4710 source corners")
		var old_mesh: MeshInstance3D = cadaver.find_children("*", "MeshInstance3D", true, false)[0]
		var old_vertices: PackedVector3Array = old_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var old_gap := 0.0
		for i in animated.size():
			old_gap = maxf(old_gap, animated[i].distance_to(old_mesh.global_transform * old_vertices[i]))
		items.nodes.erase(corpse)
		holder.visible = true
		var remaining: float = deaths.active[killed].remaining
		deaths._process(remaining + .1)
		check(items.corpse_snapshots.has(corpse), "Final pose waits for late corpse")
		await process_frame
		items.nodes[corpse] = holder
		holder.get_node("CorpseVisual").free()
		holder.get_node("PickBody").free()
		check(items._equine_corpse(holder, {"id": 0x2006, "amount": BODY, "hue": 0x8035, "direction": 5}, corpse), "Late corpse uses retained pose")
		var snapshot := holder.get_node("CorpseVisual") as Node3D
		var frozen: MeshInstance3D = snapshot.find_children("*", "MeshInstance3D", true, false)[0]
		var vertices: PackedVector3Array = frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pick_bounds: AABB = snapshot.transform * snapshot.get_meta("corpse_bounds")
		var pick := holder.get_node("PickBody/PickShape") as CollisionShape3D
		var matched_offset := 0.0
		var enclosing := pick_bounds.grow(.0001)
		var outside := 0
		for i in animated.size():
			var local := holder.to_local(frozen.global_transform * vertices[i])
			matched_offset = maxf(matched_offset, animated[i].distance_to(holder.to_global(local)))
			outside += int(not enclosing.has_point(local))
		samples[-1]["default_corpse_max_gap_m"] = old_gap
		samples[-1]["snapshot_corpse_max_gap_m"] = matched_offset
		check(old_gap > .10 and matched_offset < .0001, "Snapshot keeps final source placement")
		check(outside == 0 and pick.position.is_equal_approx(pick_bounds.get_center()), "Updated item selection encloses every snapshot corner")
		check(holder.visible and snapshot.is_visible_in_tree(), "World item releases the oriented static corpse")
		holder.free()
		holder = Node3D.new()
		items.add_child(holder)
		items.nodes[corpse] = holder
		check(items._equine_corpse(holder, {"id": 0x2006, "amount": BODY, "hue": 0x8035, "direction": 5}, corpse), "Redrawn world item rebuilds its default view")
		var redrawn := holder.get_node("CorpseVisual") as Node3D
		var redrawn_mesh: MeshInstance3D = redrawn.find_children("*", "MeshInstance3D", true, false)[0]
		var redrawn_points: PackedVector3Array = redrawn_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var redraw_error := 0.0
		for i in animated.size():
			redraw_error = maxf(redraw_error, animated[i].distance_to(redrawn_mesh.global_transform * redrawn_points[i]))
		check(redraw_error < .0001 and holder.get_node("PickBody/PickShape").position.is_equal_approx(pick_bounds.get_center()), "Redraw keeps the frozen placement and selection")
		samples[-1]["redraw_max_gap_m"] = redraw_error
		items.remove(corpse)
		check(items.corpse_snapshots.is_empty(), "Removal clears the snapshot")
		items.nodes.erase(corpse)

		avatar.free()
		await process_frame
	FileAccess.open("res://../work/creatures/bog-thing/runtime-snapshot-handoff.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples}, "\t"))
	print("BOG THING RUNTIME SNAPSHOT: ", checks, " checks / ", failures, " failures ", samples)
	quit(int(failures != 0))
