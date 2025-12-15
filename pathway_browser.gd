## PathwayBrowser - Dialog for browsing, previewing, and loading pathway presets
## Shows built-in pathways (real biochemistry) and user-saved pathways
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
	size = Vector2i(750, 550)
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
	pathway_list.custom_minimum_size = Vector2(280, 0)
	pathway_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pathway_list.item_selected.connect(_on_pathway_selected)
	pathway_list.item_activated.connect(_on_item_activated)
	builtin_split.add_child(pathway_list)
	
	preview_panel = RichTextLabel.new()
	preview_panel.bbcode_enabled = true
	preview_panel.custom_minimum_size = Vector2(400, 0)
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
	
	## Default/Simple pathway
	builtin_pathways.append(PathwayPreset.create_default(4))
	
	## Real biochemistry pathways
	builtin_pathways.append(PathwayPreset.create_glycolysis())
	builtin_pathways.append(PathwayPreset.create_krebs_cycle())
	builtin_pathways.append(PathwayPreset.create_pentose_phosphate())
	builtin_pathways.append(PathwayPreset.create_beta_oxidation())
	builtin_pathways.append(PathwayPreset.create_urea_cycle())
	
	## Populate list with icons based on difficulty
	for preset in builtin_pathways:
		var display_name = preset.pathway_name
		var idx = pathway_list.add_item(display_name)
		pathway_list.set_item_tooltip(idx, preset.description)


func _scan_user_snapshots() -> void:
	user_snapshots.clear()
	
	var dir = DirAccess.open("user://snapshots/")
	if not dir:
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
	preview_panel.text = _format_preview(preset)
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

#region Formatting

func _format_preview(preset: PathwayPreset) -> String:
	var lines: Array[String] = []
	
	lines.append("[b][font_size=18]%s[/font_size][/b]" % preset.pathway_name)
	lines.append("")
	lines.append("[color=gray]Difficulty: %s[/color]" % "★".repeat(preset.difficulty))
	
	if not preset.tags.is_empty():
		lines.append("[color=gray]Tags: %s[/color]" % ", ".join(preset.tags))
	
	lines.append("")
	lines.append(preset.description)
	lines.append("")
	lines.append("[b]Components:[/b]")
	lines.append("  • %d molecules" % preset.molecules.size())
	lines.append("  • %d enzymes" % preset.enzymes.size())
	lines.append("  • %d genes" % preset.genes.size())
	
	## Count total reactions
	var rxn_count = 0
	for enz in preset.enzymes:
		rxn_count += enz.reactions.size()
	lines.append("  • %d reactions" % rxn_count)
	
	lines.append("")
	lines.append("[b]Key Molecules:[/b]")
	var mol_list: Array[String] = []
	for i in range(mini(8, preset.molecules.size())):
		mol_list.append(preset.molecules[i].molecule_name)
	lines.append("  " + ", ".join(mol_list))
	if preset.molecules.size() > 8:
		lines.append("  ... and %d more" % (preset.molecules.size() - 8))
	
	lines.append("")
	lines.append("[b]Key Enzymes:[/b]")
	var enz_list: Array[String] = []
	for i in range(mini(6, preset.enzymes.size())):
		enz_list.append(preset.enzymes[i].enzyme_name)
	lines.append("  " + ", ".join(enz_list))
	if preset.enzymes.size() > 6:
		lines.append("  ... and %d more" % (preset.enzymes.size() - 6))
	
	lines.append("")
	lines.append("[color=gray]Suggested duration: %.0f seconds[/color]" % preset.suggested_duration)
	
	return "\n".join(lines)

#endregion
