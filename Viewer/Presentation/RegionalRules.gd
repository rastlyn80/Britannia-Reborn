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
 ["cup","goblet|mug|pitcher|glass|jugs|bucket|pot$|tray|^plate$|plate of|bowl|flour sifter"],
 ["weapon","weapon|shield|sword|axe|dagger|knife|cleaver|crossbow|bow$|mace|maul|hammer|staff|wand|armor|platemail|plate helm|ringmail|chainmail|studded|whip"],
 ["tool","tool|silverware|saw|scissors|quill|pen and ink|inshave|plane$|tongs|brush|rolling pin|moulding board|clock|hourglass|springs|gears|wire|nails|arrow|bolts|horse shoes|sewing kit"],
 ["food","bread|cheese|cookie|cake|food|fish|bird|carcass|lamb|ribs|goat|deer|chicken|donut|honey|flour|dough|sausage|stew|limes|onion|cabbage|squash|corn|carrot|bacon|pie|muffin|spam|fruit|nest with eggs"],
 ["resource","ore|ingot|metal|iron|gem|rub%|amethyst|emerald|diamond|sapphire|citrine|tourmaline|amber|crystal|blackroc|pearl|blood|moss|reagent|nightshade|mandrake|ash|silk|batwing|feather|shell|conch|nautilus|jewel|necklace|bracelet|beads|ring$|earrings|coin|bones|skull|cannon balls|wood curls|stump|wood$|boards$|hay|wheat|woodworker|muck"],
 ["symbol","pentagram|alchemical|rune|humility|sacrifice|valor|compassion|spirituality|justice|honor|honesty|bell of courage|serpent crest|spiderweb|fire$|lava|icicle|snow$"]
]
const Facade := preload("res://Presentation/Facade.gd")
static var FLOOR := _regex("floor|tiles?$|^tile|paver|flagstone|cobble|slate tile|blacktile|blue tiles|^marble$|^sandstone$")
static var LAVA := _regex("^(lava|acid|slime)( |$)|lava$")
static var TROPICAL := _regex("blade plant|fan plant|elephant ear|snake plant|ponytail palm|agave|water plants|century plant|bamboo plant|small palm|banana|yucca")
static var WATER_PLANT := _regex("lil+y ?pads?|water lil|water plant|seaweed|kelp|algae")

static func _regex(pattern: String) -> RegEx:
 var regex := RegEx.new()
 regex.compile(pattern)
 return regex

static func roof_material(n: String) -> String:
 if "thatch" in n: return "thatch"
 if "palm" in n or "frond" in n or "leaf" in n or "reed" in n: return "palm"
 if "tent" in n: return "tent"
 if "marble" in n: return "marble"
 if "stone" in n or "slate" in n and not "tile" in n: return "stone" if "stone" in n else "slate"
 if "tile" in n or "ceramic" in n or "clay" in n: return "clay"
 if "shingle" in n or "log" in n or "wood" in n: return "shingle"
 return "slate"

static func resolve(id: int,info: Dictionary) -> Dictionary:
 var n := str(info.get("name","")).strip_edges().to_lower()
 var height := int(info.get("height",0))
 var base := {"axis":"x","confidence":"semantic 3D substitute; orientation inferred from source topology","regional":true}
 if n in ["no draw","nodraw","light"]:
  return base.merged({"kind":"invisible","reason":"native authoring/no-draw marker"})
 if n=="town_cryer": return base.merged({"kind":"prop","model":"newspaper","confidence":"local visual inspection: printed news sheet"})
 if id==13040: return base.merged({"kind":"asset","asset":"Nature/Rock_Medium_1.gltf","dimensions":[0.65,3.0,0.65],"confidence":"local visual inspection: tall crag fragment"})
 if id==7185: return base.merged({"kind":"prop","model":"gem","confidence":"local visual inspection: faceted blue ornament"})
 var flags := int(info.get("flags",0))
 if n.is_empty():
  # Legacy rug components have empty tiledata labels; retain source modules.
  if id>=2787 and id<=2810: return base.merged({"kind":"carpet"})
  return {}
 if "cloud" in n: return base.merged({"kind":"invisible","reason":"sky decoration above the play area"})
 if "floor" in n and height<=2: return base.merged({"kind":"floor","surface":Facade.surface_for(n)})
 if n in ["bricks","brick"]: return base.merged({"kind":"floor","surface":"brick"} if height<=2 else {"kind":"landing"})
 if n=="waterfall": return base.merged({"kind":"waterfall"})
 if "cactus" in n: return base.merged({"kind":"cactus"})
 # "wall torch", "wall sconce" and "wall map" name things hung on a wall.
 if n.begins_with("wall ") and n!="wall map": return base.merged({"kind":"prop","model":"wall_light" if "torch" in n or "sconce" in n else "painting","mount":"wall"})
 if "wall map" in n: return base.merged({"kind":"prop","model":"painting","mount":"wall"})
 if "wall" in n or n in ["window","arrow loop","battlement"]:
  return base.merged({"kind":"window" if n in ["window","arrow loop"] else ("trim" if height<15 else "wall"),"asset":"Village/Wall_UnevenBrick_Straight.gltf" if "stone" in n or "brick" in n else "Village/Wall_Plaster_Straight.gltf"})
 if "arch" in n and n not in ["arcanist statue"]: return base.merged({"kind":"arch","asset":"Village/Wall_Arch.gltf"})
 if "stairs" in n or n in ["stone step","carpeted stair"]: return base.merged({"kind":"stairs","rise":[0,-1]})
 if n in ["stone","marble","platform","sandstone","eodon","white marble","gold stone","blue marble"]: return base.merged({"kind":"landing"})
 if "ruin" in n and not "statue" in n: return base.merged({"kind":"trim" if height<15 else "wall","asset":"Village/Wall_UnevenBrick_Straight.gltf"})
 if n=="wooden logs" and height<=3: return base.merged({"kind":"floor","surface":"wood"})
 # Tiledata Roof flag covers frond, leaf and tent roofs whose names omit "roof".
 if "roof" in n or "shingle" in n or (flags & 0x10000000 and not "leaves" in n and not "grass" in n): return base.merged({"kind":"roof","material":roof_material(n),"rise":[0,0],"ridgeAxis":"x","profile":"flat" if height==0 else "slope","anchorOffset":[-1,-1]})
 if n in ["cobblestones","stone pavers","stone pavers dark","marble floor","flagstones","wooden planks","wooden plank","wooden boards","wooden bridge"] or (height<=2 and FLOOR.search(n)): return base.merged({"kind":"floor","surface":Facade.surface_for(n)})
 # Only animated/damaging lava is molten; the rest is cooled black flow rock.
 if LAVA.search(n):
  if flags & 0x1000020: return base.merged({"kind":"lava","tint":"acid" if "acid" in n or "slime" in n else "lava"})
  return base.merged({"kind":"floor","surface":"basalt"} if height<=2 else {"kind":"rock","asset":"Nature/Rock_Medium_3.gltf"})
 if n in ["hover over","hoverover"]: return base.merged({"kind":"invisible","reason":"native movement helper"})
 if n in ["swamp","water"]: return base.merged({"kind":"water"})
 # Raised flower beds are stone planters that flowers and trees stand on.
 if n.replace(" ","").begins_with("flowerbed"): return base.merged({"kind":"planter"})
 if "rug" in n or "carpet" in n: return base.merged({"kind":"carpet"})
 if "bench" in n: return base.merged({"kind":"bench"})
 # Legacy "bar" art is a panelled serving counter, not a rail.
 if "table" in n or n in ["counter","bar"]: return base.merged({"kind":"counter" if n in ["counter","bar"] else "table"})
 if n=="bed" or n=="cot": return base.merged({"kind":"bed","asset":"Kenney/bedSingle.glb"})
 if n=="wooden fence": return base.merged({"kind":"fence","asset":"MedievalKit/Fence_2m.gltf"})
 if "fence" in n or "banister" in n: return base.merged({"kind":"fence","asset":"Village/Prop_MetalFence_Simple.gltf" if "iron" in n or "metal" in n else "Village/Prop_WoodenFence_Single.gltf"})
 if "signpost" in n: return base.merged({"kind":"sign"})
 if "column" in n or "pillar" in n or "buttress" in n or n=="stone post": return base.merged({"kind":"pillar"})
 if n in ["lamp post","lantern post"]: return base.merged({"kind":"asset","asset":"MedievalKit/Lantern_Post.gltf","dimensions":[0.6,2.7,0.3]})
 if "sack of flour" in n: return base.merged({"kind":"asset","asset":"MedievalKit/"+("Sack_Open" if "open" in n else "Sack")+".gltf","dimensions":[0.6,0.73,0.54]})
 if "post" in n or n=="wooden beam": return base.merged({"kind":"beam" if n=="wooden beam" else "post","asset":"Village/Prop_Support.gltf"})
 if n=="chimney": return base.merged({"kind":"chimney"})
 # Height-0 "leaves" are fallen leaf litter on the ground, not a canopy.
 if ("leaves" in n or "needles" in n) and height==0: return base.merged({"kind":"litter"})
 if "palisade" in n: return base.merged({"kind":"palisade"})
 if "leaves" in n or "needles" in n or "palm frond" in n and height>0: return base.merged({"kind":"canopy","asset":"Nature/CommonTree_1.gltf"})
 if "fern" in n: return base.merged({"kind":"fern","asset":"Nature/Fern_1.gltf"})
 if TROPICAL.search(n): return base.merged({"kind":"plant","asset":"Nature/Plant_1_Big.gltf"})
 if "palm" in n or n in ["yew tree"]: return base.merged({"kind":"tree","asset":"Nature/Pine_1.gltf"})
 if "tree" in n or "sapling" in n or n=="tuscany pine": return base.merged({"kind":"tree","asset":"Nature/Pine_1.gltf" if "pine" in n else ("Nature/DeadTree_1.gltf" if "spider" in n else "Nature/CommonTree_1.gltf")})
 if "mushroom" in n: return base.merged({"kind":"mushroom","asset":"Nature/Mushroom_Common.gltf"})
 if "flower" in n or n in ["snowdrops","red poppies","rose of trinsic"]: return base.merged({"kind":"flower","asset":"Nature/Flower_4_Group.gltf"})
 if n in ["cattails","bulrushes","reeds","wheat","flax"]: return base.merged({"kind":"reeds","asset":"Nature/Grass_Wispy_Tall.gltf"})
 if "grass" in n or n in ["weed","rushes"]: return base.merged({"kind":"grass","asset":"Nature/Grass_Common_Short.gltf"})
 if WATER_PLANT.search(n): return base.merged({"kind":"lilypad"})
 if "vine" in n or "ivy" in n or "morning glor" in n: return base.merged({"kind":"vine","asset":"Village/Prop_Vine1.gltf"})
 if "bush" in n or "hedge" in n or "shrub" in n or "cactus" in n or n in ["vanillaplantmedium s","vanillaplantlarge so"]: return base.merged({"kind":"bush","asset":"Nature/Bush_Common.gltf"})
 if n in ["rock","rocks","boulder","stone","flowstone","rock formation"] or "boulder" in n: return base.merged({"kind":"rock","asset":"Nature/Rock_Medium_2.gltf" if height<8 else "Nature/Rock_Medium_1.gltf"})
 if "stalag" in n: return base.merged({"kind":"stalagmite"})
 if "crystal" in n: return base.merged({"kind":"crystal","scatter":"broken" in n or "shard" in n})
 # A stacked pile of split logs (CC0 MedievalKit woodpile), not a lone trunk.
 if n=="logs": return base.merged({"kind":"asset","asset":"MedievalKit/Woodpile.gltf","dimensions":[1.2,0.6,0.65]})
 if n in ["fallen log","fallen branch","sunken log","wooden logs","log","stump"] or n.ends_with(" stump"): return base.merged({"kind":"log","asset":"Village/Roof_Log.gltf"})
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
