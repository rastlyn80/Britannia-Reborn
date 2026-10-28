extends RefCounted
# Every classic Ultima Online macro action (the client's Macro Options list,
# as ClassicUO's MacroManager implements it) with its options, grouped for the
# quickbar's slot editor. A slot runs one action or a sequence of them.
# Spell IDs, skill IDs, potion graphics and spellbook types are the values the
# server expects (checked against ModernUO's incoming packet handlers).
const Character = preload("res://Network/CharacterProtocol.gd")

# Magery, by circle; spell ID = index + 1. Reagents: BP black pearl, BM blood
# moss, GA garlic, GS ginseng, MR mandrake root, NS nightshade, SA sulfurous
# ash, SS spider's silk.
const MAGERY := [
	["Clumsy","BM NS"],["Create Food","GA GS MR"],["Feeblemind","GS NS"],["Heal","GA GS SS"],["Magic Arrow","SA"],["Night Sight","SA SS"],["Reactive Armor","GA SA SS"],["Weaken","GA NS"],
	["Agility","BM MR"],["Cunning","MR NS"],["Cure","GA GS"],["Harm","NS SS"],["Magic Trap","GA SS SA"],["Remove Trap","BM SA"],["Protection","GA GS SA"],["Strength","MR NS"],
	["Bless","GA MR"],["Fireball","BP"],["Magic Lock","BM GA SA"],["Poison","NS"],["Telekinesis","BM MR"],["Teleport","BM MR"],["Unlock","BM SA"],["Wall of Stone","BM GA"],
	["Arch Cure","GA GS MR"],["Arch Protection","GA GS MR SA"],["Curse","GA NS SA"],["Fire Field","BP SS SA"],["Greater Heal","GA GS MR SS"],["Lightning","MR SA"],["Mana Drain","BP MR SS"],["Recall","BP BM MR"],
	["Blade Spirits","BP MR NS"],["Dispel Field","BP GA SS SA"],["Incognito","BM GA NS"],["Magic Reflection","GA MR SS"],["Mind Blast","BP MR NS SA"],["Paralyze","GA MR SS"],["Poison Field","BP NS SS"],["Summon Creature","BM MR SS"],
	["Dispel","GA MR SA"],["Energy Bolt","BP NS"],["Explosion","BM MR"],["Invisibility","BM NS"],["Mark","BM BP MR"],["Mass Curse","GA MR NS SA"],["Paralyze Field","BP GS SS"],["Reveal","BM SA"],
	["Chain Lightning","BP BM MR SA"],["Energy Field","BP MR SS SA"],["Flamestrike","SS SA"],["Gate Travel","BP MR SA"],["Mana Vampire","BP BM MR SS"],["Mass Dispel","BP GA MR SA"],["Meteor Swarm","BM MR SS SA"],["Polymorph","BM MR SS"],
	["Earthquake","BM GS MR SA"],["Energy Vortex","BP BM MR NS"],["Resurrection","BM GA GS"],["Air Elemental","BM MR SS"],["Summon Daemon","BM MR SS SA"],["Earth Elemental","BM MR SS"],["Fire Elemental","BM MR SS SA"],["Water Elemental","BM MR SS"],
]
const CIRCLE_MANA := [4,6,9,11,14,20,40,50]
# Words of power, in Magery order.
const WORDS := ["Uus Jux","In Mani Ylem","Rel Wis","In Mani","In Por Ylem","In Lor","Flam Sanct","Des Mani",
	"Ex Uus","Uus Wis","An Nox","An Mani","In Jux","An Jux","Uus Sanct","Uus Mani",
	"Rel Sanct","Vas Flam","An Por","In Nox","Ort Por Ylem","Rel Por","Ex Por","In Sanct Ylem",
	"Vas An Nox","Vas Uus Sanct","Des Sanct","In Flam Grav","In Vas Mani","Por Ort Grav","Ort Rel","Kal Ort Por",
	"In Jux Hur Ylem","An Grav","Kal In Ex","In Jux Sanct","Por Corp Wis","An Ex Por","In Nox Grav","Kal Xen",
	"An Ort","Corp Por","Vas Ort Flam","An Lor Xen","Kal Por Ylem","Vas Des Sanct","In Ex Grav","Wis Quas",
	"Vas Ort Grav","In Sanct Grav","Kal Vas Flam","Vas Rel Por","Ort Sanct","Vas An Ort","Flam Kal Des Ylem","Vas Ylem Rel",
	"In Vas Por","Vas Corp Por","An Corp","Kal Vas Xen Hur","Kal Vas Xen Corp","Kal Vas Xen Ylem","Kal Vas Xen Flam","Kal Vas Xen An Flam"]
const REAGENTS := {"BP":[0x0F7A,"Black Pearl"],"BM":[0x0F7B,"Blood Moss"],"GA":[0x0F84,"Garlic"],"GS":[0x0F85,"Ginseng"],"MR":[0x0F86,"Mandrake Root"],"NS":[0x0F88,"Nightshade"],"SA":[0x0F8C,"Sulfurous Ash"],"SS":[0x0F8D,"Spider's Silk"]}
# Other schools: [first spell ID, spellbook type for "open", names].
const SCHOOLS := {
	"Magery":[1,1,[]],
	"Necromancy":[101,2,["Animate Dead","Blood Oath","Corpse Skin","Curse Weapon","Evil Omen","Horrific Beast","Lich Form","Mind Rot","Pain Spike","Poison Strike","Strangle","Summon Familiar","Vampiric Embrace","Vengeful Spirit","Wither","Wraith Form","Exorcism"]],
	"Chivalry":[201,3,["Cleanse by Fire","Close Wounds","Consecrate Weapon","Dispel Evil","Divine Fury","Enemy of One","Holy Light","Noble Sacrifice","Remove Curse","Sacred Journey"]],
	"Bushido":[401,5,["Honorable Execution","Confidence","Evasion","Counter Attack","Lightning Strike","Momentum Strike"]],
	"Ninjitsu":[501,4,["Focus Attack","Death Strike","Animal Form","Ki Attack","Surprise Attack","Backstab","Shadowjump","Mirror Image"]],
	"Spellweaving":[601,6,["Arcane Circle","Gift of Renewal","Immolating Weapon","Attunement","Thunderstorm","Nature's Fury","Summon Fey","Summon Fiend","Reaper Form","Wildfire","Essence of Wind","Dryad Allure","Ethereal Voyage","Word of Death","Gift of Life","Arcane Empowerment"]],
	"Mysticism":[678,7,["Nether Bolt","Healing Stone","Purge Magic","Enchant","Sleep","Eagle Strike","Animated Weapon","Stone Form","Spell Trigger","Mass Sleep","Cleansing Winds","Bombard","Spell Plague","Hail Storm","Nether Cyclone","Rising Colossus"]],
}
# Potions by graphic (UsePotion), as the classic macro finds them.
const POTIONS := {"Confusion Blast":0x0F06,"Cure":0x0F07,"Agility":0x0F08,"Strength":0x0F09,"Poison":0x0F0A,"Refresh":0x0F0B,"Heal":0x0F0C,"Explosion":0x0F0D}
# UseObject: preferred variants by name (strongest first), else a graphic.
const OBJECTS := {
	"Best Heal Potion":["greater heal","heal","lesser heal"],"Best Cure Potion":["greater cure","cure","lesser cure"],"Best Refresh Potion":["total refresh","refresh"],
	"Best Strength Potion":["greater strength","strength"],"Best Agility Potion":["greater agility","agility"],"Best Explosion Potion":["greater explosion","explosion","lesser explosion"],
	"Best Conflagration Potion":["greater conflagration","conflagration"],"Enchanted Apple":["enchanted apple"],"Petals of Trinsic":["petals of trinsic"],"Orange Petals":["orange petals"],
	"Trapped Box":["trapped box","trap box"],"Smoke Bomb":[0x2808],"Healing Stone":["healing stone"],"Spell Stone":["spell stone"],
}
const BANDAGE := 0x0E21
const WINDOWS := ["Configuration","Paperdoll","Status","Journal","Skills","Mage Spellbook","Chat","Backpack","Overview","World Map","Mail","Party Manifest","Party Chat","Necro Spellbook","Paladin Spellbook","Combat Book","Bushido Spellbook","Ninjitsu Spellbook","Guild","Spellweaving Spellbook","Quest Log","Mysticism Spellbook","Racial Abilities Book","Bard Spellbook"]
const DIRECTIONS := ["North","Northeast","East","Southeast","South","Southwest","West","Northwest"]
const SCAN := ["Hostile","Party","Follower","Object","Mobile"]

# The classic list. "options": a fixed list, "text" (free text / number) or
# none. "group": the editor's section. "icon": ActionIcons key.
const ACTIONS := [
	{"id":"Say","group":"Speech","options":"text","icon":"chat"},
	{"id":"Emote","group":"Speech","options":"text","icon":"chat"},
	{"id":"Whisper","group":"Speech","options":"text","icon":"chat"},
	{"id":"Yell","group":"Speech","options":"text","icon":"chat"},
	{"id":"Party Say","group":"Speech","options":"text","icon":"chat"},
	{"id":"Bow","group":"Speech","icon":"user"},
	{"id":"Salute","group":"Speech","icon":"user"},
	{"id":"Walk","group":"Movement","options":"directions","icon":"walk"},
	{"id":"Always Run","group":"Movement","icon":"walk"},
	{"id":"Open Door","group":"Movement","icon":"door"},
	{"id":"Toggle Gargoyle Fly","group":"Movement","icon":"wing"},
	{"id":"War/Peace","group":"Combat","icon":"war"},
	{"id":"Attack Last","group":"Combat","icon":"sword"},
	{"id":"Attack Selected Target","group":"Combat","icon":"sword"},
	{"id":"Primary Ability","group":"Combat","icon":"star"},
	{"id":"Secondary Ability","group":"Combat","icon":"star"},
	{"id":"Arm/Disarm","group":"Combat","options":["Left Hand","Right Hand"],"icon":"shield"},
	{"id":"Equip Last Weapon","group":"Combat","icon":"sword"},
	{"id":"Bandage Self","group":"Combat","icon":"bandage"},
	{"id":"Bandage Target","group":"Combat","icon":"bandage"},
	{"id":"Use Skill","group":"Skills","options":"skills","icon":"skills"},
	{"id":"Last Skill","group":"Skills","icon":"skills"},
	{"id":"Cast Spell","group":"Magic","options":"spells","icon":"book"},
	{"id":"Last Spell","group":"Magic","icon":"book"},
	{"id":"Invoke Virtue","group":"Magic","options":["Honor","Sacrifice","Valor"],"icon":"heal"},
	{"id":"Use Item Type","group":"Items","options":"item","icon":"bag"},
	{"id":"Use Item","group":"Items","options":"item","icon":"bag"},
	{"id":"Use Potion","group":"Items","options":"potions","icon":"potion"},
	{"id":"Use Object","group":"Items","options":"objects","icon":"potion"},
	{"id":"Last Object","group":"Items","icon":"bag"},
	{"id":"Use Item In Hand","group":"Items","icon":"bag"},
	{"id":"Use Selected Target","group":"Items","icon":"bag"},
	{"id":"Grab","group":"Items","icon":"bag"},
	{"id":"Set Grab Bag","group":"Items","icon":"bag"},
	{"id":"Last Target","group":"Targeting","icon":"target"},
	{"id":"Target Self","group":"Targeting","icon":"target"},
	{"id":"Wait For Target","group":"Targeting","icon":"target"},
	{"id":"Target Next","group":"Targeting","icon":"target"},
	{"id":"Select Next","group":"Targeting","options":"scan","icon":"target"},
	{"id":"Select Previous","group":"Targeting","options":"scan","icon":"target"},
	{"id":"Select Nearest","group":"Targeting","options":"scan","icon":"target"},
	{"id":"Current Target","group":"Targeting","icon":"target"},
	{"id":"Target System On/Off","group":"Targeting","icon":"target"},
	{"id":"All Names","group":"Targeting","icon":"eye"},
	{"id":"Names On/Off","group":"Targeting","icon":"eye"},
	{"id":"Open","group":"Windows","options":"windows","icon":"window"},
	{"id":"Close","group":"Windows","options":"windows","icon":"window"},
	{"id":"Minimize","group":"Windows","options":"windows","icon":"window"},
	{"id":"Maximize","group":"Windows","options":"windows","icon":"window"},
	{"id":"Close Gump","group":"Windows","icon":"window"},
	{"id":"Kill Gump Open","group":"Windows","icon":"window"},
	{"id":"Toggle Buff Icons","group":"Windows","icon":"window"},
	{"id":"Toggle Chat Visibility","group":"Windows","icon":"chat"},
	{"id":"Close All Health Bars","group":"Windows","icon":"window"},
	{"id":"Close Inactive Health Bars","group":"Windows","icon":"window"},
	{"id":"Close Corpses","group":"Windows","icon":"window"},
	{"id":"Save Desktop","group":"Windows","icon":"window"},
	{"id":"Quit Game","group":"Windows","icon":"close"},
	{"id":"Delay","group":"Macro","options":"text","icon":"clock"},
	{"id":"Paste","group":"Macro","icon":"chat"},
	{"id":"Razor Macro","group":"Macro","options":"text","icon":"chat"},
	{"id":"Use Counter Bar Slot","group":"Macro","options":"text","icon":"bag"},
	{"id":"Zoom","group":"View","options":["Default Zoom","Zoom In","Zoom Out"],"icon":"eye"},
	{"id":"Look At Mouse","group":"View","icon":"eye"},
	{"id":"Look Forwards","group":"View","icon":"eye"},
	{"id":"Look Backwards","group":"View","icon":"eye"},
	{"id":"Circle of Transparency","group":"View","icon":"eye"},
	{"id":"Update Range","group":"View","options":["Set","Modify","Increase","Decrease","Maximum","Minimum","Default"],"icon":"eye"},
	{"id":"Range Color","group":"View","options":["Enable","Disable","Toggle"],"icon":"eye"},
	{"id":"Aura","group":"View","icon":"eye"},
	{"id":"Aura On/Off","group":"View","icon":"eye"},
	{"id":"Toggle Draw Roofs","group":"View","icon":"eye"},
	{"id":"Toggle Tree Stumps","group":"View","icon":"eye"},
	{"id":"Toggle Vegetation","group":"View","icon":"eye"},
	{"id":"Toggle Cave Tiles","group":"View","icon":"eye"},
]
const GROUPS := ["Combat","Magic","Skills","Items","Targeting","Speech","Movement","Windows","Macro","View"]

static func action(id: String) -> Dictionary:
	for entry in ACTIONS:
		if entry.id == id: return entry
	return {}

# Usable skills: the server's list plus Imbuing, as the classic macro offers.
static func usable_skills() -> Array:
	var result := []
	for id in Character.USABLE+[56]:
		if id < Character.SKILLS.size(): result.append({"id":id,"name":Character.SKILLS[id]})
	result.sort_custom(func(a,b): return a.name < b.name)
	return result

static func skill_id(name: String) -> int:
	return Character.SKILLS.find(name)

# Every castable spell: name, ID, school, circle (Magery), reagents, mana.
static func spells() -> Array:
	var result := []
	for i in MAGERY.size():
		result.append({"name":MAGERY[i][0],"id":i+1,"school":"Magery","circle":i/8+1,"reagents":Array(str(MAGERY[i][1]).split(" ")),"mana":CIRCLE_MANA[i/8],"words":WORDS[i]})
	for school in SCHOOLS:
		if school == "Magery": continue
		var names: Array = SCHOOLS[school][2]
		for i in names.size():
			result.append({"name":names[i],"id":int(SCHOOLS[school][0])+i,"school":school,"circle":0,"reagents":[],"mana":-1})
	return result

static func spell(name: String) -> Dictionary:
	for entry in spells():
		if entry.name == name: return entry
	return {}

# Option list for an action, for the editor.
static func options(id: String) -> Array:
	var kind: Variant = action(id).get("options",null)
	if kind is Array: return kind
	match kind:
		"directions": return DIRECTIONS
		"windows": return WINDOWS
		"scan": return SCAN
		"potions": return POTIONS.keys()
		"objects": return OBJECTS.keys()
		"skills": return usable_skills().map(func(s): return s.name)
		"spells": return spells().map(func(s): return s.name)
	return []

# Whether the step usually raises a target cursor (so a slot's aim applies).
static func targets(step: Dictionary) -> bool:
	match str(step.get("action","")):
		"Cast Spell": return true
		"Use Skill": return str(step.get("option","")) in ["Anatomy","Animal Lore","Animal Taming","Arms Lore","Begging","Discordance","Evaluating Intelligence","Forensic Evaluation","Item Identification","Poisoning","Provocation","Remove Trap","Stealing","Taste Identification","Imbuing","Inscription","Peacemaking","Cartography"]
		"Use Item Type", "Use Item", "Bandage Target", "Last Object", "Use Object", "Use Item In Hand": return true
	return false

# A short label for a step, shown on slots and tooltips.
static func describe(step: Dictionary) -> String:
	var id := str(step.get("action",""))
	var option := str(step.get("option",""))
	var text := str(step.get("text",""))
	match id:
		"Cast Spell", "Use Skill", "Use Potion", "Use Object", "Invoke Virtue": return option
		"Use Item Type", "Use Item": return str(step.get("name","Item"))
		"Say", "Emote", "Whisper", "Yell", "Party Say": return "%s: %s" % [id,text] if text != "" else id
		"Delay": return "Wait %s ms" % text
	return id if option == "" else "%s: %s" % [id,option]

static func icon_for(step: Dictionary) -> String:
	var id := str(step.get("action",""))
	if id == "Cast Spell":
		var name := str(step.get("option",""))
		if "Heal" in name or "Cure" in name or "Wounds" in name or "Life" in name or name == "Resurrection": return "heal"
		if "Fire" in name or "Flame" in name or "Meteor" in name or "Wildfire" in name or "Explosion" in name: return "flame"
		if "Lightning" in name or "Bolt" in name or "Energy" in name or "Harm" in name or "Mind" in name: return "bolt"
		if name in ["Recall","Gate Travel","Mark","Teleport","Sacred Journey","Ethereal Voyage","Shadowjump"]: return "rune"
		if name in ["Protection","Arch Protection","Reactive Armor","Magic Reflection","Wall of Stone","Bless"]: return "shield"
		return "book"
	if id == "Use Potion" or (id == "Use Object" and "Potion" in str(step.get("option",""))): return "potion"
	if id == "Use Skill":
		var skill := str(step.get("option",""))
		if skill == "Hiding" or skill == "Stealth": return "hide"
		if skill == "Meditation": return "moon"
		if skill == "Detecting Hidden" or skill == "Tracking": return "eye"
		return "skills"
	return str(action(id).get("icon","star"))
