extends SceneTree
const Game = preload("res://Network/GameSession.gd")
const Login = preload("res://Network/LoginProtocol.gd")
const Doorway = preload("res://Presentation/DoorwayPlan.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks += 1
 if ok: print("PASS ",label)
 else:
  failures += 1
  push_error(label)
func _initialize() -> void: call_deferred("run")
func world_packet(serial: int,id: int,x: int,y: int,z: int,kind: int = 0) -> PackedByteArray:
 var p := PackedByteArray([0xf3,0,1,kind])
 p.append_array(Login.uint_be(serial,4))
 p.append_array(Login.uint_be(id,2))
 p.append_array(PackedByteArray([0,0,1,0,1]))
 p.append_array(Login.uint_be(x,2))
 p.append_array(Login.uint_be(y,2))
 p.append_array(PackedByteArray([z&255,0,0,0,0,0,0]))
 return p
func container_entry(serial: int,parent: int) -> PackedByteArray:
 var p := Login.uint_be(serial,4)
 p.append_array(PackedByteArray([0x0e,0x76,0,0,2,0,1,0,2,0]))
 p.append_array(Login.uint_be(parent,4))
 p.append_array(PackedByteArray([0,0]))
 return p
class Fixture extends Node3D:
 var world := {"originX":1000,"originY":2000,"width":32,"height":32,"elevationScale":0.2,"terrain":[],"statics":[{"x":1004,"y":2005,"z":20,"id":101},{"x":1006,"y":2005,"z":20,"id":101}],"staticData":{"101":{"height":20}}}
 var movement_surface := preload("res://Presentation/MovementSurface.gd").new()
 var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
 var static_root := Node3D.new()
 var camera := Camera3D.new()
 func entity_point(x: int,y: int,z: int) -> Vector3: return Vector3(x-world.originX+0.5,z*0.2,y-world.originY+0.5)
func run() -> void:
 var game := Game.new()
 root.add_child(game)
 game.set_process(false)
 var received := []
 game.world_item_changed.connect(func(serial: int,item: Dictionary): received.append([serial,item]))
 var packet := world_packet(0x40000001,0x6a5,1005,2005,-20)
 for byte in packet: game.feed(PackedByteArray([byte]))
 check(game.world_items[0x40000001].z == -20 and received.size() == 1,"fragmented native F3 world item with signed elevation")
 game.feed(world_packet(0x40000001,0x6a6,1004,2006,-20))
 check(game.world_items.size() == 1 and game.world_items[0x40000001].id == 0x6a6,"server door update replaces same serial without duplication")
 game.feed(world_packet(22,400,1005,2005,0,1))
 game.feed(world_packet(0x40000099,400,1005,2005,0,2))
 check(game.world_items.size() == 1,"mobile and multi F3 entities never become ordinary props")
 var legacy := PackedByteArray([0x1a,0,14,0x40,0,0,2,0x06,0xa5,0x03,0xed,0x07,0xd5,0xff])
 var parsed := Game.legacy_item(legacy)
 check(parsed.serial == 0x40000002 and parsed.x == 1005 and parsed.z == -1,"legacy item packet coordinate and signed elevation")
 check(Game.legacy_item(legacy.slice(0,12)).is_empty(),"truncated legacy optional fields rejected")
 game.feed(legacy)
 game.feed(PackedByteArray([0x1d,0x40,0,0,2]))
 check(not game.world_items.has(0x40000002),"native remove packet removes dynamic prop")
 game.feed(PackedByteArray([0x24,0x40,0,0,9,0,0x3c,0,0x7d]))
 var content := PackedByteArray([0x3c,0,25,0,1])
 content.append_array(container_entry(0x40000001,0x40000009))
 game.feed(content)
 check(game.container_serial == 0x40000009 and game.container_items[0x40000001].amount == 2,"native container open and contents parent/amount offsets")
 check(not game.world_items.has(0x40000001),"contained item no longer renders on the ground")
 var update := PackedByteArray([0x25])
 update.append_array(container_entry(0x40000002,0x40000009))
 game.feed(update)
 check(game.container_items.has(0x40000002),"grid-enabled native container update parent offset")
 game.feed(PackedByteArray([0x3c,0,5,0,0]))
 check(game.container_items.is_empty(),"empty container clears previous container contents")
 game.labels.strings = {"123":"The ~1_NAME~","124":"Quiet Inn"}
 check(game.labels.resolve(123,"#124") == "The Quiet Inn","localized native label arguments resolve referenced names")
 game.labels.strings["125"] = "~2_SECOND~ / ~1_FIRST~"
 check(game.labels.resolve(125,"first\tsecond") == "second / first","localized arguments follow numeric indices rather than text order")
 check(Game.little_unicode_text(PackedByteArray([65,0,0,0]),0) == "A","little-endian native label arguments strip NUL before decoding")
 var labels := []
 game.item_label_received.connect(func(serial: int,label: String): labels.append([serial,label]))
 var label := PackedByteArray([0xc1,0,50,0x40,0,0,4,0,0,0,0,0,0,3,0,0,0,124])
 label.resize(50)
 game.feed(label)
 check(labels.size() == 1 and labels[0][0] == 0x40000004 and labels[0][1] == "Quiet Inn","clicked sign label stays attached to its native serial")
 var fixture := Fixture.new()
 root.add_child(fixture)
 fixture.add_child(fixture.static_root)
 fixture.add_child(fixture.camera)
 fixture.reconstruction.catalog = {"101":{"kind":"wall","axis":"x"}}
 var plan := Doorway.measure(fixture.world,fixture.reconstruction.catalog,Vector3i(1005,2005,20),"x")
 check(is_equal_approx(plan.envelope,4.0) and is_equal_approx(plan.opening,2.52),"source storey height and human-scaled doorway kept separate")
 var translated := fixture.world.duplicate(true)
 for tile in translated.statics:
  tile.x += 73
  tile.y -= 42
 var moved := Doorway.measure(translated,fixture.reconstruction.catalog,Vector3i(1078,1963,20),"x")
 check(moved == plan,"doorway sizing independent of Britain coordinates")
 var rotated := fixture.world.duplicate(true)
 for tile in rotated.statics:
  var x: int = tile.x
  tile.x = tile.y
  tile.y = x
 var turned := Doorway.measure(rotated,{"101":{"kind":"wall","axis":"y"}},Vector3i(2005,1005,20),"y")
 check(turned == plan,"north/south doorways use the same lintel proportions")
 var view := preload("res://Presentation/WorldItems.gd").new()
 fixture.add_child(view)
 view.configure(fixture,game)
 var closed := {"serial":0x40000001,"id":0x6a5,"x":1005,"y":2005,"z":20,"facet":1}
 game._world_item(closed)
 check(view.nodes.size() == 1,"native item creates one visible door")
 var door: Node3D = view.nodes[0x40000001]
 var leaf: Node3D = door.get_node("Hinge/TimberLeaf")
 var boxes: Array=[]
 fixture.reconstruction._collect_bounds(leaf,Transform3D.IDENTITY,boxes)
 var bounds: AABB=boxes[0]
 for box in boxes:bounds=bounds.merge(box)
 check(bounds.size.y<2.5 and is_equal_approx(bounds.size.x,.94) and leaf.get_meta("reviewed_asset","")=="MedievalKit/Door_Rect.gltf","reviewed medieval door retains human scale and native opening width")
 check(door.has_node("DoorLintel") and door.has_node("OverDoorWall") and door.has_node("HeaderCollision"),"lintel and upper wall seal the original tall opening")
 check(door.get_node("OverDoorWall").material_override.get_shader_parameter("open_caps"),"doorway infill cannot reintroduce coplanar white floor caps")
 var location := door.position
 game._world_item({"serial":0x40000001,"id":0x6a6,"x":1004,"y":2006,"z":20,"facet":1})
 check(view.nodes[0x40000001].position.is_equal_approx(location),"open sprite offset never displaces the architectural hinge or header")
 check(door.get_node("Hinge/PickBody").collision_layer == 5,"server-open door retains camera collision on the rotating leaf")
 game._world_item({"serial":0x40000002,"id":0x6a7,"x":1006,"y":2005,"z":20,"facet":1})
 check(view.nodes.size() == 2,"native double doors keep two separate leaves")
 check(view.nodes[0x40000002].get_node("Hinge/TimberLeaf").scale.x<0 and leaf.scale.x>0,"Opposite native hinges mirror the imported leaf so paired handles meet at the opening")
 game._remove_world_item(0x40000001)
 game._world_item({"serial":0x40000001,"id":0x6a6,"x":1004,"y":2006,"z":20,"facet":1})
 check(is_equal_approx(view.nodes[0x40000001].get_meta("doorway_plan").envelope,4.0),"joining while a door is open measures its original source frame")
 check(fixture.movement_surface.dynamic_items.size() == 2,"authoritative items feed local movement obstruction prediction")
 view.definitions["3000"] = {"family":"sign","height":0,"flags":0,"type":"LocalizedSign"}
 game._world_item({"serial":0x40000003,"id":3000,"x":1009,"y":2009,"z":20,"facet":1})
 var sign: Node3D = view.nodes[0x40000003]
 check(sign.get_node("PickBody/PickShape").position.y > 2.5,"building sign and click target rise together above the entrance")
 check(sign.has_node("WallBracket") and sign.get_node("PickBody/PickShape").position.x>0.5,"projecting building sign bracket and click volume share the outward offset")
 var Sign = preload("res://Presentation/SignPlan.gd")
 var sign_world := {"statics":[{"id":901,"x":4,"y":5,"z":0}]}
 var sign_rules := {"901":{"kind":"wall","axis":"x"}}
 var a := Sign.layout({"id":3000,"x":4,"y":6,"z":0},sign_world,sign_rules)
 var b := Sign.layout({"id":3000,"x":4,"y":4,"z":0},sign_world,sign_rules)
 check(is_equal_approx(absf(angle_difference(a.yaw,b.yaw)),PI),"sign brackets project to opposite sides of opposite-facing walls")
 var turned_sign := Sign.layout({"id":3000,"x":6,"y":4,"z":0},{"statics":[{"id":901,"x":5,"y":4,"z":0}]},{"901":{"kind":"wall","axis":"z"}})
 check(is_equal_approx(absf(angle_difference(a.yaw,turned_sign.yaw)),PI/2),"perpendicular facade rotates the sign plane by ninety degrees")
 game.item_label_received.emit(0x40000003,"The Quiet Inn")
 check(sign.get_node("BuildingName").text == "The Quiet Inn" and sign.get_node("BuildingName").visible,"server-confirmed building name appears on the clicked sign")
 game._remove_world_item(0x40000003)
 check(not view.nodes.has(0x40000003),"server visibility removal also removes sign visuals")
 game.close()
 check(view.nodes.is_empty() and fixture.movement_surface.dynamic_items.is_empty(),"disconnect clears props, door colliders and prediction obstacles")
 fixture.free()
 game.free()
 for frame in 3: await process_frame
 print("WORLD ITEM CHECKS: %d passed / %d total" % [checks-failures,checks])
 quit(0 if failures == 0 else 1)
