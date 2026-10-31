extends RefCounted
# Action timers (owner requirement): each kind of action waits its turn,
# as ModernUO enforces it, and the quickbar shows the wait on every slot of
# that kind. The protocol carries no cooldown packet, so the durations are
# ModernUO's own (pinned source): one shared skill timer with each skill's
# delay (Server/Skills.cs, UOContent/Skills/*.cs), spells' cast delay by
# circle plus cast recovery (Spell.cs, MagerySpell.cs), bandage time by dex
# (Bandage.cs) and heal potion delays (Heal Potions/*.cs). The server's
# "you must wait" messages correct a timer that ran out too early.
# With our server extension (Server/PreviewTools/ActionTimers.cs) the server
# reports its own timers, whatever started the action (quickbar, spellbook,
# skills window, a double-clicked bandage), and those replace the estimates.
const SKILLS := {"Anatomy":1.0,"Animal Lore":1.0,"Arms Lore":1.0,"Cartography":1.0,"Evaluating Intelligence":1.0,"Forensic Evaluation":1.0,
	"Item Identification":1.0,"Taste Identification":1.0,"Inscription":1.0,"Hiding":10.0,"Stealth":10.0,"Tracking":10.0,"Poisoning":10.0,
	"Remove Trap":10.0,"Meditation":10.0,"Spirit Speak":5.0,"Peacemaking":10.0,"Provocation":10.0,"Discordance":12.0,"Detect Hidden":30.0,
	"Animal Taming":30.0,"Begging":30.0,"Stealing":30.0}
const LABELS := {"skill":"Skills","spell":"Spells","bandage":"Bandages","heal_potion":"Heal potions"}
# Server messages that mean "too soon" for a kind, and the wait they imply.
const TOO_SOON := {500118:["skill",2.0],502644:["spell",1.0],500119:["skill",2.0],500235:["heal_potion",2.0]}
var timers := {}
var labels: RefCounted

static func kind_of(step: Dictionary) -> String:
	match str(step.get("action","")):
		"Use Skill", "Last Skill": return "skill"
		"Cast Spell", "Last Spell": return "spell"
		"Bandage Self", "Bandage Target": return "bandage"
		"Use Potion": return "heal_potion" if str(step.get("option","")) == "Heal" else ""
	return ""

static func skill_delay(skill: String) -> float: return float(SKILLS.get(skill,10.0))

# Magery circle 1-8 from the spell id: cast delay (3+circle-1)*0.25 s plus
# the base cast recovery of 6/4 s; other schools use the middle circle.
static func spell_delay(spell_id: int) -> float:
	var circle := (spell_id-1)/8 if spell_id >= 1 and spell_id <= 64 else 4
	return (3+circle)*0.25+1.5

static func bandage_delay(on_self: bool, dex: int) -> float:
	if on_self: return 5.0+0.5*float(120-dex)/10.0
	return 0.7 if dex >= 204 else 3.2-sin(float(dex)/130.0)*2.5

static func potion_delay(name: String) -> float:
	var lower := name.to_lower()
	if "greater" in lower: return 10.0
	if "lesser" in lower: return 3.0
	return 8.0

func start(kind: String, seconds: float) -> void:
	if kind == "" or seconds <= 0.0: return
	var now := Time.get_ticks_msec()
	timers[kind] = {"start":now,"end":now+int(seconds*1000.0)}

func remaining(kind: String) -> float:
	if not timers.has(kind): return 0.0
	# A held lock never reads ready before the server says so.
	if timers[kind].get("held",false) and int(timers[kind].end) < Time.get_ticks_msec()+300: timers[kind].end = Time.get_ticks_msec()+300
	return maxf(0.0,(int(timers[kind].end)-Time.get_ticks_msec())/1000.0)

# Share of the wait still to go (1 just started, 0 ready).
func fraction(kind: String) -> float:
	if not timers.has(kind): return 0.0
	var total := maxf(1.0,float(int(timers[kind].end)-int(timers[kind].start)))
	return clampf((int(timers[kind].end)-Time.get_ticks_msec())/total,0.0,1.0)

# The server's own wait for a kind: the countdown restarts from its value
# (a fresh action keeps its full length on the dial), 0 clears it, and -1
# (a held lock, e.g. heal potions) keeps the estimate running until 0.
func server(kind: String, milliseconds: int) -> void:
	if not kind in LABELS: return
	if milliseconds == 0:
		timers.erase(kind)
	elif milliseconds < 0:
		if remaining(kind) < 0.5: start(kind,8.0)
		timers[kind].held = true
	else:
		var now := Time.get_ticks_msec()
		var begun := int(timers[kind].start) if timers.has(kind) and remaining(kind) > 0.0 else now
		timers[kind] = {"start":begun,"end":now+milliseconds}

# A server message saying it is too soon: keep (or restart) that kind's wait.
func hear(text: String) -> void:
	if labels == null: return
	for number in TOO_SOON:
		if text == labels.resolve(number):
			var entry: Array = TOO_SOON[number]
			if remaining(entry[0]) < float(entry[1]): start(entry[0],float(entry[1]))
