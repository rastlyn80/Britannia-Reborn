extends SceneTree

const Floors = preload("res://Presentation/FloorPlan.gd")
const Contact = preload("res://Presentation/FootContact.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS ",description)
	else:
		failures += 1
		push_error(description)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var catalog := {"1":{"kind":"floor"},"2":{"kind":"wall"},"3":{"kind":"stairs"},"4":{"kind":"door"}}
	for origin in [Vector2i.ZERO,Vector2i(701,-408)]:
		var tiles: Array = []
		for at in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]: tiles.append({"x":origin.x+at.x,"y":origin.y+at.y,"z":-20,"id":1})
		tiles.append({"x":origin.x,"y":origin.y+1,"z":-21,"id":2})
		var world := {"statics":tiles,"elevationScale":0.2}
		var plan := Floors.new()
		plan.index(world,catalog)
		check(plan.repairs == [Vector3i(origin.x,origin.y,-20)],"isolated basement void repair follows translated topology")
		tiles.append({"x":origin.x,"y":origin.y,"z":-25,"id":3})
		plan.index(world,catalog)
		check(plan.repairs.is_empty(),"stairwell is never filled by missing-floor repair")
		tiles[-1].id = 1
		tiles[-1].z = -40
		plan.index(world,catalog)
		check(plan.repairs.is_empty(),"lower floor opening is preserved")
		tiles[-1].id = 4
		plan.index(world,catalog)
		check(plan.repairs.is_empty(),"doorway opening is preserved")
	var plan := Floors.new()
	plan.index({"statics":[{"x":0,"y":0,"z":0,"id":1},{"x":1,"y":0,"z":-1,"id":2},{"x":2,"y":0,"z":10,"id":3},{"x":3,"y":0,"z":15,"id":3}],"elevationScale":0.2},catalog)
	check(is_equal_approx(plan.edges[0].y,0.51) and plan.edges[0].x == 0,"floor extends only toward neighboring wall base")
	check(plan.stair_rise[2] == Vector2.RIGHT,"stair rise inferred from increasing source elevations")
	var slab := plan.slab(0,StandardMaterial3D.new())
	check(is_equal_approx(slab.position.y+slab.mesh.size.y/2,0),"solid floor top remains exactly at canonical source elevation")
	slab.free()
	var hip := Vector3(0,1,0)
	var knee := Vector3(0,0.55,0.2)
	var ankle := Vector3(0,0.1,0)
	var target := Vector3(0,0.3,0.12)
	var solved := Contact.knee_target(hip,knee,ankle,target)
	check(absf(hip.distance_to(solved)-hip.distance_to(knee)) < 0.0001 and absf(solved.distance_to(target)-knee.distance_to(ankle)) < 0.0001,"two-bone solve preserves both limb lengths on raised step")
	check(Contact.knee_target(hip,knee,ankle,Vector3(0,-5,0)).is_finite(),"unreachable foot target remains finite")
	var facade := preload("res://Presentation/Facade.gd").new()
	var corner_catalog := {"1":{"kind":"wall","axis":"x"},"2":{"kind":"wall","axis":"y"},"3":{"kind":"door"}}
	for sign_x in [-1,1]:
		for sign_y in [-1,1]:
			var layout := {"statics":[{"x":700,"y":300,"z":-21,"id":1},{"x":700+sign_x,"y":300+sign_y,"z":-21,"id":2}],"staticData":{"1":{"height":20},"2":{"height":20}},"elevationScale":0.2}
			facade.index(layout,corner_catalog)
			check(facade.diagonal_joins == 1 and facade.plans[0].get("extend_left" if sign_x < 0 else "extend_right",false) and facade.plans[1].get("extend_left" if sign_y < 0 else "extend_right",false),"diagonal wall ends seal their shared axis intersection in every orientation")
			layout.statics.append({"x":700+sign_x,"y":300,"z":-21,"id":3})
			facade.index(layout,corner_catalog)
			check(facade.diagonal_joins == 0,"diagonal seal preserves an explicit doorway at the junction")
	var surface := preload("res://Presentation/MovementSurface.gd").new()
	var stairs_world := {"terrain":[],"landData":{},"staticData":{"1":{"flags":1536,"height":5},"2":{"flags":64,"height":20}},"statics":[{"x":0,"y":0,"z":0,"id":1},{"x":1,"y":0,"z":5,"id":1},{"x":2,"y":0,"z":10,"id":1}]}
	surface.index(stairs_world)
	check(surface.predict({"x":0,"y":0,"z":2},2).get("z") == 7,"ascending stairs predict bridge half-height with full-top step reach")
	check(surface.predict({"x":2,"y":0,"z":12},6).get("z") == 7,"descending stairs predict a continuous source-backed endpoint")
	stairs_world.statics.append({"x":1,"y":0,"z":5,"id":2})
	surface.index(stairs_world)
	check(surface.predict({"x":0,"y":0,"z":2},2).is_empty(),"stair prediction never crosses a source wall")
	stairs_world.statics.pop_back()
	stairs_world.staticData["3"] = {"flags":512,"height":0}
	stairs_world.statics.append({"x":1,"y":0,"z":10,"id":3})
	surface.index(stairs_world)
	check(surface.predict({"x":0,"y":0,"z":2},2).is_empty(),"stair prediction rejects insufficient headroom below an upper floor")
	var terrain_world := {"originX":90,"originY":80,"width":5,"height":5,"elevationScale":0.2,"terrain":[],"statics":[],"landData":{"1":{"name":"grass"}},"staticData":{"2":{"name":"stone wall"}}}
	for y in range(80,85):
		for x in range(90,95): terrain_world.terrain.append({"x":x,"y":y,"z":6 if x==92 and y==82 else 0,"id":1})
	var raw := JSON.stringify(terrain_world)
	var terrain := preload("res://Presentation/TerrainSurface.gd").new()
	terrain.index(terrain_world)
	check(terrain.peak_repairs.size() == 1 and is_equal_approx(terrain.height_at(Vector2(92,82)),0.2),"isolated natural spike becomes a low bounded rise")
	check(is_equal_approx(terrain.raw_z(Vector2i(92,82)),1.2) and JSON.stringify(terrain_world) == raw,"spike filtering preserves source elevations and canonical IR")
	terrain_world.statics.append({"x":92,"y":82,"z":0,"id":2})
	terrain.index(terrain_world)
	check(terrain.peak_repairs.is_empty(),"spike filter protects building foundations")
	terrain_world.statics.clear()
	terrain_world.terrain[13].z = 6
	terrain.index(terrain_world)
	check(terrain.peak_repairs.is_empty(),"connected natural ridge is preserved")
	var roof_fixture := {"originX":0,"originY":0,"width":4,"height":4,"elevationScale":0.2,"terrain":[],"landData":{},"staticData":{"1194":{"height":0},"300":{"height":10},"1476":{"height":3}},"statics":[{"x":0,"y":0,"z":0,"id":1194},{"x":0,"y":0,"z":0,"id":300},{"x":1,"y":1,"z":20,"id":1476}]}
	var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
	reconstruction.index(roof_fixture)
	var shell := preload("res://Presentation/InteriorShell.gd").new()
	shell.index(roof_fixture,reconstruction)
	check(shell.ceilings.has(0) and shell.wall_caps.has(1) and shell.wall_caps[1].height > 1.5,"short wall receives a supported closure up to the interior roof liner")
	var floor_fixture := {"originX":0,"originY":0,"width":3,"height":3,"elevationScale":0.2,"terrain":[],"statics":[{"id":1194,"x":0,"y":0,"z":0}],"staticData":{"1194":{"name":"wooden boards","height":0}},"landData":{"1":{"name":"wooden floor"}}}
	for y in 3:
		for x in 3: floor_fixture.terrain.append({"id":1,"x":x,"y":y,"z":0})
	terrain.index(floor_fixture)
	check(terrain.floor_overrides.size() == 1 and terrain.floor_overrides.has(Vector2i.ZERO),"static floor owns a coincident terrain cell without double drawing")
	floor_fixture.statics[0].z = -20
	terrain.index(floor_fixture)
	check(terrain.floor_overrides.is_empty(),"basement floor never removes the separate ground storey")
	reconstruction.index(floor_fixture)
	shell.index(floor_fixture,reconstruction)
	floor_fixture.statics.append(floor_fixture.statics[0].duplicate())
	reconstruction.index(floor_fixture)
	check(reconstruction.groups[0].owner == reconstruction.groups[1].owner,"duplicate source floor records share one reconstruction owner")
	var lining := shell.build(floor_fixture,reconstruction)
	var liner: MeshInstance3D = lining.get_child(0)
	check(liner.position.y+liner.mesh.size.y/2 <= -0.019,"basement ceiling top stays below the ground floor to prevent z-fighting")
	lining.free()
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.reconstruction.floors.stair_rise.size() >= 10,"real Britain stair runs resolve source-backed directions")
	var consistent_stairs := true
	var material_fixture := preload("res://Presentation/Reconstruction.gd").new()
	for id in [1824,1848,1872]:
		var landing: Node3D = material_fixture.build({"id":id,"x":0,"y":0,"z":0,"hue":0},scene.world)
		var expected: Material = material_fixture.facade.material("stone" if id == 1872 else "wood")
		consistent_stairs = consistent_stairs and landing.get_child(0).get_child(0).material_override == expected and landing.get_child(0).get_child(1).material_override == expected
		landing.free()
	check(consistent_stairs,"wood and stone stair supports share the tread texture and surface material")
	var on_stairs := {"x":1621,"y":1576,"z":-20}
	var stair_path := true
	for i in 5:
		var next: Dictionary = scene.movement_surface.predict(on_stairs,6)
		if next.is_empty():
			stair_path = false
			break
		on_stairs = next
	check(stair_path and on_stairs.x == 1616,"complete real basement stair ascent has source-backed continuous predictions")
	for i in 5:
		var next: Dictionary = scene.movement_surface.predict(on_stairs,2)
		if next.is_empty():
			stair_path = false
			break
		on_stairs = next
	check(stair_path and on_stairs.x == 1621 and on_stairs.z == -20,"complete real basement stair descent returns to its canonical floor")
	check(scene.interior_shell.ceilings.size() > 100,"room-supported roof liners and wall-top closures generated")
	var cables_safe := true
	var basement_lights := 0
	var lighting = scene.get_node("DistrictLighting")
	for span in lighting.fixture_spans:
		if span.floor_y < 0: basement_lights += 1
		for floor in scene.world.terrain:
			if floor.x != floori(span.source_x) or floor.y != floori(span.source_y): continue
			var level := float(floor.z)*float(scene.world.elevationScale)
			if level > span.lamp_y and level < span.ceiling_y-0.001: cables_safe = false
	check(cables_safe and basement_lights > 0,"basement light suspension stops at its ceiling without crossing the bedroom floor")
	var unchanged := JSON.stringify(scene.world)
	for i in scene.interior_shell.ceilings:
		check_ceiling(scene,i)
	check(JSON.stringify(scene.world) == unchanged,"interior reconstruction leaves canonical source IR untouched")
	var avatar := preload("res://Presentation/Avatar.gd").new()
	root.add_child(avatar)
	avatar.set_physics_process(false)
	await process_frame
	avatar.animate(true,0,0.1,2.66)
	avatar.animator.advance(0.2)
	var phase := avatar.animator.current_animation_position/avatar.animator.current_animation_length
	avatar.displayed_speed = 5
	avatar.animate(true,0,0.001,5)
	check(avatar.current_clip == "Sprint" and absf(avatar.animator.current_animation_position/avatar.animator.current_animation_length-phase) < 0.01,"walk/run blend preserves stride phase")
	for i in 40: avatar.animate(true,0,0.016,3.5)
	check(avatar.current_clip == "Sprint","gait hysteresis prevents rapid clip switching near run threshold")
	avatar.jump.start(1)
	avatar.animate(true,0,0.016,3)
	check(not avatar.foot_contact.grounded,"foot contact releases during jump")
	avatar.jump.reset()
	avatar.position = Vector3(100,0,100)
	avatar.animate(false,0,0.2,0)
	var support := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,0.1,4)
	collision.shape = box
	support.position = Vector3(100,-0.05,100)
	support.add_child(collision)
	root.add_child(support)
	var solved_feet := {}
	var rig: Skeleton3D = avatar.foot_contact.get_skeleton()
	avatar.foot_contact.modification_processed.connect(func():
		for side in ["l","r"]: solved_feet[side] = (rig.global_transform*rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin).y)
	for i in 40:
		await physics_frame
		avatar.foot_contact.sample(avatar.get_world_3d().direct_space_state,0)
		avatar.animate(false,0,0.016,0)
		await process_frame
	check(solved_feet.size() == 2 and absf(solved_feet.get("l",10)-0.085) < 0.035 and absf(solved_feet.get("r",10)-0.085) < 0.035,"post-animation foot solver places both idle soles on real physics floor")
	var raised := StaticBody3D.new()
	var raised_shape := CollisionShape3D.new()
	var raised_box := BoxShape3D.new()
	raised_box.size = Vector3(4,0.18,4)
	raised_shape.shape = raised_box
	raised.position = Vector3(100,0.09,100)
	raised.add_child(raised_shape)
	root.add_child(raised)
	for i in 40:
		await physics_frame
		avatar.foot_contact.sample(avatar.get_world_3d().direct_space_state,0)
		await process_frame
	check(absf(solved_feet.get("l",10)-0.265) < 0.04 and absf(solved_feet.get("r",10)-0.265) < 0.04,"both feet reach a raised tread without moving the authoritative root")
	raised.free()
	support.position.y = 3
	await physics_frame
	await physics_frame
	avatar.foot_contact.sample(avatar.get_world_3d().direct_space_state,0)
	check(avatar.foot_contact.contacts.is_empty(),"support sampling rejects upper-storey floors outside bounded reach")
	support.free()
	var arm := preload("res://Presentation/CameraBoom.gd").new()
	arm.position = Vector3(100,1.4,100)
	arm.collision_mask = 3
	var camera := Camera3D.new()
	arm.add_child(camera)
	root.add_child(arm)
	arm.collision_mask = 3
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 2
	obstacle.position = Vector3(100,1.4,103)
	var trunk_shape := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.18
	trunk.height = 3
	trunk_shape.shape = trunk
	obstacle.add_child(trunk_shape)
	root.add_child(obstacle)
	for i in 5:
		await physics_frame
		await process_frame
		arm.set_distance(7,0.016)
	check(camera.position.z < 2.8 and camera.position.z > 2,"camera-only trunk collider retracts view without a canopy-sized blocker")
	check(arm.headroom(arm.get_world_3d().direct_space_state,Vector3(100,0,103)) > 0.9,"camera-only tree layer never blocks character headroom")
	var tucked := arm.visual_distance
	obstacle.position.x += 10
	for i in 3:
		await physics_frame
		await process_frame
	arm.set_distance(7,0.016)
	check(arm.visual_distance > tucked and arm.visual_distance < tucked+1,"camera restores outward gradually after obstruction clears")
	for i in 80: arm.set_distance(7,0.016)
	check(arm.visual_distance > 6.9 and arm.spring_length == 7,"camera recovery reaches requested range without shortening future sweeps")
	arm.free()
	obstacle.free()
	avatar.free()
	scene.free()
	print("CONTACT/INTERIORS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)

func check_ceiling(scene, ordinal: Variant) -> void:
	# Aggregate assertion to avoid hundreds of repetitive check lines.
	var height: float = scene.interior_shell.ceilings[ordinal]
	if height < 1.85 or height > 5.0:
		failures += 1
		push_error("ceiling leaves plausible room headroom")
