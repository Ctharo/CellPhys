## UI Manager for Enzyme Simulator
## Handles all UI building, updating, and event handling
## Separated from simulation logic

class_name SimulatorUI
extends Control

var simulator: EnzymeSimulator

## UI element storage
var molecule_ui_elements: Dictionary = {}
var enzyme_list_buttons: Dictionary = {}

## UI References
var stats_label: Label
var pause_button: Button
var system_energetics_label: Label
var molecules_panel: VBoxContainer
var enzyme_list_container: VBoxContainer
var enzyme_detail_container: VBoxContainer
var molecule_detail_container: VBoxContainer

func _init(sim: EnzymeSimulator) -> void:
	simulator = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)

func build_ui() -> void:
	## Create background
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.118, 0.235, 0.447)
	add_child(background)
	
	## Create main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	## Main horizontal layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	## Build left and right panels
	build_left_panel(hbox)
	build_right_panel(hbox)

func build_left_panel(parent: HBoxContainer) -> void:
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.7
	left_panel.add_theme_constant_override("separation", 20)
	parent.add_child(left_panel)
	
	## Title
	var title = Label.new()
	title.text = "🧬 Enzyme Simulator"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Thermodynamic Regulation"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(subtitle)
	
	## Stats and thermodynamic summary
	var stats_thermo_vbox = VBoxContainer.new()
	stats_thermo_vbox.add_theme_constant_override("separation", 10)
	left_panel.add_child(stats_thermo_vbox)
	
	stats_label = Label.new()
	stats_label.text = "Time: 0.0s | Iteration: 0"
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_thermo_vbox.add_child(stats_label)
	
	system_energetics_label = Label.new()
	system_energetics_label.name = "SystemEnergetics"
	system_energetics_label.text = "⚡ System: Forward: 0.0 | Reverse: 0.0 | Net: 0.0 mM/s"
	system_energetics_label.add_theme_font_size_override("font_size", 13)
	system_energetics_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	system_energetics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_thermo_vbox.add_child(system_energetics_label)
	
	## Control buttons
	var control_hbox = HBoxContainer.new()
	control_hbox.add_theme_constant_override("separation", 15)
	control_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(control_hbox)
	
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(120, 40)
	pause_button.pressed.connect(simulator._on_pause_button_pressed)
	pause_button.pressed.connect(func(): pause_button.text = "Resume" if simulator.is_paused else "Pause")
	control_hbox.add_child(pause_button)
	
	var reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(120, 40)
	reset_button.pressed.connect(simulator._on_reset_button_pressed)
	control_hbox.add_child(reset_button)
	
	## Molecules panel
	build_molecules_panel(left_panel)
	
	## Molecule detail panel
	build_molecule_detail_panel(left_panel)

func build_molecules_panel(parent: VBoxContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "📊 Molecules"
	title.add_theme_color_override("font_color", Color(0.3, 0.686, 0.314))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+ Add Molecule"
	add_btn.pressed.connect(simulator._on_add_molecule_pressed)
	vbox.add_child(add_btn)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	molecules_panel = VBoxContainer.new()
	molecules_panel.add_theme_constant_override("separation", 5)
	molecules_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(molecules_panel)

func build_molecule_detail_panel(parent: VBoxContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Molecule Details"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	molecule_detail_container = VBoxContainer.new()
	molecule_detail_container.add_theme_constant_override("separation", 10)
	molecule_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(molecule_detail_container)
	
	var placeholder = Label.new()
	placeholder.text = "Click a molecule info button to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)

func build_right_panel(parent: HBoxContainer) -> void:
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.5
	right_panel.add_theme_constant_override("separation", 20)
	parent.add_child(right_panel)
	
	## Header with add button
	var header = HBoxContainer.new()
	right_panel.add_child(header)
	
	var title = Label.new()
	title.text = "⚗️ Enzymes & Reactions"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.3, 0.686, 0.314))
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+ Add Enzyme"
	add_btn.custom_minimum_size = Vector2(150, 40)
	add_btn.pressed.connect(simulator._on_add_enzyme_pressed)
	header.add_child(add_btn)
	
	## Split container for list and details
	var hsplit = HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(hsplit)
	
	build_enzyme_list_panel(hsplit)
	build_enzyme_detail_panel(hsplit)

func build_enzyme_list_panel(parent: HSplitContainer) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Enzyme List"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	enzyme_list_container = VBoxContainer.new()
	enzyme_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enzyme_list_container.add_theme_constant_override("separation", 5)
	scroll.add_child(enzyme_list_container)

func build_enzyme_detail_panel(parent: HSplitContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var scroll = ScrollContainer.new()
	panel.add_child(scroll)
	
	enzyme_detail_container = VBoxContainer.new()
	enzyme_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enzyme_detail_container.add_theme_constant_override("separation", 15)
	scroll.add_child(enzyme_detail_container)
	
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)

## ============================================================================
## UPDATE FUNCTIONS
## ============================================================================

func update_all() -> void:
	update_stats()
	update_molecule_list()
	update_enzyme_list()
	
	if simulator.selected_enzyme:
		update_enzyme_detail()
	if simulator.selected_molecule != "":
		update_molecule_detail()

func update_stats() -> void:
	stats_label.text = "Time: %.1fs | Iteration: %d" % [simulator.total_time, simulator.iteration]
	
	## Calculate and display system energetics
	var energetics = simulator.calculate_system_energetics()
	system_energetics_label.text = "⚡ System: Fwd: %.2f | Rev: %.2f | Net: %.2f mM/s\n  ΣΔG: %.1f kJ/mol | Fav:%d Eq:%d Unfav:%d" % [
		energetics["total_forward_rate"],
		energetics["total_reverse_rate"],
		energetics["total_net_rate"],
		energetics["sum_delta_g"],
		energetics["favorable_count"],
		energetics["equilibrium_count"],
		energetics["unfavorable_count"]
	]

func update_molecule_list() -> void:
	for mol_name in simulator.molecules.keys():
		if molecule_ui_elements.has(mol_name):
			var mol = simulator.molecules[mol_name]
			var ui = molecule_ui_elements[mol_name]
			ui["label"].text = "  %s: %.3f mM" % [mol.name, mol.concentration]

func update_enzyme_list() -> void:
	for enzyme in simulator.enzymes:
		if enzyme_list_buttons.has(enzyme.id):
			var btn = enzyme_list_buttons[enzyme.id]
			var type_str = ""
			if enzyme.is_source():
				type_str = " [SOURCE]"
			elif enzyme.is_sink():
				type_str = " [SINK]"

			## Get first reaction's ΔG for display
			var dg_indicator = ""
			if not enzyme.reactions.is_empty():
				var first_rxn = enzyme.reactions[0]
				if abs(first_rxn.current_delta_g_actual) < 0.1:
					dg_indicator = " ⇄"
				elif first_rxn.current_delta_g_actual < -10:
					dg_indicator = " →→"
				elif first_rxn.current_delta_g_actual < 0:
					dg_indicator = " →"
				elif first_rxn.current_delta_g_actual > 10:
					dg_indicator = " ←←"
				else:
					dg_indicator = " ←"
			
			btn.text = "%s%s%s\nNet: %.3f mM/s\n[E]: %.4f mM" % [
				enzyme.name, 
				type_str, 
				dg_indicator,
				enzyme.current_net_rate,
				enzyme.concentration
			]

func update_enzyme_detail() -> void:
	if not simulator.selected_enzyme:
		return
	
	var enzyme = simulator.selected_enzyme
	
	## Update enzyme concentration label
	for child in enzyme_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
		elif child.name == "TotalRateInfo":
			child.text = "Total Forward: %.3f mM/s\nTotal Reverse: %.3f mM/s\nTotal Net: %.3f mM/s" % [
				enzyme.current_total_forward_rate,
				enzyme.current_total_reverse_rate,
				enzyme.current_net_rate
			]
	
	## Update individual reaction displays
	for reaction in enzyme.reactions:
		var reaction_panel_name = "ReactionPanel_%s" % reaction.id
		for child in enzyme_detail_container.get_children():
			if child.name == reaction_panel_name and child is PanelContainer:
				var vbox = child.get_child(0) if child.get_child_count() > 0 else null
				if vbox:
					for label in vbox.get_children():
						if label.name == "RxnRate":
							label.text = "Fwd: %.3f | Rev: %.3f | Net: %.3f mM/s" % [
								reaction.current_forward_rate,
								reaction.current_reverse_rate,
								reaction.current_forward_rate - reaction.current_reverse_rate
							]
						elif label.name == "RxnDeltaG":
							label.text = "ΔG: %.1f kJ/mol (ΔG°: %.1f)" % [
								reaction.current_delta_g_actual,
								reaction.delta_g
							]
							var dg_color = Color.GREEN if reaction.current_delta_g_actual < 0 else Color.RED
							label.add_theme_color_override("font_color", dg_color)
						elif label.name == "RxnDirection":
							var direction_text = ""
							var direction_color = Color.WHITE
							if reaction.current_delta_g_actual < -5.0:
								direction_text = "→ Forward Favorable"
								direction_color = Color(0.4, 1.0, 0.4)
							elif reaction.current_delta_g_actual > 5.0:
								direction_text = "← Reverse Favorable"
								direction_color = Color(1.0, 0.5, 0.3)
							else:
								direction_text = "⇄ Near Equilibrium"
								direction_color = Color(1.0, 1.0, 0.4)
							label.text = direction_text
							label.add_theme_color_override("font_color", direction_color)
						elif label.name == "RxnKeq":
							var keq_text = "Keq: %s.2e" % reaction.current_keq
							label.text = keq_text

func update_molecule_detail() -> void:
	if simulator.selected_molecule == "" or not simulator.molecules.has(simulator.selected_molecule):
		return
	
	var mol = simulator.molecules[simulator.selected_molecule]
	
	## Update concentration
	for child in molecule_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Concentration: %.3f mM" % mol.concentration
	
	## Calculate net rate for this molecule
	var net_rate = 0.0
	for enzyme in simulator.enzymes:
		for reaction in enzyme.reactions:
			var reaction_net = reaction.current_forward_rate - reaction.current_reverse_rate
			if reaction.products.has(simulator.selected_molecule):
				var stoich = reaction.products[simulator.selected_molecule]
				net_rate += reaction_net * stoich
			if reaction.substrates.has(simulator.selected_molecule):
				var stoich = reaction.substrates[simulator.selected_molecule]
				net_rate -= reaction_net * stoich
	
	for child in molecule_detail_container.get_children():
		if child.name == "NetRateLabel":
			var net_sign = "+" if net_rate >= 0 else ""
			var net_color = Color(0.4, 1.0, 0.4) if net_rate >= 0 else Color(1.0, 0.4, 0.4)
			child.text = "%s%.3f mM/s" % [net_sign, net_rate]
			child.add_theme_color_override("font_color", net_color)

## ============================================================================
## BUILD/REBUILD FUNCTIONS
## ============================================================================

func rebuild_molecule_list() -> void:
	## Clear existing
	for child in molecules_panel.get_children():
		child.queue_free()
	molecule_ui_elements.clear()
	
	## Rebuild all
	for mol_name in simulator.molecules.keys():
		add_molecule_ui(mol_name)

func add_molecule_ui(mol_name: String) -> void:
	var mol = simulator.molecules[mol_name]
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	molecules_panel.add_child(hbox)

	var label = Label.new()
	label.text = "  %s: %.3f mM" % [mol_name, mol.concentration]
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	## Info button
	var info_btn = Button.new()
	info_btn.text = "ℹ"
	info_btn.custom_minimum_size = Vector2(30, 0)
	info_btn.tooltip_text = "View molecule details"
	info_btn.pressed.connect(func(): simulator.on_molecule_info_clicked(mol_name))
	hbox.add_child(info_btn)

	## Delete button
	var delete_btn = Button.new()
	delete_btn.text = "✕"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(func(): 
		if simulator.remove_molecule(mol_name):
			rebuild_molecule_list()
	)
	hbox.add_child(delete_btn)

	molecule_ui_elements[mol_name] = {
		"label": label,
		"container": hbox
	}

func rebuild_enzyme_list() -> void:
	## Clear existing
	for child in enzyme_list_container.get_children():
		child.queue_free()
	enzyme_list_buttons.clear()
	
	## Rebuild all
	for enzyme in simulator.enzymes:
		add_enzyme_button(enzyme)

func add_enzyme_button(enzyme: Enzyme) -> void:
	var btn = Button.new()
	btn.text = "%s\n0.000 mM/s\n[E]: %.4f" % [enzyme.name, enzyme.concentration]
	btn.custom_minimum_size = Vector2(0, 80)
	btn.pressed.connect(simulator.on_enzyme_selected.bind(enzyme))
	enzyme_list_container.add_child(btn)
	enzyme_list_buttons[enzyme.id] = btn

## ============================================================================
## DETAIL VIEW BUILDERS
## ============================================================================

func show_enzyme_detail(enzyme: Enzyme) -> void:
	## Clear molecule detail
	for child in molecule_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Click a molecule info button to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)
	
	## Build enzyme detail
	build_enzyme_detail_view(enzyme)

func show_molecule_detail(mol_name: String) -> void:
	## Clear enzyme detail
	for child in enzyme_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)
	
	## Build molecule detail
	build_molecule_detail_view(mol_name)

func build_enzyme_detail_view(enzyme: Enzyme) -> void:
	for child in enzyme_detail_container.get_children():
		child.queue_free()

	## Header
	var header_hbox = HBoxContainer.new()
	enzyme_detail_container.add_child(header_hbox)

	var title = Label.new()
	title.text = "⚗️ %s" % enzyme.name
	title.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var delete_btn = Button.new()
	delete_btn.text = "Delete Enzyme"
	delete_btn.pressed.connect(func(): 
		simulator.remove_enzyme(enzyme)
		rebuild_enzyme_list()
		show_enzyme_detail(null)
	)
	header_hbox.add_child(delete_btn)

	## Total rate info
	var rate_label = Label.new()
	rate_label.name = "TotalRateInfo"
	rate_label.text = "Total Forward: %.3f mM/s\nTotal Reverse: %.3f mM/s\nTotal Net: %.3f mM/s" % [
		enzyme.current_total_forward_rate,
		enzyme.current_total_reverse_rate,
		enzyme.current_net_rate
	]
	rate_label.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	rate_label.add_theme_font_size_override("font_size", 14)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(rate_label)
	
	## Enzyme concentration
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
	conc_label.add_theme_font_size_override("font_size", 14)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(conc_label)

	## Reactions section
	enzyme_detail_container.add_child(_create_section_label("Reactions"))
	
	if enzyme.reactions.is_empty():
		var no_rxn_label = Label.new()
		no_rxn_label.text = "No reactions defined for this enzyme"
		no_rxn_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_rxn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enzyme_detail_container.add_child(no_rxn_label)
	else:
		for reaction in enzyme.reactions:
			enzyme_detail_container.add_child(create_reaction_display(reaction))

	## Enzyme-level regulation
	enzyme_detail_container.add_child(_create_section_label("Enzyme Regulation"))
	
	## Inhibitors
	if not enzyme.inhibitors.is_empty():
		var inh_label = Label.new()
		var inh_text = "Inhibitors: "
		for inhibitor in enzyme.inhibitors:
			inh_text += "%s (Ki: %.2f) " % [inhibitor, enzyme.inhibitors[inhibitor]]
		inh_label.text = inh_text
		inh_label.add_theme_font_size_override("font_size", 12)
		enzyme_detail_container.add_child(inh_label)
	
	## Activators
	if not enzyme.activators.is_empty():
		var act_label = Label.new()
		var act_text = "Activators: "
		for activator in enzyme.activators:
			act_text += "%s (Fold: %.1f×) " % [activator, enzyme.activators[activator]]
		act_label.text = act_text
		act_label.add_theme_font_size_override("font_size", 12)
		enzyme_detail_container.add_child(act_label)

	## Enzyme Dynamics
	enzyme_detail_container.add_child(_create_section_label("Enzyme Dynamics"))
	
	var creation_slider = create_parameter_slider("Base Creation Rate", enzyme.creation_rate, 0.0, 0.1, 0.001, 
		func(val): enzyme.creation_rate = val)
	enzyme_detail_container.add_child(creation_slider)
	
	var degr_slider = create_parameter_slider("Base Degradation Rate", enzyme.degradation_rate, 0.0, 0.5, 0.001,
		func(val): enzyme.degradation_rate = val)
	enzyme_detail_container.add_child(degr_slider)

func create_reaction_display(reaction: Reaction) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "ReactionPanel_%s" % reaction.id
	panel.custom_minimum_size = Vector2(0, 140)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	panel.add_child(vbox)
	
	## Reaction name and equation
	var name_label = Label.new()
	name_label.text = "⚛️ %s" % reaction.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(name_label)
	
	var equation_label = Label.new()
	equation_label.text = reaction.get_summary()
	equation_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(equation_label)
	
	## Rate info
	var rate_label = Label.new()
	rate_label.name = "RxnRate"
	rate_label.text = "Fwd: %.3f | Rev: %.3f | Net: %.3f mM/s" % [
		reaction.current_forward_rate,
		reaction.current_reverse_rate,
		reaction.current_forward_rate - reaction.current_reverse_rate
	]
	rate_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rate_label)
	
	## Thermodynamics
	var dg_label = Label.new()
	dg_label.name = "RxnDeltaG"
	dg_label.text = "ΔG: %.1f kJ/mol (ΔG°: %.1f)" % [
		reaction.current_delta_g_actual,
		reaction.delta_g
	]
	var dg_color = Color.GREEN if reaction.current_delta_g_actual < 0 else Color.RED
	dg_label.add_theme_color_override("font_color", dg_color)
	dg_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(dg_label)
	
	## Direction indicator
	var direction_label = Label.new()
	direction_label.name = "RxnDirection"
	var direction_text = ""
	var direction_color = Color.WHITE
	if reaction.current_delta_g_actual < -5.0:
		direction_text = "→ Forward Favorable"
		direction_color = Color(0.4, 1.0, 0.4)
	elif reaction.current_delta_g_actual > 5.0:
		direction_text = "← Reverse Favorable"
		direction_color = Color(1.0, 0.5, 0.3)
	else:
		direction_text = "⇄ Near Equilibrium"
		direction_color = Color(1.0, 1.0, 0.4)
	direction_label.text = direction_text
	direction_label.add_theme_color_override("font_color", direction_color)
	direction_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(direction_label)
	
	## Keq
	var keq_label = Label.new()
	keq_label.name = "RxnKeq"
	keq_label.text = "Keq: %s.2e" % reaction.current_keq
	keq_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(keq_label)
	
	return panel

func build_molecule_detail_view(mol_name: String) -> void:
	for child in molecule_detail_container.get_children():
		child.queue_free()
	
	if not simulator.molecules.has(mol_name):
		return
	
	var mol = simulator.molecules[mol_name]
	
	## Header
	var header = Label.new()
	header.text = "🧪 Molecule: %s" % mol_name
	header.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(header)
	
	## Current concentration
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Concentration: %s.3f mM" % mol.concentration
	conc_label.add_theme_font_size_override("font_size", 16)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(conc_label)
	
	## Calculate net rate
	var net_rate = 0.0
	for enzyme in simulator.enzymes:
		for reaction in enzyme.reactions:
			var reaction_net = reaction.current_forward_rate - reaction.current_reverse_rate
			if reaction.products.has(mol_name):
				var stoich = reaction.products[mol_name]
				net_rate += reaction_net * stoich
			if reaction.substrates.has(mol_name):
				var stoich = reaction.substrates[mol_name]
				net_rate -= reaction_net * stoich
	
	var net_header = _create_section_label("Net Rate")
	molecule_detail_container.add_child(net_header)
	
	var net_label = Label.new()
	net_label.name = "NetRateLabel"
	var net_sign = "+" if net_rate >= 0 else ""
	var net_color = Color(0.4, 1.0, 0.4) if net_rate >= 0 else Color(1.0, 0.4, 0.4)
	net_label.text = "%s%.3f mM/s" % [net_sign, net_rate]
	net_label.add_theme_color_override("font_color", net_color)
	net_label.add_theme_font_size_override("font_size", 16)
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(net_label)
	
	## List all reactions involving this molecule
	molecule_detail_container.add_child(_create_section_label("Reactions Involving This Molecule"))
	
	var reaction_count = 0
	for enzyme in simulator.enzymes:
		for reaction in enzyme.reactions:
			if reaction.substrates.has(mol_name) or reaction.products.has(mol_name):
				reaction_count += 1
				var rxn_label = Label.new()
				var role = ""
				if reaction.substrates.has(mol_name):
					role = "Substrate"
				elif reaction.products.has(mol_name):
					role = "Product"
				rxn_label.text = "• %s (%s) - %s" % [reaction.name, role, enzyme.name]
				rxn_label.add_theme_font_size_override("font_size", 12)
				molecule_detail_container.add_child(rxn_label)
	
	if reaction_count == 0:
		var no_rxn = Label.new()
		no_rxn.text = "No reactions involve this molecule"
		no_rxn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		molecule_detail_container.add_child(no_rxn)

## ============================================================================
## UI ELEMENT CREATORS
## ============================================================================

func create_parameter_slider(param_name: String, initial_value: float, min_val: float, max_val: float, step_val: float, callback: Callable) -> VBoxContainer:
	var container = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "%s: %.3f" % [param_name, initial_value]
	container.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial_value
	slider.value_changed.connect(func(val):
		label.text = "%s: %.3f" % [param_name, val]
		callback.call(val)
	)
	container.add_child(slider)
	
	return container

func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	return label

## ============================================================================
## DIALOGS
## ============================================================================

func show_add_molecule_dialog() -> void:
	var dialog = Window.new()
	dialog.title = "Add New Molecule"
	dialog.size = Vector2i(400, 250)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	dialog.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "Molecule Name:"
	vbox.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "e.g., glucose, ATP"
	vbox.add_child(name_input)

	var conc_label = Label.new()
	conc_label.text = "Initial Concentration (mM):"
	vbox.add_child(conc_label)
	
	var conc_input = SpinBox.new()
	conc_input.min_value = 0.0
	conc_input.max_value = 100.0
	conc_input.step = 0.1
	conc_input.value = 1.0
	vbox.add_child(conc_input)

	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(100, 40)
	button_hbox.add_child(add_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	button_hbox.add_child(cancel_btn)

	add_btn.pressed.connect(func():
		var mol_name = name_input.text.strip_edges()
		if mol_name.is_empty():
			print("⚠️ Molecule name cannot be empty")
			return
		if simulator.molecules.has(mol_name):
			print("⚠️ Molecule '%s' already exists" % mol_name)
			return
		simulator.add_molecule(mol_name, conc_input.value)
		rebuild_molecule_list()
		dialog.queue_free()
	)

	cancel_btn.pressed.connect(func(): dialog.queue_free())
	
	add_child(dialog)
	dialog.popup_centered()
