extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open("res://../outputs/britain/atlas.json"):quit(1);return
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.prepare(data)
 var missing:Dictionary={}
 var core_ids:Dictionary={}
 var kinds:Dictionary={}
 for source in plan.world.statics:
  if not Rect2i(1088,1408,704,512).has_point(Vector2i(source.x,source.y)):continue
  core_ids[int(source.id)]=true
  var kind:String=plan.reconstruction.rule_for(source.id).get("kind","unmapped")
  kinds[kind]=int(kinds.get(kind,0))+1
  if plan.reconstruction.rule_for(source.id).is_empty():missing[str(source.id)]=plan.world.staticData.get(str(source.id),{}).get("name","")
 var owned:Dictionary={}
 for chunk in plan.chunks.values():
  for ordinal in chunk:
   if owned.has(ordinal):push_error("Duplicate chunk owner");quit(1);return
   owned[ordinal]=true
 if owned.size()!=int(data.manifest.staticCount):push_error("Static ownership count mismatch");quit(1);return
 print("CITY OWNERSHIP: ",owned.size()," unique source records")
 var rendered:Dictionary={}
 for i in plan.world.statics.size():
  var source:Dictionary=plan.world.statics[i]
  if rendered.has(int(source.id)):continue
  rendered[int(source.id)]=true
  var node:Node3D=plan.reconstruction.build(source,plan.world,i)
  if node:node.free()
 print("REPRESENTATIVE MODELS: ",rendered.size())
 var bindings:Dictionary={}
 for id in core_ids:
  var rule:Dictionary=plan.reconstruction.rule_for(id).duplicate(true)
  if rule.get("kind","")=="prop":rule["implementation"]="CityProps.gd/"+str(rule.model)
  bindings[str(id)]=rule
 var registry:=FileAccess.open("res://../outputs/validation/britain-id-mapping.local.json",FileAccess.WRITE)
 registry.store_string(JSON.stringify({"scope":"LOCAL SOURCE DATA — do not redistribute","rules":bindings},"  "));registry.close()
 var report={"passed":missing.is_empty(),"source_records":owned.size(),"unique_ids":core_ids.size(),"unmapped":missing,"kinds":kinds,"context_records":plan.world.statics.size(),"planning_ms":plan.elapsed_ms,"scope":"Every city graphic has an explicit semantic 3D rule or verified nonvisual marker handling; replacements are stylized substitutes, not exact reproductions of proprietary artwork."}
 var file:=FileAccess.open("res://../outputs/validation/britain-assets.local.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("CITY ASSET AUDIT: ",JSON.stringify(report))
 print("CITY UNMAPPED: ",JSON.stringify(missing))
 quit(0 if missing.is_empty() else 1)
