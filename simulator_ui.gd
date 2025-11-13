## UI Manager for Enzyme Simulator
## Works with scene-based UI using unique node names
class_name SimulatorUI
extends Control

var simulator: EnzymeSimulator

## UI element storage for dynamic content
var molecule_ui_elements: Dictionary = {}
var enzyme_list_buttons: Dictionary = {}

## UI References (assigned from scene using unique names)
@onready var stats_label: Label = %StatsLabel
@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_label: Label = %HeatLabel
@onready var energy_label: Label = %EnergyLabel
@onready var system_energetics_label: Label = %SystemEnergeticsLabel
@onready var molecules_container: VBoxContainer = %MoleculesContainer
@onready var enzyme_list_container: VBoxContainer = %EnzymeListContainer
@onready var enzyme_detail_container: VBoxContainer = %EnzymeDetailContainer
@onready var molecule_detail_container: VBoxContainer = %MoleculeDetailContainer
@onready var add_molecule_button: Button = %AddMoleculeButton
@onready var add_enzyme_button: Button = %AddEnzymeButton
@onready var cell_status_label: Label = %CellStatusLabel

func _init(sim: EnzymeSimulator) -> void:
	simulator = sim

func _ready() -> void:
	## Defer connections to next frame when @onready vars are ready
	call_deferred("_connect_signals")
	
	## Initial build
	call_deferred("rebuild_molecule_list")
	call_deferred("rebuild_enzyme_list")

func _connect_signals() -> void:
	pause_button.pressed.connect(simulator._on_pause_button_pressed)
	pause_button.pressed.connect(func(): pause_button.text = "Resume" if simulator.is_paused else "Pause")
	reset_button.pressed.connect(simulator._on_reset_button_pressed)
	add_molecule_button.pressed.connect(simulator._on_add_molecule_pressed)
	add_enzyme_button.pressed.connect(simulator._on_add_enzyme_pressed)

## ============================================================================
## UPDATE FUNCTIONS
## ============================================================================

func update_all() -> void:
	update_stats()
	update_thermal_display()
	update_energy_display()
	update_molecule_list()
	update_enzyme_list()
	update_cell_status()
	
	if simulator.selected_enzyme:
		update_enzyme_detail()
	if simulator.selected_molecule != "":
		update_molecule_detail()

func update_stats() -> void:
	stats_label.text = "Time: %.1fs | Iteration: %d" % [simulator.total_time, simulator.iteration]
	
	var energetics = simulator.calculate_system_energetics()
	system_energetics_label.text = "⚡ System Flow: Fwd: %.2f | Rev: %.2f | Net: %.2f mM/s\n  ΣΔG: %.1f kJ/mol | Fav:%d Eq:%d Unfav:%d" % [
		energetics["total_forward_rate"],
		energetics["total_reverse_rate"],
		energetics["total_net_rate"],
		energetics["sum_delta_g"],
		energetics["favorable_count"],
		energetics["equilibrium_count"],
		energetics["unfavorable_count"]
	]

func update_thermal_display() -> void:
	var thermal = simulator.cell.get_thermal_status()
	
	## Update heat bar
	heat_bar.min_value = thermal["min_threshold"]
	heat_bar.max_value = thermal["max_threshold"]
	heat_bar.value = thermal["heat"]
	
	## Color coding
	var heat_ratio = thermal["heat_ratio"]
	if heat_ratio < 0.3:
		heat_bar.modulate = Color(0.4, 0.4, 1.0)  ## Cold (blue)
	elif heat_ratio < 0.7:
		heat_bar.modulate = Color(0.4, 1.0, 0.4)  ## Optimal (green)
	else:
		heat_bar.modulate = Color(1.0, 0.4, 0.4)  ## Hot (red)
	
	heat_label.text = "🔥 Heat: %.1f (%.1f - %.1f)" % [
		thermal["heat"],
		thermal["min_threshold"],
		thermal["max_threshold"]
	]

func update_energy_display() -> void:
	var energy = simulator.cell.get_energy_status()
	
	energy_label.text = "⚡ Energy Pool: %.1f kJ\n  Generated: %.1f | Consumed: %.1f | Heat Waste: %.1f kJ" % [
		energy["usable_energy"],
		energy["total_generated"],
		energy["total_consumed"],
		energy["total_heat"]
	]

func update_cell_status() -> void:
	if simulator.cell.is_alive:
		cell_status_label.text = "✅ Cell Alive"
		cell_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		cell_status_label.text = "💀 Cell Dead: %s" % simulator.cell.death_reason
		cell_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func update_molecule_list() -> void:
	for mol_name in simulator.cell.molecules.keys():
		if molecule_ui_elements.has(mol_name):
			var mol = simulator.cell.molecules[mol_name]
			var ui = molecule_ui_elements[mol_name]
			ui["label"].text = "%s: %.3f mM\n  Code: %s" % [
				mol.name,
				mol.concentration,
				mol.get_genetic_code_string()
			]

func update_enzyme_list() -> void:
	for enzyme in simulator.cell.enzymes:
		if enzyme_list_buttons.has(enzyme.id):
			var btn = enzyme_list_buttons[enzyme.id]
			
			var dg_indicator = ""
			if not enzyme.reactions.is_empty():
				var first_rxn = enzyme.reactions[0]
				if abs(first_rxn.current_delta_g_actual) < 1.0:
					dg_indicator = " ⇄"
				elif first_rxn.current_delta_g_actual < -10:
					dg_indicator = " →→"
				elif first_rxn.current_delta_g_actual < 0:
					dg_indicator = " →"
				elif first_rxn.current_delta_g_actual > 10:
					dg_indicator = " ←←"
				else:
					dg_indicator = " ←"
			
			btn.text = "%s%s\nNet: %.3f mM/s" % [
				enzyme.name,
				dg_indicator,
				enzyme.current_net_rate
			]

func update_enzyme_detail() -> void:
	if not simulator.selected_enzyme:
		return
	
	var enzyme = simulator.selected_enzyme
	
	## Update enzyme info labels
	for child in enzyme_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
		elif child.name == "TotalRateInfo":
			child.text = "Total Forward: %.3f mM/s\nTotal Reverse: %.3f mM/s\nTotal Net: %.3f mM/s" % [
				enzyme.current_total_forward_rate,
				enzyme.current_total_reverse_rate,
				enzyme.current_net_rate
			]
	
	## Update individual reactions
	for reaction in enzyme.reactions:
		var panel_name = "ReactionPanel_%s" % reaction.id
		for child in enzyme_detail_container.get_children():
			if child.name == panel_name and child is PanelContainer:
				update_reaction_panel(child, reaction)

func update_reaction_panel(panel: PanelContainer, reaction: Reaction) -> void:
	var vbox = panel.get_child(0) if panel.get_child_count() > 0 else null
	if not vbox:
		return
	
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
		elif label.name == "RxnEfficiency":
			## Fixed: use genetic_efficiency instead of structural_efficiency
			## Calculate total efficiency on the fly
			var total_eff = reaction.get_total_efficiency()
			label.text = "Efficiency: Genetic=%.2f Total=%.2f" % [
				reaction.genetic_efficiency,
				total_eff
			]
		elif label.name == "RxnEnergy":
			## Fixed: use actual properties from reaction.gd
			label.text = "Energy: Usable=%.2f Heat=%.2f kJ/s" % [
				reaction.current_useful_work,
				reaction.current_heat_generated
			]

func update_molecule_detail() -> void:
	if simulator.selected_molecule == "" or not simulator.cell.molecules.has(simulator.selected_molecule):
		return
	
	var mol = simulator.cell.molecules[simulator.selected_molecule]
	
	for child in molecule_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Concentration: %.3f mM" % mol.concentration
		elif child.name == "PropertiesLabel":
			child.text = "Potential Energy: %.1f kJ/mol\nGenetic Code: %s" % [
				mol.potential_energy,
				mol.get_genetic_code_display()
			]

## ============================================================================
## BUILD/REBUILD FUNCTIONS
## ============================================================================

func rebuild_molecule_list() -> void:
	for child in molecules_container.get_children():
		child.queue_free()
	molecule_ui_elements.clear()
	
	for mol_name in simulator.cell.molecules.keys():
		add_molecule_ui(mol_name)

func add_molecule_ui(mol_name: String) -> void:
	var mol = simulator.cell.molecules[mol_name]
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	molecules_container.add_child(hbox)
	
	var label_button = Button.new()
	label_button.text = "%s: %.3f mM\n  Code: %s" % [
		mol_name,
		mol.concentration,
		mol.get_genetic_code_string()
	]
	label_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_button.pressed.connect(func(): simulator.on_molecule_info_clicked(mol_name))
	hbox.add_child(label_button)
	
	var delete_btn = Button.new()
	delete_btn.text = "✕"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(func():
		if simulator.remove_molecule(mol_name):
			rebuild_molecule_list()
	)
	hbox.add_child(delete_btn)
	
	molecule_ui_elements[mol_name] = {
		"label": label_button,
		"container": hbox
	}

func rebuild_enzyme_list() -> void:
	for child in enzyme_list_container.get_children():
		child.queue_free()
	enzyme_list_buttons.clear()
	
	for enzyme in simulator.cell.enzymes:
		add_enzyme_button_ui(enzyme)

func add_enzyme_button_ui(enzyme: Enzyme) -> void:
	var btn = Button.new()
	btn.text = "%s\n0.000 mM/s" % enzyme.name
	btn.custom_minimum_size = Vector2(0, 60)
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
	placeholder.text = "Click a molecule to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)
	
	build_enzyme_detail_view(enzyme)

func show_molecule_detail(mol_name: String) -> void:
	## Clear enzyme detail
	for child in enzyme_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)
	
	build_molecule_detail_view(mol_name)

func build_enzyme_detail_view(enzyme: Enzyme) -> void:
	for child in enzyme_detail_container.get_children():
		child.queue_free()
	
	## Header
	var title = Label.new()
	title.text = "⚗️ %s" % enzyme.name
	title.add_theme_font_size_override("font_size", 18)
	enzyme_detail_container.add_child(title)
	
	## Rate info
	var rate_label = Label.new()
	rate_label.name = "TotalRateInfo"
	rate_label.text = "Total Forward: %.3f mM/s\nTotal Reverse: %.3f mM/s\nTotal Net: %.3f mM/s" % [
		enzyme.current_total_forward_rate,
		enzyme.current_total_reverse_rate,
		enzyme.current_net_rate
	]
	enzyme_detail_container.add_child(rate_label)
	
	## Concentration
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
	enzyme_detail_container.add_child(conc_label)
	
	## Reactions
	for reaction in enzyme.reactions:
		enzyme_detail_container.add_child(create_reaction_display(reaction))

func create_reaction_display(reaction: Reaction) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "ReactionPanel_%s" % reaction.id
	panel.custom_minimum_size = Vector2(0, 160)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = "⚛️ %s" % reaction.name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	var equation_label = Label.new()
	equation_label.text = reaction.get_summary()
	equation_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(equation_label)
	
	var rate_label = Label.new()
	rate_label.name = "RxnRate"
	rate_label.text = "Fwd: %.3f | Rev: %.3f | Net: %.3f mM/s" % [
		reaction.current_forward_rate,
		reaction.current_reverse_rate,
		reaction.current_forward_rate - reaction.current_reverse_rate
	]
	vbox.add_child(rate_label)
	
	var dg_label = Label.new()
	dg_label.name = "RxnDeltaG"
	dg_label.text = "ΔG: %.1f kJ/mol (ΔG°: %.1f)" % [
		reaction.current_delta_g_actual,
		reaction.delta_g
	]
	var dg_color = Color.GREEN if reaction.current_delta_g_actual < 0 else Color.RED
	dg_label.add_theme_color_override("font_color", dg_color)
	vbox.add_child(dg_label)
	
	var eff_label = Label.new()
	eff_label.name = "RxnEfficiency"
	var total_eff = reaction.get_total_efficiency()
	eff_label.text = "Efficiency: Genetic=%.2f Total=%.2f" % [
		reaction.genetic_efficiency,
		total_eff
	]
	vbox.add_child(eff_label)
	
	var energy_label = Label.new()
	energy_label.name = "RxnEnergy"
	energy_label.text = "Energy: Usable=%.2f Heat=%.2f kJ/s" % [
		reaction.current_useful_work,
		reaction.current_heat_generated
	]
	vbox.add_child(energy_label)
	
	return panel

func build_molecule_detail_view(mol_name: String) -> void:
	for child in molecule_detail_container.get_children():
		child.queue_free()
	
	if not simulator.cell.molecules.has(mol_name):
		return
	
	var mol = simulator.cell.molecules[mol_name]
	
	var title = Label.new()
	title.text = "🧪 %s" % mol_name
	title.add_theme_font_size_override("font_size", 18)
	molecule_detail_container.add_child(title)
	
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Concentration: %.3f mM" % mol.concentration
	molecule_detail_container.add_child(conc_label)
	
	var props_label = Label.new()
	props_label.name = "PropertiesLabel"
	props_label.text = "Potential Energy: %.1f kJ/mol\nGenetic Code: %s" % [
		mol.potential_energy,
		mol.get_genetic_code_display()
	]
	molecule_detail_container.add_child(props_label)
