class_name AppTheme
extends RefCounted
## Shared colours and a touch-friendly Theme, sized for a 1080x2400 portrait
## viewport (roughly 2.6 px per dp on a Pixel-class phone).

const BG := Color("15171c")
const PANEL := Color("1f232b")
const BUTTON := Color("2a2f3a")
const BUTTON_HOVER := Color("343a47")
const ACCENT := Color("e0a030")
const TEXT := Color("eceff4")
const TEXT_DIM := Color("9aa3b2")
const ROOT := Color("e06c4c")
const TONE := Color("4ca0e0")
const GOOD := Color("5cb85c")
const BAD := Color("d9534f")

const FONT_SMALL := 34
const FONT_BODY := 44
const FONT_LARGE := 64
const FONT_HUGE := 96
## 48 dp minimum touch target.
const TOUCH := 130
const GAP := 18


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	t.set_stylebox("normal", "Button", _box(BUTTON))
	t.set_stylebox("hover", "Button", _box(BUTTON))
	t.set_stylebox("pressed", "Button", _box(ACCENT))
	t.set_stylebox("hover_pressed", "Button", _box(ACCENT))
	t.set_stylebox("disabled", "Button", _box(BUTTON.darkened(0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_hover_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.4))

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 28))
	t.set_stylebox("panel", "Panel", _box(PANEL, 0))

	# Thin scrollbars: dragging the content is the main way to scroll.
	var grabber := _box(BUTTON_HOVER, 6)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", _box(Color(0, 0, 0, 0), 6))

	t.set_stylebox("slider", "HSlider", _box(BUTTON, 10, 16))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT, 10, 16))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, 10, 16))
	t.set_icon("grabber", "HSlider", _circle(56, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _circle(56, TEXT))
	return t


## Paints a button in a solid colour in every state, e.g. to mark a quiz answer.
static func tint(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, _box(color))
	for state in ["font_color", "font_hover_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE)


static func untint(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.remove_theme_stylebox_override(state)
	for state in ["font_color", "font_hover_color", "font_disabled_color"]:
		b.remove_theme_color_override(state)


static func _box(color: Color, radius := 22, content_margin := 20) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(content_margin)
	return b


static func _circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(color, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## A label with a theme font size and colour, the most common UI building block.
static func label(text: String, size := FONT_BODY, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, toggle := false, group: ButtonGroup = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = TOUCH
	b.toggle_mode = toggle
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	return b
