class_name DungeonView
extends Node2D
## Draws the current floor with simple shapes: tiles, portals, loot and actors.

const TILE := 28
const ITEM_COLORS := {
	"bread": Color("#b0763c"), "potion": Color("#e0475b"), "antidote": Color("#59c96b"),
	"torch": Color("#f0a030"), "vial": Color("#a0c8ff"),
}

var run: DungeonRun
var camera := Camera2D.new()
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	add_child(camera)
	camera.make_current()
	refresh()


func refresh() -> void:
	camera.position = _center(run.player.pos)
	queue_redraw()


func tile_at_mouse() -> Vector2i:
	var g := get_global_mouse_position()
	return Vector2i(floori(g.x / TILE), floori(g.y / TILE))


func _center(p: Vector2i) -> Vector2:
	return Vector2(p * TILE) + Vector2(TILE, TILE) * 0.5


func _draw() -> void:
	var m := run.map
	var d := m.def()
	var floor_c := Color(d["floor_color"])
	var wall_c := Color(d["wall_color"])
	var dark_c := Color(d["dark_floor_color"])
	var accent := Color(d["accent"])
	var half := Vector2i(get_viewport_rect().size / camera.zoom / TILE / 2.0) + Vector2i(2, 2)
	var c := run.player.pos
	for y in range(maxi(0, c.y - half.y), mini(m.height, c.y + half.y + 1)):
		for x in range(maxi(0, c.x - half.x), mini(m.width, c.x + half.x + 1)):
			var p := Vector2i(x, y)
			var i := m.idx(p)
			if m.explored[i] == 0:
				continue
			var seen := run.fov.has(p)
			var wall := m.tiles[i] == FloorMap.WALL
			var col := wall_c if wall else (dark_c if m.dark[i] == 1 else floor_c)
			if not seen:
				col = col.darkened(0.5)
			var r := Rect2(Vector2(p * TILE), Vector2(TILE, TILE))
			draw_rect(r, col)
			if wall:
				draw_rect(r.grow(-3), col.lightened(0.07))
			else:
				draw_rect(r, col.darkened(0.15), false, 1.0)
			if m.portals.has(p):
				var center := _center(p)
				draw_circle(center, TILE * 0.45, Color(accent, 0.25 if seen else 0.12))
				draw_arc(center, TILE * 0.42, 0, TAU, 24, Color(accent, 0.9 if seen else 0.4), 2.5)
				draw_arc(center, TILE * 0.22, 0, TAU, 16, Color(accent, 0.9 if seen else 0.4), 2.0)

	for p in m.traps:
		if m.traps[p] and m.explored[m.idx(p)] == 1:
			var tc := _center(p)
			var k := TILE * 0.22
			var col := Color("#ff6b5e", 0.9 if run.fov.has(p) else 0.45)
			draw_line(tc - Vector2(k, k), tc + Vector2(k, k), col, 3.0)
			draw_line(tc + Vector2(-k, k), tc + Vector2(k, -k), col, 3.0)

	for p in m.ground:
		if not run.fov.has(p):
			continue
		for e in m.ground[p]:
			_draw_ground(p, e, accent)

	for a in run.actors:
		if run.is_visible_to_player(a):
			_draw_actor(a)
		elif run.is_smelled(a):
			draw_arc(_center(a.pos), TILE * 0.36, 0, TAU, 16, Color(a.color, 0.45), 1.5)


func _draw_ground(p: Vector2i, e: Dictionary, accent: Color) -> void:
	var c := _center(p)
	match e["kind"]:
		"stone":
			var s := TILE * 0.18
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Color("#7fd6ff"))
		"essence":
			var col := Color(GameData.essence(e["id"])["color"])
			draw_circle(c, TILE * 0.42, Color(1.0, 0.85, 0.3, 0.25))
			draw_circle(c, TILE * 0.26, col)
			draw_arc(c, TILE * 0.32, 0, TAU, 20, Color("#ffd75e"), 2.0)
		"item":
			var col: Color = ITEM_COLORS.get(e["id"], Color.WHITE)
			draw_rect(Rect2(c - Vector2(TILE, TILE) * 0.16, Vector2(TILE, TILE) * 0.32), col)


func _draw_actor(a: Actor) -> void:
	var c := _center(a.pos)
	var alpha := 0.45 if a.status.has("stealth") else 1.0
	if a.is_player:
		draw_arc(c, TILE * 0.47, 0, TAU, 24, Color(UI.ACCENT, alpha), 2.0)
	draw_circle(c, TILE * 0.40, Color(a.color.darkened(0.6), alpha))
	draw_circle(c, TILE * 0.34, Color(a.color, alpha))
	draw_string(_font, Vector2(c.x - TILE / 2.0, c.y + 6), a.glyph, HORIZONTAL_ALIGNMENT_CENTER, TILE, 17, Color(0, 0, 0, alpha))
	if a.hp < a.max_hp:
		var w := TILE - 6.0
		var top := Vector2(c.x - w / 2.0, c.y - TILE * 0.5)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.8))
		var frac := clampf(float(a.hp) / a.max_hp, 0.0, 1.0)
		var col := Color("#7ed37e") if a.faction == Actor.PARTY else Color("#ff6b5e")
		draw_rect(Rect2(top, Vector2(w * frac, 4)), col)
	if a.status.has("poison"):
		draw_circle(c + Vector2(TILE * 0.32, TILE * 0.32), 4, Color("#a35bd6"))
