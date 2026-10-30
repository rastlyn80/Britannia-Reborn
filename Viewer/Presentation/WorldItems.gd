extends Node3D
const Geometry = preload("res://Presentation/GeometryLibrary.gd")
var geometry := Geometry.new()
const Appearance = preload("res://Presentation/ItemAppearance.gd")
const LocalProps = preload("res://Presentation/LocalProps.gd")
var session: Node
var scene: Node3D
var nodes := {}
var definitions := {}
var local_art := preload("res://Presentation/LocalItemArt.gd").new()
var selected := 0
var suppressed_posts := {}
var contacts_pending:=false
var hint := Label.new()
# Signs ask the server for their text as they appear (a few per second), so
# street and shop names are painted on the boards without clicking.
var label_queue: Array[int] = []
var sign_labels := {}
var label_clock := 0.0
const LABEL_INTERVAL := 0.25
# Street-board arrow directions by graphic (x east, z south) from the source
# art: "\\" boards run east-west, "/" north-south, level boards face the view.
const STREET_BOARDS := {4759:Vector2(0.7071,-0.7071),4766:Vector2(-0.7071,0.7071),4760:Vector2(-0.7071,-0.7071),4763:Vector2(0.7071,0.7071),4761:Vector2(0,-1),4765:Vector2(0,1),4762:Vector2(1,0),4764:Vector2(-1,0)}

func configure(owner_scene: Node3D, connection: Node) -> void:
 scene = owner_scene
 session = connection
 if FileAccess.file_exists("res://item-definitions.local.json"):
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-definitions.local.json"))
  if parsed is Dictionary: definitions = parsed
 refresh_source_records()
 session.world_item_changed.connect(upsert)
 session.world_item_removed.connect(remove)
 session.ended.connect(clear)
 session.item_label_received.connect(func(serial: int, label: String):
  if serial == selected: hint.text = label
  if nodes.has(serial) and nodes[serial].get_meta("family","") == "sign":
   sign_labels[serial] = label
   nodes[serial].set_meta("labelled",true)
   var plaque: Label3D = nodes[serial].get_node_or_null("BuildingName")
   if plaque:
    plaque.text = label
    plaque.show()
   if nodes[serial].has_meta("engrave"): engrave(nodes[serial],label))
 var canvas := CanvasLayer.new()
 add_child(canvas)
 hint.position = Vector2(24,640)
 hint.custom_minimum_size = Vector2(800,0)
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 hint.add_theme_font_size_override("font_size",18)
 hint.add_theme_color_override("font_shadow_color",Color.BLACK)
 hint.add_theme_constant_override("shadow_offset_x",2)
 hint.add_theme_constant_override("shadow_offset_y",2)
 hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(hint)

func definition(item: Dictionary) -> Dictionary:
 if definitions.has(str(int(item.id))):
  var rule: Dictionary = definitions[str(int(item.id))].duplicate()
  if rule.get("family","") == "decoration" and _sign_graphic(item): rule.family = "sign"
  if rule.get("type","") in ["Chessboard","CheckerBoard","Backgammon"]: rule.family = "gameboard"
  if rule.get("family","") == "door" and (int(rule.get("facing",0)) < 0 or int(rule.get("facing",0)) > 7): rule.facing = door_facing(rule)
  return rule
 # Native generator's dark-wood door family remains usable without an exported catalogue.
 if int(item.id) >= 0x6a5 and int(item.id) <= 0x6b4:
  var facing := (int(item.id)-0x6a5)/2
  var offsets := [[-1,1,0],[1,1,0],[-1,0,0],[1,-1,0],[1,1,0],[1,-1,0],[0,0,0],[0,-1,0]]
  return {"family":"door","facing":facing,"height":16,"flags":64,"is_open":(int(item.id)-0x6a5)%2 == 1,"offset":offsets[facing]}
 # Shop and guild sign boards (0xBA3-0xC1E) placed by decoration without an
 # exported definition hang like the server signs.
 if _sign_graphic(item): return {"family":"sign","height":1,"flags":0,"container":false}
 return {"family":"decoration","height":1,"flags":0,"container":false}

func _sign_graphic(item: Dictionary) -> bool:
 var sign_name := str(scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name",""))
 return int(item.id) >= 2979 and int(item.id) <= 3086 and not "broken" in sign_name and not "bench" in sign_name and not "signpost" in sign_name

# ModernUO door facings (WestCW, EastCCW, WestCCW, EastCW, SouthCW, NorthCCW,
# SouthCCW, NorthCW) and the offset each open graphic moves by.
const DOOR_OFFSETS := [Vector2i(-1,1),Vector2i(1,1),Vector2i(-1,0),Vector2i(1,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(0,0),Vector2i(0,-1)]
var door_facings := {}
# Some exported door definitions carry an out-of-range facing. The facing is
# the closed graphic's position in its door set (two graphics per facing);
# the set starts at the lowest closed graphic of the same type within 14 IDs,
# and the open offset confirms it.
func door_facing(rule: Dictionary) -> int:
 var closed := int(rule.get("closed_id",0))
 if door_facings.has(closed): return int(door_facings[closed])
 var offset := Vector2i(int(rule.get("offset",[0,0])[0]),int(rule.get("offset",[0,0])[1]))
 var base := closed
 for id in range(closed-14,closed+1,2):
  var other: Dictionary = definitions.get(str(id),{})
  if str(other.get("type","")) == str(rule.get("type","")) and int(other.get("closed_id",-1)) == id:
   base = id
   break
 var facing := clampi((closed-base)/2,0,7)
 if DOOR_OFFSETS[facing] != offset:
  # Fall back to the facing whose offset matches, preferring the set parity.
  for candidate in 8:
   if DOOR_OFFSETS[candidate] == offset and candidate%2 == facing%2: facing = candidate
 door_facings[closed] = facing
 return facing

# A rebuilt sign repaints a known name at once; otherwise its text is queued.
func _label_sign(serial: int) -> void:
 if not nodes.has(serial): return
 if sign_labels.has(serial):
  nodes[serial].set_meta("labelled",true)
  if nodes[serial].has_meta("engrave"): engrave(nodes[serial],str(sign_labels[serial]))
  else:
   var plaque: Label3D = nodes[serial].get_node_or_null("BuildingName")
   if plaque:
    plaque.text = str(sign_labels[serial])
    plaque.show()
 elif not serial in label_queue: label_queue.append(serial)

func _process(delta: float) -> void:
 label_clock -= delta
 if label_clock > 0.0 or label_queue.is_empty() or session == null: return
 label_clock = LABEL_INTERVAL
 var serial: int = label_queue.pop_front()
 if nodes.has(serial) and not nodes[serial].has_meta("labelled"): session.request_label(serial)

# Item studio (3D icons, inspect view): the model an item graphic gets in the
# world, built by the same code path, then detached from the world without
# its physics body, picking or labels. Meta "studio_quality" is "model" when
# a real model or crafted shape drew it and "fallback" for the generic box.
var studio_serial := -1
func studio_model(graphic: int, hue := 0, amount := 1) -> Node3D:
 if scene == null or scene.world.is_empty(): return null
 var serial := studio_serial
 studio_serial -= 1
 upsert(serial,{"serial":serial,"id":graphic,"hue":hue,"amount":amount,"x":int(scene.world.originX)+1,"y":int(scene.world.originY)+1,"z":0,"facet":1})
 var root: Node3D = nodes.get(serial)
 nodes.erase(serial)
 suppressed_posts.erase(serial)
 if scene.movement_surface: scene.movement_surface.dynamic_items.erase(serial)
 if root == null: return null
 remove_child(root)
 var stripped: Array = root.find_children("*","CollisionObject3D",true,false)+root.find_children("*","Label3D",true,false)
 for node in stripped:
  if is_instance_valid(node): node.free()
 root.position = Vector3.ZERO
 root.set_meta("studio_quality","fallback" if str(root.get_meta("appearance","")) == "unknown" else "model")
 return root

func upsert(serial: int, item: Dictionary) -> void:
 var bounds := Rect2i(int(scene.world.originX),int(scene.world.originY),int(scene.world.width),int(scene.world.height))
 var rule := definition(item)
 var visible_cell := Vector2i(item.x,item.y)
 if rule.family == "door" and rule.get("is_open",false):
  var offset: Array = rule.get("offset",[0,0,0])
  visible_cell -= Vector2i(int(offset[0]),int(offset[1]))
 if int(item.get("facet",1)) != 1 or not bounds.has_point(visible_cell):
  remove(serial)
  return
 if scene.movement_surface: scene.movement_surface.dynamic_items[serial] = item.merged({"definition":rule})
 if scene.reconstruction and scene.reconstruction.supports.has_record(item):
  remove_visual(serial)
  return
 if nodes.has(serial) and rule.family == "door" and nodes[serial].get_meta("family","") == "door":
  _door_state(nodes[serial],item,rule,false)
  return
 remove_visual(serial)
 # Native decoration floor patches replace source gaps, while the shared floor
 # pass already owns those surfaces. Avoid another coplanar floor layer.
 if rule.get("type","") == "Static" and int(rule.get("height",0)) == 0 and (int(rule.get("flags",0)) & 0x200) != 0: return
 request_contact_refresh()
 var root := Node3D.new()
 root.name = "ServerItem_%08X" % serial
 root.set_meta("serial",serial)
 root.set_meta("family",rule.family)
 root.set_meta("interactive",true)
 root.set_meta("graphic_id",int(item.id))
 root.set_meta("appearance",Appearance.variant(int(item.id),rule))
 add_child(root)
 nodes[serial] = root
 if rule.get("family","") == "sign": call_deferred("_label_sign",serial)
 root.position = scene.entity_point(item.x,item.y,item.z)
 # A corpse (0x2006) carries its creature's body in the amount field: horses
 # lie as the shared horse model held at the end of its death clip.
 if int(item.id) == 0x2006 and _equine_corpse(root,item,serial): return
 # Modern Britain: server decoration whose name matches a library slot uses
 # the owner-pack/CC0 library model, set onto the surface under it.
 if preload("res://Presentation/GraphicsMode.gd").modern() and not str(rule.family) in ["door","sign","lamp","noticeboard","gameboard","backgammon"] and not preload("res://Presentation/ReviewedCatalog.gd").scanned(int(item.id)) and not preload("res://Presentation/PropReplacements.gd").has(str(rule.get("display_name",scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name",""))),int(item.id)) and not preload("res://Presentation/CraftedProps.gd").handles(str(rule.get("display_name",scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name","")))):
  # Server definitions carry the tiledata name; map statics only know their own IDs.
  var item_name := str(rule.get("display_name",scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name",""))).strip_edges().to_lower()
  var found: Array = preload("res://Presentation/RegionalRules.gd").slot_for(item_name) if item_name != "" else []
  if not found.is_empty() and preload("res://Presentation/LocalLibrary.gd").has(str(found[0])):
   var fit: Array = found[1]
   var library := preload("res://Presentation/LocalLibrary.gd")
   var model: Node3D = library.pile(str(found[0]),int(item.x),int(item.y),Vector3(fit[0],fit[1],fit[2]),int(found[2])) if int(found[2]) > 1 else library.build(str(found[0]),int(item.x),int(item.y),Vector3(fit[0],fit[1],fit[2]))
   if model:
    model.name = "LibraryVisual"
    root.add_child(model)
    root.set_meta("library_item",str(found[0]))
    root.set_meta("pick_half",float(fit[1])/2)
    _body(root,Vector3(float(fit[0]),float(fit[1]),float(fit[2])),Vector3(0,float(fit[1])/2,0),serial,(int(rule.get("flags",0))&64)!=0)
    request_contact_refresh()
    return
 # Decoration that the static builders draw (effects, ground decals, vines,
 # fences): the same builder as the map static of that name.
 if rule.family == "decoration":
  var static_rule: Dictionary = preload("res://Presentation/RegionalRules.gd").resolve(int(item.id),scene.world.get("staticData",{}).get(str(int(item.id)),{}))
  var built: Node3D = null
  match str(static_rule.get("kind","")):
   "effect": built = preload("res://Presentation/EffectBuilder.gd").build(str(static_rule.effect))
   "decal": built = preload("res://Presentation/GroundDecal.gd").build(str(static_rule.decal),Vector2i(item.x,item.y))
   "vine": if str(static_rule.get("builder","")) == "vine": built = preload("res://Presentation/VineBuilder.gd").build(str(scene.world.staticData.get(str(int(item.id)),{}).get("name","")),int(item.id),1.8,serial,scene.reconstruction)
   "fence": if preload("res://Presentation/FenceBuilder.gd").handles(str(scene.world.staticData.get(str(int(item.id)),{}).get("name",""))): built = preload("res://Presentation/FenceBuilder.gd").build(str(scene.world.staticData.get(str(int(item.id)),{}).get("name","")),int(item.id),scene.reconstruction.geometry,scene.reconstruction.facade)
  if built:
   built.name = "BuilderVisual"
   root.add_child(built)
   _body(root,Vector3(0.6,0.4,0.6),Vector3(0,0.2,0),serial,(int(rule.get("flags",0))&64)!=0)
   return
 # Simple objects built from photoscanned materials (CraftedProps.gd).
 var crafted_name := str(rule.get("display_name",scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name","")))
 if not str(rule.family) in FIXED_FAMILIES and not preload("res://Presentation/PropReplacements.gd").has(crafted_name,int(item.id)) and preload("res://Presentation/CraftedProps.gd").handles(crafted_name):
  var crafted: Node3D = preload("res://Presentation/CraftedProps.gd").build(crafted_name,serial,int(item.id))
  crafted.name = "CraftedVisual"
  if crafted.has_meta("art_yaw"):
   crafted.rotation.y = float(crafted.get_meta("art_yaw"))
   crafted.position = crafted.get_meta("art_offset")
  root.add_child(crafted)
  _body(root,Vector3(0.6,0.5,0.6),Vector3(0,0.25,0),serial,(int(rule.get("flags",0))&64)!=0)
  request_contact_refresh()
  return
 # Photoscanned CC0 replacements by item name (prop-replacements.json).
 var replacement_name := str(rule.get("display_name",scene.world.get("staticData",{}).get(str(int(item.id)),{}).get("name","")))
 if not str(rule.family) in FIXED_FAMILIES and preload("res://Presentation/PropReplacements.gd").has(replacement_name,int(item.id)):
  var replaced: Node3D = _footprint_replacement(item,replacement_name,serial) if str(preload("res://Presentation/PropReplacements.gd").entry_for(replacement_name,int(item.id)).get("assembly","")) == "footprint" and not preload("res://Presentation/PropReplacements.gd").entry_for(replacement_name,int(item.id)).get("hide",false) else preload("res://Presentation/PropReplacements.gd").build(scene.reconstruction,replacement_name,serial,int(item.id))
  if replaced:
   replaced.name = "ReplacementVisual"
   root.add_child(replaced)
   var boxes: Array = []
   scene.reconstruction._collect_bounds(replaced,Transform3D.IDENTITY,boxes)
   var box: AABB = boxes[0] if not boxes.is_empty() else AABB(Vector3(-0.2,0,-0.2),Vector3(0.4,0.4,0.4))
   for other in boxes: box = box.merge(other)
   _body(root,box.size,box.get_center(),serial,(int(rule.get("flags",0))&64)!=0)
   request_contact_refresh()
   return
 var review: Dictionary=preload("res://Presentation/ReviewedCatalog.gd").entry(int(item.id))
 if (review.has("asset") or review.get("construction","")=="wardrobe") and rule.family!="door":
  var visual: Node3D=preload("res://Presentation/ReviewedCatalog.gd").build(scene.reconstruction,int(item.id))
  visual.name="ReviewedVisual"
  root.add_child(visual)
  var boxes: Array=[]
  scene.reconstruction._collect_bounds(visual,Transform3D.IDENTITY,boxes)
  var box: AABB=boxes[0]
  for other in boxes:box=box.merge(other)
  _body(root,box.size,box.get_center(),serial,(int(rule.get("flags",0))&64)!=0)
  request_contact_refresh()
  return
 if rule.family == "door":
  if rule.get("is_open",false):
   var offset: Array = rule.get("offset",[0,0,0])
   root.position = scene.entity_point(int(item.x)-int(offset[0]),int(item.y)-int(offset[1]),int(item.z)-int(offset[2]))
  _door(root,rule)
  _door_state(root,item,rule,true)
  return
 var size := Vector3(0.48,0.38,0.48)
 var pick_center := Vector3.ZERO
 var kind := Appearance.variant(int(item.id),rule)
 var small_size := Appearance.small(root,geometry,kind,int(item.id))
 if small_size != Vector3.ZERO:
  _body(root,small_size,Vector3(0,small_size.y/2,0),serial,(int(rule.get("flags",0))&64)!=0)
  return
 match kind:
  "chest","crate","drawers","wardrobe","bookcase":
   size = Vector3(0.88,1.85 if rule.family in ["wardrobe","bookcase"] else (1.0 if rule.family == "drawers" else 0.65),0.60)
   var local: Node3D = LocalProps.build("crate",int(item.x),int(item.y)) if rule.family == "crate" else null
   if local: root.add_child(local)
   elif rule.family == "chest":
    var metal := "Metal" in str(rule.get("type",""))
    size = Vector3(0.5,0.34,0.34) if metal else Vector3(0.82,0.56,0.5)
    # Scanned/PBR chests (CC-BY, Art/Objaverse) when pinned; crafted otherwise.
    var chest_model := "Objaverse/chest_old/chest_old.glb" if metal else "Objaverse/chest_medieval/chest_medieval.glb"
    if ResourceLoader.exists("res://Art/"+chest_model):
     var chest: Node3D = scene.reconstruction.fitted(chest_model,size,[0,180,0] if metal else [0,0,0])
     root.add_child(chest)
    else: _chest(root,size,metal)
   elif rule.family == "drawers":
    # Photoscanned carved commode (CC0 Poly Haven GothicCommode_01).
    size = Vector3(0.96,0.97,0.46)
    root.add_child(scene.reconstruction.fitted("PolyHaven/GothicCommode_01/GothicCommode_01_1k.gltf",size))
   else: _cabinet(root,size,rule.family,rule)
   # Graphics drawn facing east: upstream decoration places them in
   # north-south runs against west walls (crates are square either way).
   if int(item.id) in [2612,2616,2641,2643,2718,3645,3648,3650]: root.rotation.y = PI/2
  "gameboard","backgammon":
   size = Vector3(0.72,0.045,0.72)
   geometry.crafted_box(root,size,Vector3(0,0.0225,0),"5d432d")
   for x in (6 if kind == "backgammon" else 8):
    for y in (2 if kind == "backgammon" else 8):
     if kind == "backgammon":
      var triangle := SurfaceTool.new()
      triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
      var base := Vector3(-0.30+x*0.12,0.048,-0.31 if y == 0 else 0.31)
      for point in [base+Vector3(-0.045,0,0),base+Vector3(0.045,0,0),base+Vector3(0,0,0.25 if y == 0 else -0.25)]: triangle.add_vertex(point)
      triangle.generate_normals()
      var wedge := MeshInstance3D.new()
      wedge.mesh = triangle.commit()
      var tint := geometry.material("d0b685" if (x+y)%2 == 0 else "554430").duplicate()
      tint.cull_mode = BaseMaterial3D.CULL_DISABLED
      wedge.material_override = tint
      root.add_child(wedge)
     else: geometry.box(root,Vector3(0.075,0.006,0.075),Vector3(-0.2625+x*0.075,0.048,-0.2625+y*0.075),"d0b685" if (x+y)%2 == 0 else "554430")
  "barrel","water_barrel":
   size = Vector3(0.72,0.95,0.72)
   var local: Node3D = LocalProps.build("barrel",int(item.x),int(item.y))
   if local:
    root.add_child(local)
    # Water only shows in an upright barrel, just under its own rim (pack
    # variants include barrels lying on a rack).
    var barrel_boxes: Array = []
    scene.reconstruction._collect_bounds(local,Transform3D.IDENTITY,barrel_boxes)
    var barrel := AABB()
    for i in barrel_boxes.size(): barrel = barrel_boxes[i] if i == 0 else barrel.merge(barrel_boxes[i])
    if kind == "water_barrel" and barrel.size.y >= maxf(barrel.size.x,barrel.size.z):
     geometry.cylinder(root,minf(barrel.size.x,barrel.size.z)*0.42,0.012,Vector3(barrel.get_center().x,barrel.end.y-0.05,barrel.get_center().z),"467987")
   else:
    geometry.cylinder(root,0.35,0.92,Vector3(0,0.46,0),"795638")
    for y in [0.16,0.74]: geometry.cylinder(root,0.365,0.06,Vector3(0,y,0),"42464a")
    if kind == "water_barrel": geometry.cylinder(root,0.32,0.012,Vector3(0,0.91,0),"467987")
  "street_sign","plaque":
   # Text boards: the source XYZ is the post top (street signs) or the plaque
   # base beside its wall. The server label is engraved on the faces on click.
   var street := kind == "street_sign"
   size = Vector3(1.05,0.24,0.05) if street else Vector3(0.95,0.5,0.05)
   var board_y := 0.06 if street else 0.45
   var board := Node3D.new()
   board.name = "TextBoard"
   root.add_child(board)
   geometry.crafted_box(board,size,Vector3.ZERO,"6b4a2c")
   geometry.crafted_box(board,Vector3(size.x-0.06,size.y-0.06,size.z+0.01),Vector3.ZERO,"8a6a42")
   board.position.y = board_y
   if street:
    # The arrow board leaves the post in its pointing direction with a
    # pointed tip; a post section always reaches it (stacked boards).
    var toward: Vector2 = STREET_BOARDS.get(int(item.id),Vector2(1,0))
    board.rotation.y = atan2(-toward.y,toward.x)
    board.position += Vector3(toward.x,0,toward.y)*(size.x/2-0.05)
    var tip := geometry.crafted_box(board,Vector3(0.17,0.17,size.z),Vector3(size.x/2,0,0),"6b4a2c")
    tip.rotation.z = PI/4
    var land: Dictionary = scene.reconstruction.supports.land_at(Vector2i(item.x,item.y)) if scene.reconstruction else {}
    var drop := clampf((float(item.z)-float(land.get("z",item.z)))*float(scene.world.elevationScale),0.0,4.0)
    geometry.crafted_box(root,Vector3(0.1,drop+board_y+0.16,0.1),Vector3(0,(board_y+0.16-drop)/2,0),"4a3524")
   else:
    var plan := preload("res://Presentation/SignPlan.gd").layout(item,scene.world,scene.reconstruction.catalog,scene.reconstruction.supports.tiles_at)
    root.rotation.y = float(plan.yaw)+PI/2
    root.set_meta("sign_plan",plan)
    if Vector2(plan.mount).length() > 0.2:
     root.position += Vector3(plan.mount.x,0,plan.mount.y)
    else:
     # No facade behind it (e.g. a bridge-head plaque): stand it on two posts.
     var land: Dictionary = scene.reconstruction.supports.land_at(Vector2i(item.x,item.y)) if scene.reconstruction else {}
     var drop := (float(item.z)-float(land.get("z",item.z)))*float(scene.world.elevationScale)
     var post_height := drop+board_y
     for side in [-1,1]: geometry.crafted_box(root,Vector3(0.09,post_height,0.09),Vector3(side*(size.x/2-0.1),board_y-post_height/2,0),"4a3524")
   root.set_meta("engrave",Vector2(size.x-0.12,size.y-0.06)*0.85)
   pick_center = Vector3(0,board_y,0)
   size = Vector3(size.x,size.y,0.2)
   var building_name := Label3D.new()
   building_name.name = "BuildingName"
   building_name.position = Vector3(0,board_y+0.5,0)
   building_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   building_name.font_size = 30
   building_name.pixel_size = 0.003
   building_name.outline_size = 6
   building_name.modulate = Color("fff1ce")
   building_name.hide()
   preload("res://Network/ScreenLabels.gd").track(building_name)
   root.add_child(building_name)
  "sign","noticeboard":
   size = Vector3(1.1,0.85,0.17) if kind == "noticeboard" else Vector3(0.78,0.64,0.17)
   var ground := float(item.z)*float(scene.world.elevationScale)
   var land: Dictionary = scene.reconstruction.supports.land_at(Vector2i(item.x,item.y)) if scene.reconstruction else {}
   if not land.is_empty(): ground = float(land.z)*float(scene.world.elevationScale)
   var above_ground := float(item.z)*float(scene.world.elevationScale)-ground
   var board_y := maxf(0.40,2.80-above_ground) if rule.family == "sign" else 1.0
   # Owner-painted sign faces: a square board hanging on two links from the arm.
   var modern: StandardMaterial3D = preload("res://Presentation/LocalSignArt.gd").face(int(item.id)) if kind == "sign" else null
   if modern:
    size = Vector3(0.80,0.82,0.12)
    preload("res://Presentation/LocalSignArt.gd").board(root,geometry,modern,0.74,board_y+0.59)
    geometry.crafted_box(root,Vector3(0.84,0.055,0.08),Vector3(0,board_y+0.59,0),"3b3e3e")
   else:
    geometry.crafted_box(root,size,Vector3(0,board_y,0),"725231")
    for side in [-1,1]:
     geometry.crafted_box(root,Vector3(size.x-0.12,size.y-0.10,0.025),Vector3(0,board_y,side*0.10),"b79a62")
    if kind == "noticeboard":
     for i in 4: geometry.box(root,Vector3(0.19,0.27,0.008),Vector3(-0.32+i*0.21,board_y+(0.08 if i%2 else -0.07),-0.12),"e0d3ad")
    var classic_face := local_art.apply_face(root,int(item.id),Vector3(0,board_y,0),Vector2(size.x-0.13,size.y-0.10)) if kind != "noticeboard" else false
    for face in ([] if classic_face else [-1,1]):
     var sign_type := (int(item.id)-0xb95)/2
     if sign_type == 23:
      geometry.box(root,Vector3(0.22,0.26,0.025),Vector3(-0.035,board_y,face*0.123),"59432b")
      for bar_y in [-0.08,0.06]: geometry.box(root,Vector3(0.26,0.025,0.027),Vector3(-0.035,board_y+bar_y,face*0.14),"d1bb85")
      var handle := MeshInstance3D.new()
      var ring := TorusMesh.new()
      ring.inner_radius = 0.045
      ring.outer_radius = 0.075
      handle.mesh = ring
      handle.material_override = geometry.material("59432b")
      handle.rotation.x = PI/2
      handle.position = Vector3(0.115,board_y+0.02,face*0.128)
      root.add_child(handle)
     elif sign_type == 15:
      geometry.box(root,Vector3(0.39,0.11,0.03),Vector3(0,board_y-0.03,face*0.13),"59432b")
      for x in [-0.17,0.17]: geometry.box(root,Vector3(0.05,0.27,0.03),Vector3(x,board_y,face*0.13),"59432b")
      geometry.box(root,Vector3(0.09,0.055,0.035),Vector3(-0.10,board_y+0.045,face*0.14),"ead6a4")
    for side in [-1,1]: geometry.cylinder(root,0.015,0.26,Vector3(side*0.24,board_y+0.44,0),"3b3e3e")
    geometry.crafted_box(root,Vector3(0.84,0.055,0.08),Vector3(0,board_y+0.59,0),"3b3e3e")
   if int(item.id)%2: root.rotation.y = PI/2
   pick_center = Vector3(0,board_y,0)
   if rule.family == "sign":
    # Source anchor stays fixed; the visible plaque and its pick volume hang
    # perpendicular to the nearest facade, outside it on a forged bracket.
    var plan := preload("res://Presentation/SignPlan.gd").layout(item,scene.world,scene.reconstruction.catalog,scene.reconstruction.supports.tiles_at)
    root.rotation.y = float(plan.yaw)
    root.position += Vector3(plan.mount.x,0,plan.mount.y)
    for child in root.get_children():
     if child is Node3D: child.position.x += float(plan.reach)
    geometry.crafted_box(root,Vector3(0.06,0.44,0.10),Vector3(0,board_y+0.48,0),"353d40").name = "WallBracket"
    geometry.crafted_box(root,Vector3(float(plan.reach)+0.47,0.055,0.07),Vector3((float(plan.reach)+0.40)/2,board_y+0.59,0),"353d40")
    var brace := geometry.crafted_box(root,Vector3(float(plan.reach)*0.8,0.035,0.045),Vector3(float(plan.reach)*0.32,board_y+0.42,0),"353d40")
    brace.rotation.z = 0.38
    root.set_meta("sign_plan",plan)
    pick_center.x = float(plan.reach)
   var building_name := Label3D.new()
   building_name.name = "BuildingName"
   building_name.position = Vector3(pick_center.x,board_y+0.84,0)
   building_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   building_name.font_size = 30
   building_name.pixel_size = 0.003
   building_name.outline_size = 6
   building_name.modulate = Color("fff1ce")
   building_name.hide()
   preload("res://Network/ScreenLabels.gd").track(building_name)
   root.add_child(building_name)
   var posts: Array = []
   for old in scene.static_root.find_children("*","Node3D",true,false):
    if old.get_meta("kind","") == "sign" and old.get_meta("source_xyz",Vector3i.ZERO) == Vector3i(item.x,item.y,item.z):
     posts.append(old)
     old.hide()
   suppressed_posts[serial] = posts
  "lamp":
   var lamp_type := str(rule.get("type",""))
   var lamp_height := 3.2 if "LampPost" in lamp_type else (0.32 if lamp_type == "CandleLarge" else (0.48 if lamp_type == "Candelabra" else 1.7))
   size = Vector3(0.30,lamp_height,0.30)
   # Modern Britain: the owner packs' standing candelabrum, three-arm table
   # candelabra and wax candles (slot names follow the pack import).
   var light_slot: Array = {"CandelabraStand":["chandelier","chandelier_01"],"Candelabra":["candlestick","candlestick_03"],"CandleLarge":["candle","candle_02"]}.get(lamp_type,[])
   var light_model: Node3D = null
   if not light_slot.is_empty() and preload("res://Presentation/GraphicsMode.gd").modern() and preload("res://Presentation/LocalLibrary.gd").has(str(light_slot[0])):
    light_model = preload("res://Presentation/LocalLibrary.gd").build(str(light_slot[0]),int(item.x),int(item.y),Vector3(lamp_height*0.32,lamp_height,lamp_height*0.32),true,str(light_slot[1]))
   # Scanned street lamps and candelabra by name (prop-replacements.json); the light stays.
   var scanned_lamp: Node3D = preload("res://Presentation/PropReplacements.gd").build(scene.reconstruction,replacement_name,serial,int(item.id)) if preload("res://Presentation/GraphicsMode.gd").modern() else null
   if scanned_lamp:
    var lamp_boxes: Array = []
    scene.reconstruction._collect_bounds(scanned_lamp,Transform3D.IDENTITY,lamp_boxes)
    lamp_height = (lamp_boxes[0] as AABB).end.y
    for other in lamp_boxes: lamp_height = maxf(lamp_height,(other as AABB).end.y)
    size = Vector3(0.30,lamp_height,0.30)
    root.add_child(scanned_lamp)
   elif "LampPost" in lamp_type:
    # Timber post with a hanging iron lantern (MedievalKit, CC0).
    root.add_child(scene.reconstruction.fitted("MedievalKit/Lantern_Post.gltf",Vector3(0.6,lamp_height,0.3)))
   elif light_model:
    root.add_child(light_model)
   else:
    geometry.cylinder(root,0.045,lamp_height-0.25,Vector3(0,(lamp_height-0.25)/2,0),"3c4141")
    geometry.crafted_box(root,Vector3(0.23,0.25,0.23),Vector3(0,lamp_height-0.125,0),"e4c88c")
   if light_model and light_model.get_parent()==null: light_model.free()
   var lamp := OmniLight3D.new()
   lamp.position.y = lamp_height-0.12
   lamp.light_color = Color("ffd398")
   lamp.light_energy = 0.8
   lamp.omni_range = 3.5
   root.add_child(lamp)
  "plant":
   # Photoscanned CC0 potted plants (Poly Haven): a potted tree stands tall,
   # small pots sit on counters and sills.
   var tree := "Tree" in str(rule.get("type",""))
   size = Vector3(0.7,1.5,0.7) if tree else Vector3(0.42,0.62,0.42)
   var plant: Node3D = scene.reconstruction.fitted("PolyHaven/potted_plant_02/potted_plant_02_1k.gltf" if tree else "PolyHaven/potted_plant_04/potted_plant_04_1k.gltf",size)
   plant.rotation.y = float((int(item.x)*7+int(item.y)*13)%8)*PI/4
   root.add_child(plant)
  "chair":
   size = Vector3(0.55,0.85,0.55)
   geometry.crafted_box(root,Vector3(0.55,0.10,0.55),Vector3(0,0.45,0),"785734")
   for x in [-0.20,0.20]:
    for z in [-0.20,0.20]: geometry.crafted_box(root,Vector3(0.065,0.45,0.065),Vector3(x,0.225,z),"65492d")
   if "Stool" not in rule.get("type",""): geometry.crafted_box(root,Vector3(0.55,0.40,0.06),Vector3(0,0.70,0.23),"785734")
  _:
   size = Appearance.small(root,geometry,"unknown",int(item.id))
 _body(root,size,pick_center if pick_center != Vector3.ZERO else Vector3(0,size.y/2,0),serial,(int(rule.get("flags",0))&64)!=0)

# Paint the server-confirmed text on both faces of a street sign or plaque,
# scaled down until it fits the board.
func engrave(root: Node3D, text: String) -> void:
 var board: Node3D = root.get_node_or_null("TextBoard")
 if board == null: return
 var area: Vector2 = root.get_meta("engrave")
 for side in [-1,1]:
  var label: Label3D = board.get_node_or_null("Engraving_%d" % side)
  if label == null:
   label = Label3D.new()
   label.name = "Engraving_%d" % side
   label.font_size = 64
   label.outline_size = 0
   label.modulate = Color("f2e2bd")
   label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
   label.position = Vector3(0,0,side*0.032)
   if side < 0: label.rotation.y = PI
   board.add_child(label)
  label.text = text
  # Fit: wrap to the board width, then shrink until the lines fit its height.
  var font: Font = label.font if label.font else ThemeDB.fallback_font
  var pixel := 0.004
  for attempt in 12:
   label.width = area.x/pixel
   var lines := font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,label.width,label.font_size)
   if lines.y*pixel <= area.y and lines.x*pixel <= area.x: break
   pixel *= 0.85
  label.pixel_size = pixel
 var floating: Label3D = root.get_node_or_null("BuildingName")
 if floating: floating.hide()

# Horse corpses use the living horse's model, coat and hue (HorseVisual),
# posed at the last frame of its authored death clip and left still: no reins,
# gait or ground-contact sway. Other creatures keep the generic corpse look
# until their models exist.
func _equine_corpse(root: Node3D,item: Dictionary,serial: int) -> bool:
 var Horse := preload("res://Presentation/HorseVisual.gd")
 var body := int(item.get("amount",0))
 if not Horse.available() or not Horse.BODIES.has(body): return false
 var horse: Node3D = Horse.new()
 horse.name = "CorpseVisual"
 horse.native_body = body
 horse.native_hue = int(item.get("hue",0))
 root.add_child(horse)
 horse.apply_identity(body,int(item.get("hue",0)))
 horse.dead = true
 horse.current_clip = "death"
 horse.contact.enabled = false
 horse.reins.visible = false
 horse.animator.play("death")
 horse.animator.seek(horse.animator.get_animation("death").length,true)
 horse.animator.pause()
 horse.set_process(false)
 horse.set_physics_process(false)
 horse.rotation.y = fposmod(float(serial)*0.618034,1.0)*TAU
 root.set_meta("corpse_body",body)
 _body(root,Vector3(2.2,0.7,1.2),Vector3(0,0.35,0),serial,false)
 return true

# Iron-bound chest (or an all-iron strongbox) in photoscanned oak and rusted
# iron: carcass, barrel lid, corner straps, bands and a hasp plate.
func _chest(root: Node3D,size: Vector3,metal: bool) -> void:
 var iron := DoorLeaf.surface("rusty_metal_02",Color(0.36,0.33,0.31),0.55)
 var body := iron if metal else DoorLeaf.surface("medieval_wood",Color(0.62,0.48,0.36))
 var lid_height := size.y*0.3
 var base := size.y-lid_height
 DoorLeaf._box(root,Vector3(size.x,base,size.z),Vector3(0,base/2,0),body)
 var lid := MeshInstance3D.new()
 var drum := CylinderMesh.new()
 drum.top_radius = size.z/2
 drum.bottom_radius = size.z/2
 drum.height = size.x
 drum.radial_segments = 16
 lid.mesh = drum
 lid.material_override = body
 lid.rotation.z = PI/2
 lid.scale = Vector3(1,1,lid_height/(size.z/2))
 lid.position.y = base
 root.add_child(lid)
 DoorLeaf._box(root,Vector3(size.x,0.02,size.z+0.004),Vector3(0,base,0),iron)
 for x in ([-size.x*0.32,size.x*0.32] if not metal else [-size.x*0.25,size.x*0.25]):
  DoorLeaf._box(root,Vector3(0.045,base,size.z+0.012),Vector3(x,base/2,0),iron)
  var band := MeshInstance3D.new()
  var ring := CylinderMesh.new()
  ring.top_radius = size.z/2+0.006
  ring.bottom_radius = size.z/2+0.006
  ring.height = 0.045
  ring.radial_segments = 16
  band.mesh = ring
  band.material_override = iron
  band.rotation.z = PI/2
  band.scale = Vector3(1,1,lid_height/(size.z/2))
  band.position = Vector3(x,base,0)
  root.add_child(band)
 for side in [-1,1]: DoorLeaf._box(root,Vector3(0.05,base,0.05),Vector3(side*(size.x/2-0.02),base/2,-size.z/2+0.02),iron)
 DoorLeaf._box(root,Vector3(0.09,0.12,0.015),Vector3(0,base-0.02,-size.z/2-0.008),iron)

func _cabinet(root: Node3D,size: Vector3,family: String,rule: Dictionary = {}) -> void:
 geometry.crafted_box(root,size,Vector3(0,size.y/2,0),"657076" if "Metal" in str(rule.get("type","")) else "6d4b30")
 if family == "bookcase":
  for y in [0.35,0.85,1.35]:
   geometry.crafted_box(root,Vector3(size.x-0.05,0.055,0.63),Vector3(0,y,0),"a17a4c")
   for i in (0 if rule.get("type","") == "EmptyBookcase" else 7):
    geometry.crafted_box(root,Vector3(0.075,0.26+float(i%3)*0.035,0.17),Vector3(-0.30+i*0.1,y+0.18,-0.33),["766044","566d68","855749"][i%3])
 elif family == "drawers":
  for i in 3:
   geometry.crafted_box(root,Vector3(0.78,0.25,0.04),Vector3(0,0.19+i*0.30,-0.32),"936b42")
   geometry.cylinder(root,0.025,0.04,Vector3(0,0.19+i*0.30,-0.36),"c4a86c").rotation.x = PI/2
 else:
  for side in [-1,1]:
   geometry.crafted_box(root,Vector3(0.025,size.y-0.07,0.62),Vector3(side*(size.x/2-0.10),size.y/2,0),"b18b54")
  if family == "wardrobe":
   for side in [-1,1]: geometry.crafted_box(root,Vector3(0.36,size.y-0.12,0.035),Vector3(side*0.20,size.y/2,-0.32),"936b42")
  else:
   geometry.crafted_box(root,Vector3(size.x+0.025,0.10,0.65),Vector3(0,size.y-0.035,0),"9a7548")
   for x in [-0.27,0.27]: geometry.crafted_box(root,Vector3(0.055,size.y,0.04),Vector3(x,size.y/2,-0.33),"424746")

func _body(root: Node3D,size: Vector3,at: Vector3,serial: int,solid: bool) -> StaticBody3D:
 var body := StaticBody3D.new()
 body.name = "PickBody"
 body.set_meta("server_serial",serial)
 body.collision_layer = 4 | (1 if solid else 0)
 body.collision_mask = 0
 var shape := CollisionShape3D.new()
 shape.name = "PickShape"
 var box := BoxShape3D.new()
 box.size = size
 shape.shape = box
 shape.position = at
 body.add_child(shape)
 root.add_child(body)
 return body

# Leaves are built at the doorway's size from photoscanned surfaces (DoorLeaf.gd).
const DoorLeaf := preload("res://Presentation/DoorLeaf.gd")
func _door(root: Node3D,rule: Dictionary) -> void:
 var pivot := Node3D.new()
 pivot.name = "Hinge"
 root.add_child(pivot)
 var right := int(rule.get("facing",0))%2 == 1
 pivot.position.x = 0.47 if right else -0.47
 var center := -0.47 if right else 0.47
 var cell := Vector3i(int(round(root.position.x+scene.world.originX-0.5)),int(round(root.position.z+scene.world.originY-0.5)),int(round(root.position.y/float(scene.world.elevationScale))))
 var plan := preload("res://Presentation/DoorwayPlan.gd").measure(scene.world,scene.reconstruction.catalog,cell,"y" if int(rule.get("facing",0)) >= 4 else "x",scene.reconstruction.supports.tiles_at)
 var height := float(plan.leaf_height)
 root.set_meta("doorway_plan",plan)
 preload("res://Presentation/DoorwayPlan.gd").header(root,plan,geometry,scene.reconstruction.facade)
 var style := DoorLeaf.style_for(str(rule.get("type","")))
 var leaf: Node3D=DoorLeaf.build(0.94,height,style)
 leaf.name="TimberLeaf"
 # The leaf's x origin is its hinge edge; mirror for right-hung leaves.
 leaf.position=Vector3(0.0,.025,0)
 leaf.scale.x=-1.0 if right else 1.0
 leaf.set_meta("door_style",style)
 pivot.add_child(leaf)
 _body(pivot,Vector3(0.94,height,0.13),Vector3(center,height/2+0.025,0),int(root.get_meta("serial")),true)

func _door_state(root: Node3D,item: Dictionary,rule: Dictionary,instant: bool) -> void:
 var offset: Array = rule.get("offset",[0,0,0])
 var open := bool(rule.get("is_open",false))
 var x := int(item.x)-(int(offset[0]) if open else 0)
 var y := int(item.y)-(int(offset[1]) if open else 0)
 var z := int(item.z)-(int(offset[2]) if open else 0)
 root.position = scene.entity_point(x,y,z)
 var facing := clampi(int(rule.get("facing",0)),0,7)
 root.rotation.y = PI/2 if facing >= 4 else 0.0
 var hinge: Node3D = root.get_node("Hinge")
 var angle := float([-1,1,1,-1,-1,1,1,-1][facing])*PI/2 if open else 0.0
 var old: Tween = root.get_meta("door_tween") if root.has_meta("door_tween") else null
 if old and old.is_valid(): old.kill()
 if instant: hinge.rotation.y = angle
 else:
  var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tween.tween_property(hinge,"rotation:y",angle,0.18)
  root.set_meta("door_tween",tween)
 hinge.get_node("PickBody").collision_layer = 5 # The camera follows the physical leaf in either state.
 root.set_meta("open",open)

# Doors and signs measure the walls around them; a district that finishes
# streaming after they arrived rebuilds them against its real facades.
func rebuild_in_chunks(origins: Array) -> void:
 if origins.is_empty() or session == null: return
 var wanted := {}
 for origin in origins: wanted[origin] = true
 for serial in nodes.keys():
  var item: Dictionary = session.world_items.get(serial,{})
  if item.is_empty() or not str(definition(item).get("family","")) in ["door","sign"]: continue
  var near := false
  for offset in [Vector2i.ZERO,Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3)]:
   var cell: Vector2i = Vector2i(int(item.x),int(item.y))+offset
   if wanted.has(Vector2i(floori(cell.x/64.0)*64,floori(cell.y/64.0)*64)): near = true
  if not near: continue
  remove_visual(serial)
  upsert(serial,item)

func remove_visual(serial: int) -> void:
 for post in suppressed_posts.get(serial,[]):
  if is_instance_valid(post): post.show()
 suppressed_posts.erase(serial)
 if nodes.has(serial):
  nodes[serial].free()
  nodes.erase(serial)
func remove(serial: int) -> void:
 request_contact_refresh()
 remove_visual(serial)
 if scene and scene.movement_surface: scene.movement_surface.dynamic_items.erase(serial)
 if serial == selected:
  selected = 0
  hint.text = ""
func clear() -> void:
 for serial in nodes.keys(): remove(serial)
 if scene and scene.movement_surface: scene.movement_surface.dynamic_items.clear()
 label_queue.clear()
 sign_labels.clear()
 hint.text = ""

func activate(serial: int) -> bool:
 if not nodes.has(serial) or not session.world_items.has(serial): return false
 var item: Dictionary = session.world_items[serial]
 if maxi(absi(int(item.x)-int(session.player.x)),absi(int(item.y)-int(session.player.y))) > 2 or absi(int(item.z)-int(session.player.z)) > 16:
  hint.text = "Move closer to use this object."
  return false
 selected = serial
 hint.text = session.labels.item_name(int(item.id))
 if not session.target_request.is_empty(): return preload("res://Network/ActionRunner.gd").target_entity(session,serial)
 return session.use_item(serial)

func click(at: Vector2, double: bool = false) -> void:
 if session.phase != "world": return
 var from: Vector3 = scene.camera.project_ray_origin(at)
 var direction: Vector3 = scene.camera.project_ray_normal(at)
 # Include walls so clicks cannot select an object hidden behind a building.
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+direction*30.0,5))
 if not hit.is_empty() and session.placement_serial:
  var cell := Vector3i(floori(hit.position.x+scene.world.originX),floori(hit.position.z+scene.world.originY),roundi(hit.position.y/float(scene.world.elevationScale)))
  if maxi(absi(cell.x-int(session.player.x)),absi(cell.y-int(session.player.y)))>2 or absi(cell.z-int(session.player.z))>16:
   hint.text = "Choose a surface within reach."
   return
  if session.move_item(session.placement_serial,0,false,cell): session.placement_serial = 0
  return
 if not hit.is_empty() and hit.collider.has_meta("server_mobile"):
  var mobile := int(hit.collider.get_meta("server_mobile"))
  # An open target cursor takes the creature; otherwise it is selected (for
  # the quickbar's attack and target actions) and its menu opens.
  if not session.target_request.is_empty():
   preload("res://Network/ActionRunner.gd").target_entity(session,mobile)
   return
  preload("res://Network/ActionRunner.gd").selected = mobile
  # In war mode a double-click on another creature attacks it (as in the
  # native client); otherwise it is used (paperdoll, mount, ...).
  # In war mode a double-click on yourself opens your paperdoll rather than
  # dismounting, so a fight cannot throw you off your horse by accident.
  if double and session.in_war_mode() and mobile == int(session.player.get("serial",0)):
   session.send(preload("res://Network/Packets/Player.gd").open_paperdoll(mobile))
  elif double and session.in_war_mode() and mobile != int(session.player.get("serial",0)):
   if session.attack(mobile): preload("res://Network/ActionRunner.gd").last_target = mobile
  elif double:
   session.use_mobile(mobile)
   # Peace mode: attackable creatures (notoriety 3-6) need war mode first.
   if int(session.entities.get(mobile,{}).get("notoriety",0)) in [3,4,5,6] and not preload("res://Presentation/HorseVisual.gd").BODIES.has(int(session.entities.get(mobile,{}).get("body",0))): hint.text = "Switch to war mode (the War button) to attack."
  elif preload("res://Presentation/HorseVisual.gd").BODIES.has(int(session.entities.get(mobile,{}).get("body",0))):hint.text="Double-click the horse to ride."
  elif mobile==int(session.player.get("serial",0)) and not preload("res://Presentation/HorseVisual.gd").mount_item(session.equipment.values()).is_empty():hint.text="Double-click yourself to dismount."
  else:session.request_context(mobile)
 elif not hit.is_empty() and hit.collider.has_meta("server_serial"): activate(int(hit.collider.get_meta("server_serial")))

# The server object or creature under the mouse (quickbar "under the mouse").
func hovered_serial() -> int:
 if session.phase != "world": return 0
 var at := get_viewport().get_mouse_position()
 var from: Vector3 = scene.camera.project_ray_origin(at)
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+scene.camera.project_ray_normal(at)*30.0,5))
 if hit.is_empty(): return 0
 if hit.collider.has_meta("server_mobile"): return int(hit.collider.get_meta("server_mobile"))
 return int(hit.collider.get_meta("server_serial",0))

func nearest() -> void:
 var best := 0
 var distance := INF
 for serial in nodes:
  if not nodes[serial].get_meta("interactive",false): continue
  var item: Dictionary = session.world_items.get(serial,{})
  if item.is_empty() or absi(int(item.z)-int(session.player.z)) > 16: continue
  var delta := Vector2(item.x-session.player.x,item.y-session.player.y).length()
  if delta < distance and delta <= 2.0:
   distance = delta
   best = serial
 if best: activate(best)
 else: hint.text = "No server object within reach."

func suppress_streamed_posts(root: Node = null) -> void:
 # New source chunks can arrive after a native sign packet. Reapply only the
 # presentation suppression; do not recreate native entities or their state.
 var signs := false
 for serial in nodes:
  if nodes[serial].get_meta("family","") == "sign": signs = true
 if not signs: return
 var posts: Array = (root if root else scene.static_root).find_children("*","Node3D",true,false)
 for serial in nodes:
  if nodes[serial].get_meta("family","") != "sign": continue
  if not session.world_items.has(serial): continue
  var item: Dictionary = session.world_items[serial]
  var hidden: Array = suppressed_posts.get(serial,[]) if root else []
  for post in posts:
   if post.get_meta("kind","") == "sign" and post.get_meta("source_xyz",Vector3i.ZERO) == Vector3i(item.x,item.y,item.z):
    post.hide()
    hidden.append(post)
  suppressed_posts[serial] = hidden

# Streaming registers districts with the support plan incrementally; fixed
# worlds rebuild the flat index here.
func refresh_source_records(incremental: bool = false) -> void:
 if scene.reconstruction:
  if not incremental: scene.reconstruction.supports.index(scene.world)
  scene.reconstruction.supports.dynamic=session.world_items
  scene.reconstruction.supports.dynamic_definitions=definitions
  request_contact_refresh()

func request_contact_refresh() -> void:
 if contacts_pending:return
 contacts_pending=true
 refresh_contacts.call_deferred()

# Every free-standing item rests on what is really under it: source Z stacks
# sprites, but presented counters, shelves, tables and floors have their own
# heights, and imported models do not all have their pivot at their base. The
# item's lowest mesh point (not its origin) is put on the surface found by a
# downward ray. Doors, signs and wall-hung pieces stay where they are.
const FIXED_FAMILIES := ["door","sign","noticeboard","street_sign","plaque","light","lamp"]
func _free_standing(node: Node3D) -> bool:
 if not node.is_inside_tree() or str(node.get_meta("family","")) in FIXED_FAMILIES: return false
 var item: Dictionary = session.world_items.get(int(node.get_meta("serial",0)),{})
 var label := str(definition(item).get("display_name","")).to_lower() if not item.is_empty() else ""
 return not (preload("res://Presentation/ContactSettle.gd").hung(label) or "wall" in label)

# Lowest point of the node's meshes in its own frame (INF without meshes).
func _local_bottom(node: Node3D) -> float:
 var bottom := INF
 var inverse := node.global_transform.affine_inverse()
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var box: AABB = (inverse*(mesh as MeshInstance3D).global_transform)*(mesh as MeshInstance3D).get_aabb()
  bottom = minf(bottom,box.position.y)
 return bottom

# Moves the node's children so its lowest point sits on the surface below.
# Idempotent: the previous correction is undone first unless the caller has
# just reset the children (fresh = true).
# Server-placed multi-tile decoration (one item per tile, e.g. a fireplace or
# loom): neighbouring items of the same name/group within 6 Z are one object.
# The lowest serial draws the model centred over the footprint; the others
# keep only their pick body.
func _footprint_replacement(item: Dictionary, name: String, serial: int) -> Node3D:
 var Swaps := preload("res://Presentation/PropReplacements.gd")
 var group := str(Swaps.entry_for(name,int(item.id)).get("group",Swaps.key(name)))
 var members := {serial:item}
 var pending := [item]
 while not pending.is_empty():
  var at: Dictionary = pending.pop_back()
  for other_serial in session.world_items:
   if members.has(other_serial): continue
   var other: Dictionary = session.world_items[other_serial]
   if absi(int(other.x)-int(at.x)) > 1 or absi(int(other.y)-int(at.y)) > 1 or absi(int(other.z)-int(at.z)) > 6: continue
   var other_name := str(definitions.get(str(int(other.id)),{}).get("display_name",scene.world.get("staticData",{}).get(str(int(other.id)),{}).get("name","")))
   if other_name == "" or Swaps.entry_for(other_name,int(other.id)).is_empty(): continue
   if str(Swaps.entry_for(other_name,int(other.id)).get("group",Swaps.key(other_name))) != group: continue
   members[other_serial] = other
   pending.append(other)
 var root := Node3D.new()
 if serial != members.keys().min(): return root
 var low := Vector2i(100000,100000)
 var high := Vector2i(-100000,-100000)
 for m in members.values():
  low = low.min(Vector2i(m.x,m.y))
  high = high.max(Vector2i(m.x,m.y))
 var span := Vector2(high-low)+Vector2.ONE
 var model: Node3D = Swaps.build(scene.reconstruction,name,0,int(item.id),{"length":maxf(span.x,span.y)*0.92})
 if model == null: return root
 var centre := Vector2(low+high)/2.0+Vector2(0.5,0.5)
 model.position = Vector3(centre.x-float(item.x)-0.5,0,centre.y-float(item.y)-0.5)
 if span.y > span.x+0.5: model.rotation.y = PI/2
 root.add_child(model)
 return root

func _rest_on_surface(node: Node3D, space: PhysicsDirectSpaceState3D, fresh := false) -> void:
 if not _free_standing(node): return
 var previous := 0.0 if fresh else float(node.get_meta("rest_delta",0.0))
 for child in node.get_children():
  if child is Node3D: child.position.y -= previous
 node.set_meta("rest_delta",0.0)
 var bottom := _local_bottom(node)
 if bottom == INF: return
 var base := node.global_position.y+bottom
 var from := Vector3(node.global_position.x,maxf(base,node.global_position.y)+0.6,node.global_position.z)
 var query := PhysicsRayQueryParameters3D.create(from,from-Vector3(0,2.4,0),1)
 var own := node.find_children("PickBody","StaticBody3D",true,false)
 query.exclude = own.map(func(body: Node) -> RID: return (body as StaticBody3D).get_rid())
 var hit := space.intersect_ray(query)
 if hit.is_empty(): return
 var delta := float(hit.position.y)-base
 if absf(delta) < 0.01 or delta > 1.2 or delta < -1.6: return
 for child in node.get_children():
  if child is Node3D: child.position.y += delta
 node.set_meta("rest_delta",delta)

func refresh_contacts() -> void:
 contacts_pending=false
 if not is_instance_valid(scene):return
 var supports: RefCounted=scene.reconstruction.supports
 supports.cache.clear()
 var space := get_world_3d().direct_space_state
 for serial in nodes:
  var node: Node3D=nodes[serial]
  var visual: Node3D=node.get_node_or_null("ReviewedVisual")
  if not session.world_items.has(serial):continue
  if node.has_meta("library_item") and node.is_inside_tree():
   _rest_on_surface(node,space)
   continue
  var review: Dictionary=preload("res://Presentation/ReviewedCatalog.gd").entry(int(session.world_items[serial].id))
  if review.get("attachment","") not in ["floor","surface"]:
   _rest_on_surface(node,space)
   continue
  var placement: Dictionary=supports.placement(session.world_items[serial])
  # Undo the last surface correction; the plan is re-applied, then the
  # real surface under the model's lowest point decides the final height.
  var rested := float(node.get_meta("rest_delta",0.0))
  for child in node.get_children():
   if child is Node3D: child.position.y -= rested
  node.set_meta("rest_delta",0.0)
  if visual:
   visual.position=placement.offset
   node.get_node("PickBody").position=placement.offset
  else:
   var previous: Vector3=node.get_meta("contact_offset",Vector3.ZERO)
   for child in node.get_children():
    if child is Node3D:child.position+=placement.offset-previous
  node.set_meta("contact_offset",placement.offset)
  node.set_meta("contact",placement)
  _rest_on_surface(node,space,true)
