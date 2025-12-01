## Dockable panel wrapper with header, collapse, close, and drag-drop functionality
## Panels can be dragged and dropped to rearrange within or between columns
class_name DockPanel
extends PanelContainer

signal collapse_changed(panel_name: String, is_collapsed: bool)
signal panel_visibility_changed(panel_name: String, is_visible: bool)
signal drag_started(panel: DockPanel)
signal drag_ended(panel: DockPanel)
signal drop_requested(panel: DockPanel, target_container: Control, drop_position: int)

@export var panel_title: String = "Panel"
@export var panel_icon: String = "📊"
@export var panel_name: String = ""
@export var can_close: bool = true
@export var can_collapse: bool = true
@export var can_drag: bool = true

var is_collapsed: bool = false
var is_dragging: bool = false
var drag_preview: Control = null

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
	
	## Setup drag handle if it exists
	if drag_handle:
		drag_handle.visible = can_drag
		drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	
	## Make the header draggable
	var header = $VBox/Header
	if header and can_drag:
		header.gui_input.connect(_on_header_gui_input)

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

#region Drag and Drop

func _on_header_gui_input(event: InputEvent) -> void:
	if not can_drag:
		return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag()
			else:
				_end_drag()

func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if not can_drag:
		return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag()
			else:
				_end_drag()

func _start_drag() -> void:
	is_dragging = true
	modulate = Color(1.0, 1.0, 1.0, 0.7)
	drag_started.emit(self)

func _end_drag() -> void:
	if is_dragging:
		is_dragging = false
		modulate = Color.WHITE
		drag_ended.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag:
		return null
	
	## Create visual preview
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	return {
		"type": "dock_panel",
		"panel": self,
		"panel_name": panel_name
	}

func _create_drag_preview() -> Control:
	var preview = PanelContainer.new()
	
	## Style the preview
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 1.0)
	preview.add_theme_stylebox_override("panel", style)
	
	## Add title label
	var label = Label.new()
	label.text = "%s %s" % [panel_icon, panel_title]
	label.add_theme_font_size_override("font_size", 14)
	preview.add_child(label)
	
	preview.custom_minimum_size = Vector2(150, 30)
	
	return preview

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "dock_panel":
		## Can't drop on itself
		return data.get("panel") != self
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "dock_panel":
		var source_panel: DockPanel = data.get("panel")
		if source_panel and source_panel != self:
			## Request to swap or insert
			var my_parent = get_parent()
			if my_parent:
				var my_index = my_parent.get_children().find(self)
				drop_requested.emit(source_panel, my_parent, my_index)

#endregion

#region Input Handling

func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_drag()

#endregion
