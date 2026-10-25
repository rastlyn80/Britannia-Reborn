extends RefCounted
# Original geometry, selected from native graphic IDs and exported server types.
# Shared by world objects and the inventory preview; no client art is copied.
static func variant(id: int, rule: Dictionary = {}) -> String:
 var type := str(rule.get("type",""))
 if "Checker" in type and type != "CheckerBoard": return "checkers"
 if type.begins_with("Piece"): return "chessmen"
 if str(rule.get("display_name","")) == "book": return "book"
 if type == "Jug": return "jug"
 if type == "BeverageBottle" or id in [0x99b,0x99c,0x99f,0x9a0,0x9c7]: return "bottle"
 if id in [0x9c8,0x9c9]: return "jug"
 if type == "Dices" or id == 0xfa7: return "dice"
 if id in [4092,4093,4094]: return "skull_mug"
 if type == "PewterMug": return "mug"
 if id in [4030,4081,4082,4083,4084] or "Book" in type and not "Bookcase" in type: return "book"
 if id == 4032: return "ink"
 if id in [3603,3604]: return "chessmen"
 if id in [3608,3609]: return "cards"
 if id in [3610,3611]: return "checkers"
 if id == 5453: return "water_barrel"
 if type == "BulletinBoard": return "noticeboard"
 if id in [4761,4766]: return "street_sign"
 if type == "Backgammon": return "backgammon"
 return str(rule.get("family","unknown"))

static func small(root: Node3D, g: RefCounted, kind: String, id: int) -> Vector3:
 root.set_meta("appearance",kind)
 match kind:
  "book":
   var cover: String = ["644e37","4b665b","804c42","465d78"][id%4]
   for y in [0.012,0.075]: g.crafted_box(root,Vector3(0.24,0.018,0.32),Vector3(0,y,0),cover)
   g.box(root,Vector3(0.215,0.048,0.295),Vector3(0,0.044,0),"dfd4af")
   g.crafted_box(root,Vector3(0.025,0.08,0.32),Vector3(-0.115,0.04,0),cover)
   for z in [-0.1,0.1]: g.box(root,Vector3(0.02,0.012,0.035),Vector3(-0.12,0.083,z),"c1a56d")
   return Vector3(0.24,0.09,0.32)
  "bottle","jug","mug","skull_mug":
   var jug := kind == "jug"
   var mug := kind in ["mug","skull_mug"]
   var radius := 0.11 if jug else 0.065
   var height := 0.20 if mug else (0.23 if jug else 0.19)
   g.cylinder(root,radius,height,Vector3(0,height/2,0),"9d7750" if jug else ("aaa591" if mug else "45634c"))
   if not mug:
    g.cylinder(root,radius*0.48,0.09,Vector3(0,height+0.035,0),"9d7750" if jug else "45634c")
    g.cylinder(root,radius*0.58,0.022,Vector3(0,height+0.085,0),"b08a55")
   else:
    g.cylinder(root,radius*1.05,0.014,Vector3(0,height,0),"c6bfab")
    g.cylinder(root,radius*0.83,0.003,Vector3(0,height+0.008,0),"4d3422")
   if jug or mug:
    var handle := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.04
    torus.outer_radius = 0.06
    handle.mesh = torus
    handle.material_override = g.material("9d7750" if jug else "aaa591")
    handle.rotation.x = PI/2
    handle.position = Vector3(radius,0.12,0)
    root.add_child(handle)
   if kind == "skull_mug":
    g.crafted_box(root,Vector3(0.12,0.13,0.035),Vector3(0,0.11,0.055),"d4c8ac")
    for x in [-0.032,0.032]: g.box(root,Vector3(0.028,0.033,0.008),Vector3(x,0.135,0.078),"3a3530")
    for x in [-0.035,0,0.035]: g.box(root,Vector3(0.008,0.027,0.008),Vector3(x,0.06,0.078),"766b59")
   return Vector3(radius*2.8,height+0.1,radius*2)
  "dice":
   for i in 2:
    var at := Vector3(-0.06+i*0.13,0.045,0.02*i)
    g.crafted_box(root,Vector3.ONE*0.085,at,"e7dcc2")
    for dot in i+2: g.cylinder(root,0.007,0.002,at+Vector3(-0.02+dot*0.017,0.044,-0.02+dot*0.017),"292c2c")
   return Vector3(0.25,0.09,0.14)
  "ink":
   g.cylinder(root,0.045,0.06,Vector3(0,0.03,0),"353335")
   var quill: MeshInstance3D = g.crafted_box(root,Vector3(0.02,0.25,0.009),Vector3(0.03,0.16,0),"e5d9b5")
   quill.rotation.z = -0.4
   return Vector3(0.14,0.30,0.12)
  "cards","checkers","chessmen":
   for i in 3:
    var at := Vector3(-0.08+i*0.08,0.014,0.03*(i%2))
    if kind == "cards":
     g.box(root,Vector3(0.065,0.008,0.095),at,"e3d7b5")
     g.box(root,Vector3(0.025,0.003,0.04),at+Vector3.UP*0.006,"854b45")
    else:
     g.cylinder(root,0.035,0.022,at,"303130" if i%2 else "c5ad7e")
     if kind == "chessmen": g.cylinder(root,0.016,0.09,at+Vector3.UP*0.05,"303130" if i%2 else "c5ad7e")
   return Vector3(0.27,0.13,0.18)
  "unknown":
   # Visible, deliberately neutral fallback. Never misrepresent an unknown ID as a cup.
   g.crafted_box(root,Vector3(0.12,0.08,0.12),Vector3(0,0.04,0),"777b7c")
   return Vector3(0.12,0.08,0.12)
 return Vector3.ZERO
