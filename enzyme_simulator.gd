## Advanced enzyme feedback loop simulator with thermodynamics
## Simulation logic separated from UI concerns

class_name EnzymeSimulator
extends Control

## Simulation state
var molecules: Dictionary = {}
var enzymes: Array[Enzyme] = []
var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false
var enzyme_count: int = 0

## UI state
var selected_enzyme: Enzyme = null
var selected_molecule: String = ""
var dragging_molecule: String = ""

## UI manager
var ui_manager: SimulatorUI

## Constants
const R: float = 8.314e-3  # Gas constant in kJ/(mol·K)
const TEMPERATURE: float = 310.0  # 37°C in Kelvin

func _ready() -> void:
	ui_manager = SimulatorUI.new(self)
	add_child(ui_manager)
	ui_manager.build_ui()
	
	initialize_molecules()
	initialize_enzymes()
	
	## Build UI elements for all molecules and enzymes
	ui_manager.rebuild_molecule_list()
	ui_manager.rebuild_enzyme_list()
	ui_manager.update_all()
	
	print("✅ Thermodynamic Enzyme Simulator initialized")

func _process(delta: float) -> void:
	if is_paused:
		return

	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		ui_manager.update_all()

## ============================================================================
## SIMULATION LOGIC (No UI code here)
## ============================================================================

func initialize_molecules() -> void:
	add_molecule("ADP_precursor", 5.0)
	add_molecule("Pi_precursor", 5.0)
	add_molecule("ADP", 0.1)
	add_molecule("Phosphate", 0.1)
	add_molecule("ATP", 0.05)

func initialize_enzymes() -> void:
	## Source 1: ADP_precursor synthase
	var source_adp = add_enzyme_object("ADP Precursor Synthase")
	source_adp.products["ADP_precursor"] = 1.0
	source_adp.kcat_forward = 3.0
	source_adp.km_substrates = {}
	source_adp.delta_g_standard = -10.0
	
	## Source 2: Pi_precursor synthase
	var source_pi = add_enzyme_object("Phosphate Precursor Synthase")
	source_pi.products["Pi_precursor"] = 1.0
	source_pi.kcat_forward = 3.0
	source_pi.delta_g_standard = -10.0
	
	## Enzyme 3: ADP_precursor → ADP
	var adp_synthase = add_enzyme_object("ADP Synthase")
	adp_synthase.substrates["ADP_precursor"] = 1.0
	adp_synthase.products["ADP"] = 1.0
	adp_synthase.kcat_forward = 3.0
	adp_synthase.kcat_reverse = 0.3
	adp_synthase.km_substrates["ADP_precursor"] = 0.5
	adp_synthase.delta_g_standard = -8.0

	## Enzyme 4: Pi_precursor → Phosphate
	var pi_synthase = add_enzyme_object("Phosphate Synthase")
	pi_synthase.substrates["Pi_precursor"] = 1.0
	pi_synthase.products["Phosphate"] = 1.0
	pi_synthase.kcat_forward = 3.0
	pi_synthase.kcat_reverse = 0.3
	pi_synthase.km_substrates["Pi_precursor"] = 0.5
	pi_synthase.delta_g_standard = -8.0

	## ATP Synthase: ADP + Phosphate → ATP (with product inhibition)
	var atp_synthase = add_enzyme_object("ATP Synthase")
	atp_synthase.substrates["ADP"] = 1.0
	atp_synthase.substrates["Phosphate"] = 1.0
	atp_synthase.products["ATP"] = 1.0
	atp_synthase.kcat_forward = 5.0
	atp_synthase.kcat_reverse = 0.5
	atp_synthase.km_substrates["ADP"] = 0.3
	atp_synthase.km_substrates["Phosphate"] = 0.3
	atp_synthase.km_products["ATP"] = 0.5
	atp_synthase.delta_g_standard = 30.5  # Unfavorable, driven by concentrations!
	
	## Allosteric product inhibition by ATP
	atp_synthase.allosteric_inhibitors["ATP"] = {
		"kd": 2.0,
		"fold": 0.3
	}

	## ATPase: ATP → ADP + Phosphate (reverse reaction/ATP consumption)
	var atpase = add_enzyme_object("ATPase")
	atpase.substrates["ATP"] = 1.0
	atpase.products["ADP"] = 1.0
	atpase.products["Phosphate"] = 1.0
	atpase.kcat_forward = 10.0
	atpase.kcat_reverse = 1.0
	atpase.km_substrates["ATP"] = 4.0
	atpase.delta_g_standard = -30.5  # Very favorable

func simulate_step() -> void:
	## Update enzyme concentrations (creation/degradation)
	for enzyme in enzymes:
		enzyme.update_enzyme_concentration(molecules, timestep)

	## Calculate forward and reverse rates
	for enzyme in enzymes:
		enzyme.current_forward_rate = enzyme.calculate_forward_rate(molecules)
		enzyme.current_reverse_rate = enzyme.calculate_reverse_rate(molecules)
		enzyme.current_delta_g = enzyme.calculate_actual_delta_g(molecules)

	## Apply net reactions
	for enzyme in enzymes:
		var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
		apply_catalysis(enzyme, net_rate)

	## Prevent negative concentrations
	for mol in molecules.values():
		mol.concentration = max(mol.concentration, 0.0)
	for enzyme in enzymes:
		enzyme.concentration = max(enzyme.concentration, 0.0)

func apply_catalysis(enzyme: Enzyme, net_rate: float) -> void:
	var rate = net_rate * timestep

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

## ============================================================================
## DATA MANAGEMENT (No UI code here)
## ============================================================================

func add_molecule(mol_name: String, concentration: float) -> void:
	molecules[mol_name] = Molecule.new(mol_name, concentration)
	print("✅ Added molecule: %s" % mol_name)

func remove_molecule(mol_name: String) -> bool:
	if not molecules.has(mol_name):
		return false

	## Check if molecule is used by any enzyme
	for enzyme in enzymes:
		if enzyme.substrates.has(mol_name) or enzyme.products.has(mol_name):
			print("⚠️ Cannot remove '%s': used by enzyme '%s'" % [mol_name, enzyme.name])
			return false
		if enzyme.competitive_inhibitors.has(mol_name):
			print("⚠️ Cannot remove '%s': used as competitive inhibitor by '%s'" % [mol_name, enzyme.name])
			return false
		if enzyme.allosteric_inhibitors.has(mol_name) or enzyme.allosteric_activators.has(mol_name):
			print("⚠️ Cannot remove '%s': used as allosteric regulator by '%s'" % [mol_name, enzyme.name])
			return false

	molecules.erase(mol_name)
	print("✅ Removed molecule: %s" % mol_name)
	return true

func add_enzyme_object(enzyme_name: String) -> Enzyme:
	enzyme_count += 1
	var enzyme_id = "e" + str(enzyme_count)
	var enzyme = Enzyme.new(enzyme_id, enzyme_name)
	enzyme.temperature = TEMPERATURE
	enzymes.append(enzyme)
	print("✅ Added enzyme: %s" % enzyme_name)
	return enzyme

func remove_enzyme(enzyme: Enzyme) -> void:
	enzymes.erase(enzyme)
	if selected_enzyme == enzyme:
		selected_enzyme = null
	print("✅ Removed enzyme: %s" % enzyme.name)

func add_molecule_to_enzyme(enzyme: Enzyme, mol_name: String, slot_type: String) -> void:
	match slot_type:
		"substrate":
			if not enzyme.substrates.has(mol_name):
				enzyme.substrates[mol_name] = 1.0
				if not enzyme.km_substrates.has(mol_name):
					enzyme.km_substrates[mol_name] = 0.5
		"product":
			if not enzyme.products.has(mol_name):
				enzyme.products[mol_name] = 1.0
				if not enzyme.km_products.has(mol_name):
					enzyme.km_products[mol_name] = 0.5
		"competitive_inhibitor":
			if not enzyme.competitive_inhibitors.has(mol_name):
				enzyme.competitive_inhibitors[mol_name] = 0.5  # Ki
		"noncompetitive_inhibitor":
			if not enzyme.noncompetitive_inhibitors.has(mol_name):
				enzyme.noncompetitive_inhibitors[mol_name] = 0.5  # Ki
		"allosteric_inhibitor":
			if not enzyme.allosteric_inhibitors.has(mol_name):
				enzyme.allosteric_inhibitors[mol_name] = {"kd": 0.5, "fold": 0.3}
		"allosteric_activator":
			if not enzyme.allosteric_activators.has(mol_name):
				enzyme.allosteric_activators[mol_name] = {"kd": 0.5, "fold": 2.0}
		"creation_regulator":
			if not enzyme.creation_regulators.has(mol_name):
				enzyme.creation_regulators[mol_name] = {"type": "activator", "kd": 0.5, "max_effect": 0.01}
		"degradation_regulator":
			if not enzyme.degradation_regulators.has(mol_name):
				enzyme.degradation_regulators[mol_name] = {"type": "activator", "kd": 0.5, "max_effect": 0.01}
	print("✅ Added %s '%s' to %s" % [slot_type, mol_name, enzyme.name])

func remove_molecule_from_enzyme(enzyme: Enzyme, mol_name: String, slot_type: String) -> void:
	match slot_type:
		"substrate":
			enzyme.substrates.erase(mol_name)
		"product":
			enzyme.products.erase(mol_name)
		"competitive_inhibitor":
			enzyme.competitive_inhibitors.erase(mol_name)
		"noncompetitive_inhibitor":
			enzyme.noncompetitive_inhibitors.erase(mol_name)
		"allosteric_inhibitor":
			enzyme.allosteric_inhibitors.erase(mol_name)
		"allosteric_activator":
			enzyme.allosteric_activators.erase(mol_name)
		"creation_regulator":
			enzyme.creation_regulators.erase(mol_name)
		"degradation_regulator":
			enzyme.degradation_regulators.erase(mol_name)
	print("✅ Removed %s '%s' from %s" % [slot_type, mol_name, enzyme.name])

## ============================================================================
## BUTTON CALLBACKS (Minimal logic, delegates to UI manager)
## ============================================================================

func _on_pause_button_pressed() -> void:
	is_paused = !is_paused

func _on_reset_button_pressed() -> void:
	## Reset all molecules to initial values
	for mol in molecules.values():
		mol.concentration = mol.initial_concentration

	## Reset all enzymes to initial values
	for enzyme in enzymes:
		enzyme.concentration = enzyme.initial_concentration

	total_time = 0.0
	iteration = 0
	ui_manager.update_all()
	print("✅ Reset to initial values")

func _on_add_molecule_pressed() -> void:
	ui_manager.show_add_molecule_dialog()

func _on_add_enzyme_pressed() -> void:
	var n = "Enzyme %d" % (enzyme_count + 1)
	add_enzyme_object(n)
	ui_manager.rebuild_enzyme_list()

func on_enzyme_selected(enzyme: Enzyme) -> void:
	selected_enzyme = enzyme
	selected_molecule = ""
	ui_manager.show_enzyme_detail(enzyme)

func on_molecule_info_clicked(mol_name: String) -> void:
	selected_molecule = mol_name
	selected_enzyme = null
	ui_manager.show_molecule_detail(mol_name)

func start_molecule_drag(mol_name: String) -> void:
	dragging_molecule = mol_name

func stop_molecule_drag() -> void:
	dragging_molecule = ""
