## PathwayBrowser - Dialog for browsing, previewing, and loading pathway presets
## Shows built-in pathways and user-saved pathways
class_name PathwayBrowser
extends Window

signal pathway_selected(preset: PathwayPreset)
signal snapshot_selected(snapshot: SimulationSnapshot)

#region UI References

var pathway_list: ItemList
var preview_panel: RichTextLabel
var load_button: Button
var cancel_button: Button
var tab_container: TabContainer

var builtin_pathways: Array[PathwayPreset] = []
var user_snapshots: Array[SimulationSnapshot] = []
var current_selection: Resource = null

#endregion

#region Initialization

func _init() -> void:
	title = "Load Pathway or Snapshot"
	size = Vector2i(700, 500)
	exclusive = true
	unresizable = false

func _ready() -> void:
	_create_ui()
	_populate_builtin_pathways()
	_scan_user_snapshots()

func _create_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
	## Tab container for Built-in / User snapshots
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	## Built-in pathways tab
	var builtin_split = HSplitContainer.new()
	builtin_split.name = "Built-in Pathways"
	tab_container.add_child(builtin_split)
	
	pathway_list = ItemList.new()
	pathway_list.custom_minimum_size = Vector2(250, 0)
	pathway_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pathway_list.item_selected.connect(_on_pathway_selected)
	pathway_list.item_activated.connect(_on_item_activated)
	builtin_split.add_child(pathway_list)
	
	preview_panel = RichTextLabel.new()
	preview_panel.bbcode_enabled = true
	preview_panel.custom_minimum_size = Vector2(350, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builtin_split.add_child(preview_panel)
	
	## User snapshots tab
	var user_panel = VBoxContainer.new()
	user_panel.name = "My Snapshots"
	tab_container.add_child(user_panel)
	
	var user_label = Label.new()
	user_label.text = "Saved snapshots will appear here.\nSnapshots are saved to: user://snapshots/"
	user_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	user_panel.add_child(user_label)
	
	## Bottom button bar
	var button_bar = HBoxContainer.new()
	button_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(button_bar)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_bar.add_child(spacer)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_bar.add_child(cancel_button)
	
	load_button = Button.new()
	load_button.text = "Load"
	load_button.disabled = true
	load_button.pressed.connect(_on_load_pressed)
	button_bar.add_child(load_button)

func _populate_builtin_pathways() -> void:
	builtin_pathways.clear()
	pathway_list.clear()
	
	## Create built-in pathways
	builtin_pathways.append(PathwayPreset.create_linear_pathway(3))
	builtin_pathways.append(PathwayPreset.create_linear_pathway(5))
	builtin_pathways.append(PathwayPreset.create_feedback_inhibition())
	builtin_pathways.append(PathwayPreset.create_branched_pathway())
	builtin_pathways.append(PathwayPreset.create_oscillator())
	
	## Populate list
	for preset in builtin_pathways:
		var idx = pathway_list.add_item(preset.pathway_name)
		pathway_list.set_item_tooltip(idx, preset.description)

func _scan_user_snapshots() -> void:
	user_snapshots.clear()
	
	var dir = DirAccess.open("user://snapshots/")
	if not dir:
		## Create directory if it doesn't exist
		DirAccess.make_dir_absolute("user://snapshots/")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "user://snapshots/" + file_name
			var snapshot = SimulationSnapshot.load_from_file(path)
			if snapshot:
				user_snapshots.append(snapshot)
		file_name = dir.get_next()

#endregion

#region Event Handlers

func _on_pathway_selected(index: int) -> void:
	if index < 0 or index >= builtin_pathways.size():
		current_selection = null
		preview_panel.text = ""
		load_button.disabled = true
		return
	
	var preset = builtin_pathways[index]
	current_selection = preset
	preview_panel.text = preset.get_summary()
	load_button.disabled = false

func _on_item_activated(index: int) -> void:
	_on_pathway_selected(index)
	_on_load_pressed()

func _on_load_pressed() -> void:
	if current_selection is PathwayPreset:
		pathway_selected.emit(current_selection)
	elif current_selection is SimulationSnapshot:
		snapshot_selected.emit(current_selection)
	hide()

func _on_cancel_pressed() -> void:
	hide()

#endregion
