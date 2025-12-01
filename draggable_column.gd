## DraggableColumn - Container that accepts dock panel drops and shows drop indicators
## Used by VSplitContainer columns to enable drag-drop panel rearrangement
class_name DraggableColumn
extends VSplitContainer

signal panel_dropped(panel: DockPanel, at_index: int)
signal panel_moved_out(panel: DockPanel)

var drop_indicator: Panel = null
var is_drop_target: bool = false
var drop_index: int = -1

#region Initialization

func _ready() -> void:
	_create_drop_indicator()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _create_drop_indicator() -> void:
	drop_indicator = Panel.new()
	drop_indicator.custom_minimum_size = Vector2(0, 4)
	drop_indicator.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	drop_indicator.add_theme_stylebox_override("panel", style)

#endregion

#region Drag and Drop

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "dock_panel":
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	_hide_drop_indicator()
	
	if not (data is Dictionary) or data.get("type") != "dock_panel":
		return
	
	var panel: DockPanel = data.get("panel")
	if not panel:
		return
	
	## Calculate drop index based on position
	var target_index = _get_drop_index(at_position)
	
	## Remove from old parent
	var old_parent = panel.get_parent()
	if old_parent:
		if old_parent != self:
			panel_moved_out.emit(panel)
		old_parent.remove_child(panel)
	
	## Add to new position
	if target_index >= get_child_count():
		add_child(panel)
	else:
		add_child(panel)
		move_child(panel, target_index)
	
	panel_dropped.emit(panel, target_index)

func _get_drop_index(at_position: Vector2) -> int:
	var local_y = at_position.y
	var children = get_children()
	
	for i in range(children.size()):
		var child = children[i]
		if child == drop_indicator:
			continue
		if not child is Control:
			continue
		
		var child_rect = child.get_rect()
		var child_center_y = child_rect.position.y + child_rect.size.y / 2
		
		if local_y < child_center_y:
			return i
	
	return children.size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		## Show we're a valid drop target
		pass
	elif what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_instance_valid(get_viewport()):
		var drag_data = get_viewport().gui_get_drag_data()
		if drag_data is Dictionary and drag_data.get("type") == "dock_panel":
			_show_drop_indicator(event.position)

func _show_drop_indicator(at_position: Vector2) -> void:
	var target_index = _get_drop_index(at_position)
	
	## Don't show indicator if nothing would change
	if not drop_indicator.get_parent():
		add_child(drop_indicator)
	
	drop_indicator.visible = true
	
	## Position the indicator
	if target_index < get_child_count():
		move_child(drop_indicator, target_index)
	else:
		move_child(drop_indicator, get_child_count() - 1)

func _hide_drop_indicator() -> void:
	if drop_indicator:
		drop_indicator.visible = false

#endregion

#region Panel Management

## Move a panel within this column
func move_panel(panel: DockPanel, to_index: int) -> void:
	if panel.get_parent() != self:
		return
	
	var current_index = get_children().find(panel)
	if current_index != to_index:
		move_child(panel, to_index)

## Get index of a panel in this column
func get_panel_index(panel: DockPanel) -> int:
	return get_children().find(panel)

## Check if this column contains a panel
func has_panel(panel: DockPanel) -> bool:
	return panel.get_parent() == self

#endregion
