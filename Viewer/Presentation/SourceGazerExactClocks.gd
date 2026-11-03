extends RefCounted
## Install exact source keys. The ordinary skeleton import bakes a uniform
## clock and can lose sharp original source key boundaries even at240Hz.
var document: Dictionary={}
var data:=PackedByteArray()
var cache: Dictionary={}
func values(index: int) -> Array:
	if cache.has(index):return cache[index]
	assert(index>=0 and index<document.accessors.size())
	var accessor: Dictionary=document.accessors[index];var view: Dictionary=document.bufferViews[int(accessor.bufferView)]
	assert(int(accessor.componentType)==5126 and int(view.buffer)==0 and not view.has("byteStride"))
	var width:=int({"SCALAR":1,"VEC3":3,"VEC4":4}.get(str(accessor.type),0));var count:=int(accessor.count)
	var start:=int(view.get("byteOffset",0))+int(accessor.get("byteOffset",0));assert(width>0 and count>0 and count<30000 and start>=0 and start+count*width*4<=data.size())
	var result: Array=[]
	for item in count:
		var row: Array=[]
		for axis in width:
			var value:=data.decode_float(start+(item*width+axis)*4);assert(is_finite(value));row.append(value)
		result.append(row[0] if width==1 else row)
	cache[index]=result;return result
func install(path: String,player: AnimationPlayer,rig: Skeleton3D) -> Dictionary:
	document=JSON.parse_string(FileAccess.get_file_as_string(path));assert(document is Dictionary and document.buffers.size()==1)
	var uri:=str(document.buffers[0].uri);assert(uri.begins_with("data:application/octet-stream;base64,"))
	data=Marshalls.base64_to_raw(uri.get_slice(",",1));assert(data.size()==int(document.buffers[0].byteLength) and data.size()<64000000)
	var library:=AnimationLibrary.new();var root_node:=player.get_node(player.root_node);var rig_path:=str(root_node.get_path_to(rig));var clips: Array=[]
	for source: Dictionary in document.animations:
		var animation:=Animation.new();var length:=0.;var key_count:=0
		for channel: Dictionary in source.channels:
			var target: Dictionary=channel.target;var node:=int(target.node);assert(node>=0 and node<document.nodes.size())
			var name:=str(document.nodes[node].name);assert(not name.contains(":") and not name.contains("/") and rig.find_bone(name)>=0)
			var sampler: Dictionary=source.samplers[int(channel.sampler)];assert(str(sampler.interpolation)=="LINEAR")
			var times:=values(int(sampler.input));var output:=values(int(sampler.output));assert(times.size()==output.size())
			var type: int={"translation":Animation.TYPE_POSITION_3D,"rotation":Animation.TYPE_ROTATION_3D,"scale":Animation.TYPE_SCALE_3D}[str(target.path)]
			var track:=animation.add_track(type);animation.track_set_path(track,NodePath(rig_path+":"+name));animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
			var previous:=-1.;var packed:=PackedFloat32Array()
			for key in times.size():
				var time:=float(times[key]);assert(time>=0. and time>previous);previous=time;length=maxf(length,time);var v: Array=output[key]
				packed.append(time);packed.append(1.)
				if type==Animation.TYPE_ROTATION_3D:
					var q:=Quaternion(v[0],v[1],v[2],v[3]).normalized();packed.append_array(PackedFloat32Array([q.x,q.y,q.z,q.w]))
				else:packed.append_array(PackedFloat32Array([v[0],v[1],v[2]]))
			# The public insertion API merges near-equal clocks. Serialized track
			# storage retains every distinct float32 key; independently audit it.
			animation.set("tracks/"+str(track)+"/keys",packed)
			assert(animation.track_get_key_count(track)==times.size(),"Source key times must not merge or disappear")
			for key in times.size():assert(animation.track_get_key_time(track,key)==float(times[key]),"Every actual serialized source clock retained")
			key_count+=times.size()
		animation.length=length;animation.loop_mode=Animation.LOOP_NONE;assert(library.add_animation(str(source.name),animation)==OK)
		clips.append({"name":source.name,"keys":key_count,"tracks":animation.get_track_count(),"length":length})
	player.stop()
	for name: String in player.get_animation_library_list():player.remove_animation_library(name)
	assert(player.add_animation_library("",library)==OK);player.clear_caches();return {"clips":clips,"scope":"Actual raw GLTF key clocks/values installed without uniform skeleton baking, optimization or compression. Geometry/bind skeleton uses the actual GLTF importer; this alone is not source skin/renderer/native acceptance."}
