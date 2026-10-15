class_name MiniMap
extends Control
## Small overview of the explored part of the floor.

const PX := 3

var run: DungeonRun


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var m := run.map
	custom_minimum_size = Vector2(m.width * PX, m.height * PX)
	draw_rect(Rect2(Vector2.ZERO, Vector2(m.width * PX, m.height * PX)), Color(0, 0, 0, 0.6))
	for y in m.height:
		for x in m.width:
			var i := y * m.width + x
			if m.explored[i] == 0 or m.tiles[i] == FloorMap.WALL:
				continue
			var col := Color(0.78, 0.8, 0.88, 0.9) if run.fov.has(Vector2i(x, y)) else Color(0.42, 0.45, 0.54, 0.8)
			draw_rect(Rect2(x * PX, y * PX, PX, PX), col)
	var accent := Color(m.def()["accent"])
	for p in m.portals:
		if m.explored[m.idx(p)] == 1:
			draw_rect(Rect2(Vector2(p * PX) - Vector2(2, 2), Vector2(PX + 4, PX + 4)), accent)
	for a in run.actors:
		var col: Color
		if a.is_player:
			col = UI.ACCENT
		elif a.faction == Actor.PARTY:
			col = Color("#7ed37e")
		elif run.is_visible_to_player(a) or run.is_smelled(a):
			col = Color("#ff6b5e")
		else:
			continue
		draw_rect(Rect2(Vector2(a.pos * PX) - Vector2(1, 1), Vector2(PX + 2, PX + 2)), col)
