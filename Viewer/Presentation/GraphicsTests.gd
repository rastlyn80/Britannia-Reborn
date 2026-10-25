extends SceneTree
const Jump = preload("res://Presentation/JumpMotion.gd")
const Motion = preload("res://Presentation/MotionTrack.gd")
const Geometry = preload("res://Presentation/GeometryLibrary.gd")
const Session = preload("res://Network/GameSession.gd")
const Boom = preload("res://Presentation/CameraBoom.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS ",description)
	else:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func solid(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

func run() -> void:
	var walking := Session.movement_packet(10,3,false)
	var running := Session.movement_packet(10,3,true)
	check(walking.size() == 7 and walking[1] == 2 and running[1] == 0x82 and running[2] == 3,"real UO run flag preserves direction and sequence")
	var motion := Motion.new()
	motion.push(Vector3(1,0,0),0.41)
	motion.push(Vector3(2,0,0),0.21)
	check(motion.advance(0.515).is_equal_approx(Vector3(1.5,0,0)),"walk-to-run transition retains duration of each segment")
	var jump := Jump.new()
	check(not jump.start(0.1),"jump refuses insufficient headroom")
	check(jump.start(0.7) and not jump.start(0.7),"jump starts once and prevents double jumping")
	var peak := 0.0
	for i in 100: peak = maxf(peak,jump.advance(0.01,0.7))
	check(peak <= 0.701 and peak >= 0.68 and jump.height == 0 and not jump.airborne,"jump arc respects ceiling and returns exactly to ground")
	jump.start(1)
	jump.advance(0.12)
	jump.advance(0.04,0.2)
	check(jump.height <= 0.2 and jump.velocity <= 0,"new low ceiling clamps ascent while moving")
	var a := Jump.new()
	var b := Jump.new()
	a.start(1)
	b.start(1)
	for i in 6: a.advance(1.0/30)
	for i in 24: b.advance(1.0/120)
	check(is_equal_approx(a.height,b.height),"jump integration is frame-rate independent")
	var north := {"rise":[0,-1]}
	var south := {"rise":[0,1]}
	check(is_equal_approx(Geometry.roof_height(0.5,0,north),Geometry.roof_height(0.5,1,north)+0.6),"roof slope matches three UO elevation units")
	check(is_equal_approx(Geometry.roof_height(0.5,1,south),Geometry.roof_height(0.5,0,south)+0.6),"opposite roof slope retains boundary continuity")
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	check(scene.reconstruction.unresolved == 0 and scene.reconstruction.report.size() == scene.world.statics.size(),"every source static has an explicit replacement or grouped contribution")
	var anchors := true
	for i in scene.world.statics.size():
		var source: Dictionary = scene.world.statics[i]
		var entry: Dictionary = scene.reconstruction.report[i]
		if entry.ordinal != i or entry.id != source.id or entry.xyz != [source.x,source.y,source.z]: anchors = false
	check(anchors,"all source IDs, ordinals and XYZ survive reconstruction")
	var group_owner_is_trunk := true
	for ordinal in scene.reconstruction.groups:
		var group: Dictionary = scene.reconstruction.groups[ordinal]
		if group.kind == "tree" and scene.reconstruction.rule_for(scene.world.statics[group.owner].id).kind != "tree": group_owner_is_trunk = false
	check(group_owner_is_trunk and scene.reconstruction.grouped > 0,"canopy records reference a trunk owner without duplicate trees")
	check(scene.collision_builder.triangles > 1000 and scene.find_children("SolidChunk*","StaticBody3D",true,false).size() > 0,"reconstructed geometry produces actual solid collision bodies")
	check(scene.entity_point(int(scene.world.originX),int(scene.world.originY),-5).is_equal_approx(Vector3(0.5,-1,0.5)),"character and static footprints share the same tile centre")
	var green := false
	for mesh in scene.static_root.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(surface)
			if mat is StandardMaterial3D and mat.resource_name == "Leaves_TwistedTree": green = not mat.vertex_color_use_as_albedo and mat.albedo_texture.resource_path.ends_with("Leaves_NormalTree_C.png")
	check(green,"Britain foliage uses the green palette rather than default red leaves")
	scene.queue_free()
	await process_frame
	var stage := Node3D.new()
	root.add_child(stage)
	var wall := solid(stage,Vector3(0,1.5,3),Vector3(10,4,0.1))
	var arm := Boom.new()
	arm.position = Vector3(0,1.5,0)
	stage.add_child(arm)
	arm.add_child(Camera3D.new())
	arm.spring_length = 7
	await physics_frame
	await physics_frame
	await process_frame
	check(arm.get_hit_length() < 2.8 and arm.get_hit_length() > 2.0,"swept camera retracts before a thin wall")
	wall.position.x = 30
	await physics_frame
	await physics_frame
	await process_frame
	check(arm.get_hit_length() > 6.8,"camera restores distance after obstruction clears")
	var ceiling := solid(stage,Vector3(0,2.15,0),Vector3(5,0.1,5))
	await physics_frame
	await physics_frame
	var room := arm.headroom(stage.get_world_3d().direct_space_state,Vector3.ZERO)
	check(room > 0.1 and room < 0.4,"capsule sweep measures real low-ceiling jump clearance")
	ceiling.position.y = 1.5
	await physics_frame
	await physics_frame
	check(arm.headroom(stage.get_world_3d().direct_space_state,Vector3.ZERO) == 0,"initial head overlap blocks jumping")
	stage.free()
	print("GRAPHICS CHECKS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
