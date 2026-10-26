class_name OptionList
extends ScrollContainer
## Scrollable, grouped list of toggle buttons built from Theory.CHORDS or
## Theory.SCALES. Replaces dropdowns, which are awkward on a phone.
##
## Buttons pass input through so a drag on them scrolls the list; a tap that
## turns out to be a scroll is ignored instead of changing the selection.

signal selected(key: String)

const DRAG_TOLERANCE := 12

var current := ""
var _buttons := {}
var _scroll_at_down := 0


func _init(table: Dictionary, columns: int, text_for: Callable) -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep a row and a half visible (so it still reads as scrollable) even when
	# an explanation card is open.
	custom_minimum_size.y = int(AppTheme.TOUCH * 1.5) + AppTheme.GAP * 2
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", AppTheme.GAP)
	add_child(box)
	for group in Theory.groups(table):
		box.add_child(AppTheme.label(group, AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", AppTheme.GAP)
		grid.add_theme_constant_override("v_separation", AppTheme.GAP)
		box.add_child(grid)
		for key in table:
			if table[key].group != group:
				continue
			var b := AppTheme.button(text_for.call(key), true)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.button_down.connect(func(): _scroll_at_down = scroll_vertical)
			b.pressed.connect(_on_pressed.bind(key))
			grid.add_child(b)
			_buttons[key] = b


func select(key: String) -> void:
	current = key
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == key)


## Scrolls so the selected button is visible, e.g. after a jump from another tab.
func reveal_selected() -> void:
	if _buttons.has(current):
		ensure_control_visible(_buttons[current])


func _on_pressed(key: String) -> void:
	if absi(scroll_vertical - _scroll_at_down) > DRAG_TOLERANCE:
		select(current)
		return
	select(key)
	selected.emit(key)
