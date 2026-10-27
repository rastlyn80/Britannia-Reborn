extends RefCounted
# Character status, vitals, skills and locks on the native ModernUO protocol:
# 0x11 mobile status, 0xA1-0xA3 vitals, 0x3A skills, 0xBF/0x19 stat locks.
# Requests: 0x34 status/skills query, 0x12/0x24 use skill, 0x3A skill lock,
# 0xBF/0x1A stat lock. Field layouts follow ModernUO's packet writers.
const Login = preload("res://Network/LoginProtocol.gd")

# Skill IDs are ModernUO SkillName values. Names and the default client
# grouping are game facts; no client data files are read.
const SKILLS := ["Alchemy","Anatomy","Animal Lore","Item Identification","Arms Lore","Parrying","Begging","Blacksmithy","Bowcraft/Fletching","Peacemaking","Camping","Carpentry","Cartography","Cooking","Detecting Hidden","Discordance","Evaluating Intelligence","Healing","Fishing","Forensic Evaluation","Herding","Hiding","Provocation","Inscription","Lockpicking","Magery","Resisting Spells","Tactics","Snooping","Musicianship","Poisoning","Archery","Spirit Speak","Stealing","Tailoring","Animal Taming","Taste Identification","Tinkering","Tracking","Veterinary","Swordsmanship","Mace Fighting","Fencing","Wrestling","Lumberjacking","Mining","Meditation","Stealth","Remove Trap","Necromancy","Focus","Chivalry","Bushido","Ninjitsu","Spellweaving","Mysticism","Imbuing","Throwing"]
const GROUPS := [
	["Combat",[1,31,42,50,17,41,5,40,27,57,43]],
	["Magic",[52,51,16,25,46,55,49,53,26,54,32]],
	["Trade Skills",[0,7,8,11,13,56,23,44,45,34,37]],
	["Wilderness",[2,35,10,18,20,38,39]],
	["Thieving",[14,21,24,30,48,28,33,47]],
	["Bardic",[15,29,9,22]],
	["Miscellaneous",[4,6,12,19,3,36]],
]
# Skills ModernUO registers a use callback for (the "use" button).
const USABLE := [1,2,3,4,6,9,12,14,15,16,19,21,22,23,30,32,33,35,36,38,46,47,48]
const LOCKS := ["up","down","locked"]

# Full 0x11 status. Other mobiles only get the compact form (name and hits,
# normalised to 0-100); the player's own status carries every field.
static func status(p: PackedByteArray) -> Dictionary:
	if p.size() < 43: return {}
	var version := int(p[42])
	var result := {"serial":Login.read_be(p,3,4),"name":_latin(p,7,30),"hits":Login.read_be(p,37,2),"hits_max":Login.read_be(p,39,2),"version":version}
	if version == 0 or p.size() < 66: return result
	result.merge({"female":p[43] != 0,"str":Login.read_be(p,44,2),"dex":Login.read_be(p,46,2),"int":Login.read_be(p,48,2),
		"stam":Login.read_be(p,50,2),"stam_max":Login.read_be(p,52,2),"mana":Login.read_be(p,54,2),"mana_max":Login.read_be(p,56,2),
		"gold":Login.read_be(p,58,4),"armor":_short(p,62),"weight":Login.read_be(p,64,2)},true)
	var at := 66
	if version >= 5 and p.size() >= at+3:
		result.weight_max = Login.read_be(p,at,2)
		result.race = int(p[at+2])
		at += 3
	if p.size() >= at+4:
		result.stat_cap = Login.read_be(p,at,2)
		result.followers = int(p[at+2])
		result.followers_max = int(p[at+3])
		at += 4
	if version >= 4 and p.size() >= at+18:
		result.merge({"fire":_short(p,at),"cold":_short(p,at+2),"poison":_short(p,at+4),"energy":_short(p,at+6),"luck":_short(p,at+8),
			"damage_min":Login.read_be(p,at+10,2),"damage_max":Login.read_be(p,at+12,2),"tithing":Login.read_be(p,at+14,4)},true)
	return result

# 0xA1 hits / 0xA2 mana / 0xA3 stamina: serial, maximum, current.
static func vital(p: PackedByteArray) -> Dictionary:
	if p.size() != 9: return {}
	var key: String = {0xa1:"hits",0xa2:"mana",0xa3:"stam"}.get(int(p[0]),"")
	if key.is_empty(): return {}
	return {"serial":Login.read_be(p,1,4),key+"_max":Login.read_be(p,5,2),key:Login.read_be(p,7,2)}

# 0x3A: full lists (0x00/0x02, IDs 1-based, zero-terminated) or single
# updates (0xFF/0xDF, IDs 0-based). Values are tenths of a point.
static func skills(p: PackedByteArray) -> Dictionary:
	if p.size() < 4: return {}
	var type := int(p[3])
	var capped := type in [0x02,0xdf]
	var entry := 9 if capped else 7
	var result := {}
	var at := 4
	while at+entry <= p.size():
		var id := Login.read_be(p,at,2)
		if type in [0x00,0x02]:
			if id == 0: break
			id -= 1
		var skill := {"id":id,"value":Login.read_be(p,at+2,2)/10.0,"base":Login.read_be(p,at+4,2)/10.0,"lock":clampi(int(p[at+6]),0,2)}
		skill.cap = Login.read_be(p,at+7,2)/10.0 if capped else 100.0
		if id >= 0 and id < SKILLS.size(): result[id] = skill
		at += entry
		if type in [0xff,0xdf]: break
	return {"full":type in [0x00,0x02],"skills":result}

# 0xBF subcommand 0x19 type 2: stat lock bits (str<<4 | dex<<2 | int).
static func stat_locks(p: PackedByteArray) -> Dictionary:
	if p.size() < 12 or Login.read_be(p,3,2) != 0x19 or int(p[5]) != 2: return {}
	var bits := int(p[11])
	return {"serial":Login.read_be(p,6,4),"str":(bits >> 4) & 3,"dex":(bits >> 2) & 3,"int":bits & 3}

static func query(serial: int, skills_query: bool) -> PackedByteArray:
	var p := PackedByteArray([0x34,0xed,0xed,0xed,0xed,5 if skills_query else 4])
	p.append_array(Login.uint_be(serial,4))
	return p

static func use_skill(id: int) -> PackedByteArray:
	var p := PackedByteArray([0x12,0,0,0x24])
	p.append_array(("%d 0" % id).to_ascii_buffer())
	p.append(0)
	p[1] = p.size() >> 8
	p[2] = p.size() & 255
	return p

static func skill_lock(id: int, lock: int) -> PackedByteArray:
	var p := PackedByteArray([0x3a,0,6])
	p.append_array(Login.uint_be(id,2))
	p.append(clampi(lock,0,2))
	return p

static func stat_lock(stat: int, lock: int) -> PackedByteArray:
	return PackedByteArray([0xbf,0,7,0,0x1a,clampi(stat,0,2),clampi(lock,0,2)])

static func _short(p: PackedByteArray, at: int) -> int:
	var value := Login.read_be(p,at,2)
	return value-65536 if value >= 32768 else value

static func _latin(p: PackedByteArray, at: int, length: int) -> String:
	var bytes := p.slice(at,at+length)
	var end := bytes.find(0)
	if end >= 0: bytes = bytes.slice(0,end)
	return bytes.get_string_from_ascii()
