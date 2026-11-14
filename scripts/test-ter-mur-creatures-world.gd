# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Profiles := preload("res://Presentation/SourceTerMurProfile.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Game := preload("res://Network/GameSession.gd")
const Gargoyles := preload("res://Presentation/GargoyleAppearance.gd")
const Bodies := [293, 666, 667, 739]

func run() -> void:
	var folder := OS.get_environment("BR_TER_MUR_OUTPUT")
	if folder.is_empty():
		folder = Profiles.Folder
	if not expect(Profiles.enable(folder) == Bodies, "Activate all four hash-checked stages"):
		return
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not expect(world.enhanced_creature_actions == ("--enhanced-creature-actions" in OS.get_cmdline_user_args()),
			"The requested Classic or Enhanced World mode is active"):
		return
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var session := Game.new()
	if not expect(not session.toggle_gargoyle_flight(), "Flight request refuses an offline session"):
		return
	session.phase = "world"
	session.player = {"body": 400}
	if not expect(not session.toggle_gargoyle_flight(), "Flight request refuses a human body"):
		return
	session.free()
	for body: int in Bodies:
		if not await check_form(world, at, body):
			return
	if not await check_front_end():
		return
	var rows := Corpses.catalogue()
	for body: int in Bodies:
		if not expect(rows.any(func(row: Dictionary): return row.body == body and row.graphic == 0x2006),
				"Native corpse graphic catalogue includes " + str(body)):
			return
	print("TER MUR MODEL WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func check_form(world: Node, at: Vector2i, body: int) -> bool:
	var serial := 0x34100 + body
	var hue := 34536 if body == 666 else 0
	var native := mobile_packet(at, serial, body, 0)
	native[13] = hue >> 8
	native[14] = hue & 255
	world.game._handle(native)
	var avatar: Node3D = world.avatars.get(serial)
	if not expect(avatar != null and avatar.horse_visual != null, "Body %d has a 3D native actor" % body):
		return false
	var visual: Node3D = avatar.horse_visual
	if not expect(visual.native_body == body and visual.native_hue == hue and visual.skeleton.get_bone_count() > 25,
			"Body %d keeps its original server ID and hue on a real rig" % body):
		return false
	visual.play_gait(true, 2.0)
	if not expect(visual.current_clip == "Walk", "Body %d can walk" % body):
		return false
	var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var clip: Animation = visual.animator.get_animation("Walk")
	var bound: AABB
	for phase in range(12):
		visual.animator.seek(clip.length * float(phase) / 12.0, true)
		visual.animator.advance(0.0)
		visual.skeleton.force_update_all_bone_transforms()
		bound = Geometry.deformed_bounds(mesh, visual.skeleton)
		if not expect(bound.position.is_finite() and bound.size.x > .2 and bound.size.y > .3,
				"Body %d has finite full-skin walk pose %d" % [body, phase]):
			return false
	var override := mesh.get_surface_override_material(0) as ShaderMaterial
	if not expect(override != null and override.get_shader_parameter("use_hue") == (hue != 0),
			"Body %d handles its native palette in the shader" % body):
		return false
	if body in [666, 667]:
		if not check_gargoyle_equipment(world, serial, visual, body, hue):
			return false
		var armor := {"id": 0x304 if body == 666 else 0x303, "hue": 2305}
		visual.set_equipment([armor, {"id": 0x901}])
		var cyclone: MeshInstance3D = visual.model.find_child("Cyclone", true, false)
		if not expect(cyclone.visible and Corpses.supports_equipment(body), "Live Gargoyle equipment is supported"):
			return false
		var dyed := 0
		for surface in mesh.mesh.get_surface_count():
			if int(mesh.mesh.surface_get_material(surface).get_meta("ter_mur_armor_id", 0)) == 0x304:
				var garment := mesh.get_surface_override_material(surface) as ShaderMaterial
				dyed += int(garment.get_shader_parameter("use_hue"))
		if not expect(dyed == 1, "Chest uses its own server equipment hue"):
			return false
		var fitted := Corpses.build(body, hue, [armor, {"id": 0x901}])
		if not expect(fitted != null and fitted.find_child("Cyclone", false, false) != null,
				"The equipped corpse retains the actual weapon attachment"):
			return false
		fitted.free()
		visual.set_equipment([])
	if body != 739:
		native[15] = 4
		world.game._handle(native)
		if not expect(visual.current_clip == "Fly" and not visual.contact.enabled, "Body %d uses the native flight flag" % body):
			return false
		native[15] = 0
		world.game._handle(native)
		if not expect(visual.current_clip == "Idle" and visual.contact.enabled, "Body %d lands back to biped/ground animation" % body):
			return false
		if body in [666, 667] and not check_gargoyle_flight(world, visual, serial, native):
			return false
	var action := PackedByteArray([0x6e])
	action.append_array(Wire.uint_be(serial, 4))
	action.append_array(PackedByteArray([0, 4, 0, 5, 0, 1, 1, 0, 0]))
	world.game._handle(action)
	if not expect(visual.current_clip == "Attack", "Body %d accepts native Classic attack" % body):
		return false
	if body == 293 and not check_vollem_breath(world, visual, serial, action):
		return false
	world.game._handle(action_packet(serial, 3, 0))
	if not expect(visual.current_clip == "Death" and visual.dead, "Body %d accepts native newer death" % body):
		return false
	var corpse := 0x40000000 + serial
	world.game._handle(corpse_packet(at, corpse, body, hue))
	world.game._handle(death_packet(serial, corpse))
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	await create_timer(float(state.get("remaining", 0.0)) + .16).timeout
	var item: Node3D = world.world_items.nodes.get(corpse)
	var frozen := item.get_node_or_null("CorpseVisual") if item != null else null
	if not expect(frozen != null and frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == hue
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"Body %d keeps its identity and hue through a static frozen corpse" % body):
		return false
	var count := frozen.find_children("*", "MeshInstance3D", true, false).size()
	var frozen_mesh: MeshInstance3D = frozen.find_children("*", "MeshInstance3D", true, false)[0]
	return expect(count == 1 and frozen_mesh.mesh.get_surface_count() == mesh.mesh.get_surface_count(),
		"Body %d corpse keeps the full visible skinned surface" % body)


func check_gargoyle_equipment(world: Node, serial: int, visual: Node3D, body: int, hue: int) -> bool:
	var female := body == 667
	var worn := Gargoyles.starter(female)
	for item: Dictionary in worn:
		world.game._handle(gargoyle_wear_packet(serial, item))
	var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var regions := {}
	for surface in mesh.mesh.get_surface_count():
		var region := int(mesh.mesh.surface_get_material(surface).get_meta("ter_mur_armor_id", 0))
		if region in [0x304, 0x40a]:
			regions[region] = mesh.get_active_material(surface).get_shader_parameter("roughness")
	if not expect(regions.size() == 2 and is_equal_approx(regions[0x304], .96)
			and is_equal_approx(regions[0x40a], .96), "The stock chest and leg packets dress the Gargoyle in matte cloth"):
		return false
	var prior: MeshInstance3D
	for graphic: int in Gargoyles.horn_graphics(female):
		var item := {"id": graphic, "layer": 11, "hue": 0x70d}
		world.game._handle(gargoyle_wear_packet(serial, item))
		var name := "Horn11%04x" % graphic
		var horn: MeshInstance3D = visual.model.find_child(name, true, false)
		var material := horn.get_active_material(0) as ShaderMaterial if horn else null
		if not expect(horn != null and horn.visible and not (prior and prior.visible)
				and horn.get_parent().bone_name == "bip01 head" and material != null
				and material.get_shader_parameter("use_hue"),
				"Body %d selects and dyes horn %04x on its animated head" % [body, graphic]):
			return false
		prior = horn
	world.game.mobile_equipment.erase(serial)
	if female:
		return true
	for graphic: int in Gargoyles.FacialHorns:
		var horns := [{"id": 0x4259, "layer": 11, "hue": 0x70d}, {"id": graphic, "layer": 16, "hue": 0x765}]
		var fitted := Corpses.build(body, hue, worn + horns)
		var crown: MeshInstance3D = fitted.find_child("Horn114259", false, false)
		var facial: MeshInstance3D = fitted.find_child("Horn16%04x" % graphic, false, false)
		if not expect(crown and facial and crown.get_active_material(0).get_shader_parameter("hue_palette")
				!= facial.get_active_material(0).get_shader_parameter("hue_palette"),
				"The static corpse retains independent palettes for the crown and the facial horns"):
			fitted.free()
			return false
		fitted.free()
	return true


func gargoyle_wear_packet(serial: int, item: Dictionary) -> PackedByteArray:
	var packet := wear_packet(serial, int(item.id), int(item.hue))
	var item_serial := Wire.uint_be(0x41000000 + serial * 32 + int(item.layer), 4)
	for i in 4:
		packet[i+1] = item_serial[i]
	packet[8] = int(item.layer)
	return packet


func check_front_end() -> bool:
	var session := Game.new()
	root.add_child(session)
	session.characters = [{"name":"","slot":0}]
	session.cities = [{"name":"Britain","index":0,"x":1496,"y":1628}]
	session.phase = "characters"
	var front: Control = load("res://Network/FrontEnd.gd").new()
	root.add_child(front)
	front.session = session
	front.go("create")
	if not expect(not front.race_picker.visible, "The creation screen respects the server's expansion features"):
		front.free()
		session.free()
		return false
	session._handle(PackedByteArray([0xb9, 0, 1, 0, 0]))
	front._preview_creation()
	if not expect(front.race_picker.visible, "Verified local assets and server features enable Gargoyle creation"):
		front.free()
		session.free()
		return false
	front.creation_rows.gargoyle[1].pressed.emit()
	await process_frame
	var ok := expect(front.stage.avatar.initial_body == 666 and front.creation_rows.hair.size() == 9,
		"The creation screen previews the male Gargoyle with eight native horn choices")
	front.creation_rows.sex[1].pressed.emit()
	await process_frame
	ok = expect(front.stage.avatar.initial_body == 667 and front.creation_rows.hair.size() == 10
		and front.beard_rows.is_empty(), "The female preview has nine native horn choices and no separate facial layer") and ok
	var male := Game.creation_packet("Test Keeper",0,0,false,{"gargoyle":true,"hair_id":0x4259})
	var female := Game.creation_packet("Test Witness",0,0,true,{"gargoyle":true,"hair_id":0x42b0})
	ok = expect(male[70] == 6 and female[70] == 7 and male[84] == 0x42 and female[85] == 0xb0,
		"The creation packets use the two verified gender/race bytes and transmit the original horn IDs") and ok
	front.free()
	session.free()
	return ok


func check_gargoyle_flight(world: Node, visual: Node3D, serial: int, native: PackedByteArray) -> bool:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, 60, 0, 10, 0, 1, 0, 0, 0]))
	world.game._handle(packet)
	native[15] = 4
	world.game._handle(native)
	if not expect(visual.current_clip == "TakeOff" and visual.flying and not visual.contact.enabled,
			"Gargoyle group 60 follows the real takeoff packet and airborne flag"):
		return false
	visual._physics_process(.4)
	if not expect(is_equal_approx(visual.model.position.y - visual.ground_offset, .36), "Airborne Gargoyle separates from ground contact"):
		return false
	visual.action_remaining = 0.0
	visual.play_gait(true, 2.0)
	if not expect(visual.current_clip == "Fly", "Airborne movement keeps the wing cycle"):
		return false
	packet[6] = 61
	world.game._handle(packet)
	native[15] = 0
	world.game._handle(native)
	if not expect(visual.current_clip == "Land" and not visual.flying, "Gargoyle group 61 keeps the native landing"):
		return false
	visual._physics_process(.5)
	visual.action_remaining = 0.0
	visual.play_gait(false, 0.0)
	return expect(is_equal_approx(visual.flight_lift, 0.0) and visual.current_clip == "Idle" and visual.contact.enabled,
		"Gargoyle regains its standing pose and ground contact after landing")


func check_vollem_breath(world: Node, visual: Node3D, serial: int, request: PackedByteArray) -> bool:
	request[6] = 12
	request[11] = 0
	world.game._handle(request)
	if not expect(visual.current_clip == "VollemFireBreath" and visual.action_remaining > 2.0,
			"The stock five-frame Vollem windup starts the dedicated visible breath"):
		return false
	var length: float = visual.animator.get_animation(visual.current_clip).length
	visual.animator.seek(length * 1.3 / 2.1, true)
	visual.animator.advance(0.0)
	var mouth: Variant = visual.fire_breath_origin()
	var effect := {"source": serial, "graphic": 0x36d4, "from": Vector3i.ZERO}
	for node: Node in world.get_children():
		if node.has_method("_bolt_origin"):
			var actual: Vector3 = node._bolt_origin(effect)
			var head: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.breath_joint).origin)
			return expect(mouth is Vector3 and actual.distance_to(mouth) < .001 and actual.distance_to(head) < .7
					and actual.distance_to(head) > .04 and actual.y > visual.global_position.y + .20,
				"The real World effect starts at Vollem's animated muzzle: " + str([node.get_script().resource_path, actual, mouth, visual.global_position]))
	return expect(false, "The normal World effect presenter is available")
