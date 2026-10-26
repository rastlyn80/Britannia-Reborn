extends RefCounted

# Native graphic parity provides a fallback. Facade topology determines which
# side faces the street; no town-specific coordinates or changed source XYZ.
static func layout(item: Dictionary,world: Dictionary,catalog: Dictionary) -> Dictionary:
 var axis := "x" if int(item.id)%2 else "z"
 var best := INF
 var wall := Vector2(float(item.x),float(item.y))
 for source in world.statics:
  var rule: Dictionary = catalog.get(str(int(source.id)),{})
  if rule.get("kind","") not in ["wall","window"]: continue
  var delta := Vector2(float(item.x-source.x),float(item.y-source.y))
  if absf(float(source.z-item.z))>22 or delta.length_squared()>9: continue
  var score := delta.length_squared()
  if score < best:
   best = score
   axis = str(rule.get("axis","x"))
   wall = Vector2(source.x,source.y)
 var sign_at := Vector2(item.x,item.y)
 var outward := Vector2(0,1) if axis=="x" else Vector2(1,0)
 if (sign_at-wall).dot(outward)<0: outward = -outward
 var yaw := atan2(-outward.y,outward.x)
 return {"mount":wall-sign_at+outward*0.12,"yaw":yaw,"reach":0.62,"axis":axis,"source":Vector3i(item.x,item.y,item.z)}
