class_name BottomSheet
extends Control
## Slide-up settings panel over a dimmed backdrop. Add controls to `content`,
## then call open(). Tapping the backdrop closes it.

signal closed

var content: VBoxContainer
var _panel: PanelContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			close())
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", AppTheme.GAP)
	_panel.add_child(content)


func open() -> void:
	visible = true
	var h := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(size.x, h)
	_panel.position.y = size.y
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
		.tween_property(_panel, "position:y", size.y - h, 0.25)


func close() -> void:
	if not visible:
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "position:y", size.y, 0.2)
	tw.tween_callback(func(): visible = false)
	closed.emit()


## Grid of toggle buttons, a common building block for settings.
static func toggle_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", AppTheme.GAP)
	grid.add_theme_constant_override("v_separation", AppTheme.GAP)
	return grid
