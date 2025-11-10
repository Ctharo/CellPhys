## Biochemistry simulator with thermal survival dynamics
## Cells must maintain heat balance through efficient metabolism
class_name EnzymeSimulator
extends Control

## Cell and simulation state
var cell: Cell
var molecular_generator: MolecularGenerator
var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false

## UI state
var selected_enzyme: Enzyme = null
var selected_molecule: String = ""

## UI manager
var ui_manager: SimulatorUI

## Constants
const R: float = 8.314e-3
const TEMPERATURE: float = 310.0

func _ready() -> void:
	## Initialize cell
	cell = Cell.new()
	molecular_generator = MolecularGenerator.new(cell)
	
	## Setup UI
	ui_manager = SimulatorUI.new(self)
	add_child(ui_manager)
	
	## Initialize with random molecules and enzymes
	initialize_random_system()
	
	## UI will be built in the scene file
	ui_manager.update_all()
	
	print("✅ Dynamic Biochemistry Simulator initialized")
	print("🔥 Heat: %.1f (survival range: %.1f - %.1f)" % [cell.heat, cell.min_heat_threshold, cell.max_heat_threshold])

func _process(delta: float) -> void:
	if is_paused or not cell.is_alive:
		return
	
	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		ui_manager.update_all()

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize_random_system() -> void:
	print("\n🧬 Generating random biochemical system...")
	
	## Generate starting molecules
	molecular_generator.initialize_starting_molecules(5)
	
	## Generate starting enzymes with reactions
	molecular_generator.initialize_starting_enzymes(4)
	
	## Optional: generate a pathway
	if randf() < 0.5:
		molecular_generator.generate_linear_pathway(3)
	
	print("\n📊 System initialized:")
	print("  - Molecules: %d" % cell.molecules.size())
	print("  - Enzymes: %d" % cell.enzymes.size())
	print("  - Initial heat: %.1f" % cell.heat)
	print("  - Usable energy: %.1f kJ" % cell.usable_energy_pool)

## ============================================================================
## SIMULATION LOGIC
## ============================================================================

func simulate_step() -> void:
	if not cell.is_alive:
		return
	
	## Get all reactions
	var all_reactions: Array[Reaction] = []
	for enzyme in cell.enzymes:
		all_reactions.append_array(enzyme.reactions)
	
	## Update reaction rates
	for enzyme in cell.enzymes:
		enzyme.update_reaction_rates(cell.molecules, cell.usable_energy_pool)
	
	## Apply reactions
	for enzyme in cell.enzymes:
		for reaction in enzyme.reactions:
			var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
			apply_reaction(reaction, net_rate)
	
	## Update cell thermal and energy state
	cell.update_heat(timestep, all_reactions)
	cell.update_energy_pool(timestep, all_reactions)
	
	## Prevent negative concentrations
	for mol in cell.molecules.values():
		mol.concentration = max(mol.concentration, 0.0)
	for enzyme in cell.enzymes:
		enzyme.concentration = max(enzyme.concentration, 0.0)
	
	## Check for extinction events
	check_molecular_extinction()

func apply_reaction(reaction: Reaction, net_rate: float) -> void:
	var rate = net_rate * timestep
	
	## Consume substrates
	for substrate in reaction.substrates:
		if cell.molecules.has(substrate):
			var stoich = reaction.substrates[substrate]
			cell.molecules[substrate].concentration -= rate * stoich
	
	## Produce products
	for product in reaction.products:
		if cell.molecules.has(product):
			var stoich = reaction.products[product]
			cell.molecules[product].concentration += rate * stoich

## Check if any molecules have gone extinct
func check_molecular_extinction() -> void:
	var extinct_molecules: Array[String] = []
	
	for mol_name in cell.molecules.keys():
		if cell.molecules[mol_name].concentration < 0.0001:
			extinct_molecules.append(mol_name)
	
	## Remove extinct molecules
	for mol_name in extinct_molecules:
		## Check if it's critical (used in reactions)
		var is_critical = false
		for enzyme in cell.enzymes:
			for reaction in enzyme.reactions:
				if reaction.substrates.has(mol_name):
					is_critical = true
					break
			if is_critical:
				break
		
		if is_critical:
			print("⚠️ Critical molecule extinct: %s" % mol_name)
		else:
			cell.molecules.erase(mol_name)
			if selected_molecule == mol_name:
				selected_molecule = ""

## ============================================================================
## DATA MANAGEMENT
## ============================================================================

func add_molecule(mol_name: String, concentration: float) -> void:
	if cell.molecules.has(mol_name):
		print("⚠️ Molecule already exists: %s" % mol_name)
		return
	
	var mol = Molecule.new(mol_name, concentration)
	cell.molecules[mol_name] = mol
	print("✅ Added molecule: %s" % mol.get_summary())

func remove_molecule(mol_name: String) -> bool:
	if not cell.molecules.has(mol_name):
		return false
	
	## Check if used in reactions
	for enzyme in cell.enzymes:
		for reaction in enzyme.reactions:
			if reaction.substrates.has(mol_name) or reaction.products.has(mol_name):
				print("⚠️ Cannot remove: used in reaction")
				return false
	
	cell.molecules.erase(mol_name)
	print("✅ Removed molecule: %s" % mol_name)
	return true

func add_random_molecule() -> void:
	var mol = molecular_generator.generate_random_molecule(randf_range(0.5, 2.0))
	cell.molecules[mol.name] = mol
	print("✅ Generated molecule: %s" % mol.get_summary())

func add_random_enzyme() -> void:
	var enzyme = molecular_generator.generate_enzyme_with_reaction("random")
	cell.enzymes.append(enzyme)
	print("✅ Generated enzyme: %s" % enzyme.name)

func remove_enzyme(enzyme: Enzyme) -> void:
	cell.enzymes.erase(enzyme)
	if selected_enzyme == enzyme:
		selected_enzyme = null
	print("✅ Removed enzyme: %s" % enzyme.name)

## Calculate system energetics
func calculate_system_energetics() -> Dictionary:
	var total_forward_rate = 0.0
	var total_reverse_rate = 0.0
	var total_net_rate = 0.0
	var sum_delta_g = 0.0
	var favorable_count = 0
	var unfavorable_count = 0
	var equilibrium_count = 0
	
	for enzyme in cell.enzymes:
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
## BUTTON CALLBACKS
## ============================================================================

func _on_pause_button_pressed() -> void:
	is_paused = !is_paused

func _on_reset_button_pressed() -> void:
	## Full reset
	cell = Cell.new()
	molecular_generator = MolecularGenerator.new(cell)
	total_time = 0.0
	iteration = 0
	selected_enzyme = null
	selected_molecule = ""
	
	initialize_random_system()
	ui_manager.rebuild_molecule_list()
	ui_manager.rebuild_enzyme_list()
	ui_manager.update_all()
	
	print("✅ System reset with new random configuration")

func _on_add_molecule_pressed() -> void:
	add_random_molecule()
	ui_manager.rebuild_molecule_list()

func _on_add_enzyme_pressed() -> void:
	add_random_enzyme()
	ui_manager.rebuild_enzyme_list()

func on_enzyme_selected(enzyme: Enzyme) -> void:
	selected_enzyme = enzyme
	selected_molecule = ""
	ui_manager.show_enzyme_detail(enzyme)

func on_molecule_info_clicked(mol_name: String) -> void:
	selected_molecule = mol_name
	selected_enzyme = null
	ui_manager.show_molecule_detail(mol_name)
