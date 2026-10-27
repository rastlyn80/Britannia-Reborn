extends RefCounted
static var records: Dictionary={}
static func entries() -> Dictionary:
 if records.is_empty():records=JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/reviewed-catalog.json")).entries
 return records
static func entry(id: int) -> Dictionary:return entries().get(str(id),{})
# Reviewed photoscans (Poly Haven, museum/Objaverse scans) outrank pack stand-ins.
static func scanned(id: int) -> bool:
 var asset:=str(entry(id).get("asset",""))
 return asset.begins_with("PolyHaven/") or asset.begins_with("Objaverse/")
static func extend(catalog: Dictionary) -> void:
 for id in entries():
  var review: Dictionary=entries()[id]
  if not review.has("asset"):continue
  var rule: Dictionary=catalog.get(id,{}).duplicate()
  rule.merge({"kind":review.kind,"asset":review.asset,"reviewed":true,"confidence":review.confidence},true)
  catalog[id]=rule

static func dimensions(review: Dictionary, group: Dictionary={}) -> Vector3:
 var a: Array=review.dimensions
 var size:=Vector3(a[0],a[1],a[2])
 if group.has("size") and review.assembly in ["table-run","bench-run","counter-run"]:
  var footprint: Vector2=group.size
  size.x=maxf(footprint.x,footprint.y)
  size.z=0.44 if review.assembly=="bench-run" else minf(footprint.x,footprint.y)
 if group.has("size") and "bed-components" in str(review.assembly):
  size.x=minf(group.size.x,group.size.y)
  size.z=maxf(group.size.x,group.size.y)
 return size

static func build(reconstruction: RefCounted, id: int, group: Dictionary={}) -> Node3D:
 var review:=entry(id)
 if review.get("construction","")=="wardrobe":return wardrobe(reconstruction,review)
 if not review.has("asset"):return null
 var size:=dimensions(review,group)
 var node:=Node3D.new()
 var model: Node3D=reconstruction.fitted(review.asset,size,review.get("modelRotation",[0,0,0]))
 node.add_child(model)
 if review.has("palette"):reconstruction.tint_prop(model,review.palette)
 if review.get("books",false):
  for y in [.28,.77,1.27]:
   var books: Node3D=reconstruction.fitted("Props/BookGroup_Small_1.gltf",Vector3(.74,.28,.20))
   books.position=Vector3(0,y,.035)
   node.add_child(books)
 var yaw:=float(review.get("yawDegrees",0))
 if group.has("size") and review.assembly in ["table-run","bench-run","counter-run","bed-components","canopy-bed-components"]:
  if group.size.y>group.size.x and "bed" not in str(review.assembly):yaw=90
  if group.size.x>group.size.y and "bed" in str(review.assembly):yaw=90
 node.rotation_degrees.y=yaw
 if review.assembly=="canopy-bed-components":
  for x in [-size.x/2+0.06,size.x/2-0.06]:
   for z in [-size.z/2+0.06,size.z/2-0.06]:reconstruction.geometry.crafted_box(node,Vector3(.07,1.95,.07),Vector3(x,.975,z),"88613b")
  for x in [-size.x/2,size.x/2]:reconstruction.geometry.crafted_box(node,Vector3(.08,.07,size.z),Vector3(x,1.92,0),"88613b")
  for z in [-size.z/2,size.z/2]:reconstruction.geometry.crafted_box(node,Vector3(size.x,.07,.08),Vector3(0,1.92,z),"88613b")
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for x in 20:
   var a:=-size.x/2+size.x*float(x)/20
   var b:=-size.x/2+size.x*float(x+1)/20
   for p in [Vector2(a,.76),Vector2(b,.76),Vector2(b,1.88),Vector2(a,.76),Vector2(b,1.88),Vector2(a,1.88)]:
    tool.add_vertex(Vector3(p.x,p.y,-size.z/2+.08+sin(p.x*35)*.025))
  tool.generate_normals()
  var curtain:=MeshInstance3D.new();curtain.mesh=tool.commit()
  var cloth:=StandardMaterial3D.new();cloth.albedo_color=Color("d8ceb5");cloth.roughness=.96;cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
  curtain.material_override=cloth;node.add_child(curtain)
 return node

static func wardrobe(reconstruction: RefCounted, review: Dictionary) -> Node3D:
 var node:=Node3D.new()
 var g: RefCounted=reconstruction.geometry
 g.crafted_box(node,Vector3(.88,1.80,.52),Vector3(0,.90,0),"765337")
 g.crafted_box(node,Vector3(.96,.08,.62),Vector3(0,1.84,0),"a17a4c")
 g.crafted_box(node,Vector3(.94,.10,.60),Vector3(0,.05,0),"65472e")
 var iron:=StandardMaterial3D.new();iron.albedo_color=Color("3e4140");iron.metallic=.25;iron.roughness=.85
 for side in [-1,1]:
  g.crafted_box(node,Vector3(.40,1.58,.045),Vector3(side*.208,.94,.28),"96734a")
  g.crafted_box(node,Vector3(.29,1.34,.018),Vector3(side*.208,.94,.31),"785b3c")
  for y in [.36,1.50]:
   var hinge: MeshInstance3D=g.box(node,Vector3(.11,.04,.016),Vector3(side*.36,y,.322),"ffffff")
   hinge.material_override=iron
  var pull:=MeshInstance3D.new();var ring:=TorusMesh.new()
  ring.inner_radius=.021;ring.outer_radius=.032;ring.rings=12;ring.ring_segments=8
  pull.mesh=ring;pull.material_override=iron;pull.position=Vector3(side*.047,.99,.34);pull.rotation.x=PI/2;node.add_child(pull)
 node.rotation_degrees.y=float(review.get("yawDegrees",0))
 return node
