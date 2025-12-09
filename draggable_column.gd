## DraggableColumn - Container that accepts dock panel drops
## Uses proper Godot 4.6+ drag-drop API for reliable panel rearrangement
class_name DraggableColumn
extends VSplitContainer

signal panel_dropped(panel: DockPanel, at_index: int)
signal panel_moved_out(panel: DockPanel)

var drop_indicator: Panel = null
var hover_index: int = -1

#region Initialization

func _ready() -> void:
	_create_drop_indicator()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _create_drop_indicator() -> void:
	drop_indicator = Panel.new()
	drop_indicator.custom_minimum_size = Vector2(0, 6)
	drop_indicator.visible = false
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 1.0, 0.9)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	drop_indicator.add_theme_stylebox_override("panel", style)

#endregion

#region Drag and Drop - Godot 4.6+ API

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		_hide_drop_indicator()
		return false
	if data.get("type") != "dock_panel":
		_hide_drop_indicator()
		return false
	
	## Show drop indicator while hovering
	_show_drop_indicator(at_position)
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	_hide_drop_indicator()
	
	if not (data is Dictionary) or data.get("type") != "dock_panel":
		return
	
	var panel: DockPanel = data.get("panel")
	if not panel:
		return
	
	## Calculate drop index
	var target_index = _calculate_drop_index(at_position)
	
	## Remove from old parent
	var old_parent = panel.get_parent()
	var was_in_same_column = old_parent == self
	var old_index = panel.get_index() if was_in_same_column else -1
	
	if old_parent and old_parent != self:
		old_parent.remove_child(panel)
		panel_moved_out.emit(panel)
	elif old_parent == self:
		remove_child(panel)
	
	## Adjust index if moving within same column
	if was_in_same_column and old_index < target_index:
		target_index -= 1
	
	## Add to new position
	add_child(panel)
	if target_index >= 0 and target_index < get_child_count():
		move_child(panel, target_index)
	
	panel_dropped.emit(panel, target_index)

func _calculate_drop_index(at_position: Vector2) -> int:
	var local_y = at_position.y
	var children = get_children()
	
	for i in range(children.size()):
		var child = children[i]
		if child == drop_indicator:
			continue
		if not child is Control:
			continue
		
		var child_rect = child.get_rect()
		var child_center_y = child_rect.position.y + child_rect.size.y / 2.0
		
		if local_y < child_center_y:
			return i
	
	return children.size()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			_hide_drop_indicator()

#endregion

#region Drop Indicator

func _show_drop_indicator(at_position: Vector2) -> void:
	var target_index = _calculate_drop_index(at_position)
	
	## Add indicator to scene if not already
	if not drop_indicator.get_parent():
		add_child(drop_indicator)
	
	drop_indicator.visible = true
	
	## Position indicator
	var child_count = get_child_count()
	var indicator_idx = drop_indicator.get_index()
	
	## Calculate where to move indicator
	var actual_target = target_index
	if indicator_idx < target_index:
		actual_target = target_index  ## Already adjusted
	
	if actual_target != indicator_idx:
		if actual_target >= child_count:
			move_child(drop_indicator, child_count - 1)
		else:
			move_child(drop_indicator, actual_target)
	
	hover_index = target_index

func _hide_drop_indicator() -> void:
	if drop_indicator:
		drop_indicator.visible = false
	hover_index = -1

#endregion

#region Panel Management

## Move a panel within this column
func move_panel(panel: DockPanel, to_index: int) -> void:
	if panel.get_parent() != self:
		return
	
	var current_index = panel.get_index()
	if current_index != to_index:
		move_child(panel, to_index)

## Get index of a panel in this column
func get_panel_index(panel: DockPanel) -> int:
	return panel.get_index() if panel.get_parent() == self else -1

## Check if this column contains a panel
func has_panel(panel: DockPanel) -> bool:
	return panel.get_parent() == self

## Get all dock panels in this column
func get_dock_panels() -> Array[DockPanel]:
	var panels: Array[DockPanel] = []
	for child in get_children():
		if child is DockPanel:
			panels.append(child)
	return panels

#endregion
