## Advanced enzyme feedback loop simulator with thermodynamics
## Simulation logic separated from UI concerns

class_name EnzymeSimulator
extends Control

## Simulation state
var molecules: Dictionary = {}
var enzymes: Array[Enzyme] = []
var reactions: Array[Reaction] = []  ## All reactions across all enzymes
var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false
var enzyme_count: int = 0
var reaction_count: int = 0

## UI state
var selected_enzyme: Enzyme = null
var selected_reaction: Reaction = null
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
	## Start with conditions far from equilibrium to see dynamic behavior
	add_molecule("ADP", 5.0)  ## High ADP
	add_molecule("Pi", 5.0)   ## High inorganic phosphate
	add_molecule("ATP", 0.01)  ## Low ATP (will build up)
	add_molecule("Glucose", 10.0)  ## High glucose (fuel source)
	add_molecule("G6P", 0.05)  ## Very low G6P
	add_molecule("Pyruvate", 0.05)  ## Very low Pyruvate

func initialize_enzymes() -> void:
	## Glucose source (represents external glucose supply)
	var glucose_source = add_enzyme_object("Glucose Transporter")
	glucose_source.concentration = 0.005  ## Lower concentration
	var gluc_import = create_reaction("Glucose Import")
	gluc_import.products["Glucose"] = 1.0
	gluc_import.delta_g = -8.0  ## More favorable to push glucose in
	gluc_import.vmax = 1.5  ## Slower import
	gluc_import.initial_vmax = 1.5
	gluc_import.km = 0.5
	gluc_import.initial_km = 0.5
	glucose_source.add_reaction(gluc_import)
	
	## Hexokinase: Glucose + ATP → G6P + ADP (consumes ATP)
	var hexokinase = add_enzyme_object("Hexokinase")
	hexokinase.concentration = 0.02
	var hex_rxn = create_reaction("Glucose Phosphorylation")
	hex_rxn.substrates["Glucose"] = 1.0
	hex_rxn.substrates["ATP"] = 1.0
	hex_rxn.products["G6P"] = 1.0
	hex_rxn.products["ADP"] = 1.0
	hex_rxn.delta_g = -16.7  ## Highly favorable, ATP hydrolysis
	hex_rxn.vmax = 5.0  ## Higher capacity
	hex_rxn.initial_vmax = 5.0
	hex_rxn.km = 0.15  ## Lower Km for better substrate binding
	hex_rxn.initial_km = 0.15
	hex_rxn.is_irreversible = true  ## This is a committed step in glycolysis
	hexokinase.add_reaction(hex_rxn)
	hexokinase.inhibitors["G6P"] = 0.5  ## Product inhibition (higher Ki)
	
	## Glycolytic enzyme: G6P → Pyruvate + ATP (net ATP production)
	## Simplified representation of glycolysis
	var glycolysis = add_enzyme_object("Glycolysis Enzymes")
	glycolysis.concentration = 0.015
	var glyc_rxn = create_reaction("Glycolysis")
	glyc_rxn.substrates["G6P"] = 1.0
	glyc_rxn.substrates["ADP"] = 2.0
	glyc_rxn.substrates["Pi"] = 2.0
	glyc_rxn.products["Pyruvate"] = 2.0
	glyc_rxn.products["ATP"] = 2.0
	glyc_rxn.delta_g = -85.0  ## Very favorable overall
	glyc_rxn.vmax = 3.0  ## Moderate rate
	glyc_rxn.initial_vmax = 3.0
	glyc_rxn.km = 0.3  ## Higher Km
	glyc_rxn.initial_km = 0.3
	glycolysis.add_reaction(glyc_rxn)
	
	## ATP Synthase (represents oxidative phosphorylation)
	## ADP + Pi → ATP (powered by proton gradient in reality)
	## This reaction is IRREVERSIBLE under normal physiological conditions
	var atp_synthase = add_enzyme_object("ATP Synthase")
	atp_synthase.concentration = 0.03  ## Higher concentration
	var atp_synth_rxn = create_reaction("ATP Synthesis")
	atp_synth_rxn.substrates["ADP"] = 1.0
	atp_synth_rxn.substrates["Pi"] = 1.0
	atp_synth_rxn.products["ATP"] = 1.0
	atp_synth_rxn.delta_g = 30.5  ## Unfavorable thermodynamically (needs proton gradient)
	atp_synth_rxn.vmax = 8.0  ## High capacity for ATP synthesis
	atp_synth_rxn.initial_vmax = 8.0
	atp_synth_rxn.km = 1.0  ## Higher Km
	atp_synth_rxn.initial_km = 1.0
	atp_synth_rxn.is_irreversible = true  ## Cannot run backwards (would require ATP hydrolysis to pump protons)
	atp_synthase.add_reaction(atp_synth_rxn)
	atp_synthase.inhibitors["ATP"] = 1.0  ## Product inhibition (higher Ki)
	atp_synthase.activators["Pyruvate"] = 5.0  ## Strongly activated by metabolic fuel
	
	## ATPase: ATP → ADP + Pi (ATP consumption/hydrolysis)
	var atpase = add_enzyme_object("ATPase")
	atpase.concentration = 0.008  ## Lower concentration
	var atp_hydro = create_reaction("ATP Hydrolysis")
	atp_hydro.substrates["ATP"] = 1.0
	atp_hydro.products["ADP"] = 1.0
	atp_hydro.products["Pi"] = 1.0
	atp_hydro.delta_g = -30.5  ## Highly favorable
	atp_hydro.vmax = 1.5  ## Lower consumption rate
	atp_hydro.initial_vmax = 1.5
	atp_hydro.km = 1.5  ## Higher Km (only active when ATP is abundant)
	atp_hydro.initial_km = 1.5
	atpase.add_reaction(atp_hydro)

func simulate_step() -> void:
	## Update enzyme concentrations (creation/degradation)
	for enzyme in enzymes:
		enzyme.update_enzyme_concentration(molecules, timestep)

	## Calculate forward and reverse rates for all reactions
	for enzyme in enzymes:
		enzyme.update_reaction_rates(molecules)

	## Apply net reactions
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
			apply_reaction(reaction, net_rate)

	## Prevent negative concentrations
	for mol in molecules.values():
		mol.concentration = max(mol.concentration, 0.0)
	for enzyme in enzymes:
		enzyme.concentration = max(enzyme.concentration, 0.0)

func apply_reaction(reaction: Reaction, net_rate: float) -> void:
	var rate = net_rate * timestep

	## Consume substrates with stoichiometry
	for substrate in reaction.substrates:
		if molecules.has(substrate):
			var stoich = reaction.substrates[substrate]
			molecules[substrate].concentration -= rate * stoich

	## Produce products with stoichiometry
	for product in reaction.products:
		if molecules.has(product):
			var stoich = reaction.products[product]
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

	## Check if molecule is used by any reaction
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			if reaction.substrates.has(mol_name) or reaction.products.has(mol_name):
				print("⚠️ Cannot remove '%s': used by reaction '%s'" % [mol_name, reaction.name])
				return false
		if enzyme.inhibitors.has(mol_name) or enzyme.activators.has(mol_name):
			print("⚠️ Cannot remove '%s': used as regulator by '%s'" % [mol_name, enzyme.name])
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

func create_reaction(reaction_name: String) -> Reaction:
	reaction_count += 1
	var reaction_id = "r" + str(reaction_count)
	var reaction = Reaction.new(reaction_id, reaction_name)
	reaction.temperature = TEMPERATURE
	reactions.append(reaction)
	print("✅ Created reaction: %s" % reaction_name)
	return reaction

func remove_enzyme(enzyme: Enzyme) -> void:
	## Remove all reactions associated with this enzyme
	for reaction in enzyme.reactions:
		reactions.erase(reaction)
	
	enzymes.erase(enzyme)
	if selected_enzyme == enzyme:
		selected_enzyme = null
	print("✅ Removed enzyme: %s" % enzyme.name)

## Calculate system-wide thermodynamics
func calculate_system_energetics() -> Dictionary:
	var total_forward_rate = 0.0
	var total_reverse_rate = 0.0
	var total_net_rate = 0.0
	var sum_delta_g = 0.0
	var favorable_count = 0
	var unfavorable_count = 0
	var equilibrium_count = 0
	
	for enzyme in enzymes:
		total_forward_rate += enzyme.current_total_forward_rate
		total_reverse_rate += enzyme.current_total_reverse_rate
		total_net_rate += enzyme.current_net_rate
		
		for reaction in enzyme.reactions:
			sum_delta_g += reaction.current_delta_g_actual
			
			if reaction.current_delta_g_actual < -5.0:
				favorable_count += 1
			elif reaction.current_delta_g_actual > 5.0:
				unfavorable_count += 1
			else:
				equilibrium_count += 1
	
	return {
		"total_forward_rate": total_forward_rate,
		"total_reverse_rate": total_reverse_rate,
		"total_net_rate": total_net_rate,
		"sum_delta_g": sum_delta_g,
		"favorable_count": favorable_count,
		"unfavorable_count": unfavorable_count,
		"equilibrium_count": equilibrium_count
	}

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

	## Reset all reactions
	for reaction in reactions:
		reaction.vmax = reaction.initial_vmax
		reaction.km = reaction.initial_km

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
