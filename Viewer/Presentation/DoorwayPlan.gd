extends RefCounted
# Source walls define the storey envelope; the leaf/lintel stay human-scaled.
static func measure(world: Dictionary,catalog: Dictionary,cell: Vector3i,axis: String) -> Dictionary:
 var scale := float(world.get("elevationScale",0.2))
 var envelope := 3.2
 var found := false
 for tile in world.statics:
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
 var opening := minf(2.52,envelope-0.04)
 return {"envelope":envelope,"opening":opening,"leaf_height":opening-0.045,"leaf_width":0.94,"lintel_height":0.16}

static func header(root: Node3D,plan: Dictionary,geometry,facade) -> void:
 var opening := float(plan.opening)
 var envelope := float(plan.envelope)
 var beam_height := minf(float(plan.lintel_height),envelope-opening)
 var beam = geometry.crafted_box(root,Vector3(1.0,beam_height,0.22),Vector3(0,opening+beam_height/2,0),"745334")
 beam.name = "DoorLintel"
 var remainder := envelope-opening-beam_height
 if remainder > 0.001:
  var fill = geometry.box(root,Vector3(1.0,remainder,0.18),Vector3(0,opening+beam_height+remainder/2,0),"ded2b7")
  fill.name = "OverDoorWall"
  var plaster: ShaderMaterial = facade.material("plaster").duplicate()
  plaster.set_shader_parameter("open_caps",true)
  fill.material_override = plaster
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
