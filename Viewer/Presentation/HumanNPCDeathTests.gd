extends SceneTree
## Packet-decoder/client-state tests; not a live-server or GPU certificate.
const Game=preload("res://Network/GameSession.gd")
const Wire=preload("res://Network/LoginProtocol.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Profiles=preload("res://Presentation/HumanNPCProfiles.gd")
const Deaths=preload("res://Presentation/CreatureDeaths.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
class Arena extends Node3D:
	var avatars: Dictionary={}
class Items extends Node:
	var nodes: Dictionary={}
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Human death presentation deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func packet(killed: int,corpse: int) -> PackedByteArray:
	var p:=PackedByteArray([0xaf]);p.append_array(Wire.uint_be(killed,4));p.append_array(Wire.uint_be(corpse,4));p.append_array(Wire.uint_be(0,4));return p
func run() -> void:
	Profiles.load_index();var saved:=Profiles.entries.duplicate(true)
	var accepted_path:="res://local-art/human-npcs/accepted-index.json";var accepted_sha:=FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent"
	for body: int in [183,184]:Profiles.entries[body]={"body":body,"female":body==184,"skin":"savage","status":"prepared"}
	var inputs: Dictionary={}
	for name in ["HumanNPCDeathTests.gd","HumanNPCDeathVisual.gd","HumanDeathFloor.gd","CreatureDeaths.gd","CorpseModels.gd","HumanAvatar.gd","HumanVisual.gd","HumanNPCProfiles.gd","HumanNPCMotion.gd","HumanNPCFootContact.gd","SavageBodyPaint.gd","SavageSkin.gdshader"]:inputs[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();root.add_child(arena);var items:=Items.new();arena.add_child(items);var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items)
	var records: Array=[]
	for body: int in [183,184,400,401]:
		for hue: int in [53,0x8035]:
			for with_corpse: bool in [false,true]:
				var serial:=100000+body;var corpse: int=0x40010000+body if with_corpse else 0
				var actor:=Avatar.new();actor.initial_body=body;arena.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.position=Vector3(3.,.25,-4.)
				var worn: Array=[{"id":0x144e,"layer":19,"hue":54,"serial":20001},{"id":0x1452,"layer":4,"hue":55,"serial":20002},{"id":0xf62,"layer":2,"hue":53,"serial":20003},{"id":0x203c,"layer":11,"hue":56,"serial":20004}]
				var entity:={"serial":serial,"body":body,"hue":hue,"direction":5,"x":100,"y":200,"z":0,"flags":0}
				actor.apply_server_appearance(entity,worn);var human: Node3D=actor.human_visual;human.set_process(false)
				human.animator.play("Walk",0.);human.animator.seek(.41,true);human.animator.pause();human.skeleton.force_update_all_bone_transforms()
				var original_death: Animation=human.animator.get_animation("Death");var original_length:=original_death.length
				var poses: Array[Transform3D]=[]
				for bone in human.skeleton.get_bone_count():poses.append(human.skeleton.get_bone_pose(bone))
				game.entities[serial]=entity.duplicate(true);arena.avatars[serial]=actor
				var holder:=Node3D.new();items.add_child(holder);var collider:=StaticBody3D.new();holder.add_child(collider);collider.collision_layer=4
				if with_corpse:items.nodes[corpse]=holder
				game._handle(packet(serial,corpse))
				check(deaths.active.has(serial),"Decoded0xAF starts the real human death presenter")
				if not deaths.active.has(serial):actor.free();holder.free();continue
				var visual: Node3D=deaths.active[serial].visual;visual.set_process(false)
				check(visual.native_body==body and visual.native_hue==hue and visual.female==(body in [184,401]),"Snapshot preserves the native body/gender/hue")
				check(visual.server_equipment==worn and visual.native_action.is_empty(),"Snapshot keeps original equipment without inventing a server animation packet")
				check(visual.global_position.is_equal_approx(human.global_position) and is_equal_approx(visual.rotation.y,PI-5.*PI/4.),"Death begins at the displayed location and native corpse facing")
				check(not actor.visible and game.entities[serial]==entity,"Temporary presentation hides the actor without altering authoritative data")
				check(is_equal_approx(visual.action_duration,original_length+.08) and original_death.length==original_length and human.animator.get_animation("Death")==original_death,"Only the death snapshot owns its short entry clip")
				for bone in visual.skeleton.get_bone_count():
					var pose: Transform3D=visual.skeleton.get_bone_pose(bone)
					check(pose.origin.distance_to(poses[bone].origin)<.000001 and pose.basis.is_equal_approx(poses[bone].basis),"First death pose retains the displayed bone "+str(visual.skeleton.get_bone_name(bone)))
				if with_corpse:check(not holder.visible and collider.collision_layer==4,"Corpse visual waits while its interaction collider stays active")
				human.set_skin(1002);check(visual.skin_hue==hue and visual.skin!=human.skin,"Living appearance changes cannot mutate the death snapshot")
				game._handle(packet(serial,corpse));check(deaths.active.size()==1,"Duplicate death packets are idempotent")
				var minimum:=INF
				for phase: float in [.1,.31,.63,.89,1.]:
					visual.animator.seek(visual.action_duration*phase,true);visual.skeleton.force_update_all_bone_transforms()
					var mesh: MeshInstance3D=visual.model.find_children("Body*","MeshInstance3D",true,false)[0]
					var bounds:=Geometry.deformed_bounds(mesh,visual.skeleton)
					check(bounds.position.is_finite() and bounds.size.is_finite(),"Complete human skin stays finite during the death action")
					minimum=minf(minimum,bounds.position.y-visual.global_position.y)
					check(bounds.position.y-visual.global_position.y>=-.004,"Grounded body stays above the flat floor after the exact live-pose entry")
				var posed:=Corpses.posed(body,hue,worn)
				check(posed!=null,"The same native body builds an equipped static corpse pose")
				if posed!=null:
					for bone in visual.skeleton.get_bone_count():
						check(visual.skeleton.get_bone_pose(bone).is_equal_approx(posed.skeleton.get_bone_pose(bone)),"Animated death ends on the existing static corpse skeleton pose")
					var frozen:=Corpses.freeze(posed)
					check(frozen.get_meta("corpse_body")==body and frozen.get_meta("native_hue")==hue and frozen.get_meta("graphic_id")==0x2006,"Frozen corpse retains exact native graphic/body/hue identity")
					check(frozen.find_children("*","Skeleton3D",true,false).is_empty(),"Frozen corpse requires no animated rig")
					frozen.free();posed.free()
				var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(serial,4));game._handle(remove);arena.avatars.erase(serial);actor.free()
				check(is_instance_valid(visual),"Death snapshot survives native mobile removal")
				if with_corpse:
					var replacement:=Node3D.new();items.add_child(replacement);items.nodes[corpse]=replacement;holder.free();holder=replacement
					game.world_item_changed.emit(corpse,{"id":0x2006,"amount":body});check(not holder.visible,"Replacing the pending corpse does not flash its static model")
				deaths._process(float(deaths.active[serial].remaining)+.01)
				check(deaths.active.is_empty() and deaths.held_corpses.is_empty(),"Finished human death releases its temporary state")
				if with_corpse:check(holder.visible,"Static corpse appears after the complete death clip")
				items.nodes.erase(corpse);holder.free()
				records.append({"body":body,"hue":hue,"with_corpse":with_corpse,"intro_s":.08,"authored_duration_s":original_length,"minimum_sampled_body_y_m":minimum,"scope":"CPU pose/lifecycle snapshot; no rendered floor/material claim"})
				await process_frame
	for body: int in [400,401]:
		var serial:=200000+body;var actor:=Avatar.new();actor.initial_body=body;arena.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		actor.apply_server_appearance({"body":body,"hue":1002,"flags":0},[]);arena.avatars[serial]=actor
		var player: AnimationPlayer=actor.human_visual.animator;var library: AnimationLibrary=player.get_animation_library("").duplicate()
		player.stop(true);player.remove_animation_library("");player.add_animation_library("",library);library.remove_animation("Death")
		game.entities[serial]={"serial":serial,"body":body,"hue":1002,"direction":0};game._handle(packet(serial,0))
		check(deaths.active.is_empty() and deaths.held_corpses.is_empty() and actor.visible,"Base-body-only client safely retains its actor without inventing a missing death clip")
		arena.avatars.erase(serial);game.entities.erase(serial);actor.free()
	game.ended.emit();check(deaths.active.is_empty() and deaths.held_corpses.is_empty(),"Disconnect clears any remaining human transitions")
	Profiles.entries=saved;check((FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent")==accepted_sha,"Prepared death tests leave acceptance unchanged")
	for name: String in inputs:check(inputs[name]==FileAccess.get_sha256("res://Presentation/"+name),"Death source input remains unchanged: "+name)
	var report:={"checks":checks,"failures":failures,"cases":records,"runtime_sha256":inputs,"scope":"Decoded0xAF client pipeline on actual male/female human/Savage avatars, displayed-pose entry, private clip/material/equipment state, native data/facing, removal/repeated-packet/corpse-refresh lifecycle and exact final static corpse rig. Candidate profiles are in-memory only. No actual server/GPU/terrain/clipping/material/loot or family acceptance."}
	var f:=FileAccess.open("res://../work/creatures/savages/death-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("HUMAN NPC DEATH: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
