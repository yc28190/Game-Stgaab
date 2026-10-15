class_name FloorMap
extends RefCounted
## One generated labyrinth floor: tiles, lighting, portals, traps and loot on the ground.

enum { WALL, FLOOR }

var floor_id := ""
var width := 0
var height := 0
var tiles := PackedByteArray()
var dark := PackedByteArray()
var explored := PackedByteArray()
var rooms: Array[Rect2i] = []
var room_regions: Array[String] = []
## Vector2i -> destination floor id
var portals := {}
## Vector2i -> true when revealed
var traps := {}
## Vector2i -> Array of ground entries: {"kind": "item"|"stone"|"essence", ...}
var ground := {}
## Monsters left on this floor while the party is elsewhere.
var monsters: Array[Actor] = []
var astar := AStarGrid2D.new()


func _init(p_floor_id: String, w: int, h: int) -> void:
	floor_id = p_floor_id
	width = w
	height = h
	tiles.resize(w * h)
	tiles.fill(WALL)
	dark.resize(w * h)
	explored.resize(w * h)


func def() -> Dictionary:
	return GameData.floor_def(floor_id)


func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func is_walkable(p: Vector2i) -> bool:
	return in_bounds(p) and tiles[idx(p)] != WALL


func is_dark(p: Vector2i) -> bool:
	return in_bounds(p) and dark[idx(p)] == 1


func set_tile(p: Vector2i, t: int) -> void:
	tiles[idx(p)] = t


## Region of the floor a position belongs to: N, S, E, W, or C for the middle.
func region_at(p: Vector2i) -> String:
	var dx := (float(p.x) - width / 2.0) / (width / 2.0)
	var dy := (float(p.y) - height / 2.0) / (height / 2.0)
	if absf(dx) < 0.25 and absf(dy) < 0.25:
		return "C"
	if absf(dy) >= absf(dx):
		return "N" if dy < 0 else "S"
	return "W" if dx < 0 else "E"


func build_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.update()
	for y in height:
		for x in width:
			if tiles[y * width + x] == WALL:
				astar.set_point_solid(Vector2i(x, y), true)


func add_ground(p: Vector2i, entry: Dictionary) -> void:
	if not ground.has(p):
		ground[p] = []
	ground[p].append(entry)


func random_floor_tile(rng: RandomNumberGenerator) -> Vector2i:
	var room := rooms[rng.randi_range(0, rooms.size() - 1)]
	return Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))


func room_index_at(p: Vector2i) -> int:
	for i in rooms.size():
		if rooms[i].has_point(p):
			return i
	return -1
