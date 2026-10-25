extends RefCounted

# Confirmed tile endpoints remain canonical. Render every intermediate point on
# each accepted segment, including corners and slopes; never extrapolate through walls.
var position := Vector3.ZERO
var start := Vector3.ZERO
var elapsed := 0.0
var duration := 0.41
var queue: Array[Vector3] = []
var segment_durations: Array[float] = []

func reset(location: Vector3) -> void:
	position = location
	start = location
	elapsed = 0.0
	queue.clear()
	segment_durations.clear()

func push(location: Vector3, seconds: float = -1.0) -> void:
	var last: Vector3 = queue.back() if not queue.is_empty() else position
	if last.is_equal_approx(location): return
	if last.distance_to(location) > 8.0 or queue.size() >= 4:
		reset(location) # teleport / bounded catch-up after a network stall
		return
	if queue.is_empty():
		start = position
		elapsed = 0.0
	queue.append(location)
	segment_durations.append(maxf(0.05,seconds if seconds > 0 else duration))

func advance(delta: float) -> Vector3:
	var remaining := maxf(delta,0.0)
	while not queue.is_empty():
		var length := segment_durations[0]
		var consumed := minf(remaining,maxf(0.0,length-elapsed))
		elapsed += consumed
		remaining -= consumed
		position = start.lerp(queue[0],minf(1.0,elapsed/length))
		if elapsed + 0.000001 < length: break
		position = queue.pop_front()
		segment_durations.pop_front()
		start = position
		elapsed = 0.0
		if remaining <= 0.0: break
	return position
