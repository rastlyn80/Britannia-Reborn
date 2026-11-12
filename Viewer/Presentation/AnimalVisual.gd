extends RefCounted
## Loose animal identities only. This registry invents no ridden items.
const Visual=preload("res://Presentation/BovineVisual.gd")
const EnhancedBovine=preload("res://Presentation/SourceEnhancedBovineVisual.gd")
const LivingBull := preload("res://Presentation/BullLivingVisual.gd")
const EnhancedLivingBull := preload("res://Presentation/EnhancedBullLivingVisual.gd")
static var enhanced_bovine_actions := false
const BOVINE_ACTIONS_MARKER := "res://local-art/animals/bovine-actions-active.json"
static var bovine_actions_trial := false
const Creatures=preload("res://Presentation/CreatureRegistry.gd")
const BODIES={0xd8:["Cow / black and white","bovine_cow_spotted"],0xe7:["Cow / brown and white","bovine_cow_brown"],0xe8:["Bull / brown","bovine_bull_brown"],0xe9:["Bull / spotted","bovine_bull_spotted"]}
static func kind(body: int) -> String:return str(BODIES[body][1]) if BODIES.has(body) else ""
static func supports_body(body: int) -> bool:return Creatures.supports_body(body) or BODIES.has(body) and ResourceLoader.exists("res://local-art/animals/"+kind(body)+"-modern.gltf")
static func available() -> bool:
	Creatures.load_index()
	if not Creatures.entries.is_empty():return true
	for body: int in BODIES:
		if supports_body(body):return true
	return false
static func create(body: int) -> Node3D:
	if Creatures.supports_body(body):return Creatures.create(body)
	var asset_kind := kind(body)
	var renderer: Script = Visual
	if enhanced_bovine_actions and not asset_kind.is_empty():
		renderer = EnhancedLivingBull if body in [232, 233] else EnhancedBovine
	elif not asset_kind.is_empty() and (bovine_actions_trial or FileAccess.file_exists(BOVINE_ACTIONS_MARKER)):
		var actions := load("res://Presentation/BovineActionsVisual.gd") as GDScript
		if actions.available(asset_kind):
			renderer = LivingBull if body in [232, 233] else actions
	var result: Node3D = renderer.new()
	result.kind = asset_kind
	return result
