extends "res://Presentation/HumanNPCDeathTests.gd"
## Native order: remove worn items, create equipped corpse, then send0xAF.
func run() -> void:
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();root.add_child(arena);var items:=Items.new();arena.add_child(items)
	var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items)
	for body: int in [185,186,400,401]:
		var serial:=900000+body;var corpse:=0x40080000+body
		var entity:={"serial":serial,"body":body,"hue":0x8035,"flags":0,"direction":3}
		game.entities[serial]=entity
		var worn: Array=[{"serial":corpse+1000,"id":0x1f03,"layer":22,"hue":53,"container":serial},{"serial":corpse+1001,"id":0x144e,"layer":19,"hue":54,"container":serial}]
		var removed:={"serial":corpse+1002,"id":0x203c,"layer":11,"hue":55,"container":serial}
		var actor:=Avatar.new();actor.initial_body=body;arena.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		actor.apply_server_appearance(entity,worn+[removed]);actor.human_visual.set_process(false);arena.avatars[serial]=actor
		game.mobile_equipment[serial]={22:worn[0],19:worn[1],11:removed}
		var callback:=func(changed: int):
			if changed==serial:actor.apply_server_appearance(entity,game.mobile_equipment.get(serial,{}).values())
		game.appearance_changed.connect(callback)
		for item: Dictionary in worn+[removed]:
			var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(item.serial,4));game._handle(remove)
			game.remember_item(item.merged({"container":corpse if item.layer!=11 else corpse+99},true))
		check(actor.human_visual.server_equipment.is_empty(),"Normal live appearance has already lost transferred gear before0xAF")
		var equipment:=PackedByteArray([0x89]);equipment.append_array(Wire.uint_be(28,2));equipment.append_array(Wire.uint_be(corpse,4))
		for item: Dictionary in worn+[removed]:equipment.append(int(item.layer)+1);equipment.append_array(Wire.uint_be(item.serial,4))
		var mount_serial:=corpse+1003
		game.remember_item({"serial":mount_serial,"id":0x3eb8,"hue":0,"container":corpse})
		equipment.append(26);equipment.append_array(Wire.uint_be(mount_serial,4));equipment.append(0)
		game._handle(equipment);game._handle(packet(serial,corpse))
		check(deaths.active.has(serial),"Native-order0xAF begins the supported human death")
		if deaths.active.has(serial):
			var visual: Node3D=deaths.active[serial].visual
			check(visual.server_equipment.size()==2,"Death resolves only the actual corpse's two known worn items")
			for expected: Dictionary in worn:
				check(visual.server_equipment.any(func(actual: Dictionary):return actual.serial==expected.serial and actual.id==expected.id and actual.layer==expected.layer and actual.hue==expected.hue and actual.container==corpse),"Death restores exact server serial, graphic, layer and hue from corpse ownership")
			check(not visual.server_equipment.any(func(actual: Dictionary):return int(actual.layer) in [11,25]),"Previously removed mask and mount layer are never resurrected")
			check(visual.current_clip=="Death" and visual.native_body==body and visual.native_hue==0x8035,"Equipment recovery preserves native body, partial hue and death animation")
			deaths.finish(serial)
		game.appearance_changed.disconnect(callback);arena.avatars.erase(serial);actor.free();game.entities.erase(serial)
		await process_frame
	game.ended.emit()
	print("HUMAN CORPSE TRANSFER: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
