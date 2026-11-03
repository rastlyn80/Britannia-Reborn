extends RefCounted
## One native graphic, many body variants. No invented wire/static graphic IDs.
const GRAPHIC:=0x2006
const Humans=preload("res://Presentation/HumanVisual.gd")
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Creatures=preload("res://Presentation/CreatureRegistry.gd")
const HumanNPCs=preload("res://Presentation/HumanNPCProfiles.gd")

static func human_body(body: int) -> bool:return Wardrobe.living_player(body) or HumanNPCs.supports_body(body)
static func female_body(body: int) -> bool:return Wardrobe.female(body)

static func supports(body: int) -> bool:
	return Humans.available(female_body(body)) if human_body(body) else Mounts.supports_body(body)

static func supports_equipment(body: int) -> bool:
	return human_body(body) or not Creatures.entry(body).get("native_equipment_layers",[]).is_empty()

static func catalogue() -> Array[Dictionary]:
	# Derived from the actual runtime registries: future accepted bodies acquire
	# a corpse automatically, including explicit compatibility artwork.
	Creatures.load_index()
	var candidates: Dictionary={0x190:"Human / male",0x191:"Human / female",605:"Elf / male",606:"Elf / female",0x319:"Skeletal mount"}
	HumanNPCs.load_index()
	for body: int in HumanNPCs.entries:candidates[body]=str(HumanNPCs.entries[body].get("name","Human NPC"))
	for body: int in Mounts.Horse.Equines.BODIES:candidates[body]=Mounts.Horse.Equines.BODIES[body][0]
	for body: int in Mounts.Horse.Equines.COMPATIBILITY:candidates[body]=Mounts.Horse.Equines.COMPATIBILITY[body][0]
	for body: int in Mounts.BODIES:candidates[body]=str(Mounts.BODIES[body][0]).capitalize()
	for body: int in Mounts.Animals.BODIES:candidates[body]=Mounts.Animals.BODIES[body][0]
	for body: int in Creatures.entries:
		var row: Dictionary=Creatures.entries[body]
		candidates[body]=str(row.kind).replace("_"," ").capitalize()
		for identity: Dictionary in row.get("bodies",[]):
			if int(identity.body)==body:candidates[body]=str(identity.get("name",identity.get("native",candidates[body])))
	var result: Array[Dictionary]=[];var bodies: Array=candidates.keys();bodies.sort()
	for body: int in bodies:
		if not supports(body):continue
		result.append({"key":"corpse-%04x"%body,"graphic":GRAPHIC,"hex":"0x2006","body":body,"body_hex":"0x%04X"%body,"amount":body,"name":str(candidates[body])+" corpse","category":"Corpses","compatibility":Mounts.Horse.Equines.COMPATIBILITY.has(body),"provider":"human" if human_body(body) else "creature" if Creatures.supports_body(body) else "mount/animal"})
	return result

static func posed(body: int,hue: int=0,worn: Array=[]) -> Node3D:
	if not supports(body):return null
	var tree:=Engine.get_main_loop() as SceneTree
	if tree==null:return null
	var actor: Node3D
	if human_body(body):
		actor=Humans.new();actor.female=female_body(body)
	else:actor=Mounts.create(body)
	tree.root.add_child(actor)
	if actor is Humans:
		actor.set_skin(hue);actor.set_equipment(worn);actor.set_native_profile(HumanNPCs.entry(body),hue)
	else:
		actor.apply_identity(body,hue);actor.dead=true;actor.contact.enabled=false
		if actor.has_method("set_equipment"):actor.set_equipment(worn)
		if actor is Mounts.Horse:actor.reins.visible=false
	var clip:="Death" if actor.animator.has_animation("Death") else "death"
	if not actor.animator.has_animation(clip):
		push_error("No corpse death pose for body 0x%04X"%body);actor.free();return null
	actor.current_clip=clip
	actor.animator.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length,true);actor.animator.pause()
	for modifier in actor.skeleton.find_children("*","SkeletonModifier3D",true,false):modifier.active=false
	actor.skeleton.force_update_all_bone_transforms()
	if actor is Mounts.Horse:actor.fit_action_floor()
	actor.set_process(false);actor.set_physics_process(false);actor.animator.process_mode=Node.PROCESS_MODE_DISABLED
	actor.set_meta("corpse_body",body);actor.set_meta("native_hue",hue);actor.set_meta("death_clip",clip)
	return actor

static func freeze(actor: Node3D) -> Node3D:
	# CPU skinning works with headless imports too. Keep UVs, colours, indices,
	# surface materials and rigid attachments; remove the rig and all processing.
	var result:=Node3D.new();result.name="CorpseVisual"
	var first:=true;var bounds:=AABB();var vertices_count:=0
	for source: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not source.is_visible_in_tree() or source.mesh==null or source.has_meta("source_death_flash"):continue
		var rig: Skeleton3D=source.get_node_or_null(source.skeleton) as Skeleton3D if source.skin!=null else null
		var matrices: Array[Transform3D]=[]
		if rig:
			for bind in source.skin.get_bind_count():
				var bone:=source.skin.get_bind_bone(bind)
				if bone<0:bone=rig.find_bone(source.skin.get_bind_name(bind))
				if bone<0:push_error("Missing corpse skin binding");result.free();return null
				matrices.append(rig.get_bone_global_pose(bone)*source.skin.get_bind_pose(bind))
		var mesh:=ArrayMesh.new()
		var local:=actor.global_transform.affine_inverse()*(rig.global_transform if rig else source.global_transform)
		for surface in source.mesh.get_surface_count():
			var arrays:=source.mesh.surface_get_arrays(surface).duplicate(true)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
			if rig and arrays[Mesh.ARRAY_BONES]!=null:
				var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				var stride:=bones.size()/points.size()
				for vertex in points.size():
					var point:=Vector3.ZERO;var normal:=Vector3.ZERO;var tangent:=Vector3.ZERO
					for influence in stride:
						var index:=vertex*stride+influence;var weight:=weights[index]
						if weight==0.:continue
						var transform:=matrices[bones[index]]
						point+=(transform*points[vertex])*weight
						if not normals.is_empty():normal+=(transform.basis.inverse().transposed()*normals[vertex])*weight
						if not tangents.is_empty():tangent+=(transform.basis*Vector3(tangents[vertex*4],tangents[vertex*4+1],tangents[vertex*4+2]))*weight
					points[vertex]=point
					if not normals.is_empty():normals[vertex]=normal.normalized()
					if not tangents.is_empty():
						tangent=tangent.normalized();tangents[vertex*4]=tangent.x;tangents[vertex*4+1]=tangent.y;tangents[vertex*4+2]=tangent.z
				arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
			arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals if not normals.is_empty() else null;arrays[Mesh.ARRAY_TANGENT]=tangents if not tangents.is_empty() else null
			for point in points:
				var position:=local*point
				if not position.is_finite():push_error("Non-finite corpse geometry");result.free();return null
				bounds=AABB(position,Vector3.ZERO) if first else bounds.expand(position);first=false
			vertices_count+=points.size()
			# Extra UV/color channels may contain floats, not default RGBA8 bytes.
			# Keep their source formats when removing only the rig/skin arrays.
			var custom_flags:=0
			if source.mesh is ArrayMesh:
				var format: int=source.mesh.surface_get_format(surface)
				for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:custom_flags|=format&(Mesh.ARRAY_FORMAT_CUSTOM_MASK<<shift)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES if source.mesh is PrimitiveMesh else source.mesh.surface_get_primitive_type(surface),arrays,[],{},custom_flags)
			if mesh.get_surface_count()!=surface+1:push_error("Failed to freeze corpse surface with its source attribute formats");result.free();return null
			var material:=source.get_active_material(surface)
			# Explicitly animated procedural surfaces retain this exact phase even
			# if their living actor continues or subsequently changes appearance.
			if material is ShaderMaterial and (material.get_meta("snapshot_uniform_time",false) or material.get_meta("snapshot_uniforms",false)):
				var snapshot:=ShaderMaterial.new();snapshot.shader=material.shader
				for uniform: Dictionary in material.shader.get_shader_uniform_list():snapshot.set_shader_parameter(uniform.name,material.get_shader_parameter(uniform.name))
				material=snapshot
			mesh.surface_set_material(surface,material)
		var frozen:=MeshInstance3D.new();frozen.name=source.name;frozen.mesh=mesh;frozen.transform=local;frozen.cast_shadow=source.cast_shadow;result.add_child(frozen)
	if first:result.free();return null
	# Static cadavers sit on their actual deformed lower surface.
	for child: Node3D in result.get_children():child.position.y-=bounds.position.y
	bounds.position.y=0.
	result.set_meta("corpse_bounds",bounds);result.set_meta("vertices",vertices_count)
	for key in ["corpse_body","native_hue","death_clip"]:result.set_meta(key,actor.get_meta(key))
	result.set_meta("graphic_id",GRAPHIC);result.set_meta("static_cadaver",true)
	return result

static func build(body: int,hue: int=0,worn: Array=[]) -> Node3D:
	var actor:=posed(body,hue,worn)
	if actor==null:return null
	var result:=freeze(actor)
	actor.get_parent().remove_child(actor)
	# Release overrides while their MeshInstance still exists. This also avoids
	# headless-renderer material callbacks during immediate actor destruction.
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,null)
	actor.free()
	return result
