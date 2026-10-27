extends RefCounted
# Original procedural models, in metres. Semantic substitutes remain identified
# in conversion reports; no proprietary textures or source mesh payloads.
static func build(kind: String,s: Dictionary,info: Dictionary,g: RefCounted) -> Node3D:
 var root:=Node3D.new()
 root.set_meta("model",kind)
 var name_text:=str(info.get("name","")).to_lower()
 var wood:="745638"
 var iron:="51585c"
 var stone:="9e9a87"
 var cloth:String=["854d49","405e72","66734e"][int(s.id)%3]
 # Owner-licensed Dexsoft props replace barrels, crates, tubs and hay locally.
 var local_kind:=preload("res://Presentation/LocalProps.gd").kind_for(kind,name_text)
 var local:Node3D=preload("res://Presentation/LocalProps.gd").build(local_kind,int(s.x),int(s.y),0.7 if "keg" in name_text else 1.0) if local_kind!="" else null
 if local:
  root.add_child(local)
  return root
 match kind:
  "globe","gem":
   var ball:=MeshInstance3D.new()
   var shape:=SphereMesh.new();shape.radius=0.19 if kind=="globe" else 0.055;shape.height=shape.radius*2;shape.radial_segments=12;shape.rings=6
   ball.mesh=shape;ball.position.y=0.33 if kind=="globe" else 0.055;ball.material_override=g.material("4f8292");root.add_child(ball)
   if kind=="globe":g.cylinder(root,0.13,0.07,Vector3(0,0.04,0),wood)
  "vase":
   g.cylinder(root,0.15,0.26,Vector3(0,0.15,0),"aa805a")
   g.cylinder(root,0.075,0.18,Vector3(0,0.36,0),"b99266")
   g.cylinder(root,0.095,0.025,Vector3(0,0.46,0),"d0b18a")
  "anvil":
   g.crafted_box(root,Vector3(0.44,0.08,0.30),Vector3(0,0.04,0),iron)
   g.crafted_box(root,Vector3(0.20,0.27,0.19),Vector3(0,0.20,0),iron)
   g.crafted_box(root,Vector3(0.55,0.10,0.24),Vector3(0,0.38,0),iron)
  "book","bottle":
   preload("res://Presentation/ItemAppearance.gd").small(root,g,"scroll" if "scroll" in name_text or "map" in name_text else ("book" if kind=="book" else "bottle"),int(s.id))
  "cup":
   if "plate" in name_text or "tray" in name_text: g.cylinder(root,0.17,0.025,Vector3(0,0.015,0),"c5c4af")
   elif "bucket" in name_text or "basin" in name_text:
    g.cylinder(root,0.19,0.27,Vector3(0,0.135,0),wood)
    g.cylinder(root,0.17,0.006,Vector3(0,0.274,0),"48636c")
   else: preload("res://Presentation/ItemAppearance.gd").small(root,g,"jug" if "pitcher" in name_text or "jug" in name_text else "mug",int(s.id))
  "chair":
   g.crafted_box(root,Vector3(0.55,0.08,0.55),Vector3(0,0.48,0),wood)
   for x in [-0.21,0.21]:
    for z in [-0.21,0.21]: g.box(root,Vector3(0.065,0.47,0.065),Vector3(x,0.235,z),wood)
   if "stool" not in name_text:
    g.crafted_box(root,Vector3(0.55,0.65,0.07),Vector3(0,0.81,0.23),wood)
    g.crafted_box(root,Vector3(0.40,0.40,0.04),Vector3(0,0.83,0.18),cloth)
  "container":
   if "barrel" in name_text or "keg" in name_text:
    g.cylinder(root,0.34,0.83,Vector3(0,0.415,0),wood)
    for y in [0.12,0.70]:g.cylinder(root,0.35,0.055,Vector3(0,y,0),iron)
   elif "bag" in name_text or "backpack" in name_text or "pouch" in name_text: preload("res://Presentation/ItemAppearance.gd").small(root,g,"bag",int(s.id))
   else:
    var height:=1.6 if "armoire" in name_text or "vault" in name_text else 0.65
    g.crafted_box(root,Vector3(0.78,height,0.62),Vector3(0,height/2,0),iron if "safe" in name_text else wood)
    for x in [-0.31,0.31]: g.box(root,Vector3(0.06,height,0.66),Vector3(x,height/2,0),"a17c50")
    for y in [0.07,height-0.07]: g.box(root,Vector3(0.81,0.06,0.66),Vector3(0,y,0),"a17c50")
    g.box(root,Vector3(0.08,0.07,0.04),Vector3(0,height*0.55,-0.33),"bba773")
  "shelf":
   for x in [-0.40,0.40]:g.crafted_box(root,Vector3(0.075,1.65,0.40),Vector3(x,0.825,0),wood)
   for y in [0.06,0.55,1.05,1.62]:g.box(root,Vector3(0.84,0.055,0.40),Vector3(0,y,0),wood)
   for row in 3:
    for i in 6:g.crafted_box(root,Vector3(0.08,0.28,0.23),Vector3(-0.28+i*0.11,0.22+row*0.5,0),["5b6b61","8d5a4e","a48a5e"][i%3])
  "display_case":
   g.crafted_box(root,Vector3(0.95,0.80,0.85),Vector3(0,0.40,0),wood)
   g.box(root,Vector3(0.88,0.045,0.78),Vector3(0,0.84,0),"a99e86")
   for x in [-0.43,0.43]:
    for z in [-0.38,0.38]:g.box(root,Vector3(0.035,0.32,0.035),Vector3(x,1.02,z),wood)
   var glass:MeshInstance3D=g.box(root,Vector3(0.90,0.27,0.80),Vector3(0,1.02,0),"99b8bb")
   var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.6,0.75,0.76,0.16);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=0.15
   glass.material_override=mat
  "fountain":
   g.cylinder(root,0.46,0.30,Vector3(0,0.15,0),stone)
   g.cylinder(root,0.40,0.012,Vector3(0,0.31,0),"4f8a9c")
   if "fountain" in name_text:
    g.cylinder(root,0.09,0.80,Vector3(0,0.55,0),stone)
    g.cylinder(root,0.28,0.08,Vector3(0,0.95,0),stone)
    for i in 4:g.cylinder(root,0.018,0.37,Vector3(sin(i*PI/2)*0.20,0.73,cos(i*PI/2)*0.20),"8bbbc1")
  "cannon":
   for x in [-0.28,0.28]:
    var wheel:MeshInstance3D=g.cylinder(root,0.22,0.07,Vector3(x,0.22,0.05),wood);wheel.rotation.z=PI/2
   g.crafted_box(root,Vector3(0.45,0.25,0.70),Vector3(0,0.32,0),wood)
   var barrel:MeshInstance3D=g.cylinder(root,0.11,1.1,Vector3(0,0.53,-0.18),iron);barrel.rotation.x=PI/2-0.12
  "statue":
   g.crafted_box(root,Vector3(0.62,0.16,0.62),Vector3(0,0.08,0),stone)
   g.cylinder(root,0.15,0.55,Vector3(0,0.43,0),stone)
   g.crafted_box(root,Vector3(0.35,0.50,0.20),Vector3(0,0.87,0),stone)
   g.cylinder(root,0.13,0.25,Vector3(0,1.22,0),stone)
  "grave":
   g.crafted_box(root,Vector3(0.54,0.85,0.16),Vector3(0,0.425,0),stone)
   for y in [0.40,0.50,0.60]:g.box(root,Vector3(0.27,0.018,0.012),Vector3(0,y,-0.086),"64675f")
  "fabric":
   var vertical:= "banner" in name_text or "curtain" in name_text or "tapestr" in name_text
   g.crafted_box(root,Vector3(0.8,1.35,0.025) if vertical else Vector3(0.32,0.06,0.44),Vector3(0,0.675 if vertical else 0.03,0),cloth)
   if vertical:
    g.box(root,Vector3(0.90,0.055,0.055),Vector3(0,1.38,0),wood)
    for x in [-0.31,-0.10,0.10,0.31]:g.box(root,Vector3(0.025,1.3,0.015),Vector3(x,0.68,-0.02),"a99362")
  "painting": root.add_child(g.painting())
  "wall_light":
   # Iron back plate on the wall face, a short bracket and either a leaning
   # wooden torch or a candle cup. Front faces -Z; mounting comes from walls.
   g.box(root,Vector3(0.09,0.34,0.03),Vector3(0,0.55,-0.015),iron)
   g.box(root,Vector3(0.035,0.035,0.17),Vector3(0,0.45,-0.10),iron)
   var flame_at:=Vector3(0,0.86,-0.24)
   if "sconce" in name_text:
    g.cylinder(root,0.06,0.03,Vector3(0,0.47,-0.19),iron)
    g.cylinder(root,0.025,0.16,Vector3(0,0.57,-0.19),"e6dcc0")
    flame_at=Vector3(0,0.68,-0.19)
   else:
    var torch:MeshInstance3D=g.cylinder(root,0.026,0.46,Vector3(0,0.64,-0.17),wood)
    torch.rotation.x=0.28
    g.cylinder(root,0.04,0.08,Vector3(0,0.84,-0.23),"3b2d22")
   var flame:=MeshInstance3D.new()
   var tip:=SphereMesh.new();tip.radius=0.045;tip.height=0.13;tip.radial_segments=8;tip.rings=4
   var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ffb347");glow.emission_enabled=true;glow.emission=Color("ff9a2e");glow.emission_energy_multiplier=2.5
   flame.mesh=tip;flame.material_override=glow;flame.position=flame_at+Vector3(0,0.05,0);root.add_child(flame)
  "lamp":
   var tall:="post" in name_text
   var h:=2.5 if tall else 0.7
   g.cylinder(root,0.035,h-0.2,Vector3(0,(h-0.2)/2,0),iron)
   g.crafted_box(root,Vector3(0.20,0.25,0.20),Vector3(0,h-0.12,0),"d5b777")
   for x in [-0.11,0.11]:g.box(root,Vector3(0.025,0.30,0.24),Vector3(x,h-0.12,0),iron)
  "hearth":
   g.crafted_box(root,Vector3(0.9,0.7,0.8),Vector3(0,0.35,0),stone)
   g.box(root,Vector3(0.60,0.35,0.025),Vector3(0,0.28,-0.415),"282b2a")
   for x in [-0.2,0,0.2]:g.crafted_box(root,Vector3(0.16,0.07,0.06),Vector3(x,0.16,-0.44),"b17037")
  "training":
   g.cylinder(root,0.045,1.5,Vector3(0,0.75,0),wood)
   g.crafted_box(root,Vector3(0.42,0.65,0.23),Vector3(0,1.05,0),"a69359")
   g.cylinder(root,0.15,0.25,Vector3(0,1.52,0),"a69359")
   g.box(root,Vector3(1,0.09,0.09),Vector3(0,1.27,0),wood)
  "music":
   if name_text=="drum" or name_text=="tambourine":
    g.cylinder(root,0.23,0.28 if name_text=="drum" else 0.05,Vector3(0,0.14,0),wood)
    g.cylinder(root,0.235,0.02,Vector3(0,0.29 if name_text=="drum" else 0.175,0),"c5b58d")
   elif name_text=="lute":
    var body:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=0.18;shape.height=0.10
    body.mesh=shape;body.scale.z=1.35;body.position.y=0.07;body.material_override=g.material(wood);root.add_child(body)
    g.box(root,Vector3(0.07,0.06,0.40),Vector3(0,0.06,-0.38),wood)
    for x in [-0.015,0,0.015]:g.box(root,Vector3(0.003,0.003,0.60),Vector3(x,0.125,-0.24),"b7ac80")
   elif "harp" in name_text and "harpsichord" not in name_text:
    for x in [-0.30,0.30]:g.crafted_box(root,Vector3(0.07,1.2,0.09),Vector3(x,0.60,0),wood)
    g.crafted_box(root,Vector3(0.68,0.07,0.09),Vector3(0,1.20,0),wood)
    g.crafted_box(root,Vector3(0.68,0.10,0.25),Vector3(0,0.05,0),wood)
    for i in 9:g.box(root,Vector3(0.005,1.10,0.005),Vector3(-0.24+i*0.06,0.60,0),"cbbd88")
   else:
    g.crafted_box(root,Vector3(0.65,0.8,0.42),Vector3(0,0.4,0),wood)
    for i in 9:g.box(root,Vector3(0.045,0.025,0.20),Vector3(-0.25+i*0.06,0.82,-0.10),"d4ccb7")
    g.crafted_box(root,Vector3(0.68,0.12,0.48),Vector3(0,0.91,0.16),wood)
  "newspaper":
   g.box(root,Vector3(0.23,0.008,0.29),Vector3(0,0.005,0),"dbd2b9")
   for y in range(1,8):
    for x in [-0.055,0.055]:g.box(root,Vector3(0.08,0.002,0.007),Vector3(x,0.010,-0.12+y*0.027),"6e695d")
  "ship":
   if "ladder" in name_text:
    for x in [-0.25,0.25]:g.box(root,Vector3(0.055,1.8,0.055),Vector3(x,0.9,0),wood)
    for i in 6:g.box(root,Vector3(0.5,0.055,0.055),Vector3(0,0.15+i*0.28,0),wood)
   else:
    g.cylinder(root,0.12,0.8,Vector3(0,0.4,0),wood)
    g.crafted_box(root,Vector3(0.65,0.08,0.08),Vector3(0,0.62,0),iron)
  "weapon":
   if "mail" in name_text or "armor" in name_text or "tunic" in name_text:
    g.crafted_box(root,Vector3(0.35,0.10,0.42),Vector3(0,0.05,0),iron)
    for x in [-0.20,0.20]:g.box(root,Vector3(0.13,0.08,0.18),Vector3(x,0.05,-0.1),iron)
   else:preload("res://Presentation/ItemAppearance.gd").small(root,g,"weapon",int(s.id))
  "tool":
   if "silverware" in name_text:
    for x in [-0.055,0.055]:g.box(root,Vector3(0.018,0.01,0.20),Vector3(x,0.01,0),"b9bfc0")
    for x in [-0.07,-0.055,-0.04]:g.box(root,Vector3(0.005,0.01,0.06),Vector3(x,0.01,-0.12),"b9bfc0")
    return root
   g.cylinder(root,0.022,0.40,Vector3(0,0.04,0),wood).rotation.x=PI/2
   g.crafted_box(root,Vector3(0.20,0.06,0.07),Vector3(0,0.04,-0.18),iron)
  "food":
   if "bread" in name_text or "cheese" in name_text:
    preload("res://Presentation/ItemAppearance.gd").small(root,g,"cheese" if "cheese" in name_text else "bread",int(s.id))
   elif "pie" in name_text or "cake" in name_text or "cookie" in name_text:
    g.cylinder(root,0.16,0.06,Vector3(0,0.03,0),"b78e53")
    for x in [-0.08,0,0.08]:g.box(root,Vector3(0.018,0.008,0.24),Vector3(x,0.065,0),"e3bf7e")
   else:
    var food:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=0.13;shape.height=0.12
    food.mesh=shape;food.position.y=0.07
    var meat:="carcass" in name_text or "bird" in name_text or "ribs" in name_text or "fish" in name_text or "bacon" in name_text or "lamb" in name_text or "skinned" in name_text
    food.scale.z=1.8 if meat else 1.0
    food.material_override=g.material("9b675b" if meat else ("a9a17b" if "flour" in name_text else "7c9a4e"));root.add_child(food)
    if "fish" in name_text:
     var tail:MeshInstance3D=g.box(root,Vector3(0.14,0.025,0.10),Vector3(0,0.07,0.24),"888c7f");tail.rotation.y=PI/4
  "resource":
   for i in 3:g.crafted_box(root,Vector3(0.11,0.055,0.10),Vector3(-0.09+i*0.08,0.027+(i%2)*0.04,0.04*(i%2)),"b6a36a" if "coin" in name_text or "gem" in name_text else "706c62")
  "symbol":
   if "icicle" in name_text:
    var point:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=0.1;cone.bottom_radius=0.005;cone.height=0.65
    point.mesh=cone;point.position.y=0.325;point.material_override=g.material("c3dce0");root.add_child(point)
    return root
   if name_text=="snow":
    g.box(root,Vector3(1,0.025,1),Vector3(0,0.012,0),"d7e2dd")
    return root
   for i in 5:
    var part:MeshInstance3D=g.box(root,Vector3(0.48,0.006,0.018),Vector3(0,0.007,0),"987348");part.rotation.y=i*TAU/5
 return root
