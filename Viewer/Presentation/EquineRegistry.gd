extends RefCounted
## Native identities and explicitly separate client compatibility artwork.
## Compatibility routes never establish server species or ridden-item pairs.
const BODIES := {
	0xc8:["Horse / golden tan","tan",0x3e9f],
	0xe2:["Horse / dapple grey","grey",0x3ea0],
	0xe4:["Horse / dun","dun",0x3ea1],
	0xcc:["Horse / dark brown","brown",0x3ea2],
	0x74:["Nightmare","nightmare",0x3ea7],
	0xb2:["Nightmare / body 0xB2","nightmare",0x3ea9],
	0xb3:["Nightmare / body 0xB3","nightmare",0x3eb7],
	0x75:["Silver steed","silver",0x3ea8],
	0xbe:["Fire steed","fire",0x3e9e],
	0x7a:["Unicorn","unicorn",0x3eb4],
	0x76:["True Britannians warhorse","tan",0x3eb2],
	0x77:["Council of Mages warhorse","grey",0x3eb1],
	0x78:["Minax warhorse","brown",0x3eaf],
	0x79:["Shadowlords warhorse","black",0x3eb0],
	0x123:["Pack horse","pack",0]
}
const ETHEREALS := {0x3eaa:[0xc8,"Ethereal horse","ethereal"],0x3e9b:[0x7a,"Ethereal unicorn","ethereal_unicorn"]}
# label, modern style, NO invented mount item, fallback body, fallback hue.
# Body.def groups with >=3 entries select their THIRD entry (ClassicUO
# AnimationsLoader.ProcessBodyDef). These are presentation defaults only.
const COMPATIBILITY := {
	0x72:["Client horse fallback / 0x72","dun",0,0xe4,1109],
	0x73:["Client horse fallback / 0x73","spectral_grey",0,0xe2,0x4001],
	0xb1:["Client horse fallback / 0xB1","grey",0,0xe2,1109],
	0xbf:["Client horse fallback / 0xBF","spectral_dun",0,0xe4,0x4001],
	0xc0:["Client horse fallback / 0xC0","spectral_dun",0,0xe4,0x4001],
	0x312:["Client horse fallback / 0x312","tan",0,0xc8,2101],
	0x11c:["Mondain's steed / client-only category","brown",0,0,0],
	0x57f:["Horse_Unicorn_RB / client-only category","unicorn",0,0,0],
	0x580:["Horse_Palomino / client-only category","palomino",0,0,0]
}
const DISTINCT := {0x84:"Ki-rin",0x319:"Skeletal mount / HellSteed"}
const DEFERRED := {}
const PROFILES := {
	"tan":{"colour":Color("b6a07b")},"grey":{"colour":Color("9c9f9f"),"grey":true},
	"dun":{"colour":Color("96846a")},"brown":{"colour":Color("5e4130"),"change":0.},
	"nightmare":{"colour":Color("24232b"),"eyes":Color("d93413"),"scale":Vector3(1.035,1.025,1.03)},
	"black":{"colour":Color("24232b")},
	"silver":{"colour":Color("c3c6cc"),"grey":true,"scale":Vector3(.97,1.015,1.02)},
	"fire":{"colour":Color("a44723"),"magic":Color("ff6419"),"glow":.3,"eyes":Color("ffb943"),"embers":true,"scale":Vector3(1.02,1.02,1.02)},
	"unicorn":{"colour":Color("c9c7bc"),"horn":true,"scale":Vector3(.98,1.025,1.015)},
	"pack":{"colour":Color("96846a"),"bags":true,"scale":Vector3(1.09,.97,1.)},
	"ethereal":{"colour":Color("6799b6"),"ethereal":true},
	"spectral_grey":{"colour":Color("9c9f9f"),"grey":true,"ethereal":true},
	"spectral_dun":{"colour":Color("96846a"),"ethereal":true},
	"palomino":{"colour":Color("c5a06d")},
	"ethereal_unicorn":{"colour":Color("94b8c3"),"ethereal":true,"horn":true,"scale":Vector3(.98,1.025,1.015)}
}
static func supports_body(body: int) -> bool:return BODIES.has(body) or COMPATIBILITY.has(body)
static func body_for_mount(item: int) -> int:
	if ETHEREALS.has(item):return int(ETHEREALS[item][0])
	for body: int in BODIES:
		if int(BODIES[body][2])!=0 and int(BODIES[body][2])==item:return body
	return 0
static func profile(body: int,mount_item: int=0) -> Dictionary:
	if not supports_body(body):return {}
	var entry: Array=BODIES[body] if BODIES.has(body) else COMPATIBILITY[body]
	var style:=str(entry[1]);var label:=str(entry[0])
	if ETHEREALS.has(mount_item):
		# Ethereals have no loose mobile body. body is the renderer's rig proxy.
		if int(ETHEREALS[mount_item][0])!=body:return {}
		style=str(ETHEREALS[mount_item][2]);label=str(ETHEREALS[mount_item][1])
	var result: Dictionary=PROFILES[style].duplicate(true)
	result["style"]=style;result["name"]=label
	if COMPATIBILITY.has(body):
		result["compatibility"]=true;result["default_hue"]=int(entry[4])
	return result
