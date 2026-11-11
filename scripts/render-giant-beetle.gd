extends "res://../scripts/render-golem-sand.gd"

class Visual extends "res://Presentation/SourceBeetleRestVisual.gd":
	func _ready() -> void:
		super._ready()
		reins.hide()


func review_cast() -> Dictionary:
	return {791: ["Idle", "Walk", "Run", "Death", "LieDown", "BeetleMountedIdle", "BeetleMountedWalk", "BeetleMountedRun",
		"BeetleWingedWalk", "BeetleWingedIdle", "Death2", "BeetleWingedBite", "BeetleWingedHook", "BeetleWingedHit",
		"BeetleWingedFlare", "BeetleWingedDisplay", "BeetleRaiseWings"]}


func review_folder() -> String:
	return "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-beetle-enhanced/"


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	return Visual.new()
