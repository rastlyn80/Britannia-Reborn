extends RefCounted
## Loose animal identities only. This registry invents no ridden items.
const Visual=preload("res://Presentation/BovineVisual.gd")
const BODIES={0xd8:["Cow / black and white","bovine_cow_spotted"],0xe7:["Cow / brown and white","bovine_cow_brown"],0xe8:["Bull / brown","bovine_bull_brown"],0xe9:["Bull / spotted","bovine_bull_spotted"]}
static func kind(body: int) -> String:return str(BODIES[body][1]) if BODIES.has(body) else ""
static func supports_body(body: int) -> bool:return BODIES.has(body) and ResourceLoader.exists("res://local-art/animals/"+kind(body)+"-modern.gltf")
static func available() -> bool:
	for body: int in BODIES:
		if supports_body(body):return true
	return false
static func create(body: int) -> Node3D:
	var result:=Visual.new();result.kind=kind(body);return result
