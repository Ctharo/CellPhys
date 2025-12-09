## Integration snippet for main.gd
## Add this code to integrate LayoutSettingsDialog

#region Layout Settings Integration

## Add these variables at the top of main.gd
var layout_settings_dialog: LayoutSettingsDialog = null

## Add to _ready() or _setup_ui():
func _setup_layout_settings() -> void:
	## Create the dialog
	layout_settings_dialog = LayoutSettingsDialog.new()
	layout_settings_dialog.settings_changed.connect(_on_layout_settings_changed)
	add_child(layout_settings_dialog)
	
	## Add menu item to View menu (or create a Settings menu)
	var popup = view_menu.get_popup()
	popup.add_separator()
	popup.add_item("Layout Settings...", 200)  ## Use ID 200 or any unused ID

## Add to _on_view_menu_pressed() handler:
func _handle_view_menu_id(id: int) -> void:
	match id:
		## ... existing cases ...
		200:  ## Layout Settings
			layout_settings_dialog.show_dialog()

## Callback when layout settings change
func _on_layout_settings_changed() -> void:
	## Update all concentration panels to apply new sizing
	if molecule_panel:
		molecule_panel.apply_element_sizing()
	if enzyme_reaction_panel:
		enzyme_reaction_panel.apply_element_sizing()
	## Add other panels as needed

#endregion

## Alternative: Add a toolbar button
func _add_layout_settings_button() -> void:
	var settings_btn = Button.new()
	settings_btn.text = "⚙"
	settings_btn.tooltip_text = "Layout Settings"
	settings_btn.pressed.connect(func(): layout_settings_dialog.show_dialog())
	## Add to toolbar HBox
	# toolbar_hbox.add_child(settings_btn)
