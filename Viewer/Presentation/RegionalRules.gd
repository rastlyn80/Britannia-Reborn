extends RefCounted
# Original semantic rules shared by converter and renderer. Existing audited ID
# rules take precedence. No artwork, input geography or tiledata is distributed.
const MODELS := [
 ["globe","globe"],
 ["vase","vase"],
 ["anvil","anvil"],
 ["container","crate|safe|vault|armoire|dresser|backpack|bag|pouch|basket|sack|keg|barrel"],
 ["shelf","bookcase|bookshelf|booksh|wooden shelf|peg board"],
 ["chair","chair|stool|throne|music stand|wig stand"],
 ["display_case","display case"],
 ["fountain","fountain|water trough|water tub|wash basin|spittoon"],
 ["cannon","cannon$|cannon ramrod|cannon swab"],
 ["statue","statue|sculpture|bust|horse$|virtue_scal"],
 ["grave","gravestone|grave$|pedestal|hitching post"],
 ["fabric","banner|tapestr|curtain|pillow|hide|cloth|leather|wool|cotton|flax|saddle|horse barding|apron|cloak|skirt|shirt|pants|leggings|gloves|boots|sandals|shoes|hat$|coif|tunic"],
 ["painting","painting|portrait|wall map|floor.*mirro|floormirror|easel"],
 ["lamp","torch|sconce|candle|candelabra|brazier|lantern|lamp post|lantern post"],
 ["hearth","forge|oven|stove|fireplace|fire pit|campfire|cauldron|heating stand|rabbit on a spit"],
 ["training","trainingdummy|training dummy"],
 ["music","harpsichord|harp$|lute|drum|tambourine"],
 ["ship","anchor|winch|spyglass|rope|pier|ladder"],
 ["book","book|deed|scroll|voyage scr|map$|ship plans|cards|checkers|chess"],
 ["bottle","bottle|flask|vial|jar|potion|machine coffee|coffee grinder"],
 ["cup","goblet|mug|pitcher|glass|jugs|bucket|pot$|tray|plate|bowl|flour sifter"],
 ["weapon","weapon|shield|sword|axe|dagger|knife|cleaver|crossbow|bow$|mace|maul|hammer|staff|wand|armor|platemail|plate helm|ringmail|chainmail|studded|whip"],
 ["tool","tool|silverware|saw|scissors|quill|pen and ink|inshave|plane$|tongs|brush|rolling pin|moulding board|clock|hourglass|springs|gears|wire|nails|arrow|bolts|horse shoes|sewing kit"],
 ["food","bread|cheese|cookie|cake|food|fish|bird|carcass|lamb|ribs|goat|deer|chicken|donut|honey|flour|dough|sausage|stew|limes|onion|cabbage|squash|corn|carrot|bacon|pie|muffin|spam|fruit|nest with eggs"],
 ["resource","ore|ingot|metal|iron|gem|rub%|amethyst|emerald|diamond|sapphire|citrine|tourmaline|amber|crystal|blackroc|pearl|blood|moss|reagent|nightshade|mandrake|ash|silk|batwing|feather|shell|conch|nautilus|jewel|necklace|bracelet|beads|ring$|earrings|coin|bones|skull|cannon balls|wood curls|stump|wood$|boards$|hay|wheat|woodworker|muck"],
 ["symbol","pentagram|alchemical|rune|humility|sacrifice|valor|compassion|spirituality|justice|honor|honesty|bell of courage|serpent crest|spiderweb|fire$|lava|icicle|snow$"]
]
static func resolve(id: int,info: Dictionary) -> Dictionary:
 var n := str(info.get("name","")).strip_edges().to_lower()
 var height := int(info.get("height",0))
 var base := {"axis":"x","confidence":"semantic 3D substitute; orientation inferred from source topology","regional":true}
 if n in ["no draw","nodraw","light"]:
  return base.merged({"kind":"invisible","reason":"native authoring/no-draw marker"})
 if n=="town_cryer": return base.merged({"kind":"prop","model":"newspaper","confidence":"local visual inspection: printed news sheet"})
 if id==13040: return base.merged({"kind":"asset","asset":"Nature/Rock_Medium_1.gltf","dimensions":[0.65,3.0,0.65],"confidence":"local visual inspection: tall crag fragment"})
 if id==7185: return base.merged({"kind":"prop","model":"gem","confidence":"local visual inspection: faceted blue ornament"})
 if n.is_empty():
  # Legacy rug components have empty tiledata labels; retain source modules.
  if id>=2787 and id<=2810: return base.merged({"kind":"carpet"})
  return {}
 # "wall torch", "wall sconce" and "wall map" name things hung on a wall.
 if n.begins_with("wall ") and n!="wall map": return base.merged({"kind":"prop","model":"wall_light" if "torch" in n or "sconce" in n else "painting","mount":"wall"})
 if "wall map" in n: return base.merged({"kind":"prop","model":"painting","mount":"wall"})
 if "wall" in n or n in ["window","arrow loop","battlement"]:
  return base.merged({"kind":"window" if n in ["window","arrow loop"] else ("trim" if height<15 else "wall"),"asset":"Village/Wall_UnevenBrick_Straight.gltf" if "stone" in n or "brick" in n else "Village/Wall_Plaster_Straight.gltf"})
 if "arch" in n and n not in ["arcanist statue"]: return base.merged({"kind":"arch","asset":"Village/Wall_Arch.gltf"})
 if "stairs" in n or n in ["stone step","carpeted stair"]: return base.merged({"kind":"stairs","rise":[0,-1]})
 if n in ["stone","marble","platform"]: return base.merged({"kind":"landing"})
 if "roof" in n or "shingle" in n: return base.merged({"kind":"roof","material":"thatch" if "thatch" in n else ("stone" if "stone" in n else ("clay" if "tile" in n else "slate")),"rise":[0,0],"ridgeAxis":"x","profile":"flat" if height==0 else "slope","anchorOffset":[-1,-1]})
 if n in ["cobblestones","stone pavers","stone pavers dark","marble floor","flagstones","wooden planks","wooden plank","wooden boards","wooden bridge"]: return base.merged({"kind":"floor","surface":"wood" if "wood" in n else "stone"})
 if "rug" in n or "carpet" in n: return base.merged({"kind":"carpet"})
 if "bench" in n: return base.merged({"kind":"bench"})
 # Legacy "bar" art is a panelled serving counter, not a rail.
 if "table" in n or n in ["counter","bar"]: return base.merged({"kind":"counter" if n in ["counter","bar"] else "table"})
 if n=="bed" or n=="cot": return base.merged({"kind":"bed","asset":"Kenney/bedSingle.glb"})
 if "fence" in n or "banister" in n: return base.merged({"kind":"fence","asset":"Village/Prop_WoodenFence_Single.gltf"})
 if "signpost" in n: return base.merged({"kind":"sign"})
 if "column" in n or "pillar" in n or "buttress" in n or n=="stone post": return base.merged({"kind":"pillar"})
 if "post" in n or n=="wooden beam": return base.merged({"kind":"beam" if n=="wooden beam" else "post","asset":"Village/Prop_Support.gltf"})
 if n=="chimney": return base.merged({"kind":"asset","asset":"Village/Prop_Chimney.gltf","dimensions":[0.7,maxf(0.4,height*0.2),0.7]})
 if "leaves" in n or "needles" in n: return base.merged({"kind":"canopy","asset":"Nature/CommonTree_1.gltf"})
 if "tree" in n or "sapling" in n or n=="tuscany pine": return base.merged({"kind":"tree","asset":"Nature/Pine_1.gltf" if "pine" in n else ("Nature/DeadTree_1.gltf" if "spider" in n else "Nature/CommonTree_1.gltf")})
 if "mushroom" in n: return base.merged({"kind":"mushroom","asset":"Nature/Mushroom_Common.gltf"})
 if "flower" in n or n in ["snowdrops","red poppies","rose of trinsic"]: return base.merged({"kind":"flower","asset":"Nature/Flower_4_Group.gltf"})
 if "grass" in n or n in ["weed","rushes","cattails"]: return base.merged({"kind":"grass","asset":"Nature/Grass_Common_Short.gltf"})
 if "bush" in n or n in ["hedge","vines","vanillaplantmedium s","vanillaplantlarge so"]: return base.merged({"kind":"bush","asset":"Nature/Bush_Common.gltf"})
 if n in ["rock","rocks","boulder"]: return base.merged({"kind":"rock","asset":"Nature/Rock_Medium_2.gltf"})
 if n in ["fallen log","logs","fallen branch"]: return base.merged({"kind":"log","asset":"Village/Roof_Log.gltf"})
 if n=="water": return base.merged({"kind":"water"})
 for model in MODELS:
  var regex := RegEx.new()
  regex.compile(str(model[1]))
  if regex.search(n): return base.merged({"kind":"prop","model":model[0]})
 return {}
static func extend(world: Dictionary,catalog: Dictionary) -> void:
 if not world.get("staticData") is Dictionary:return
 for key in world.staticData:
  if catalog.has(key): continue
  var rule:=resolve(int(key),world.staticData[key])
  if not rule.is_empty(): catalog[key]=rule
 # Vote from source adjacency rather than guessing an axis from an arbitrary ID.
 var cells: Dictionary={}
 for s in world.statics:
  var key:=Vector2i(s.x,s.y)
  if not cells.has(key): cells[key]=[]
  cells[key].append(s)
 var votes: Dictionary={}
 var corner_hits:Dictionary={}
 var occurrences:Dictionary={}
 for s in world.statics:
  var rule: Dictionary=catalog.get(str(int(s.id)),{})
  if not rule.get("regional",false) or rule.get("kind","") not in ["wall","window","trim","arch","fence","beam","roof"]: continue
  var key:=str(int(s.id))
  occurrences[key]=int(occurrences.get(key,0))+1
  var directions:Dictionary={}
  if not votes.has(str(int(s.id))): votes[str(int(s.id))]=Vector2.ZERO
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   for other in cells.get(Vector2i(s.x,s.y)+offset,[]):
    var next: Dictionary=catalog.get(str(int(other.id)),{})
    if rule.kind=="roof" and next.get("kind","")!="roof":continue
    if rule.kind!="roof" and next.get("kind","") not in (["wall","window","trim","arch","beam"] if rule.kind!="fence" else ["fence"]):continue
    if rule.kind=="roof":
     var dz:=int(other.z)-int(s.z)
     if abs(dz)>0 and abs(dz)<=3: votes[str(int(s.id))]+=Vector2(offset)*signf(dz)
    elif abs(int(other.z)-int(s.z))<=1:
     votes[str(int(s.id))]+=Vector2(abs(offset.x),abs(offset.y))
     directions[offset]=true
  if rule.kind=="wall" and directions.size()==2:
   var x_axis:=false
   var y_axis:=false
   for offset in directions:
    if offset.x!=0:x_axis=true
    if offset.y!=0:y_axis=true
   if x_axis and y_axis:corner_hits[key]=int(corner_hits.get(key,0))+1
 for key in votes:
  var vote: Vector2=votes[key]
  var rule: Dictionary=catalog[key]
  if rule.kind=="wall" and int(corner_hits.get(key,0))>=ceili(float(occurrences[key])*0.7):
   rule.kind="corner"
   rule.confidence="semantic 3D stonework; perpendicular source neighbors identify a joined corner"
  rule.axis="y" if absf(vote.y)>absf(vote.x) else "x"
  if rule.kind=="roof" and vote.length_squared()>0:
   rule.rise=[0,int(signf(vote.y))] if absf(vote.y)>absf(vote.x) else [int(signf(vote.x)),0]
