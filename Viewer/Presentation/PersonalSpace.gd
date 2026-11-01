extends RefCounted
# Characters never melt into one another (owner request): UO lets mobiles share
# a tile, but in 3D two bodies on one spot blend together. Each frame, any two
# closer than their body radii are eased apart on screen. Presentation only:
# server positions, movement and targeting are unchanged. Your own character
# yields little, so the camera stays steady.
const HUMAN_RADIUS := 0.4
const LARGE_RADIUS := 0.75
const OWN_SHARE := 0.2
const EASE := 8.0
# serial -> current smoothed offset.
var offsets: Dictionary = {}

static func radius(avatar: Node3D) -> float:
	if avatar.get("horse_visual") != null: return LARGE_RADIUS
	if avatar.get("human_visual") != null: return HUMAN_RADIUS
	return LARGE_RADIUS if avatar.get_meta("large",false) else 0.55

# bases: serial -> position from the movement track; radii: serial -> body
# radius. Returns serial -> offset to add this frame.
func update(bases: Dictionary, radii: Dictionary, own: int, delta: float) -> Dictionary:
	var wanted: Dictionary = {}
	var serials: Array = bases.keys()
	for serial in serials: wanted[serial] = Vector3.ZERO
	for i in serials.size():
		var a: int = serials[i]
		for j in range(i+1,serials.size()):
			var b: int = serials[j]
			var pa: Vector3 = bases[a]
			var pb: Vector3 = bases[b]
			if absf(pa.y-pb.y) > 1.5: continue
			var apart := Vector2(pb.x-pa.x,pb.z-pa.z)
			var need := float(radii.get(a,HUMAN_RADIUS))+float(radii.get(b,HUMAN_RADIUS))
			var distance := apart.length()
			if distance >= need: continue
			# Exactly on one spot: a stable direction from the pair's serials.
			var direction := apart/distance if distance > 0.001 else Vector2.from_angle(float(absi(hash(mini(a,b)*31+maxi(a,b)))%6283)/1000.0)
			var overlap := need-distance
			var share_a := OWN_SHARE if a == own else (1.0-OWN_SHARE if b == own else 0.5)
			wanted[a] -= Vector3(direction.x,0,direction.y)*overlap*share_a
			wanted[b] += Vector3(direction.x,0,direction.y)*overlap*(1.0-share_a)
	var result: Dictionary = {}
	var blend := 1.0-exp(-EASE*delta)
	for serial in serials:
		var offset: Vector3 = offsets.get(serial,Vector3.ZERO)
		offset = offset.lerp(wanted[serial],blend)
		if offset.length() < 0.001 and (wanted[serial] as Vector3).length() < 0.001: offset = Vector3.ZERO
		offsets[serial] = offset
		result[serial] = offset
	for serial in offsets.keys():
		if not bases.has(serial): offsets.erase(serial)
	return result
