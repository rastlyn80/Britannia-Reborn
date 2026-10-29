extends SceneTree
## Actual GPU coverage: visible skin plus clothed occupancy against the full body.
var viewport: SubViewport
var camera: Camera3D
var rows: Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	var result:=viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result
func solid(colour: Vector3) -> ShaderMaterial:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded;void fragment(){ALBEDO=vec3(%s,%s,%s);}" % [colour.x,colour.y,colour.z]
	var result:=ShaderMaterial.new();result.shader=shader;return result
func skin_probe(mesh: MeshInstance3D, rig: Skeleton3D) -> ArrayMesh:
	# Classify the intentionally bare head/neck from original skin bindings,
	# before animation, so a bent head cannot be mistaken for exposed torso.
	var result:=ArrayMesh.new()
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		var colours:=PackedColorArray();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		for i in vertices.size():
			var head_weight:=0.
			for j in 4:
				var binding:=bones[i*4+j];var name:=String(mesh.skin.get_bind_name(binding))
				if name.is_empty():name=rig.get_bone_name(mesh.skin.get_bind_bone(binding))
				if name.begins_with("head") or name.begins_with("neck"):head_weight+=weights[i*4+j]
			colours.append(Color.BLACK if head_weight>.2 else Color.MAGENTA)
		arrays[Mesh.ARRAY_COLOR]=colours
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
func locate_probe(mesh: MeshInstance3D, rig: Skeleton3D, pixel: Vector2) -> void:
	var best:=INF;var detail:={}
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		for i in vertices.size():
			var point:=Vector3.ZERO;var labels:={}
			for j in 4:
				var binding:=bones[i*4+j];var name:=String(mesh.skin.get_bind_name(binding))
				if name.is_empty():name=rig.get_bone_name(mesh.skin.get_bind_bone(binding))
				var weight:=weights[i*4+j];labels[name]=weight
				point+=(rig.get_bone_global_pose(rig.find_bone(name))*mesh.skin.get_bind_pose(binding)*vertices[i])*weight
			point=rig.global_transform*point
			var distance:=camera.unproject_position(point).distance_squared_to(pixel)
			if distance<best:best=distance;detail={"point":point,"weights":labels,"distance_pixels":sqrt(best)}
	print("SKIN PROBE ",pixel," ",detail)
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=1.;viewport.add_child(environment)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.1;camera.position=Vector3(0,1.,4.);viewport.add_child(camera);camera.look_at(Vector3(0,1.,0))
	var pink:=solid(Vector3(1,0,1));var white:=solid(Vector3.ONE)
	pink.shader.code="shader_type spatial;render_mode unshaded;void fragment(){ALBEDO=COLOR.rgb;}"
	var outfits:={"plate":[0x1415,0x1410,0x1411,0x1413,0x1414,0x170b],"leather":[0x13cc,0x13c5,0x13cb,0x13c7,0x13c6,0x170b],"studded":[0x13db,0x13d4,0x13da,0x13d6,0x13d5,0x170b],"mail":[0x13ec,0x13ee,0x13f0,0x13c6,0x170b]}
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanVisual.gd").new();actor.female=female;viewport.add_child(actor);actor.set_process(false)
		for family: String in outfits:
			var worn: Array=[]
			for id in outfits[family]:worn.append({"id":id})
			actor.set_equipment(worn)
			assert(actor.missing_art.is_empty())
			var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
			for mesh: MeshInstance3D in meshes:states[mesh]={"visible":mesh.visible,"material":mesh.material_override,"mesh":mesh.mesh,"probe":skin_probe(mesh,actor.skeleton) if mesh.name.begins_with("Body") else mesh.mesh}
			var base: MeshInstance3D=actor.model.find_children("Body*","MeshInstance3D",true,false)[0]
			for clip in ["Idle","Walk","Run","Sword_A","Bow_Attack"]:
				for phase in [.23,.62]:
					for angle in [0,90,180,270]:
						actor.rotation_degrees.y=angle;actor.current_clip="";actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
						for mesh: MeshInstance3D in meshes:
							mesh.visible=states[mesh].visible;mesh.material_override=pink if mesh.name.begins_with("Body") else white
							mesh.mesh=states[mesh].probe
						var skin:=await capture()
						for mesh: MeshInstance3D in meshes:mesh.mesh=states[mesh].mesh;mesh.visible=mesh==base;mesh.material_override=white
						var reference:=await capture()
						for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=white
						var clothed:=await capture()
						var a:=skin.get_data();var b:=reference.get_data();var c:=clothed.get_data()
						var top:=clampi(roundi(camera.unproject_position(Vector3(0,1.30,0)).y),0,511);var bottom:=clampi(roundi(camera.unproject_position(Vector3(0,.15,0)).y),0,511)
						var seat_top:=roundi(camera.unproject_position(Vector3(0,1.05,0)).y);var seat_bottom:=roundi(camera.unproject_position(Vector3(0,.65,0)).y)
						var exposed:=0;var missing:=0;var count:=0;var seat_missing:=0;var seat_count:=0
						var exposed_sum:=Vector2.ZERO
						for y in range(top,bottom+1):
							for x in 512:
								var i:=(y*512+x)*4
								if a[i]>230 and a[i+1]<35 and a[i+2]>230:exposed+=1;exposed_sum+=Vector2(x,y)
								if b[i]>240 and b[i+1]>240 and b[i+2]>240:
									count+=1;var covered: bool=c[i]>240 and c[i+1]>240 and c[i+2]>240
									if not covered:missing+=1
									if y>=seat_top and y<=seat_bottom:
										seat_count+=1
										if not covered:seat_missing+=1
						var retained:=1.-float(missing)/maxi(1,count);var seat_retained:=1.-float(seat_missing)/maxi(1,seat_count)
						var passed:=exposed<=4 and retained>=.98 and seat_retained>=.995
						var row:={"female":female,"family":family,"clip":clip,"phase":phase,"angle":angle,"exposed_skin_pixels":exposed,"body_reference_pixels":count,"clothed_occupancy_fraction":retained,"seat_reference_pixels":seat_count,"seat_occupancy_fraction":seat_retained,"passed":passed};rows.append(row)
						if not passed:
							failures+=1
							if failures==1:
								for mesh: MeshInstance3D in meshes:
									if mesh.visible and mesh.name.begins_with("Body"):locate_probe(mesh,actor.skeleton,exposed_sum/maxi(1,exposed))
							if failures<=4:skin.save_png("res://../outputs/human-armour-correction/failure-%s.png" % failures)
							if failures<=8:push_error("Armour coverage: "+str(row))
			for mesh: MeshInstance3D in meshes:mesh.material_override=states[mesh].material;mesh.visible=states[mesh].visible
			print("ARMOUR GPU FAMILY ",female," ",family)
		actor.free()
	var file:=FileAccess.open("res://../outputs/human-armour-correction/coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":rows,"failures":failures,"scope":"Actual rendered full outfits on both bodies: front, rear and both sides, five actions/two phases. Body skin marked magenta; complete unmasked body provides an independent opacity reference. ROI world heights 0.15–1.30 m; hands have native gloves. <=4 skin pixels, >=98% body occupancy and >=99.5% seat occupancy required. Finite projection/pose check, not universal triangle collision."},"\t"));file.close()
	print("HUMAN ARMOUR GPU COVERAGE: ",rows.size()," poses / ",failures," failures");quit(1 if failures else 0)
