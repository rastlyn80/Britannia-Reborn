extends Node
# Walks the player to a tile: the server's pathfind order (0x38, as ClassicUO's
# Pathfinder.WalkTo) and "walk here" on the world map. The route is planned
# with A* over the client's own step prediction (MovementSurface.predict, the
# same rules that predict ordinary walking), then followed one normal step at
# a time (0x02), so the server stays in charge. A refused or stalled step
# replans from where the server put you; it stops on arrival, when you move
# yourself, or after a few failed plans.
const OFFSETS := [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
const MAX_EXPANSIONS := 12000
var game: Node
var goal := Vector2i(-1,-1)
var path: Array = []
var steps := 0
var replans := 0
var last_cell := Vector2i(-1,-1)
var stalled_since := 0

func configure(session: Node) -> void:
	game = session
	game.module("player").path_step.connect(func(point: Vector3i): walk_to(Vector2i(point.x,point.y)))
	game.ended.connect(stop)

func walk_to(point: Vector2i) -> void:
	goal = point
	steps = 0
	replans = 0
	path = plan()

func stop() -> void:
	goal = Vector2i(-1,-1)
	path = []

func active() -> bool:
	return goal.x >= 0

func _unhandled_input(event: InputEvent) -> void:
	# Your own movement keys take over.
	if active() and event is InputEventKey and event.pressed and event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: stop()

static func _cost(a: Vector2i, b: Vector2i) -> float:
	var d := (a-b).abs()
	return maxf(d.x,d.y)+0.41*minf(d.x,d.y)

# Cells from the player to the goal (or as near as the plan could get).
func plan() -> Array:
	var surface = game.surface
	if surface == null: return []
	var start := Vector3i(int(game.player.x),int(game.player.y),int(game.player.z))
	var open: Array = [[_cost(Vector2i(start.x,start.y),goal),start]]
	var came := {start:start}
	var spent := {start:0.0}
	var best := start
	var best_left := _cost(Vector2i(start.x,start.y),goal)
	var expansions := 0
	while not open.is_empty() and expansions < MAX_EXPANSIONS:
		var node: Vector3i = open.pop_front()[1]
		expansions += 1
		var cell := Vector2i(node.x,node.y)
		if cell == goal:
			best = node
			break
		var left := _cost(cell,goal)
		if left < best_left:
			best_left = left
			best = node
		for direction in 8:
			var next: Dictionary = surface.predict({"x":node.x,"y":node.y,"z":node.z},direction)
			if next.is_empty(): continue
			var to := Vector3i(int(next.x),int(next.y),int(next.z))
			var cost: float = spent[node]+(1.41 if direction%2 == 1 else 1.0)
			if spent.has(to) and spent[to] <= cost: continue
			spent[to] = cost
			came[to] = node
			var entry := [cost+_cost(Vector2i(to.x,to.y),goal),to]
			var at := open.bsearch_custom(entry,func(a,b): return a[0] < b[0])
			open.insert(at,entry)
	var route: Array = []
	var walk := best
	while walk != start:
		route.push_front(Vector2i(walk.x,walk.y))
		walk = came[walk]
	return route

func _process(_delta: float) -> void:
	if not active() or game.phase != "world": return
	var me := Vector2i(int(game.player.x),int(game.player.y))
	if me == goal or steps > 600:
		stop()
		return
	if me != last_cell:
		last_cell = me
		stalled_since = Time.get_ticks_msec()
	# Drop the cells already walked.
	if path.has(me):
		while path[0] != me: path.pop_front()
		path.pop_front()
	# Stalled (refused, blocked by something unpredicted) or off the plan: replan.
	if path.is_empty() or Time.get_ticks_msec()-stalled_since > 2500 or maxi(absi(path[0].x-me.x),absi(path[0].y-me.y)) > 1:
		replans += 1
		if replans > 8:
			stop()
			return
		path = plan()
		stalled_since = Time.get_ticks_msec()
		if path.is_empty():
			stop()
			return
	var offset: Vector2i = path[0]-me
	var direction := OFFSETS.find(offset)
	if direction < 0: return
	if game.walk(direction,path.size() > 6): steps += 1
