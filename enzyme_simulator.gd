## Advanced enzyme feedback loop simulator
## - Sources are enzymes with no substrates (produce from nothing)
## - Sinks are enzymes with no products (consume to nothing)
## - Enzymes can be created/degraded dynamically
## - Stoichiometric ratios supported

class_name EnzymeSimulator
extends Control

var molecules: Dictionary = {}
var enzymes: Array[Enzyme] = []

var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false
var enzyme_count: int = 0

## Dynamic UI element storage
var molecule_ui_elements: Dictionary = {}
var enzyme_list_buttons: Dictionary = {}
var selected_enzyme: Enzyme = null
var selected_molecule: String = ""

## Drag and drop state
var dragging_molecule: String = ""

## UI References
var stats_label: Label
var pause_button: Button
var molecules_panel: VBoxContainer
var enzyme_list_container: VBoxContainer
var enzyme_detail_container: VBoxContainer
var molecule_detail_container: VBoxContainer

func _ready() -> void:
	build_ui()
	initialize_molecules()
	initialize_enzymes()
	update_ui()
	print("✅ Enzyme Feedback Simulator initialized")

func build_ui() -> void:
	## Reference existing scene nodes instead of creating new ones
	stats_label = $MarginContainer/HBoxContainer/LeftPanel/StatsLabel
	pause_button = $MarginContainer/HBoxContainer/LeftPanel/ControlPanel/PauseButton
	var reset_button = $MarginContainer/HBoxContainer/LeftPanel/ControlPanel/ResetButton
	
	## Create molecules list container
	var mol_vbox = $MarginContainer/HBoxContainer/LeftPanel/MoleculesPanel/VBox
	var mol_scroll = ScrollContainer.new()
	mol_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mol_vbox.add_child(mol_scroll)
	
	molecules_panel = VBoxContainer.new()
	molecules_panel.add_theme_constant_override("separation", 5)
	molecules_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mol_scroll.add_child(molecules_panel)
	
	## Create molecule detail panel
	var left_panel = $MarginContainer/HBoxContainer/LeftPanel
	var mol_detail_panel = PanelContainer.new()
	mol_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(mol_detail_panel)
	
	var mol_detail_vbox = VBoxContainer.new()
	mol_detail_panel.add_child(mol_detail_vbox)
	
	var mol_detail_title = Label.new()
	mol_detail_title.text = "Molecule Details"
	mol_detail_title.add_theme_font_size_override("font_size", 18)
	mol_detail_vbox.add_child(mol_detail_title)
	
	var mol_detail_scroll = ScrollContainer.new()
	mol_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mol_detail_vbox.add_child(mol_detail_scroll)
	
	molecule_detail_container = VBoxContainer.new()
	molecule_detail_container.add_theme_constant_override("separation", 10)
	molecule_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mol_detail_scroll.add_child(molecule_detail_container)
	
	var mol_placeholder = Label.new()
	mol_placeholder.text = "Click a molecule info button to view details"
	mol_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(mol_placeholder)
	
	## Reference enzyme list container
	enzyme_list_container = $MarginContainer/HBoxContainer/RightPanel/HSplitContainer/EnzymeListPanel/VBox/ScrollContainer/EnzymeList
	
	## Reference enzyme detail container
	enzyme_detail_container = $MarginContainer/HBoxContainer/RightPanel/HSplitContainer/EnzymeDetailPanel/ScrollContainer/EnzymeDetail

func _process(delta: float) -> void:
	if is_paused:
		return

	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		update_ui()

## Initialize starting molecules
func initialize_molecules() -> void:
	add_molecule("ADP_precursor", 5.0)
	add_molecule("Pi_precursor", 5.0)
	add_molecule("ADP", 0.1)
	add_molecule("Phosphate", 0.1)
	add_molecule("ATP", 0.05)

## Initialize starting enzymes
func initialize_enzymes() -> void:
	## Source 1: ADP_precursor
	var source_adp = add_enzyme_object("ADP Precursor Synthase")
	source_adp.products["ADP_precursor"] = 1.0
	source_adp.vmax = 3.0
	source_adp.initial_vmax = 3.0
	source_adp.km = 0.5
	source_adp.initial_km = 0.5
	
	## Source 2: Pi_precursor
	var source_pi = add_enzyme_object("Phosphate Precursor Synthase")
	source_pi.products["Pi_precursor"] = 1.0
	source_pi.vmax = 3.0
	source_pi.initial_vmax = 3.0
	source_pi.km = 0.5
	source_pi.initial_km = 0.5
	
	## Enzyme 3: ADP_precursor → ADP
	var adp_synthase = add_enzyme_object("ADP Synthase")
	adp_synthase.substrates["ADP_precursor"] = 1.0
	adp_synthase.products["ADP"] = 1.0
	adp_synthase.vmax = 3.0
	adp_synthase.initial_vmax = 3.0
	adp_synthase.km = 0.5
	adp_synthase.initial_km = 0.5

	## Enzyme 4: Pi_precursor → Phosphate
	var pi_synthase = add_enzyme_object("Phosphate Synthase")
	pi_synthase.substrates["Pi_precursor"] = 1.0
	pi_synthase.products["Phosphate"] = 1.0
	pi_synthase.vmax = 3.0
	pi_synthase.initial_vmax = 3.0
	pi_synthase.km = 0.5
	pi_synthase.initial_km = 0.5

	## ATP Synthase: ADP + Phosphate → ATP (inhibited by ATP - product inhibition)
	var atp_synthase = add_enzyme_object("ATP Synthase")
	atp_synthase.substrates["ADP"] = 1.0
	atp_synthase.substrates["Phosphate"] = 1.0
	atp_synthase.products["ATP"] = 1.0
	atp_synthase.inhibitors["ATP"] = 0.4  ## Product inhibition
	atp_synthase.vmax = 5.0
	atp_synthase.initial_vmax = 5.0
	atp_synthase.km = 0.3
	atp_synthase.initial_km = 0.3

	## ATPase: ATP → ADP + Phosphate (reverse reaction/ATP consumption)
	var atpase = add_enzyme_object("ATPase")
	atpase.substrates["ATP"] = 1.0
	atpase.vmax = 10.0
	atpase.initial_vmax = 20.0
	atpase.km = 4
	atpase.initial_km = 4
	
## Main simulation step
func simulate_step() -> void:
	## Update enzyme concentrations (creation/degradation)
	for enzyme in enzymes:
		update_enzyme_concentration(enzyme)

	## Calculate and apply enzyme reactions
	for enzyme in enzymes:
		enzyme.current_rate = calculate_enzyme_rate(enzyme)
		apply_catalysis(enzyme)

	## Prevent negative concentrations
	for mol in molecules.values():
		mol.concentration = max(mol.concentration, 0.0)
	for enzyme in enzymes:
		enzyme.concentration = max(enzyme.concentration, 0.0)

## Update enzyme concentration based on creation/degradation
func update_enzyme_concentration(enzyme: Enzyme) -> void:
	## Base creation rate
	var creation = enzyme.creation_rate

	## Apply creation activators
	for mol_name in enzyme.creation_activators:
		if molecules.has(mol_name):
			var mol_conc = molecules[mol_name].concentration
			var factor = enzyme.creation_activators[mol_name]
			creation += (mol_conc / (mol_conc + 0.5)) * factor

	## Apply creation inhibitors
	for mol_name in enzyme.creation_inhibitors:
		if molecules.has(mol_name):
			var mol_conc = molecules[mol_name].concentration
			var factor = enzyme.creation_inhibitors[mol_name]
			creation -= (mol_conc / (mol_conc + 0.5)) * factor

	## Base degradation rate
	var degradation = enzyme.degradation_rate * enzyme.concentration

	## Apply degradation activators
	for mol_name in enzyme.degradation_activators:
		if molecules.has(mol_name):
			var mol_conc = molecules[mol_name].concentration
			var factor = enzyme.degradation_activators[mol_name]
			degradation += (mol_conc / (mol_conc + 0.5)) * factor * enzyme.concentration

	## Apply degradation inhibitors
	for mol_name in enzyme.degradation_inhibitors:
		if molecules.has(mol_name):
			var mol_conc = molecules[mol_name].concentration
			var factor = enzyme.degradation_inhibitors[mol_name]
			degradation -= (mol_conc / (mol_conc + 0.5)) * factor * enzyme.concentration

	creation = max(0.0, creation)
	degradation = max(0.0, degradation)

	enzyme.concentration += (creation - degradation) * timestep

## Calculate enzyme rate with stoichiometry
func calculate_enzyme_rate(enzyme: Enzyme) -> float:
	if enzyme.concentration <= 0.0:
		return 0.0

	## Sources (no substrates) - just produce at Vmax rate
	if enzyme.substrates.is_empty():
		var vmax = enzyme.vmax * enzyme.concentration
		vmax = apply_enzyme_modulation(enzyme, vmax)
		return vmax

	## Check all substrates exist
	for substrate in enzyme.substrates:
		if not molecules.has(substrate):
			return 0.0

	## Base Vmax
	var vmax = enzyme.vmax * enzyme.concentration
	vmax = apply_enzyme_modulation(enzyme, vmax)

	## Calculate limiting substrate (lowest saturation)
	var min_saturation = 1.0
	for substrate in enzyme.substrates:
		var substrate_conc = molecules[substrate].concentration
		var saturation = substrate_conc / (enzyme.km + substrate_conc)
		min_saturation = min(min_saturation, saturation)

	return vmax * min_saturation

func apply_enzyme_modulation(enzyme: Enzyme, vmax: float) -> float:
	## Apply inhibitors
	for inhibitor in enzyme.inhibitors:
		if molecules.has(inhibitor):
			var inhibitor_conc = molecules[inhibitor].concentration
			var inhibition_strength = inhibitor_conc / (inhibitor_conc + 0.5)
			var inhibition_factor = enzyme.inhibitors[inhibitor]
			vmax *= (1.0 - inhibition_strength * (1.0 - inhibition_factor))

	## Apply activators
	for activator in enzyme.activators:
		if molecules.has(activator):
			var activator_conc = molecules[activator].concentration
			var activation_strength = activator_conc / (activator_conc + 0.5)
			var activation_factor = enzyme.activators[activator]
			vmax *= (1.0 + activation_strength * (activation_factor - 1.0))

	return max(0.0, vmax)

func apply_catalysis(enzyme: Enzyme) -> void:
	var rate = enzyme.current_rate * timestep

	## Consume substrates with stoichiometry
	for substrate in enzyme.substrates:
		if molecules.has(substrate):
			var stoich = enzyme.substrates[substrate]
			molecules[substrate].concentration -= rate * stoich

	## Produce products with stoichiometry
	for product in enzyme.products:
		if molecules.has(product):
			var stoich = enzyme.products[product]
			molecules[product].concentration += rate * stoich

## Update UI
func update_ui() -> void:
	stats_label.text = "Time: %.1fs | Iteration: %d" % [total_time, iteration]

	for mol_name in molecules.keys():
		if molecule_ui_elements.has(mol_name):
			var mol = molecules[mol_name]
			var ui = molecule_ui_elements[mol_name]
			ui["label"].text = "  %s: %.3f mM" % [mol.name, mol.concentration]

	for enzyme in enzymes:
		if enzyme_list_buttons.has(enzyme.id):
			var btn = enzyme_list_buttons[enzyme.id]
			var type_str = ""
			if enzyme.is_source():
				type_str = " [SOURCE]"
			elif enzyme.is_sink():
				type_str = " [SINK]"

			## Show rate per product with stoichiometry
			var rate_str = ""
			if not enzyme.products.is_empty():
				var product_rates = []
				for product in enzyme.products:
					var stoich = enzyme.products[product]
					var product_rate = enzyme.current_rate * stoich
					product_rates.append("%s: %.3f" % [product, product_rate])
				rate_str = "\n".join(product_rates)
			else:
				rate_str = "%.3f mM/s" % enzyme.current_rate

			btn.text = "%s%s\n%s\n[E]: %.4f" % [enzyme.name, type_str, rate_str, enzyme.concentration]

	if selected_enzyme:
		update_enzyme_detail_view()
	
	if selected_molecule != "":
		update_molecule_detail_view()

func update_enzyme_detail_view() -> void:
	if not selected_enzyme:
		return

	for child in enzyme_detail_container.get_children():
		if child.name == "RateLabel":
			var rate_text = "Rate: %.3f mM/s" % selected_enzyme.current_rate
			if not selected_enzyme.products.is_empty():
				rate_text += "\nProducts:"
				for product in selected_enzyme.products:
					var stoich = selected_enzyme.products[product]
					var product_rate = selected_enzyme.current_rate * stoich
					rate_text += "\n  %s: %.3f mM/s (×%.1f)" % [product, product_rate, stoich]
			child.text = rate_text
		elif child.name == "ConcentrationLabel":
			child.text = "Enzyme Concentration: %.4f" % selected_enzyme.concentration

func show_molecule_details(mol_name: String) -> void:
	selected_molecule = mol_name
	selected_enzyme = null
	
	## Clear enzyme detail panel
	for child in enzyme_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)
	
	## Build molecule detail view
	build_molecule_detail_view(mol_name)

func build_molecule_detail_view(mol_name: String) -> void:
	for child in molecule_detail_container.get_children():
		child.queue_free()
	
	if not molecules.has(mol_name):
		return
	
	var mol = molecules[mol_name]
	
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
	conc_label.text = "Concentration: %.3f mM" % mol.concentration
	conc_label.add_theme_font_size_override("font_size", 16)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(conc_label)
	
	## Find all enzymes affecting this molecule
	var producing_enzymes: Array = []
	var consuming_enzymes: Array = []
	
	for enzyme in enzymes:
		if enzyme.products.has(mol_name):
			producing_enzymes.append(enzyme)
		if enzyme.substrates.has(mol_name):
			consuming_enzymes.append(enzyme)
	
	## Show producing enzymes
	if not producing_enzymes.is_empty():
		var prod_header = _create_section_label("Producing Enzymes")
		molecule_detail_container.add_child(prod_header)
		
		for enzyme in producing_enzymes:
			var stoich = enzyme.products[mol_name]
			var rate = enzyme.current_rate * stoich
			
			var enzyme_panel = Panel.new()
			enzyme_panel.custom_minimum_size = Vector2(0, 60)
			molecule_detail_container.add_child(enzyme_panel)
			
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
			enzyme_panel.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = "⚗️ %s" % enzyme.name
			name_label.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_label)
			
			var rate_label = Label.new()
			rate_label.name = "RateLabel_%s" % enzyme.id
			rate_label.text = "+%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
			rate_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			vbox.add_child(rate_label)
	else:
		var no_prod = Label.new()
		no_prod.text = "No enzymes producing this molecule"
		no_prod.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		molecule_detail_container.add_child(no_prod)
	
	## Show consuming enzymes
	if not consuming_enzymes.is_empty():
		var cons_header = _create_section_label("Consuming Enzymes")
		molecule_detail_container.add_child(cons_header)
		
		for enzyme in consuming_enzymes:
			var stoich = enzyme.substrates[mol_name]
			var rate = enzyme.current_rate * stoich
			
			var enzyme_panel = Panel.new()
			enzyme_panel.custom_minimum_size = Vector2(0, 60)
			molecule_detail_container.add_child(enzyme_panel)
			
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
			enzyme_panel.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = "⚗️ %s" % enzyme.name
			name_label.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_label)
			
			var rate_label = Label.new()
			rate_label.name = "RateLabel_%s" % enzyme.id
			rate_label.text = "-%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
			rate_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			vbox.add_child(rate_label)
	else:
		var no_cons = Label.new()
		no_cons.text = "No enzymes consuming this molecule"
		no_cons.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		molecule_detail_container.add_child(no_cons)
	
	## Net rate
	var net_rate = 0.0
	for enzyme in producing_enzymes:
		var stoich = enzyme.products[mol_name]
		net_rate += enzyme.current_rate * stoich
	for enzyme in consuming_enzymes:
		var stoich = enzyme.substrates[mol_name]
		net_rate -= enzyme.current_rate * stoich
	
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

func update_molecule_detail_view() -> void:
	if selected_molecule == "" or not molecules.has(selected_molecule):
		return
	
	var mol = molecules[selected_molecule]
	
	## Update concentration
	for child in molecule_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Concentration: %.3f mM" % mol.concentration
	
	## Update enzyme rates
	for enzyme in enzymes:
		var rate_label_name = "RateLabel_%s" % enzyme.id
		for child in molecule_detail_container.get_children():
			if child is Panel:
				var vbox = child.get_child(0) if child.get_child_count() > 0 else null
				if vbox:
					for label in vbox.get_children():
						if label.name == rate_label_name:
							if enzyme.products.has(selected_molecule):
								var stoich = enzyme.products[selected_molecule]
								var rate = enzyme.current_rate * stoich
								label.text = "+%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
							elif enzyme.substrates.has(selected_molecule):
								var stoich = enzyme.substrates[selected_molecule]
								var rate = enzyme.current_rate * stoich
								label.text = "-%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
	
	## Update net rate
	var net_rate = 0.0
	for enzyme in enzymes:
		if enzyme.products.has(selected_molecule):
			var stoich = enzyme.products[selected_molecule]
			net_rate += enzyme.current_rate * stoich
		if enzyme.substrates.has(selected_molecule):
			var stoich = enzyme.substrates[selected_molecule]
			net_rate -= enzyme.current_rate * stoich
	
	for child in molecule_detail_container.get_children():
		if child.name == "NetRateLabel":
			var net_sign = "+" if net_rate >= 0 else ""
			var net_color = Color(0.4, 1.0, 0.4) if net_rate >= 0 else Color(1.0, 0.4, 0.4)
			child.text = "%s%.3f mM/s" % [net_sign, net_rate]
			child.add_theme_color_override("font_color", net_color)

## Button callbacks
func _on_pause_button_pressed() -> void:
	is_paused = !is_paused
	pause_button.text = "Resume" if is_paused else "Pause"

func _on_reset_button_pressed() -> void:
	## Reset all molecules to initial values
	for mol in molecules.values():
		mol.concentration = mol.initial_concentration

	## Reset all enzymes to initial values
	for enzyme in enzymes:
		enzyme.concentration = enzyme.initial_concentration
		enzyme.vmax = enzyme.initial_vmax
		enzyme.km = enzyme.initial_km

	total_time = 0.0
	iteration = 0
	update_ui()
	print("✅ Reset to initial values")

## Add molecule
func _on_add_molecule_pressed() -> void:
	var dialog = create_molecule_dialog()
	add_child(dialog)
	dialog.popup_centered()

func create_molecule_dialog() -> Window:
	var dialog = Window.new()
	dialog.title = "Add New Molecule"
	dialog.size = Vector2i(400, 250)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	dialog.add_child(vbox)

	vbox.add_child(_create_label("Molecule Name:"))
	var name_input = LineEdit.new()
	name_input.placeholder_text = "e.g., D, glucose, ATP"
	vbox.add_child(name_input)

	vbox.add_child(_create_label("Initial Concentration (mM):"))
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
		if molecules.has(mol_name):
			print("⚠️ Molecule '%s' already exists" % mol_name)
			return
		add_molecule(mol_name, conc_input.value)
		dialog.queue_free()
	)

	cancel_btn.pressed.connect(func(): dialog.queue_free())
	return dialog

func add_molecule(mol_name: String, concentration: float) -> void:
	molecules[mol_name] = Molecule.new(mol_name, concentration)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	molecules_panel.add_child(hbox)

	## Draggable molecule button
	var drag_btn = Button.new()
	drag_btn.text = "⋮⋮"
	drag_btn.custom_minimum_size = Vector2(30, 0)
	drag_btn.tooltip_text = "Drag to enzyme slots"
	drag_btn.button_down.connect(func(): start_molecule_drag(mol_name))
	drag_btn.button_up.connect(func(): stop_molecule_drag())
	hbox.add_child(drag_btn)

	var label = Label.new()
	label.text = "  %s: %.3f mM" % [mol_name, concentration]
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	## Info button to show molecule details
	var info_btn = Button.new()
	info_btn.text = "ℹ"
	info_btn.custom_minimum_size = Vector2(30, 0)
	info_btn.tooltip_text = "View molecule details"
	info_btn.pressed.connect(func(): show_molecule_details(mol_name))
	hbox.add_child(info_btn)

	## Delete button
	var delete_btn = Button.new()
	delete_btn.text = "✕"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(func(): remove_molecule(mol_name))
	hbox.add_child(delete_btn)

	molecule_ui_elements[mol_name] = {
		"label": label,
		"container": hbox
	}

	print("✅ Added molecule: %s" % mol_name)

func remove_molecule(mol_name: String) -> void:
	if not molecules.has(mol_name):
		return

	## Check if molecule is used by any enzyme
	for enzyme in enzymes:
		if enzyme.substrates.has(mol_name) or enzyme.products.has(mol_name):
			print("⚠️ Cannot remove '%s': used by enzyme '%s'" % [mol_name, enzyme.name])
			return
		if enzyme.inhibitors.has(mol_name) or enzyme.activators.has(mol_name):
			print("⚠️ Cannot remove '%s': used as regulator by '%s'" % [mol_name, enzyme.name])
			return

	molecules.erase(mol_name)

	if molecule_ui_elements.has(mol_name):
		molecule_ui_elements[mol_name]["container"].queue_free()
		molecule_ui_elements.erase(mol_name)
	print("✅ Removed molecule: %s" % mol_name)

## Drag and drop
func start_molecule_drag(mol_name: String) -> void:
	dragging_molecule = mol_name

func stop_molecule_drag() -> void:
	dragging_molecule = ""

## Add enzyme
func _on_add_enzyme_pressed() -> void:
	var n = "Enzyme %d" % (enzyme_count + 1)
	add_enzyme_object(n)

func add_enzyme_object(enzyme_name: String) -> Enzyme:
	enzyme_count += 1
	var enzyme_id = "e" + str(enzyme_count)

	var enzyme = Enzyme.new(enzyme_id, enzyme_name)
	enzymes.append(enzyme)

	var list_button = Button.new()
	list_button.text = "%s\n0.000 mM/s\n[E]: 0.0100" % enzyme_name
	list_button.custom_minimum_size = Vector2(0, 80)
	list_button.pressed.connect(_on_enzyme_selected.bind(enzyme))
	enzyme_list_container.add_child(list_button)

	enzyme_list_buttons[enzyme_id] = list_button
	print("✅ Added enzyme: %s" % enzyme_name)

	return enzyme

func remove_enzyme(enzyme: Enzyme) -> void:
	enzymes.erase(enzyme)
	if enzyme_list_buttons.has(enzyme.id):
		enzyme_list_buttons[enzyme.id].queue_free()
		enzyme_list_buttons.erase(enzyme.id)

	if selected_enzyme == enzyme:
		selected_enzyme = null
		for child in enzyme_detail_container.get_children():
			child.queue_free()
		var placeholder = Label.new()
		placeholder.text = "Select an enzyme to view details"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enzyme_detail_container.add_child(placeholder)

	print("✅ Removed enzyme: %s" % enzyme.name)

func _on_enzyme_selected(enzyme: Enzyme) -> void:
	selected_enzyme = enzyme
	selected_molecule = ""
	
	## Clear molecule detail panel
	for child in molecule_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Click a molecule info button to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)
	
	build_enzyme_detail_view(enzyme)

## Build enzyme detail view with drag-drop slots
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
	delete_btn.pressed.connect(func(): remove_enzyme(enzyme))
	header_hbox.add_child(delete_btn)

	var rate_label = Label.new()
	rate_label.name = "RateLabel"
	rate_label.text = "Rate: %.3f mM/s" % enzyme.current_rate
	rate_label.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	rate_label.add_theme_font_size_override("font_size", 16)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(rate_label)

	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Enzyme Concentration: %.4f" % enzyme.concentration
	conc_label.add_theme_font_size_override("font_size", 14)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(conc_label)

	## Substrates
	enzyme_detail_container.add_child(_create_section_label("Substrates"))
	for substrate in enzyme.substrates:
		var stoich = enzyme.substrates[substrate]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, substrate, "substrate", stoich))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "substrate"))

	## Products
	enzyme_detail_container.add_child(_create_section_label("Products"))
	for product in enzyme.products:
		var stoich = enzyme.products[product]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, product, "product", stoich))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "product"))

	## Inhibitors
	enzyme_detail_container.add_child(_create_section_label("Inhibitors (Activity)"))
	for inhibitor in enzyme.inhibitors:
		var factor = enzyme.inhibitors[inhibitor]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, inhibitor, "inhibitor", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "inhibitor"))

	## Activators
	enzyme_detail_container.add_child(_create_section_label("Activators (Activity)"))
	for activator in enzyme.activators:
		var factor = enzyme.activators[activator]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, activator, "activator", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "activator"))

	## Enzyme Dynamics Section
	enzyme_detail_container.add_child(_create_section_label("Enzyme Dynamics"))

	## Creation rate
	var creation_container = VBoxContainer.new()
	enzyme_detail_container.add_child(creation_container)
	var creation_label = Label.new()
	creation_label.text = "Base Creation Rate: %.3f" % enzyme.creation_rate
	creation_container.add_child(creation_label)
	var creation_slider = HSlider.new()
	creation_slider.min_value = 0.0
	creation_slider.max_value = 0.1
	creation_slider.step = 0.001
	creation_slider.value = enzyme.creation_rate
	creation_slider.value_changed.connect(func(val): enzyme.creation_rate = val; creation_label.text = "Base Creation Rate: %.3f" % val)
	creation_container.add_child(creation_slider)

	## Degradation rate
	var degr_container = VBoxContainer.new()
	enzyme_detail_container.add_child(degr_container)
	var degr_label = Label.new()
	degr_label.text = "Base Degradation Rate: %.3f" % enzyme.degradation_rate
	degr_container.add_child(degr_label)
	var degr_slider = HSlider.new()
	degr_slider.min_value = 0.0
	degr_slider.max_value = 0.5
	degr_slider.step = 0.001
	degr_slider.value = enzyme.degradation_rate
	degr_slider.value_changed.connect(func(val): enzyme.degradation_rate = val; degr_label.text = "Base Degradation Rate: %.3f" % val)
	degr_container.add_child(degr_slider)

	## Creation activators
	enzyme_detail_container.add_child(_create_section_label("Creation Activators"))
	for mol in enzyme.creation_activators:
		var factor = enzyme.creation_activators[mol]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, mol, "creation_activator", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "creation_activator"))

	## Creation inhibitors
	enzyme_detail_container.add_child(_create_section_label("Creation Inhibitors"))
	for mol in enzyme.creation_inhibitors:
		var factor = enzyme.creation_inhibitors[mol]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, mol, "creation_inhibitor", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "creation_inhibitor"))

	## Degradation activators
	enzyme_detail_container.add_child(_create_section_label("Degradation Activators"))
	for mol in enzyme.degradation_activators:
		var factor = enzyme.degradation_activators[mol]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, mol, "degradation_activator", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "degradation_activator"))

	## Degradation inhibitors
	enzyme_detail_container.add_child(_create_section_label("Degradation Inhibitors"))
	for mol in enzyme.degradation_inhibitors:
		var factor = enzyme.degradation_inhibitors[mol]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, mol, "degradation_inhibitor", factor))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "degradation_inhibitor"))

	## Parameters
	enzyme_detail_container.add_child(_create_section_label("Catalytic Parameters"))

	var vmax_container = VBoxContainer.new()
	enzyme_detail_container.add_child(vmax_container)
	var vmax_label = Label.new()
	vmax_label.text = "Vmax: %.1f" % enzyme.vmax
	vmax_container.add_child(vmax_label)
	var vmax_slider = HSlider.new()
	vmax_slider.min_value = 0.0
	vmax_slider.max_value = 20.0
	vmax_slider.step = 0.1
	vmax_slider.value = enzyme.vmax
	vmax_slider.value_changed.connect(func(val): enzyme.vmax = val; vmax_label.text = "Vmax: %.1f" % val)
	vmax_container.add_child(vmax_slider)

	var km_container = VBoxContainer.new()
	enzyme_detail_container.add_child(km_container)
	var km_label = Label.new()
	km_label.text = "Km: %.2f" % enzyme.km
	km_container.add_child(km_label)
	var km_slider = HSlider.new()
	km_slider.min_value = 0.01
	km_slider.max_value = 2.0
	km_slider.step = 0.01
	km_slider.value = enzyme.km
	km_slider.value_changed.connect(func(val): enzyme.km = val; km_label.text = "Km: %.2f" % val)
	km_container.add_child(km_slider)

	var conc_container = VBoxContainer.new()
	enzyme_detail_container.add_child(conc_container)
	var conc_slider_label = Label.new()
	conc_slider_label.text = "Initial Concentration: %.3f" % enzyme.concentration
	conc_container.add_child(conc_slider_label)
	var conc_slider = HSlider.new()
	conc_slider.min_value = 0.0
	conc_slider.max_value = 0.1
	conc_slider.step = 0.001
	conc_slider.value = enzyme.concentration
	conc_slider.value_changed.connect(func(val):
		enzyme.concentration = val
		enzyme.initial_concentration = val
		conc_slider_label.text = "Initial Concentration: %.3f" % val
	)
	conc_container.add_child(conc_slider)

func create_molecule_slot(enzyme: Enzyme, mol_name: String, slot_type: String, factor: float = 0.0) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 40)
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.2, 1.2, 1.2))
	panel.mouse_exited.connect(func(): panel.modulate = Color(1, 1, 1))

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var label = Label.new()
	label.text = "  %s" % mol_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	## Factor slider for stoichiometry, inhibitors, activators, etc.
	if slot_type in ["substrate", "product"]:
		## Stoichiometry
		var stoich_label = Label.new()
		stoich_label.text = "×%.1f" % factor
		hbox.add_child(stoich_label)

		var stoich_slider = HSlider.new()
		stoich_slider.custom_minimum_size = Vector2(100, 0)
		stoich_slider.min_value = 0.1
		stoich_slider.max_value = 5.0
		stoich_slider.step = 0.1
		stoich_slider.value = factor
		stoich_slider.value_changed.connect(func(val):
			stoich_label.text = "×%.1f" % val
			if slot_type == "substrate":
				enzyme.substrates[mol_name] = val
			else:
				enzyme.products[mol_name] = val
		)
		hbox.add_child(stoich_slider)
	elif slot_type in ["inhibitor", "activator"]:
		## Activity modulation factor
		var factor_label = Label.new()
		factor_label.text = "%.2f" % factor
		hbox.add_child(factor_label)

		var factor_slider = HSlider.new()
		factor_slider.custom_minimum_size = Vector2(100, 0)
		factor_slider.min_value = 0.0
		factor_slider.max_value = 2.0
		factor_slider.step = 0.05
		factor_slider.value = factor
		factor_slider.value_changed.connect(func(val):
			factor_label.text = "%.2f" % val
			if slot_type == "inhibitor":
				enzyme.inhibitors[mol_name] = val
			else:
				enzyme.activators[mol_name] = val
		)
		hbox.add_child(factor_slider)
	elif slot_type in ["creation_activator", "creation_inhibitor", "degradation_activator", "degradation_inhibitor"]:
		## Dynamic regulation factor
		var factor_label = Label.new()
		factor_label.text = "%.3f" % factor
		hbox.add_child(factor_label)

		var factor_slider = HSlider.new()
		factor_slider.custom_minimum_size = Vector2(100, 0)
		factor_slider.min_value = 0.0
		factor_slider.max_value = 0.5
		factor_slider.step = 0.01
		factor_slider.value = factor
		factor_slider.value_changed.connect(func(val):
			factor_label.text = "%.3f" % val
			match slot_type:
				"creation_activator":
					enzyme.creation_activators[mol_name] = val
				"creation_inhibitor":
					enzyme.creation_inhibitors[mol_name] = val
				"degradation_activator":
					enzyme.degradation_activators[mol_name] = val
				"degradation_inhibitor":
					enzyme.degradation_inhibitors[mol_name] = val
		)
		hbox.add_child(factor_slider)

	## Remove button
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.pressed.connect(func(): remove_molecule_from_enzyme(enzyme, mol_name, slot_type))
	hbox.add_child(remove_btn)

	return panel

func create_add_slot(enzyme: Enzyme, slot_type: String) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 40)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var label = Label.new()
	label.text = "+ Drop molecule here"
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(label)

	## Handle drop
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and dragging_molecule != "":
			add_molecule_to_enzyme(enzyme, dragging_molecule, slot_type)
			stop_molecule_drag()
			build_enzyme_detail_view(enzyme)
	)

	return panel

func add_molecule_to_enzyme(enzyme: Enzyme, mol_name: String, slot_type: String) -> void:
	match slot_type:
		"substrate":
			if not enzyme.substrates.has(mol_name):
				enzyme.substrates[mol_name] = 1.0
		"product":
			if not enzyme.products.has(mol_name):
				enzyme.products[mol_name] = 1.0
		"inhibitor":
			if not enzyme.inhibitors.has(mol_name):
				enzyme.inhibitors[mol_name] = 0.3
		"activator":
			if not enzyme.activators.has(mol_name):
				enzyme.activators[mol_name] = 1.5
		"creation_activator":
			if not enzyme.creation_activators.has(mol_name):
				enzyme.creation_activators[mol_name] = 0.1
		"creation_inhibitor":
			if not enzyme.creation_inhibitors.has(mol_name):
				enzyme.creation_inhibitors[mol_name] = 0.1
		"degradation_activator":
			if not enzyme.degradation_activators.has(mol_name):
				enzyme.degradation_activators[mol_name] = 0.1
		"degradation_inhibitor":
			if not enzyme.degradation_inhibitors.has(mol_name):
				enzyme.degradation_inhibitors[mol_name] = 0.1
	print("✅ Added %s '%s' to %s" % [slot_type, mol_name, enzyme.name])

func remove_molecule_from_enzyme(enzyme: Enzyme, mol_name: String, slot_type: String) -> void:
	match slot_type:
		"substrate":
			enzyme.substrates.erase(mol_name)
		"product":
			enzyme.products.erase(mol_name)
		"inhibitor":
			enzyme.inhibitors.erase(mol_name)
		"activator":
			enzyme.activators.erase(mol_name)
		"creation_activator":
			enzyme.creation_activators.erase(mol_name)
		"creation_inhibitor":
			enzyme.creation_inhibitors.erase(mol_name)
		"degradation_activator":
			enzyme.degradation_activators.erase(mol_name)
		"degradation_inhibitor":
			enzyme.degradation_inhibitors.erase(mol_name)
	build_enzyme_detail_view(enzyme)
	print("✅ Removed %s '%s' from %s" % [slot_type, mol_name, enzyme.name])

func _create_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label

func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	return label
