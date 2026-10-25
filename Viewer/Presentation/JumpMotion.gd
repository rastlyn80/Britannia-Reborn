extends RefCounted

const GRAVITY := 12.0
var height := 0.0
var velocity := 0.0
var airborne := false
var elapsed := 0.0
var landed := false
var landing_time := 0.0

func start(clearance: float) -> bool:
	if airborne or landing_time > 0.0 or clearance < 0.18: return false
	velocity = sqrt(2.0*GRAVITY*minf(clearance,1.0))
	height = 0
	elapsed = 0
	airborne = true
	landed = false
	return true

func advance(delta: float, clearance: float = 10.0) -> float:
	landed = false
	landing_time = maxf(0.0,landing_time-delta)
	if not airborne: return height
	elapsed += delta
	# Analytic integration makes the arc independent of frame rate.
	height += velocity*delta-0.5*GRAVITY*delta*delta
	velocity -= GRAVITY*delta
	if height > clearance:
		height = maxf(0.0,clearance)
		velocity = minf(0.0,velocity)
	if height <= 0.0:
		height = 0.0
		velocity = 0.0
		airborne = false
		landed = true
		landing_time = 0.12
	return height

func reset() -> void:
	height = 0
	velocity = 0
	airborne = false
	landing_time = 0
	elapsed = 0
	landed = false
