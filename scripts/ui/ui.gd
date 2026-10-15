class_name UI
extends RefCounted
## Shared look and small widget helpers. Everything is built in code (no art assets yet).

const BG := Color("#14161d")
const PANEL := Color("#1f2330")
const ACCENT := Color("#e8a33d")
const TEXT := Color("#e6e9f0")
const DIM := Color("#9aa3b5")
const BAD := Color("#ff6b5e")
const GOOD := Color("#7ed37e")

const CONTROLS_HELP := """Move: arrow keys, WASD (ZQSD on AZERTY), numpad, or click a tile
Diagonals: Q / E / Z / C (A / E / W / C on AZERTY) or numpad 7 9 1 3
Attack: move into a monster      Wait a turn: Space or numpad 5
Enter: step through a portal     I: bag      1-4: essence skills
R: rest until healed     T: make camp (sleep 6 h)     H: help     Esc: close
Holding a key keeps walking, but stops when a monster appears or is within 2 tiles."""

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("#343a4d"), 12))
	t.set_stylebox("panel", "Panel", _box(PANEL, Color("#343a4d"), 12))
	t.set_stylebox("normal", "Button", _box(Color("#2b3142"), Color("#3c4459"), 6))
	t.set_stylebox("hover", "Button", _box(Color("#39415a"), ACCENT.darkened(0.3), 6))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.45), ACCENT, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT.darkened(0.2), 6))
	t.set_stylebox("disabled", "Button", _box(Color("#1c2029"), Color("#2a2f3c"), 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#646b7d"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color("#343a4d"), 14))
	_theme = t
	return t


static func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size: int = 16, color: Color = TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 20)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#11131a")
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	var l := label("", 13)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	b.add_child(l)
	return b


static func set_bar(b: ProgressBar, value: float, max_value: float, text: String) -> void:
	b.max_value = maxf(1.0, max_value)
	b.value = value
	(b.get_child(0) as Label).text = text


static func separator() -> HSeparator:
	return HSeparator.new()


static func full_rect_bg(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, all)
	return m
