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
func run() -> void:
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();root.add_child(arena);var items:=Items.new();arena.add_child(items)
	var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items)
	var selected: Array[int]=[]
	for body in [211,1,103,574,26]:
		if Registry.supports_body(body):selected.append(body)
	for body in selected:
		var killed:=10000+body;var corpse:=0 if body==574 else 0x40010000+body
		var avatar:=Avatar.new();arena.add_child(avatar);avatar.horse_visual=Registry.create(body);avatar.add_child(avatar.horse_visual);avatar.horse_visual.apply_identity(body,53)
		avatar.position=Vector3(3.,0.,-4.);arena.avatars[killed]=avatar
		game.entities[killed]={"serial":killed,"body":body,"hue":53,"x":100,"y":200,"z":0,"direction":5}
		var original: Dictionary=game.entities[killed].duplicate(true);var body_transform: Transform3D=avatar.horse_visual.global_transform
		var holder:=Node3D.new();items.add_child(holder)
		var collider:=StaticBody3D.new();holder.add_child(collider);collider.collision_layer=4
		if corpse!=0:items.nodes[corpse]=holder
		game._handle(packet(killed,corpse))
		check(deaths.active.has(killed),"Native 0xAF starts a supported creature death")
		if not deaths.active.has(killed):continue
		var visual: Node3D=deaths.active[killed].visual
		check(visual.native_body==body and visual.native_hue==53,"Death snapshot keeps body and dye")
		check(visual.dead and visual.current_clip=="Death" and not visual.contact.enabled,"Death source clip releases living contact")
		check(visual.global_position.is_equal_approx(body_transform.origin),"Death snapshot begins at displayed world position")
		check(is_equal_approx(visual.rotation.y,PI-5.*PI/4.),"Death follows native facing")
		check(not avatar.visible and game.entities[killed]==original,"Visual transition does not mutate authoritative entity data")
		if corpse!=0:
			check(not holder.visible and collider.collision_layer==4,"Pending corpse visuals hide while interaction remains active")
			check(int(game.module("player").corpse_directions[corpse])==5,"Native death caches victim facing for its corpse")
		game._handle(packet(killed,corpse));check(deaths.active.size()==1,"Repeated death packet is idempotent")
		var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(killed,4));game._handle(remove);arena.avatars.erase(killed);avatar.queue_free()
		for frame in 3:await process_frame
		check(is_instance_valid(visual) and visual.animator.is_playing(),"Death snapshot survives native mobile removal")
		if corpse!=0:
			var replacement:=Node3D.new();items.add_child(replacement);items.nodes[corpse]=replacement;holder.queue_free();holder=replacement
			game.world_item_changed.emit(corpse,{"id":0x2006,"amount":body})
			check(not holder.visible,"A refreshed pending corpse remains hidden")
		deaths._process(float(deaths.active[killed].remaining)+.1)
		check(deaths.active.is_empty(),"Death snapshot expires after its source clip")
		if corpse!=0:
			check(holder.visible,"Corpse becomes visible after death playback")
			game.world_item_removed.emit(corpse);check(not game.module("player").corpse_directions.has(corpse),"Removed corpse releases direction cache")
		items.nodes.erase(corpse);holder.queue_free()
		for frame in 2:await process_frame
	game.entities[999]={"body":400};deaths.begin_death(999,0);check(deaths.active.is_empty(),"Unsupported bodies do not acquire invented death visuals")
	game.ended.emit();check(deaths.active.is_empty() and deaths.held_corpses.is_empty(),"Disconnect clears temporary presentation")
	check(not selected.is_empty(),"Actual accepted creature assets exercised")
	print("CREATURE DEATH PRESENTATION: ",checks-failures," / ",checks);quit(1 if failures else 0)
