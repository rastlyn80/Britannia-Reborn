extends SceneTree
## Finite client-only mounted-appearance proof; native permissions stay separate.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var rows: Array=[]
var output:="res://../work/creatures/late-client-inputs/cu-riding"
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":output="res://../work/creatures/late-client-inputs/cu-riding-contact"
	create_timer(180.).timeout.connect(func():push_error("Cu Sidhe rider deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(label)
func run() -> void:
	Registry.load_index();var accepted:="res://local-art/creatures/accepted-index.json";var accepted_pin:=FileAccess.get_sha256(accepted)
	var path:="res://local-art/creatures/cu_sidhe_mount/preparation.json";var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var entries: Dictionary={}
	for entry: Dictionary in preparation.models:
		if entry.kind != "cushidhe":continue
		var body:=int(entry.bodies[0].body);Registry.entries[body]=entry;entries[body]=entry
	check(entries.size()==1,"Original Cu Sidhe source form prepared")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1200,900);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	for rider_body: int in [400,401,605,606]:
		var female := rider_body in [401,606]
		var actor:=Avatar.new();actor.initial_body=rider_body;viewport.add_child(actor);actor.set_physics_process(false)
		for body: int in [277]:
			var entry: Dictionary=entries[body];var item:=int(entry.mount_item)
			check(Mounts.horse_body(item)==body and Mounts.mount_available(body,item),"Prepared source registry maps exact native mount item")
			for outfit: Array in [[],[{"id":0x1f03},{"id":0x170b}],[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}]]:
				var worn: Array=outfit.duplicate(true);worn.append({"id":item,"layer":25,"hue":0})
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				check(actor.horse_visual!=null and actor.horse_visual.native_body==body and actor.horse_visual.native_mount_item==item,"Layer25 selects exact source form/item")
				if actor.horse_visual == null or actor.rider_contact == null:
					quit(1)
					return
				check(actor.human_visual.missing_art.is_empty(),"Prepared riding garments retained")
				actor.rider_contact.begin_mount(false);actor.human_visual.set_process(false);actor.horse_visual.set_physics_process(false);actor.horse_visual.contact.active=false
				for pair: Array in [["Rider_Idle","Idle"],["Rider_Walk","Walk"],["Rider_Run","Run"]]:
					actor.human_visual.cancel_action();actor.human_visual.play(pair[0],0.);actor.horse_visual.play(pair[1],0.)
					for phase: float in [.2371,.7231]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for frame in 4:await process_frame
						var contact: SkeletonModifier3D=actor.rider_contact;var feet: Array=contact.stirrup_errors
						var good: bool=contact.seat_error<.002 and feet.size()==2 and feet[0]<.025 and feet[1]<.025
						check(good,"Both genders and all outfits retain saddle and reachable stirrups: "+str([female,body,pair,phase,contact.seat_error,feet]))
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Mounted presentation preserves authoritative actor root")
						check(actor.human_visual.grip.reins_holding and actor.human_visual.grip.left_reins_holding,"Both empty hands use closed rein grips")
						rows.append({"female":female,"rider_body":rider_body,"body":body,"outfit":outfit,"clip":pair[0],"phase":phase,"seat_error_m":contact.seat_error,"stirrup_errors_m":feet.duplicate(),"passed":good})
						if outfit.size()==2 and phase<.5 and DisplayServer.get_name()!="headless":
							var mesh: MeshInstance3D=actor.horse_visual.model.find_children("*","MeshInstance3D",true,false)[0]
							var box:=Geometry.deformed_bounds(mesh,actor.horse_visual.skeleton);box=box.expand(actor.horse_visual.seat().origin+Vector3.UP*1.1)
							camera.size=box.size.length()*.9;camera.position=box.get_center()+Vector3(-1.,.50,1.)*box.size.length();camera.look_at(box.get_center())
							for frame in 3:await process_frame
							await RenderingServer.frame_post_draw
							viewport.get_texture().get_image().save_png(output+"/"+str(rider_body)+"-"+str(pair[1])+".png")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[])
		check(actor.retiring_horse and actor.rider_contact.mode=="dismount" and not actor.horse_visual.visible,"Dismount uses hidden source sockets without duplicate loose mount")
		actor._finish_dismount();check(actor.horse_visual==null and actor.rider_contact==null and not actor.human_visual.mounted_live_enabled,"Dismount removes mount/rider adapter")
		actor.free()
	check(FileAccess.get_sha256(accepted)==accepted_pin,"Client-only test leaves persistent accepted catalogue unchanged")
	var runtime: Dictionary={}
	for file in ["CuSidheRidingTests.gd","SourceCuSidheMountVisual.gd","HumanWardrobe.gd","SourceRigMountVisual.gd","SourcePreservingCreatureVisual.gd","BirdGroundSupport.gd","HumanAvatar.gd","HumanVisual.gd","HorseRider.gd","MountVisual.gd","CreatureRegistry.gd"]:runtime[file]=FileAccess.get_sha256("res://Presentation/"+file)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"preparation_sha256":FileAccess.get_sha256(path),"runtime_sha256":runtime,"scope":"Actual client layer25 appearance dispatch, body 277, male/female humans and elves, three outfits, Idle/Walk/Run at two off-grid phases; post-modifier seat<=2mm/ankles<=25mm, closed rein grips, and dismount. Source sockets/proportions are authored fittings. Finite sampled proof; no native permission/combat/projectile or universal garment collision certificate."},"\t"))
	print("CU SIDHE RIDING: ",checks," checks / ",failures," failures / ",rows.size()," poses");quit(1 if failures else 0)
