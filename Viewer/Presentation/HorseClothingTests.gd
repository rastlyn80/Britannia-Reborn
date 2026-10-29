extends SceneTree
## Actual GPU coverage in mounted poses, including the complete seat reference.
var viewport: SubViewport
var rows: Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func solid(colour: String) -> ShaderMaterial:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO="+colour+";}"
	var material:=ShaderMaterial.new();material.shader=shader;return material
func capture() -> Image:
	await process_frame;RenderingServer.force_draw(false)
	var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;viewport.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.6;camera.position=Vector3(0,1.6,5);viewport.add_child(camera);camera.look_at(Vector3(0,1.6,0))
	var white:=solid("vec3(1.)");var pink:=solid("COLOR.rgb")
	var outfits:={"plate":[0x1415,0x1410,0x1411,0x1414,0x170b],"robe":[0x1f03,0x1539,0x13c6,0x170b],"skirt":[0x1415,0x1410,0x1539,0x1516,0x13c6,0x170b],"kilt":[0x1415,0x1410,0x1539,0x1537,0x13c6,0x170b]}
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false)
		for family: String in outfits:
			var worn: Array=[{"id":0x3e9f,"layer":25}]
			for id in outfits[family]:worn.append({"id":id})
			actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn);actor.animate(false,0.,.1,0.);actor.rider_contact.seated_weight=1.
			var human: Node3D=actor.human_visual;human.set_process(false)
			var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
			var base: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
			for mesh: MeshInstance3D in meshes:states[mesh]={"visible":mesh.visible,"material":mesh.material_override,"mesh":mesh.mesh,"probe":preload("res://Presentation/HumanArmourCoverageTests.gd").skin_probe(mesh,human.skeleton) if mesh.name.begins_with("Body") else mesh.mesh}
			for pair in [["Rider_Idle","idle"],["Rider_Walk","walk"],["Rider_Run","canter"],["Rider_Attack","canter"],["Rider_Bow","idle"],["Rider_Crossbow","idle"]]:
				for phase in [.15,.65]:
					for angle in [0,90,180,270]:
						actor.rotation_degrees.y=angle;human.cancel_action();human.play(pair[0],0.);human.animator.seek(human.animator.current_animation_length*phase,true);human.animator.pause()
						actor.horse_visual.animator.play(pair[1],0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=pink if mesh.name.begins_with("Body") else white;mesh.mesh=states[mesh].probe
						var skin:=await capture()
						for mesh: MeshInstance3D in meshes:mesh.visible=mesh==base;mesh.material_override=white;mesh.mesh=states[mesh].mesh
						var reference:=await capture()
						for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=white
						var covered:=await capture()
						var a:=skin.get_data();var b:=reference.get_data();var c:=covered.get_data();var exposed:=0;var count:=0;var missing:=0;var seat_count:=0;var seat_missing:=0
						var saddle: Vector3=actor.horse_visual.seat().origin
						var seat_top:=roundi(camera.unproject_position(saddle+Vector3.UP*.3).y);var seat_bottom:=roundi(camera.unproject_position(saddle-Vector3.UP*.25).y)
						for y in 384:
							for x in 384:
								var i:=(y*384+x)*4
								if a[i]>230 and a[i+1]<35 and a[i+2]>230:exposed+=1
								if b[i]>240 and b[i+1]>240 and b[i+2]>240:
									count+=1;var opaque: bool=c[i]>240 and c[i+1]>240 and c[i+2]>240
									if not opaque:missing+=1
									if y>=seat_top and y<=seat_bottom:
										seat_count+=1
										if not opaque:seat_missing+=1
						var body_fraction:=1.-float(missing)/maxi(1,count);var seat_fraction:=1.-float(seat_missing)/maxi(1,seat_count)
						var passed:=exposed<=4 and body_fraction>=.98 and seat_fraction>=.995
						rows.append({"female":female,"outfit":family,"rider_clip":pair[0],"horse_clip":pair[1],"phase":phase,"angle":angle,"skin_pixels":exposed,"body_occupancy":body_fraction,"seat_occupancy":seat_fraction,"passed":passed})
						if not passed:
							failures+=1
							if failures<=8:push_error(str(rows[-1]));skin.save_png("res://../outputs/horse-session/cloth-failure-%d.png"%failures)
			for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=states[mesh].material
			print("HORSE GPU CLOTH ",female," ",family)
		actor.free()
	var file:=FileAccess.open("res://../outputs/horse-session/clothing-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":rows,"failures":failures,"scope":"Actual GPU masked skin and complete unmasked-body opacity reference: two mounted bodies, plate/robe/skirt/kilt, six rider/horse action pairs, two phases and four angles. Head/neck intentionally excluded by native bone weights. <=4 skin pixels, >=98% body and >=99.5% seat opacity. Finite visual coverage, not universal triangle collision."},"\t"));file.close()
	print("HORSE GPU CLOTHING: ",rows.size()," poses / ",failures," failures");quit(1 if failures else 0)
