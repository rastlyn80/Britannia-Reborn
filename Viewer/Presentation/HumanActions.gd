extends RefCounted
## Human-only native action families. Unsupported requests remain explicit.
const CLASSIC := {0:"Walk",1:"Sword_Walk",2:"Run",3:"Sword_Run",4:"Idle",7:"Sword_Idle",8:"Sword_Idle",9:"Sword_A",10:"Punch_Jab",11:"Punch_Cross",12:"Heavy_Attack",13:"Sword_B",14:"Sword_C",15:"Sword_Walk",16:"Cast",17:"Cast",20:"Hit",21:"Death",22:"Death",31:"Punch_Jab",32:"Bow"}
static func resolve(request: Dictionary) -> String:
	if int(request.get("body",0)) not in [400,401]: return ""
	if str(request.get("protocol",""))=="classic": return str(CLASSIC.get(int(request.get("action",-1)),""))
	if str(request.get("protocol",""))!="new": return ""
	# 0xe2 contains type/subaction/variation, not classic frame timing. The
	# sender's historical parameter names are misleading; keep the raw aliases.
	var kind:=int(request.get("type",request.get("action",-1)))
	var action:=int(request.get("subaction",request.get("frames",0)))
	match kind:
		0:
			return str({0:"Punch_Jab",3:"Punch_Cross",4:"Sword_A",5:"Punch_Jab",6:"Heavy_Attack",7:"Sword_B",8:"Sword_C"}.get(action,""))
		3: return "Death"
		4: return "Hit"
		11: return "Cast"
	return ""
static func duration(request: Dictionary, authored: float) -> float:
	if str(request.get("protocol",""))!="classic" or int(request.get("frames",0))<=0: return authored
	# ClassicUO's native frame interval: 80ms + 80ms * (delay + 1).
	return maxf(.02,float(request.frames)*.08*(int(request.get("delay",0))+2))
static func gait(speed: float, previous: String = "") -> String:
	if speed>(6.3 if previous.ends_with("Sprint") else 6.8): return "Sprint"
	if speed>(3.6 if previous.ends_with("Run") else 3.9): return "Run"
	if speed>(1.35 if previous.ends_with("Jog") else 1.6): return "Jog"
	return "Walk"
static func locomotion(name: String) -> bool:
	return name in ["Walk","Jog","Run","Sprint"] or name in ["Sword_Walk","Sword_Jog","Sword_Run","Sword_Sprint","Unarmed_Walk","Unarmed_Jog","Unarmed_Run","Unarmed_Sprint"]
