extends SceneTree
const Mounts=preload("res://Presentation/MountVisual.gd")
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var ground:=StaticBody3D.new();root.add_child(ground)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20.,.1,20.);shape.shape=box;shape.position.y=-.05;ground.add_child(shape)
	for body in [0xd2,0xda,0xdb,0x84,0xdc,0x124,0x319]:
		var actor:=Mounts.create(body);root.add_child(actor);actor.apply_identity(body,0)
		for tilt in [Vector2.ZERO,Vector2(.10,0),Vector2(0,.08)]:
			ground.rotation=Vector3(tilt.x,0,tilt.y)
			var clip:="idle" if body==0x319 else "Idle"
			actor.animator.play(clip,0.);actor.animator.seek(0.,true);actor.animator.pause()
			for frame in 30:await physics_frame;await process_frame
			var support: Array=actor.contact.hoof_errors if body==0x319 else actor.contact.errors
			var expected:=4 if body in [0x84,0xdc,0x124,0x319] else 2
			check(actor.contact.contacts.size()==expected,"Every actual stance foot samples real support: "+str([body,tilt,actor.contact.contacts.size()]))
			var good:=not support.is_empty()
			for error: float in support:good=good and is_finite(error) and error<.05
			check(good,"Stance soles retain support within 50 mm: "+str([body,tilt,support]))
			check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Terrain fitting never moves the authoritative creature root")
			rows.append({"body":body,"slope":[tilt.x,tilt.y],"stance_errors_m":support.duplicate(),"contacts":actor.contact.contacts.size()})
		actor.free()
	ground.free()
	var file:=FileAccess.open("res://../outputs/ostard-riding/terrain.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"scope":"Real collision rays and animated source skin/bone stance fitting on flat and two slopes; offline fixtures."},"\t"));file.close()
	print("MOUNT TERRAIN: ",checks-failures," / ",checks);quit(1 if failures else 0)
