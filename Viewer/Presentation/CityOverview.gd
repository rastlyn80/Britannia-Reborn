extends RefCounted
# Distant, explicitly simplified city massing. Exact source anchors/elevations;
# close inspection continues to use the shared detailed reconstruction.
static func shape(source: Dictionary,metadata: Dictionary) -> Dictionary:
 var name_text := str(metadata.get("name","")).to_lower()
 if "roof" in name_text or "shingle" in name_text:
  return {"kind":"roof","size":Vector3(1.02,0.12,1.02),"color":Color("716557")}
 if "wall" in name_text or name_text=="window" or name_text=="archway":
  return {"kind":"wall","size":Vector3(0.98,maxf(0.1,float(metadata.get("height",0))*0.2),0.98),"color":Color("c4baa2")}
 if "tree" in name_text or "sapling" in name_text:
  return {"kind":"tree","size":Vector3(1,1,1),"color":Color("38694a")}
 return {}
func build(data: RefCounted,material: ShaderMaterial) -> Node3D:
 var root := Node3D.new()
 root.name="SimplifiedCityMassing"
 var batches := {"roof":[],"wall":[],"tree":[]}
 for entry in data.manifest.chunks:
  var source: Dictionary=data.chunk(Vector2i(int(entry.x),int(entry.y)))
  for tile in source.get("statics",[]):
   var plan:=shape(tile,data.manifest.staticData.get(str(int(tile.id)),{}))
   if not plan.is_empty(): batches[plan.kind].append({"tile":tile,"plan":plan})
 var total:=0
 for kind in batches:
  var records: Array=batches[kind]
  if records.is_empty(): continue
  var instance:=MultiMeshInstance3D.new()
  instance.multimesh=MultiMesh.new()
  instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  instance.multimesh.use_colors=true
  if kind=="tree":
   var cone:=CylinderMesh.new()
   cone.top_radius=0.15;cone.bottom_radius=1.5;cone.height=5;cone.radial_segments=6
   instance.multimesh.mesh=cone
  else: instance.multimesh.mesh=BoxMesh.new()
  instance.multimesh.instance_count=records.size()
  for i in records.size():
   var record: Dictionary=records[i]
   var size: Vector3=record.plan.size
   var origin:=Vector3(record.tile.x+0.5,float(record.tile.z)*0.2+size.y/2,record.tile.y+0.5)
   if kind=="tree": origin.y+=2.0
   instance.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(size),origin))
   instance.multimesh.set_instance_color(i,record.plan.color.srgb_to_linear())
  instance.material_override=material
  root.add_child(instance)
  total+=records.size()
 root.set_meta("features",total)
 print("CITY MASSING: ",total," simplified architectural/tree records")
 return root
