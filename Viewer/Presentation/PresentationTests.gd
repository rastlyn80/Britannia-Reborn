extends SceneTree
const Motion = preload("res://Presentation/MotionTrack.gd")
const Reconstruction = preload("res://Presentation/Reconstruction.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
	else: print("PASS ",description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var motion := Motion.new()
	motion.reset(Vector3(3,-1,7))
	motion.push(Vector3(4,1,7))
	check(motion.advance(0.205).is_equal_approx(Vector3(3.5,0,7)),"fractional coordinates and continuous elevation")
	check(motion.advance(2).is_equal_approx(Vector3(4,1,7)),"exact endpoint and no extrapolation")
	motion.reset(Vector3.ZERO)
	motion.push(Vector3(1,0,0))
	motion.push(Vector3(1,0,1))
	check(motion.advance(0.41).is_equal_approx(Vector3(1,0,0)),"queued corner is visited instead of cutting diagonally")
	check(motion.advance(0.205).is_equal_approx(Vector3(1,0,0.5)),"remaining segment advances at constant speed")
	var slow := Motion.new()
	var fast := Motion.new()
	slow.push(Vector3.ONE)
	fast.push(Vector3.ONE)
	for i in 6: slow.advance(1.0/30)
	for i in 24: fast.advance(1.0/120)
	check(slow.position.is_equal_approx(fast.position),"frame-rate independent motion")
	motion.reset(Vector3.ZERO)
	check(motion.queue.is_empty() and motion.position == Vector3.ZERO,"server rejection clears pending render movement")
	motion.push(Vector3(40,0,0))
	check(motion.position == Vector3(40,0,0),"teleport snaps rather than travelling through intervening walls")
	var recon := Reconstruction.new()
	var world := {"originX":100,"originY":200,"elevationScale":0.2,"staticData":{"7":{"name":"wooden boards","height":0}},"statics":[]}
	var floor := recon.build({"id":7,"x":102,"y":203,"z":-5},world)
	check(floor.get_meta("source_xyz") == Vector3i(102,203,-5) and floor.position.is_equal_approx(Vector3(2.5,-1,3.5)),"art retains canonical anchor and signed elevation")
	check(recon.build({"id":999,"x":102,"y":203,"z":0},world) == null,"unknown statics remain explicitly unmapped")
	floor.free()
	var avatar := preload("res://Presentation/Avatar.gd").new()
	root.add_child(avatar)
	await process_frame
	var skeleton: Skeleton3D = avatar.find_children("*","Skeleton3D",true,false)[0]
	var animation: Animation = avatar.animator.get_animation("Walk")
	var compatible := true
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_subname_count() > 0 and skeleton.find_bone(path.get_subname(0)) < 0: compatible = false
	check(compatible,"locomotion animation bone names match character rig")
	avatar.animate(true,0,0.016)
	avatar.animator.advance(0.15)
	var bone := skeleton.find_bone("thigh_l")
	var before := skeleton.get_bone_pose_rotation(bone)
	avatar.animator.advance(0.2)
	check(not before.is_equal_approx(skeleton.get_bone_pose_rotation(bone)),"walk animation actually poses the imported character")
	avatar.free()
	print("PRESENTATION CHECKS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
