class_name NotationCard
extends PanelContainer
## Card explaining a chord symbol's suffix ("what does 6/9 mean?") or a
## scale's name and formula. Shown when the name is tapped in Chords,
## Practice and Scales.

## The chord quality or scale id currently explained.
var topic := ""
var _title: Label
var _text: Label


## compact uses smaller text, for screens that also need room for a list.
func _init(compact := false) -> void:
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8 if compact else 12)
	add_child(box)
	_title = AppTheme.label("", AppTheme.FONT_BODY if compact else AppTheme.FONT_LARGE, AppTheme.ACCENT)
	_text = AppTheme.label("", AppTheme.FONT_SMALL if compact else AppTheme.FONT_BODY)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	box.add_child(_text)


func show_chord(quality: String) -> void:
	topic = quality
	_title.text = "What does \"%s\" mean?" % quality
	_text.text = Theory.chord_explanation(quality)


func show_scale(scale: String) -> void:
	topic = scale
	_title.text = "What is %s?" % Theory.SCALES[scale].name
	_text.text = Theory.scale_explanation(scale)


## The big tappable chord or scale name that opens the card: a flat button that looks
## like a label.
static func make_symbol_button(font_size: int) -> Button:
	var b := AppTheme.button("")
	b.flat = true
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, AppTheme.ACCENT)
	return b
