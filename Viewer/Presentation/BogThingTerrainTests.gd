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
	var gradient := Vector2(.12, .09)
	var expected_normal := Vector3(-gradient.x, 1.0, -gradient.y).normalized()
	var plate := StaticBody3D.new()
	plate.basis = Basis(Quaternion(Vector3.UP, expected_normal))
	plate.position = -expected_normal * .1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, .2, 9.0)
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
	for origin: Vector3 in [Vector3.ZERO, Vector3(1, 0, -1), Vector3(4, 0, 0), Vector3(8, 0, 0)]:
		visual.position = origin
		for clip in ["Idle", "Walk", "Run", "Attack3"]:
			player.play(clip, 0.0)
			for sample in 21:
				player.seek(player.get_animation(clip).length * sample / 20.0, true)
				rig.force_update_all_bone_transforms()
				visual._physics_process(1.0 / 60.0)
				if origin.x >= 4.0:
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
	FileAccess.open(FOLDER + "runtime-grounding.json", FileAccess.WRITE).store_string(JSON.stringify({"supported": supported, "rejected": rejected, "max_error_m": max_error}))
	print("BOG THING GROUNDED RENDERER: ", supported, " supported; ", rejected, " rejected; max error ", max_error, " m")
	quit(int(max_error > .001))
