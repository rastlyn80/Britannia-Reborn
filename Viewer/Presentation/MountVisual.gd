extends RefCounted
## Dispatch presentation only. Native riding permissions stay with ModernUO.
const Horse=preload("res://Presentation/HorseVisual.gd")
const Ostard=preload("res://Presentation/OstardMount.gd")
const Animals=preload("res://Presentation/AnimalVisual.gd")
const BODIES={0xd2:["desert",0x3ea3],0xda:["frenzied",0x3ea4],0xdb:["forest",0x3ea5],0x84:["kirin",0x3ead],0xdc:["llama",0x3ea6],0x124:["llama",0]}
static func available() -> bool:
	if Animals.available():return true
	if Horse.available() or ResourceLoader.exists("res://local-art/mounts/skeletal-horse.glb"):return true
	for body: int in BODIES:
		if ResourceLoader.exists(asset_path(body)):return true
	return false
static func mount_available(body: int,item: int) -> bool:
	return supports_body(body) and (item not in [0x3eac,0x3eab,0x3e9c] or ResourceLoader.exists(asset_path(body,item)))
static func kind(body: int,item: int=0) -> String:
	return "ethereal" if item==0x3eac else "llama_ethereal" if item==0x3eab else "kirin_ethereal" if item==0x3e9c else str(BODIES[body][0]) if BODIES.has(body) else ""
static func asset_path(body: int,item: int=0) -> String:
	var label:=kind(body,item);return "res://local-art/"+("mounts" if label in ["kirin","kirin_ethereal","llama","llama_ethereal"] else "ostards")+"/"+("kirin" if label=="kirin_ethereal" else label)+"-modern.gltf"
static func supports_body(body: int) -> bool:
	if Animals.supports_body(body):return true
	if body==0x319:return ResourceLoader.exists("res://local-art/mounts/skeletal-horse.glb")
	return ResourceLoader.exists(asset_path(body)) if BODIES.has(body) else Horse.supports_body(body) and Horse.available()
static func mount_item(worn: Array) -> Dictionary:return Horse.mount_item(worn)
static func horse_body(item: int) -> int:
	if item==0x3eac:return 0xd2
	if item==0x3eab:return 0xdc
	if item==0x3ebb:return 0x319
	if item==0x3e9c:return 0x84
	for body: int in BODIES:
		if item!=0 and BODIES[body][1]==item:return body
	return Horse.horse_body(item)
static func matches(visual: Node3D,body: int,item: int=0) -> bool:
	if Animals.supports_body(body):return visual is Ostard and visual.kind==Animals.kind(body)
	if body==0x319:return visual is Horse and not visual.visual_path.is_empty()
	if visual is Horse and not visual.visual_path.is_empty():return false
	return visual is Ostard and visual.kind==kind(body,item) if BODIES.has(body) else visual is Horse
static func create(body: int,item: int=0) -> Node3D:
	if Animals.supports_body(body):return Animals.create(body)
	if body==0x319:
		var skeleton:=Horse.new();skeleton.visual_path="res://local-art/mounts/skeletal-horse.glb";return skeleton
	if BODIES.has(body):
		var visual:=Ostard.new();visual.kind=kind(body,item);return visual
	return Horse.new()
static func step_seconds(worn: Array,running: bool) -> float:return Horse.step_seconds(worn,running)
