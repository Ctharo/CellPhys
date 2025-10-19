## Advanced enzyme feedback loop simulator
## - Sources are enzymes with no substrates (produce from nothing)
## - Sinks are enzymes with no products (consume to nothing)
## - Enzymes can be created/degraded dynamically
## - Stoichiometric ratios supported

class_name EnzymeSimulator
extends Control

## Represents a chemical molecule with concentration
class Molecule:
	var name: String
	var concentration: float
	var initial_concentration: float

	func _init(p_name: String, p_conc: float) -> void:
		name = p_name
		concentration = p_conc
		initial_concentration = p_conc

## Enzyme that catalyzes biochemical transformations
class Enzyme:
	var id: String
	var name: String
	var concentration: float
	var initial_concentration: float
	var vmax: float
	var initial_vmax: float
	var km: float
	var initial_km: float

	var substrates: Dictionary = {}     ## {"molecule_name": stoichiometry}
	var products: Dictionary = {}       ## {"molecule_name": stoichiometry}
	var inhibitors: Dictionary = {}     ## {"molecule_name": inhibition_factor}
	var activators: Dictionary = {}     ## {"molecule_name": activation_factor}

	## Enzyme dynamics
	var creation_rate: float = 0.0      ## Base rate of enzyme production
	var degradation_rate: float = 0.0   ## Base rate of enzyme degradation
	var creation_activators: Dictionary = {}  ## {"molecule": factor}
	var creation_inhibitors: Dictionary = {}  ## {"molecule": factor}
	var degradation_activators: Dictionary = {}
	var degradation_inhibitors: Dictionary = {}

	var current_rate: float = 0.0

	func _init(p_id: String, p_name: String) -> void:
		id = p_id
		name = p_name
		concentration = 0.01
		initial_concentration = 0.01
		vmax = 10.0
		initial_vmax = 10.0
		km = 0.5
		initial_km = 0.5

	func is_source() -> bool:
		return substrates.is_empty() and not products.is_empty()

	func is_sink() -> bool:
		return not substrates.is_empty() and products.is_empty()

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

## Drag and drop state
var dragging_molecule: String = ""

## UI References
@onready var stats_label = $MarginContainer/HBoxContainer/LeftPanel/StatsLabel
@onready var pause_button = $MarginContainer/HBoxContainer/LeftPanel/ControlPanel/PauseButton
@onready var molecules_panel = $MarginContainer/HBoxContainer/LeftPanel/MoleculesPanel/VBox
@onready var enzyme_list_container = $MarginContainer/HBoxContainer/RightPanel/HSplitContainer/EnzymeListPanel/VBox/ScrollContainer/EnzymeList
@onready var enzyme_detail_container = $MarginContainer/HBoxContainer/RightPanel/HSplitContainer/EnzymeDetailPanel/ScrollContainer/EnzymeDetail

func _ready() -> void:
	initialize_molecules()
	initialize_enzymes()
	update_ui()
	print("✅ Enzyme Feedback Simulator initialized")

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
	add_molecule("A", 5.0)
	add_molecule("B", 0.1)
	add_molecule("C", 0.05)

## Initialize starting enzymes
func initialize_enzymes() -> void:
	## Source: produces A
	var source = add_enzyme_object("Source A")
	source.products["A"] = 1.0
	source.vmax = 2.0
	source.initial_vmax = 2.0

	## Enzyme 1: A → B (inhibited by C)
	var e1 = add_enzyme_object("Enzyme 1")
	e1.substrates["A"] = 1.0
	e1.products["B"] = 1.0
	e1.inhibitors["C"] = 0.3
	e1.vmax = 8.0
	e1.initial_vmax = 8.0
	e1.km = 0.5
	e1.initial_km = 0.5

	## Enzyme 2: B → C
	var e2 = add_enzyme_object("Enzyme 2")
	e2.substrates["B"] = 1.0
	e2.products["C"] = 1.0
	e2.vmax = 6.0
	e2.initial_vmax = 6.0
	e2.km = 0.3
	e2.initial_km = 0.3

	## Sink: consumes C
	var sink = add_enzyme_object("Sink C")
	sink.substrates["C"] = 1.0
	sink.vmax = 1.5
	sink.initial_vmax = 1.5

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
	var name = "Enzyme %d" % (enzyme_count + 1)
	add_enzyme_object(name)

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
