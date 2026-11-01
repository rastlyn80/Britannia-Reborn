extends SceneTree
# Characters sharing a spot stand apart on screen (PersonalSpace); the server
# positions they come from are untouched.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

func settle(space: RefCounted, bases: Dictionary, radii: Dictionary, own: int) -> Dictionary:
	var offsets: Dictionary = {}
	for i in 120: offsets = space.update(bases,radii,own,1.0/60.0)
	return offsets

func run() -> void:
	var Space := preload("res://Presentation/PersonalSpace.gd")
	var space = Space.new()
	var spot := Vector3(10,2,10)
	var offsets := settle(space,{1:spot,2:spot},{1:0.4,2:0.4},0)
	var a: Vector3 = spot+offsets[1]
	var b: Vector3 = spot+offsets[2]
	check(Vector2(a.x-b.x,a.z-b.z).length() > 0.75,"two people on one tile end up side by side (%.2f m apart)" % Vector2(a.x-b.x,a.z-b.z).length())
	check(is_equal_approx(a.y,spot.y) and is_equal_approx(b.y,spot.y),"they are moved only sideways, never up or down")
	space = Space.new()
	offsets = settle(space,{1:spot,2:spot},{1:0.4,2:0.4},1)
	check((offsets[1] as Vector3).length() < (offsets[2] as Vector3).length()*0.4,"your own character yields little, the other steps aside")
	space = Space.new()
	offsets = settle(space,{1:spot,2:spot+Vector3(1,0,0)},{1:0.4,2:0.4},0)
	check((offsets[1] as Vector3).is_zero_approx() and (offsets[2] as Vector3).is_zero_approx(),"neighbours on adjacent tiles are left where they are")
	space = Space.new()
	offsets = settle(space,{1:spot,2:spot+Vector3(0,3,0)},{1:0.4,2:0.4},0)
	check((offsets[1] as Vector3).is_zero_approx(),"someone on the floor above is not pushed")
	space = Space.new()
	offsets = settle(space,{1:spot,2:spot+Vector3(0.9,0,0)},{1:0.75,2:0.4},0)
	check((offsets[1] as Vector3).x < -0.05,"a rider needs more room than a person on foot")
	var first: Dictionary = space.update({1:spot},{1:0.4},0,0.016)
	check(first.size() == 1 and space.offsets.size() == 1,"a character that left is forgotten")
	print("PERSONAL SPACE TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
