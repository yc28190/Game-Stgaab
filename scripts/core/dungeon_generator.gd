class_name DungeonGenerator
extends RefCounted
## Builds a random floor: rectangular rooms joined by L-shaped corridors, with a few extra loops.

const ITEM_TABLE := [["bread", 40], ["potion", 12], ["antidote", 8], ["torch", 5]]


static func generate(floor_id: String, rng: RandomNumberGenerator) -> FloorMap:
	var d := GameData.floor_def(floor_id)
	var m := FloorMap.new(floor_id, int(d["width"]), int(d["height"]))
	_place_rooms(m, int(d["rooms"]), rng)
	_connect_rooms(m, rng)
	for i in m.rooms.size():
		var r := m.rooms[i]
		m.room_regions.append(m.region_at(r.get_center()))
		if rng.randf() < float(d["dark_room_chance"]):
			_fill_dark(m, r.grow(1))
	if d["dark_corridors"]:
		for y in m.height:
			for x in m.width:
				var p := Vector2i(x, y)
				if m.is_walkable(p) and m.room_index_at(p) == -1:
					m.dark[m.idx(p)] = 1
	_place_portals(m, d["portals"], rng)
	_place_traps(m, d["traps"], rng)
	_place_items(m, int(d["items"]), rng)
	m.build_astar()
	return m


static func _place_rooms(m: FloorMap, target: int, rng: RandomNumberGenerator) -> void:
	var attempts := 0
	while m.rooms.size() < target and attempts < 600:
		attempts += 1
		var w := rng.randi_range(5, 12)
		var h := rng.randi_range(4, 9)
		var r := Rect2i(rng.randi_range(2, m.width - w - 2), rng.randi_range(2, m.height - h - 2), w, h)
		var ok := true
		for other in m.rooms:
			if r.grow(2).intersects(other):
				ok = false
				break
		if not ok:
			continue
		m.rooms.append(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				m.set_tile(Vector2i(x, y), FloorMap.FLOOR)


static func _connect_rooms(m: FloorMap, rng: RandomNumberGenerator) -> void:
	# Each room links to its nearest already-connected room (a spanning tree), plus a few loops.
	for i in range(1, m.rooms.size()):
		var best := 0
		var best_d := INF
		for j in i:
			var dist := m.rooms[i].get_center().distance_squared_to(m.rooms[j].get_center())
			if dist < best_d:
				best_d = dist
				best = j
		_carve_corridor(m, m.rooms[i].get_center(), m.rooms[best].get_center(), rng)
	for _k in maxi(2, m.rooms.size() / 5):
		var a := rng.randi_range(0, m.rooms.size() - 1)
		var b := rng.randi_range(0, m.rooms.size() - 1)
		if a != b:
			_carve_corridor(m, m.rooms[a].get_center(), m.rooms[b].get_center(), rng)


static func _carve_corridor(m: FloorMap, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(m, a, corner)
	_carve_line(m, corner, b)


static func _carve_line(m: FloorMap, a: Vector2i, b: Vector2i) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	m.set_tile(p, FloorMap.FLOOR)
	while p != b:
		p += step
		m.set_tile(p, FloorMap.FLOOR)


static func _fill_dark(m: FloorMap, r: Rect2i) -> void:
	for y in range(maxi(0, r.position.y), mini(m.height, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(m.width, r.end.x)):
			m.dark[y * m.width + x] = 1


static func rooms_in_region(m: FloorMap, region: String) -> Array[int]:
	var out: Array[int] = []
	for i in m.rooms.size():
		if region == "any" or m.room_regions[i] == region:
			out.append(i)
	if out.is_empty():
		for i in m.rooms.size():
			out.append(i)
	return out


static func _place_portals(m: FloorMap, portal_defs: Array, rng: RandomNumberGenerator) -> void:
	var used: Array[int] = []
	for pd in portal_defs:
		var region: String = pd["region"]
		var candidates := rooms_in_region(m, region)
		# Prefer the room furthest out in that direction, like the portals at the edges of the novel's floors.
		var best := candidates[0]
		var best_score := -INF
		for i in candidates:
			if i in used:
				continue
			var c := Vector2(m.rooms[i].get_center()) - Vector2(m.width, m.height) / 2.0
			var score := rng.randf() * 4.0
			match region:
				"N": score += -c.y
				"S": score += c.y
				"W": score += -c.x
				"E": score += c.x
				_: score += -c.length()
			if score > best_score:
				best_score = score
				best = i
		used.append(best)
		var r := m.rooms[best]
		m.portals[r.get_center()] = pd["to"]


static func _place_traps(m: FloorMap, trap_def: Dictionary, rng: RandomNumberGenerator) -> void:
	if trap_def["region"] == "none":
		return
	var rooms := rooms_in_region(m, trap_def["region"])
	for _i in int(trap_def["count"]):
		var r := m.rooms[rooms[rng.randi_range(0, rooms.size() - 1)]]
		var p := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if not m.portals.has(p):
			m.traps[p] = false


static func _place_items(m: FloorMap, count: int, rng: RandomNumberGenerator) -> void:
	var total := 0
	for e in ITEM_TABLE:
		total += int(e[1])
	for _i in count:
		var p := m.random_floor_tile(rng)
		if m.portals.has(p) or m.traps.has(p):
			continue
		var roll := rng.randi_range(1, total)
		for e in ITEM_TABLE:
			roll -= int(e[1])
			if roll <= 0:
				m.add_ground(p, {"kind": "item", "id": e[0]})
				break
