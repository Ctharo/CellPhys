## Dockable panel wrapper with header, collapse, and close functionality
class_name DockPanel
extends PanelContainer

signal visibility_changed(panel_name: String, is_visible: bool)
signal collapse_changed(panel_name: String, is_collapsed: bool)

@export var panel_title: String = "Panel"
@export var panel_icon: String = "📊"
@export var panel_name: String = ""
@export var can_close: bool = true
@export var can_collapse: bool = true

@onready var collapse_button: Button = %CollapseButton
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var content_margin: MarginContainer = %ContentMargin
@onready var content: VBoxContainer = %Content

var is_collapsed: bool = false

#region Setup

func _ready() -> void:
	_update_title()
	collapse_button.visible = can_collapse
	close_button.visible = can_close

func _update_title() -> void:
	if title_label:
		title_label.text = "%s %s" % [panel_icon, panel_title]

func set_title(title: String, icon: String = "") -> void:
	panel_title = title
	if icon != "":
		panel_icon = icon
	_update_title()

func get_content_container() -> VBoxContainer:
	return content

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
	visibility_changed.emit(panel_name, true)

func hide_panel() -> void:
	hide()
	visibility_changed.emit(panel_name, false)

func _on_close_pressed() -> void:
	hide_panel()

#endregion
