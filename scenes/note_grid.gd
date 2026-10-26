class_name NoteGrid
extends GridContainer
## 6x2 grid of the 12 roots. One tap picks a root.

signal root_selected(index: int)

var selected := 0
var _buttons: Array[Button] = []


func _init() -> void:
	columns = 6
	add_theme_constant_override("h_separation", AppTheme.GAP)
	add_theme_constant_override("v_separation", AppTheme.GAP)
	for i in Theory.ROOTS.size():
		var b := AppTheme.button(Theory.ROOTS[i], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
		_buttons.append(b)
	select(0)


func select(index: int) -> void:
	selected = index
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == index)


func _on_pressed(index: int) -> void:
	select(index)
	root_selected.emit(index)
