extends SceneTree
const Bog = preload("res://Presentation/SourceBogThingVisual.gd")

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


const FOLDER := "res://../work/creatures/bog-thing/"
func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2)); call_deferred("run")

func surface_hit(world: World3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point - Vector3.UP * 3.0, 1)
	return world.direct_space_state.intersect_ray(query)

func run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var step := "--step" in OS.get_cmdline_user_args()
	var right := Vector3(2.45, .15, 4.9) if step else Vector3(2.75, -.1, 4.3)
	for area in [Vector3(-4.5, -.1, 9.0), right]:
		var plate := StaticBody3D.new()
		plate.position = Vector3(area.x, area.y, 0)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(area.z, .2, 9.0)
		collider.shape = shape
		plate.add_child(collider)
		arena.add_child(plate)
	var visual := preload("res://Presentation/CreatureRegistry.gd").create(780) as Bog
	assert(visual != null)
	arena.add_child(visual)
	visual.set_physics_process(false)
	visual.set_process(false)
	var player: AnimationPlayer = visual.animator
	var rig: Skeleton3D = visual.skeleton
	var mesh: MeshInstance3D = visual.base_mesh
	var corners := visual.footprint
	assert(corners.size() == 103)
	await physics_frame
	await physics_frame
	var supported := 0
	var rejected := 0
	var max_error := 0.0
	for origin: Vector3 in [Vector3(-3,0,0), Vector3(-2,0,0), Vector3(-.1,0,0), Vector3(1.5,0,0), Vector3(3,0,0), Vector3(.3,0,0)]:
		visual.position = origin
		for clip in ["Idle", "Walk", "Run", "Attack3", "Death"]:
			player.play(clip, 0.0)
			for sample in 21:
				player.seek(player.get_animation(clip).length * sample / 20.0, true)
				rig.force_update_all_bone_transforms()
				visual.model.transform = visual.neutral_model
				var complete := not surface_hit(arena.get_world_3d(), origin).is_empty()
				var unadjusted := skinned(mesh, rig)
				for i in corners:
					if surface_hit(arena.get_world_3d(), unadjusted[i]).is_empty():
						complete = false
				visual._physics_process(1.0 / 60.0)
				if not complete:
					assert(visual.model.transform.is_equal_approx(visual.neutral_model))
					rejected += 1
					continue
				var low := INF
				var points := skinned(mesh, rig)
				for i in corners:
					var hit := surface_hit(arena.get_world_3d(), points[i])
					assert(not hit.is_empty())
					low = minf(low, points[i].y - float(hit.position.y))
				max_error = maxf(max_error, absf(low))
				supported += 1
	FileAccess.open(FOLDER + ("runtime-grounding-step.json" if step else "runtime-grounding-gap.json"), FileAccess.WRITE).store_string(JSON.stringify({"supported": supported, "rejected": rejected, "max_error_m": max_error}))
	print("BOG THING GROUNDED RENDERER: ", supported, " supported; ", rejected, " rejected; max error ", max_error, " m")
	quit(int(max_error > .001))
