## SimulationSettingsDialog - Comprehensive UI for editing simulation configuration
## Supports profile management: create, edit, save, load, delete
class_name SimulationSettingsDialog
extends Window

signal config_applied(config: SimulationConfig)
signal config_saved(config: SimulationConfig, path: String)

#region State

var current_config: SimulationConfig = null
var is_editing_existing: bool = false
var current_profile_path: String = ""

#endregion

#region UI References

var main_tabs: TabContainer
var profile_list: ItemList
var preview_label: RichTextLabel
var editor_scroll: ScrollContainer
var editor_container: VBoxContainer

## Profile management buttons
var new_btn: Button
var duplicate_btn: Button
var delete_btn: Button
var save_btn: Button

## Editor controls (populated dynamically)
var editor_controls: Dictionary = {}

## Bottom buttons
var apply_btn: Button
var cancel_btn: Button

#endregion

#region Setup

func _init() -> void:
	title = "Simulation Settings"
	size = Vector2(900, 700)
	min_size = Vector2(700, 500)
	exclusive = false
	transient = true
	close_requested.connect(_on_close_requested)

func _ready() -> void:
	_create_ui()
	_populate_profile_list()
	_select_default_profile()

func _create_ui() -> void:
	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 12)
	main_margin.add_theme_constant_override("margin_right", 12)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(main_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_margin.add_child(main_vbox)
	
	## Main content area with tabs
	main_tabs = TabContainer.new()
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(main_tabs)
	
	## Tab 1: Profile Browser
	_create_browser_tab()
	
	## Tab 2: Editor
	_create_editor_tab()
	
	## Bottom button bar
	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(bottom_bar)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)
	
	apply_btn = Button.new()
	apply_btn.text = "Apply & Start"
	apply_btn.pressed.connect(_on_apply_pressed)
	bottom_bar.add_child(apply_btn)
	
	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_close_requested)
	bottom_bar.add_child(cancel_btn)

func _create_browser_tab() -> void:
	var browser_panel = HSplitContainer.new()
	browser_panel.name = "Profiles"
	main_tabs.add_child(browser_panel)
	
	## Left side: profile list with buttons
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(250, 0)
	left_vbox.add_theme_constant_override("separation", 6)
	browser_panel.add_child(left_vbox)
	
	var list_label = Label.new()
	list_label.text = "Available Profiles"
	list_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(list_label)
	
	profile_list = ItemList.new()
	profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_list.item_selected.connect(_on_profile_selected)
	profile_list.item_activated.connect(_on_profile_activated)
	left_vbox.add_child(profile_list)
	
	## Profile management buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(btn_row)
	
	new_btn = Button.new()
	new_btn.text = "New"
	new_btn.tooltip_text = "Create new profile from defaults"
	new_btn.pressed.connect(_on_new_pressed)
	btn_row.add_child(new_btn)
	
	duplicate_btn = Button.new()
	duplicate_btn.text = "Duplicate"
	duplicate_btn.tooltip_text = "Copy selected profile"
	duplicate_btn.pressed.connect(_on_duplicate_pressed)
	btn_row.add_child(duplicate_btn)
	
	delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.tooltip_text = "Delete selected profile"
	delete_btn.pressed.connect(_on_delete_pressed)
	btn_row.add_child(delete_btn)
	
	## Right side: preview
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	browser_panel.add_child(right_vbox)
	
	var preview_header = HBoxContainer.new()
	right_vbox.add_child(preview_header)
	
	var preview_title = Label.new()
	preview_title.text = "Profile Preview"
	preview_title.add_theme_font_size_override("font_size", 14)
	preview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_header.add_child(preview_title)
	
	var edit_btn = Button.new()
	edit_btn.text = "Edit →"
	edit_btn.pressed.connect(_on_edit_pressed)
	preview_header.add_child(edit_btn)
	
	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_label.add_theme_stylebox_override("normal", _create_panel_style())
	right_vbox.add_child(preview_label)

func _create_editor_tab() -> void:
	var editor_panel = VBoxContainer.new()
	editor_panel.name = "Editor"
	editor_panel.add_theme_constant_override("separation", 8)
	main_tabs.add_child(editor_panel)
	
	## Header with profile name and save
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	editor_panel.add_child(header)
	
	var name_label = Label.new()
	name_label.text = "Profile Name:"
	header.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(200, 0)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	header.add_child(name_edit)
	editor_controls["profile_name"] = name_edit
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	
	save_btn = Button.new()
	save_btn.text = "💾 Save Profile"
	save_btn.pressed.connect(_on_save_pressed)
	header.add_child(save_btn)
	
	## Scrollable editor area
	editor_scroll = ScrollContainer.new()
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_panel.add_child(editor_scroll)
	
	editor_container = VBoxContainer.new()
	editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_container.add_theme_constant_override("separation", 16)
	editor_scroll.add_child(editor_container)
	
	## Create all editor sections
	_create_section_counts()
	_create_section_molecules()
	_create_section_enzymes()
	_create_section_reactions()
	_create_section_genes()
	_create_section_regulation()
	_create_section_pathway()
	_create_section_mutations()
	_create_section_evolution()
	_create_section_simulation()

#endregion

#region Editor Sections

func _create_section_counts() -> void:
	var section = _create_section("Generation Counts", "How many entities to create")
	_add_spin_row(section, "molecule_count", "Molecules", 2, 20, 1)
	_add_spin_row(section, "enzyme_count", "Enzymes", 1, 15, 1)
	_add_spin_row(section, "source_count", "Source Reactions", 0, 10, 1)
	_add_spin_row(section, "sink_count", "Sink Reactions", 0, 10, 1)

func _create_section_molecules() -> void:
	var section = _create_section("Molecule Parameters", "Default values for generated molecules")
	_add_spin_row(section, "default_molecule_concentration", "Default Concentration (mM)", 0.01, 100.0, 0.1)
	_add_spin_row(section, "molecule_concentration_variance", "Concentration Variance", 0.0, 50.0, 0.1)
	_add_spin_row(section, "default_potential_energy", "Default Energy (kJ/mol)", -50.0, 50.0, 1.0)
	_add_spin_row(section, "potential_energy_variance", "Energy Variance", 0.0, 30.0, 1.0)
	_add_spin_row(section, "structural_code_length", "Structure Code Length", 1, 10, 1)

func _create_section_enzymes() -> void:
	var section = _create_section("Enzyme Parameters", "Kinetic and stability settings")
	_add_spin_row(section, "default_enzyme_concentration", "Default Concentration (mM)", 0.0001, 1.0, 0.001)
	_add_spin_row(section, "enzyme_concentration_variance", "Concentration Variance", 0.0, 0.5, 0.001)
	_add_spin_row(section, "default_vmax", "Default Vmax (mM/s)", 0.1, 100.0, 0.5)
	_add_spin_row(section, "vmax_variance", "Vmax Variance", 0.0, 50.0, 0.5)
	_add_spin_row(section, "default_km", "Default Km (mM)", 0.01, 10.0, 0.1)
	_add_spin_row(section, "km_variance", "Km Variance", 0.0, 5.0, 0.1)
	_add_spin_row(section, "default_half_life", "Default Half-Life (s)", 10.0, 600.0, 10.0)
	_add_slider_row(section, "degradable_fraction", "Degradable Fraction", 0.0, 1.0)

func _create_section_reactions() -> void:
	var section = _create_section("Reaction Parameters", "Thermodynamic defaults")
	_add_spin_row(section, "default_delta_g", "Default ΔG° (kJ/mol)", -30.0, 0.0, 1.0)
	_add_spin_row(section, "delta_g_variance", "ΔG Variance", 0.0, 15.0, 1.0)
	_add_slider_row(section, "default_efficiency", "Default Efficiency", 0.1, 1.0)
	_add_slider_row(section, "efficiency_variance", "Efficiency Variance", 0.0, 0.3)
	_add_slider_row(section, "irreversible_fraction", "Irreversible Fraction", 0.0, 1.0)

func _create_section_genes() -> void:
	var section = _create_section("Gene Expression", "Protein synthesis settings")
	_add_check_row(section, "create_genes_for_enzymes", "Create Genes for Enzymes")
	_add_spin_row(section, "default_basal_rate", "Default Basal Rate (mM/s)", 0.00001, 0.01, 0.00001)
	_add_spin_row(section, "basal_rate_variance", "Basal Rate Variance", 0.0, 0.005, 0.00001)
	_add_slider_row(section, "regulation_probability", "Regulation Probability", 0.0, 1.0)
	_add_slider_row(section, "activator_vs_repressor", "Activator vs Repressor", 0.0, 1.0)

func _create_section_regulation() -> void:
	var section = _create_section("Regulation Parameters", "Transcription factor binding")
	_add_spin_row(section, "default_kd", "Default Kd (mM)", 0.1, 20.0, 0.1)
	_add_spin_row(section, "kd_variance", "Kd Variance", 0.0, 10.0, 0.1)
	_add_spin_row(section, "default_max_fold", "Default Max Fold Change", 1.0, 50.0, 1.0)
	_add_spin_row(section, "max_fold_variance", "Max Fold Variance", 0.0, 20.0, 1.0)
	_add_spin_row(section, "default_hill_coefficient", "Default Hill Coefficient", 0.5, 4.0, 0.1)
	_add_spin_row(section, "hill_variance", "Hill Variance", 0.0, 1.5, 0.1)

func _create_section_pathway() -> void:
	var section = _create_section("Pathway Structure", "Network topology")
	_add_option_row(section, "pathway_type", "Pathway Type", 
		["Random", "Linear", "Branched", "Cyclic", "Feedback"])
	_add_slider_row(section, "branching_probability", "Branching Probability", 0.0, 1.0)
	_add_check_row(section, "include_feedback_loops", "Include Feedback Loops")
	_add_spin_row(section, "feedback_loop_count", "Feedback Loop Count", 0, 5, 1)

func _create_section_mutations() -> void:
	var section = _create_section("Mutation System", "Random variation rates")
	_add_check_row(section, "enable_mutations", "Enable Mutations")
	_add_slider_row(section, "enzyme_mutation_rate", "Enzyme Mutation Rate", 0.0, 0.1)
	_add_slider_row(section, "duplication_rate", "Duplication Rate", 0.0, 0.05)
	_add_slider_row(section, "novel_enzyme_rate", "Novel Enzyme Rate", 0.0, 0.02)
	_add_slider_row(section, "gene_mutation_rate", "Gene Mutation Rate", 0.0, 0.05)

func _create_section_evolution() -> void:
	var section = _create_section("Evolution System", "Selection pressure")
	_add_check_row(section, "enable_evolution", "Enable Evolution")
	_add_spin_row(section, "selection_interval", "Selection Interval (s)", 1.0, 60.0, 1.0)
	_add_slider_row(section, "elimination_threshold", "Elimination Threshold", 0.0, 0.5)
	_add_spin_row(section, "fitness_boost_factor", "Fitness Boost Factor", 0.5, 2.0, 0.1)

func _create_section_simulation() -> void:
	var section = _create_section("Simulation Settings", "Runtime behavior")
	_add_spin_row(section, "default_time_scale", "Default Time Scale", 0.1, 10.0, 0.1)
	_add_check_row(section, "start_paused", "Start Paused")
	_add_spin_row(section, "history_length", "History Length", 100, 2000, 100)

#endregion

#region Editor Helpers

func _create_section(title: String, subtitle: String = "") -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	editor_container.add_child(section)
	
	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	section.add_child(header)
	
	if subtitle != "":
		var sub = Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		section.add_child(sub)
	
	var sep = HSeparator.new()
	section.add_child(sep)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	section.add_child(content)
	
	return content

func _add_spin_row(parent: Control, prop: String, label_text: String, 
		min_val: float, max_val: float, step_val: float) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step_val
	spin.custom_minimum_size = Vector2(120, 0)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_value_changed.bind(prop))
	row.add_child(spin)
	editor_controls[prop] = spin

func _add_slider_row(parent: Control, prop: String, label_text: String,
		min_val: float, max_val: float) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_value_changed.bind(prop))
	row.add_child(slider)
	
	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	
	slider.value_changed.connect(func(v): value_label.text = "%.2f" % v)
	
	editor_controls[prop] = slider
	editor_controls[prop + "_label"] = value_label

func _add_check_row(parent: Control, prop: String, label_text: String) -> void:
	var check = CheckBox.new()
	check.text = label_text
	check.toggled.connect(_on_check_changed.bind(prop))
	parent.add_child(check)
	editor_controls[prop] = check

func _add_option_row(parent: Control, prop: String, label_text: String, options: Array) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(150, 0)
	for i in range(options.size()):
		option.add_item(options[i], i)
	option.item_selected.connect(_on_option_changed.bind(prop))
	row.add_child(option)
	editor_controls[prop] = option

func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	return style

#endregion

#region Profile Management

func _populate_profile_list() -> void:
	profile_list.clear()
	
	## Builtin profiles
	var builtins = SimulationConfig.get_builtin_profiles()
	for config in builtins:
		var idx = profile_list.add_item("📦 " + config.profile_name)
		profile_list.set_item_metadata(idx, {"config": config, "builtin": true})
	
	## User profiles
	var user_profiles = SimulationConfig.get_user_profiles()
	if not user_profiles.is_empty():
		profile_list.add_item("─── User Profiles ───")
		profile_list.set_item_disabled(profile_list.item_count - 1, true)
		profile_list.set_item_selectable(profile_list.item_count - 1, false)
		
		for config in user_profiles:
			var idx = profile_list.add_item("📄 " + config.profile_name)
			profile_list.set_item_metadata(idx, {
				"config": config, 
				"builtin": false,
				"path": SimulationConfig.PROFILES_DIR + config.profile_name.to_snake_case() + ".tres"
			})

func _select_default_profile() -> void:
	if profile_list.item_count > 0:
		profile_list.select(0)
		_on_profile_selected(0)

func _load_config_to_editor(config: SimulationConfig) -> void:
	current_config = config
	
	## Load all values into editor controls
	for prop in editor_controls:
		if prop.ends_with("_label"):
			continue
		
		var control = editor_controls[prop]
		var value = config.get(prop) if prop in config else null
		
		if value == null:
			continue
		
		if control is SpinBox:
			control.value = value
		elif control is HSlider:
			control.value = value
			if editor_controls.has(prop + "_label"):
				editor_controls[prop + "_label"].text = "%.2f" % value
		elif control is CheckBox:
			control.button_pressed = value
		elif control is OptionButton:
			control.selected = value
		elif control is LineEdit:
			control.text = value

func _save_editor_to_config() -> void:
	if not current_config:
		return
	
	for prop in editor_controls:
		if prop.ends_with("_label"):
			continue
		
		var control = editor_controls[prop]
		
		if control is SpinBox:
			current_config.set(prop, control.value)
		elif control is HSlider:
			current_config.set(prop, control.value)
		elif control is CheckBox:
			current_config.set(prop, control.button_pressed)
		elif control is OptionButton:
			current_config.set(prop, control.selected)
		elif control is LineEdit:
			current_config.set(prop, control.text)

#endregion

#region Callbacks

func _on_profile_selected(index: int) -> void:
	var metadata = profile_list.get_item_metadata(index)
	if not metadata or not metadata.has("config"):
		return
	
	var config = metadata.config as SimulationConfig
	current_config = config
	is_editing_existing = not metadata.get("builtin", true)
	current_profile_path = metadata.get("path", "")
	
	## Update preview
	preview_label.text = config.get_summary()
	
	## Update button states
	delete_btn.disabled = metadata.get("builtin", true)

func _on_profile_activated(index: int) -> void:
	_on_profile_selected(index)
	_on_edit_pressed()

func _on_edit_pressed() -> void:
	if current_config:
		_load_config_to_editor(current_config)
		main_tabs.current_tab = 1  ## Switch to editor

func _on_new_pressed() -> void:
	current_config = SimulationConfig.create_default()
	current_config.profile_name = "New Profile"
	current_config.is_builtin = false
	is_editing_existing = false
	current_profile_path = ""
	_load_config_to_editor(current_config)
	main_tabs.current_tab = 1

func _on_duplicate_pressed() -> void:
	if current_config:
		current_config = current_config.duplicate_config()
		is_editing_existing = false
		current_profile_path = ""
		_load_config_to_editor(current_config)
		main_tabs.current_tab = 1

func _on_delete_pressed() -> void:
	if current_profile_path != "" and not current_config.is_builtin:
		SimulationConfig.delete_profile(current_profile_path)
		_populate_profile_list()
		_select_default_profile()

func _on_save_pressed() -> void:
	_save_editor_to_config()
	if current_config:
		var path = SimulationConfig.PROFILES_DIR + current_config.profile_name.to_snake_case() + ".tres"
		current_config.is_builtin = false
		var err = current_config.save_to_file(path)
		if err == OK:
			current_profile_path = path
			is_editing_existing = true
			_populate_profile_list()
			config_saved.emit(current_config, path)

func _on_apply_pressed() -> void:
	_save_editor_to_config()
	if current_config:
		config_applied.emit(current_config)
	hide()

func _on_close_requested() -> void:
	hide()

func _on_name_changed(new_name: String) -> void:
	if current_config:
		current_config.profile_name = new_name

func _on_value_changed(_value: float, prop: String) -> void:
	## Auto-update config as user edits
	if current_config and editor_controls.has(prop):
		var control = editor_controls[prop]
		if control is SpinBox:
			current_config.set(prop, control.value)
		elif control is HSlider:
			current_config.set(prop, control.value)

func _on_check_changed(pressed: bool, prop: String) -> void:
	if current_config:
		current_config.set(prop, pressed)

func _on_option_changed(index: int, prop: String) -> void:
	if current_config:
		current_config.set(prop, index)

#endregion

#region Public API

func show_dialog(config: SimulationConfig = null) -> void:
	if config:
		current_config = config
		_load_config_to_editor(config)
		main_tabs.current_tab = 1
	else:
		_populate_profile_list()
		_select_default_profile()
		main_tabs.current_tab = 0
	
	popup_centered()

#endregion
