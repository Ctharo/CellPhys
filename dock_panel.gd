## Dockable panel wrapper with header, collapse, close, and drag-drop functionality
## Uses proper Godot 4.6+ drag-drop API for reliable panel rearrangement
class_name DockPanel
extends PanelContainer

signal collapse_changed(panel_name: String, is_collapsed: bool)
signal panel_visibility_changed(panel_name: String, is_visible: bool)
signal panel_dropped(source: DockPanel, target_column: Control, at_index: int)

@export var panel_title: String = "Panel"
@export var panel_icon: String = "📊"
@export var panel_name: String = ""
@export var can_close: bool = true
@export var can_collapse: bool = true
@export var can_drag: bool = true

var is_collapsed: bool = false

#region Node References

@onready var collapse_button: Button = %CollapseButton
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var content_margin: MarginContainer = %ContentMargin
@onready var drag_handle: Control = %DragHandle

#endregion

#region Setup

func _ready() -> void:
	_update_title()
	collapse_button.visible = can_collapse
	close_button.visible = can_close
	
	if drag_handle:
		drag_handle.visible = can_drag
	
	## Enable drop target behavior
	mouse_filter = Control.MOUSE_FILTER_PASS

func _update_title() -> void:
	if title_label:
		title_label.text = "%s %s" % [panel_icon, panel_title]

func set_title(title: String, icon: String = "") -> void:
	panel_title = title
	if icon != "":
		panel_icon = icon
	_update_title()

func get_content_container() -> VBoxContainer:
	return %Content

#endregion

#region Collapse/Expand

func set_collapsed(collapsed: bool) -> void:
	is_collapsed = collapsed
	if content_margin:
		content_margin.visible = not collapsed
	if collapse_button:
		collapse_button.text = "▶" if collapsed else "▼"
	collapse_changed.emit(panel_name, is_collapsed)

func toggle_collapsed() -> void:
	set_collapsed(not is_collapsed)

func _on_collapse_pressed() -> void:
	toggle_collapsed()

#endregion

#region Visibility

func show_panel() -> void:
	show()
	panel_visibility_changed.emit(panel_name, true)

func hide_panel() -> void:
	hide()
	panel_visibility_changed.emit(panel_name, false)

func _on_close_pressed() -> void:
	hide_panel()

#endregion

#region Drag and Drop - Godot 4.6+ API

## Called when drag starts from the header
func _get_drag_data(at_position: Vector2) -> Variant:
	if not can_drag:
		return null
	
	## Check if drag started from header area
	var header = $VBox/Header
	if not header:
		return null
	
	var header_rect = header.get_rect()
	if not header_rect.has_point(at_position):
		return null
	
	## Create visual drag preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	## Visual feedback on source
	modulate = Color(1.0, 1.0, 1.0, 0.5)
	
	return {
		"type": "dock_panel",
		"panel": self,
		"panel_name": panel_name
	}

func _create_drag_preview() -> Control:
	var preview = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.35, 0.55, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.65, 1.0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	preview.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "%s %s" % [panel_icon, panel_title]
	label.add_theme_font_size_override("font_size", 14)
	preview.add_child(label)
	
	preview.custom_minimum_size = Vector2(160, 36)
	
	return preview

## Called to check if this panel can receive a drop
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if data.get("type") != "dock_panel":
		return false
	## Can't drop on itself
	return data.get("panel") != self

## Called when something is dropped on this panel
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary) or data.get("type") != "dock_panel":
		return
	
	var source_panel: DockPanel = data.get("panel")
	if not source_panel or source_panel == self:
		return
	
	## Get target position (insert before this panel)
	var my_parent = get_parent()
	if my_parent:
		var my_index = get_index()
		panel_dropped.emit(source_panel, my_parent, my_index)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			## Reset visual state when drag ends
			modulate = Color.WHITE

#endregion
