extends RefCounted
# Source walls define the storey envelope; the leaf/lintel stay human-scaled.
# tiles_at (optional) reads streamed district records around the door; the
# play world's own statics are used otherwise.
static func measure(world: Dictionary,catalog: Dictionary,cell: Vector3i,axis: String,tiles_at: Callable = Callable()) -> Dictionary:
 var scale := float(world.get("elevationScale",0.2))
 var envelope := 3.2
 var found := false
 var crown := 0.0
 var families := {}
 var nearby: Array = []
 if tiles_at.is_valid():
  for d in range(-2,3):
   nearby.append_array(tiles_at.call(Vector2i(cell.x+d,cell.y) if axis == "x" else Vector2i(cell.x,cell.y+d)))
 else: nearby = world.statics
 for tile in nearby:
  var rule: Dictionary = catalog.get(str(int(tile.id)),{})
  if rule.get("kind","") not in ["wall","arch","door"] or rule.get("axis","x") != axis: continue
  if absi(int(tile.z)-cell.z) > 1: continue
  var same_plane := int(tile.y) == cell.y if axis == "x" else int(tile.x) == cell.x
  var distance := absi(int(tile.x)-cell.x) if axis == "x" else absi(int(tile.y)-cell.y)
  if not same_plane or distance > 2: continue
  var height := float(world.get("staticData",{}).get(str(int(tile.id)),{}).get("height",16))*scale
  if height < 2.0: continue
  envelope = minf(envelope,height) if found else height
  found = true
  # Battlement/parapet pieces standing on this wall continue the face above
  # the doorway; the infill must reach them or the sky shows through.
  var top := int(tile.z)+int(height/scale+0.5)
  for other in nearby:
   if int(other.x) != int(tile.x) or int(other.y) != int(tile.y): continue
   if str(catalog.get(str(int(other.id)),{}).get("kind","")) not in ["trim","pillar"]: continue
   if int(other.z) < top-1 or int(other.z) > top+8: continue
   var other_top := float(int(other.z)+int(world.get("staticData",{}).get(str(int(other.id)),{}).get("height",3))-cell.z)*scale
   crown = maxf(crown,other_top)
  var family: String = preload("res://Presentation/Reconstruction.gd").wall_family(world,int(tile.id))
  families[family] = int(families.get(family,0))+1
 var opening := minf(2.52,envelope-0.04)
 # The over-door wall continues the surrounding wall's own material.
 var family := "plaster"
 for key in families:
  if int(families[key]) > int(families.get(family,0)): family = key
 return {"envelope":maxf(envelope,crown),"opening":opening,"leaf_height":opening-0.045,"leaf_width":0.94,"lintel_height":0.16,"family":family}

static func header(root: Node3D,plan: Dictionary,geometry,facade) -> void:
 var opening := float(plan.opening)
 var envelope := float(plan.envelope)
 var beam_height := minf(float(plan.lintel_height),envelope-opening)
 var family := str(plan.get("family","plaster"))
 var masonry: bool = family in preload("res://Presentation/Facade.gd").MASONRY
 var beam = geometry.crafted_box(root,Vector3(1.0,beam_height,0.22),Vector3(0,opening+beam_height/2,0),"745334")
 beam.name = "DoorLintel"
 if masonry: beam.material_override = facade.material(family)
 var remainder := envelope-opening-beam_height
 if remainder > 0.001:
  var fill = geometry.box(root,Vector3(1.0,remainder,0.18),Vector3(0,opening+beam_height+remainder/2,0),"ded2b7")
  fill.name = "OverDoorWall"
  var infill: ShaderMaterial = facade.material(family).duplicate()
  infill.set_shader_parameter("open_caps",true)
  fill.material_override = infill
 var body := StaticBody3D.new()
 body.name = "HeaderCollision"
 body.collision_layer = 1
 body.collision_mask = 0
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(1.0,maxf(0.02,envelope-opening),0.22)
 collision.shape = box
 collision.position.y = opening+(envelope-opening)/2
 body.add_child(collision)
 root.add_child(body)
