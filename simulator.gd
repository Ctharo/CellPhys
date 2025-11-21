## Biochemistry simulator with thermal survival dynamics
## Cells must maintain heat balance through efficient metabolism
class_name Simulator
extends Node

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

## Constants
const R: float = 8.314e-3
const TEMPERATURE: float = 310.0

func _ready() -> void:
	cell = Cell.new()
	molecular_generator = MolecularGenerator.new(cell)
	
	
	initialize_random_system()
	
	print("✅ Dynamic Biochemistry Simulator initialized")
	print("🔥 Heat: %.1f (survival range: %.1f - %.1f)" % [cell.heat, cell.min_heat_threshold, cell.max_heat_threshold])

func _process(delta: float) -> void:
	if is_paused or not cell.is_alive:
		return
	
	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		
	if iteration % 10 == 0:
		print_status()

	
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

#region DATA MANAGEMENT
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
	var total_dg = 0.0
	var favorable_count = 0
	var unfavorable_count = 0
	var equilibrium_count = 0
	var total_energy_flux = 0.0
	var total_heat_flux = 0.0
	
	for enzyme in cell.enzymes:
		for reaction in enzyme.reactions:
			total_dg += reaction.current_delta_g_actual
			total_energy_flux += reaction.current_useful_work
			total_heat_flux += reaction.current_heat_generated
			
			if reaction.current_delta_g_actual < -5.0:
				favorable_count += 1
			elif reaction.current_delta_g_actual > 5.0:
				unfavorable_count += 1
			else:
				equilibrium_count += 1
	
	return {
		"sum_delta_g": total_dg,
		"favorable_count": favorable_count,
		"unfavorable_count": unfavorable_count,
		"equilibrium_count": equilibrium_count,
		"total_energy_flux": total_energy_flux,
		"total_heat_flux": total_heat_flux
	}
#endregion

## Helper function to repeat a string n times
func _repeat_string(s: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += s
	return result

## Print comprehensive simulation status
func print_status(detailed: bool = false) -> void:
	print("\n" + _repeat_string("═", 80))
	print("🔬 BIOCHEMISTRY SIMULATOR STATUS")
	print(_repeat_string("═", 80))
	
	## Cell survival and thermal state
	_print_thermal_status()
	
	## Energy accounting
	_print_energy_status()
	
	## Molecular concentrations
	_print_molecule_status(detailed)
	
	## Enzyme activities
	_print_enzyme_status(detailed)
	
	## System-level metrics
	_print_system_metrics()
	
	print(_repeat_string("═", 80) + "\n")

## Print thermal and survival status
func _print_thermal_status() -> void:
	print("\n🌡️  THERMAL STATUS")
	print(_repeat_string("─", 80))
	
	var thermal = cell.get_thermal_status()
	var status_icon = "✅" if thermal.is_alive else "💀"
	
	print("%s Cell Status: %s" % [status_icon, "ALIVE" if thermal.is_alive else "DEAD"])
	if not thermal.is_alive:
		print("   Death Reason: %s" % cell.death_reason)
	
	var heat_percent = (thermal.heat / thermal.max_threshold) * 100.0
	var heat_bar = _create_bar(thermal.heat, thermal.min_threshold, thermal.max_threshold, 40)
	
	print("   Heat Level: %.1f / %.1f (%.1f%%)" % [thermal.heat, thermal.max_threshold, heat_percent])
	print("   %s" % heat_bar)
	print("   Range: [%.1f - %.1f] (safe zone)" % [thermal.min_threshold, thermal.max_threshold])
	
	var temp_mod = cell.get_temperature_modifier()
	print("   Temperature Modifier: %.2fx (Q10 effect)" % temp_mod)

## Print energy pool status
func _print_energy_status() -> void:
	print("\n⚡ ENERGY STATUS")
	print(_repeat_string("─", 80))
	
	var energy = cell.get_energy_status()
	
	print("   Usable Energy Pool: %.2f kJ" % energy.usable_energy)
	print("   Total Generated: %.2f kJ" % energy.total_generated)
	print("   Total Consumed: %.2f kJ" % energy.total_consumed)
	print("   Total Heat Wasted: %.2f kJ" % energy.total_heat)
	print("   Net Energy: %.2f kJ" % energy.net_energy)
	
	if energy.total_generated > 0:
		var efficiency = (energy.net_energy / energy.total_generated) * 100.0
		print("   System Efficiency: %.1f%%" % efficiency)

## Print molecule concentrations
func _print_molecule_status(detailed: bool) -> void:
	print("\n🧪 MOLECULES (n=%d)" % cell.molecules.size())
	print(_repeat_string("─", 80))
	
	## Sort by concentration (descending)
	var mol_names = cell.molecules.keys()
	mol_names.sort_custom(func(a, b): return cell.molecules[a].concentration > cell.molecules[b].concentration)
	
	var count = 0
	for mol_name in mol_names:
		var mol: Molecule = cell.molecules[mol_name]
		
		## Calculate net production rate
		var net_rate = _calculate_molecule_net_rate(mol_name)
		var rate_indicator = _get_rate_indicator(net_rate)
		
		if detailed or count < 15:
			print("   %s %s: %.3f mM %s" % [
				rate_indicator,
				mol_name,
				mol.concentration,
				_format_rate(net_rate)
			])
			
			if detailed:
				print("      Energy: %.1f kJ/mol | DNA: %s" % [
					mol.potential_energy,
					mol.get_genetic_code_display()
				])
		
		count += 1
	
	if not detailed and count > 15:
		print("   ... and %d more molecules" % (count - 15))

## Print enzyme activities
func _print_enzyme_status(detailed: bool) -> void:
	print("\n⚗️  ENZYMES (n=%d)" % cell.enzymes.size())
	print(_repeat_string("─", 80))
	
	## Sort by absolute net rate (most active first)
	var sorted_enzymes = cell.enzymes.duplicate()
	sorted_enzymes.sort_custom(func(a, b): return abs(a.current_net_rate) > abs(b.current_net_rate))
	
	var count = 0
	for enzyme in sorted_enzymes:
		var direction = _get_direction_indicator(enzyme.current_net_rate)
		
		if detailed or count < 10:
			print("   %s %s [%.4f mM]" % [direction, enzyme.name, enzyme.concentration])
			print("      Fwd: %.3f | Rev: %.3f | Net: %.3f mM/s" % [
				enzyme.current_total_forward_rate,
				enzyme.current_total_reverse_rate,
				enzyme.current_net_rate
			])
			
			if detailed:
				_print_enzyme_reactions(enzyme)
		
		count += 1
	
	if not detailed and count > 10:
		print("   ... and %d more enzymes" % (count - 10))

## Print detailed reaction information for an enzyme
func _print_enzyme_reactions(enzyme: Enzyme) -> void:
	for reaction in enzyme.reactions:
		var rxn_direction = _get_direction_indicator(
			reaction.current_forward_rate - reaction.current_reverse_rate
		)
		
		print("      %s %s" % [rxn_direction, reaction.get_summary()])
		print("         ΔG: %.1f kJ/mol (std: %.1f)" % [
			reaction.current_delta_g_actual,
			reaction.delta_g
		])
		print("         Rates: F=%.3f R=%.3f Net=%.3f" % [
			reaction.current_forward_rate,
			reaction.current_reverse_rate,
			reaction.current_forward_rate - reaction.current_reverse_rate
		])
		
		if reaction.genetic_efficiency > 0:
			print("         Genetic: sim=%.2f eff=%.2f waste=%.1f kJ/mol" % [
				reaction.genetic_similarity,
				reaction.genetic_efficiency,
				reaction.energy_waste
			])
		
		print("         Energy: %.3f kJ/s | Heat: %.3f kJ/s" % [
			reaction.current_useful_work,
			reaction.current_heat_generated
		])

## Print system-wide metrics
func _print_system_metrics() -> void:
	print("\n📊 SYSTEM METRICS")
	print(_repeat_string("─", 80))
	
	var total_dg = 0.0
	var favorable_count = 0
	var equilibrium_count = 0
	var unfavorable_count = 0
	var total_energy_flux = 0.0  ## kJ/s
	var total_heat_flux = 0.0    ## kJ/s
	var active_reaction_count = 0
	
	## Aggregate from all reactions
	for enzyme in cell.enzymes:
		for reaction in enzyme.reactions:
			var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
			
			## Thermodynamic metrics
			total_dg += reaction.current_delta_g_actual
			
			if reaction.current_delta_g_actual < -2.0:
				favorable_count += 1
			elif reaction.current_delta_g_actual > 2.0:
				unfavorable_count += 1
			else:
				equilibrium_count += 1
			
			## Energy and heat fluxes
			total_energy_flux += reaction.current_useful_work
			total_heat_flux += reaction.current_heat_generated
			
			## Count active reactions
			if abs(net_rate) > 0.001:
				active_reaction_count += 1
	
	var total_reaction_count = _count_total_reactions()
	
	## System thermodynamics
	print("   System ΣΔG: %.1f kJ/mol" % total_dg)
	print("   Reactions: Favorable=%d | Equilibrium=%d | Unfavorable=%d" % [
		favorable_count,
		equilibrium_count,
		unfavorable_count
	])
	print("   Active Reactions: %d / %d" % [active_reaction_count, total_reaction_count])
	
	## Energy accounting
	print("   Total Energy Flux: %.3f kJ/s" % total_energy_flux)
	print("   Total Heat Flux: %.3f kJ/s" % total_heat_flux)
	
	if abs(total_energy_flux + total_heat_flux) > 0.001:
		var system_efficiency = (total_energy_flux / (total_energy_flux + total_heat_flux)) * 100.0
		print("   Instantaneous Efficiency: %.1f%%" % system_efficiency)
	
	## Key molecular currencies (if they exist)
	_print_currency_metrics()
	
	## Genetic diversity
	if cell.molecules.size() > 1:
		var avg_diversity = _calculate_average_genetic_diversity()
		print("   Avg Genetic Diversity: %.2f" % avg_diversity)

## Print metrics for key molecular currencies (ATP, NADH, etc.)
func _print_currency_metrics() -> void:
	var currencies = ["ATP", "ADP", "AMP", "NADH", "NAD", "FADH2", "FAD"]
	var found_currencies: Array[String] = []
	
	for currency in currencies:
		if cell.molecules.has(currency):
			found_currencies.append(currency)
	
	if found_currencies.is_empty():
		return
	
	print("   Energy Currencies:")
	for currency in found_currencies:
		var mol: Molecule = cell.molecules[currency]
		var net_rate = _calculate_molecule_net_rate(currency)
		var indicator = _get_rate_indicator(net_rate)
		print("      %s %s: %.3f mM %s" % [
			indicator,
			currency,
			mol.concentration,
			_format_rate(net_rate)
		])

## Count total reactions in the system
func _count_total_reactions() -> int:
	var count = 0
	for enzyme in cell.enzymes:
		count += enzyme.reactions.size()
	return count

## Helper: Calculate net production rate for a molecule
func _calculate_molecule_net_rate(mol_name: String) -> float:
	var net_rate = 0.0
	
	for enzyme in cell.enzymes:
		for reaction in enzyme.reactions:
			var rxn_net = reaction.current_forward_rate - reaction.current_reverse_rate
			
			## Check if molecule is a product
			if reaction.products.has(mol_name):
				net_rate += rxn_net * reaction.products[mol_name]
			
			## Check if molecule is a substrate
			if reaction.substrates.has(mol_name):
				net_rate -= rxn_net * reaction.substrates[mol_name]
	
	return net_rate

## Helper: Calculate average genetic diversity
func _calculate_average_genetic_diversity() -> float:
	var mol_list = cell.molecules.values()
	if mol_list.size() < 2:
		return 0.0
	
	var total_similarity = 0.0
	var comparisons = 0
	
	for i in range(mol_list.size()):
		for j in range(i + 1, mol_list.size()):
			var mol_i: Molecule = mol_list[i]
			var mol_j: Molecule = mol_list[j]
			total_similarity += mol_i.similarity_to(mol_j)
			comparisons += 1
	
	var avg_similarity = total_similarity / comparisons
	return 1.0 - avg_similarity  ## Convert to diversity

## Helper: Create visual bar indicator
func _create_bar(value: float, min_val: float, max_val: float, width: int) -> String:
	var range_val = max_val - min_val
	var normalized = clamp((value - min_val) / range_val, 0.0, 1.0)
	var filled = int(normalized * width)
	
	var bar = "["
	for i in range(width):
		if i < filled:
			bar += "█"
		else:
			bar += "░"
	bar += "]"
	
	return bar

## Helper: Get rate indicator symbol
func _get_rate_indicator(rate: float) -> String:
	if abs(rate) < 0.001:
		return "⊜"  ## Equilibrium
	elif rate > 0:
		return "↑"  ## Increasing
	else:
		return "↓"  ## Decreasing

## Helper: Get direction indicator
func _get_direction_indicator(net_rate: float) -> String:
	if abs(net_rate) < 0.001:
		return "⇄"
	elif net_rate > 0.5:
		return "→→"
	elif net_rate > 0:
		return "→"
	elif net_rate < -0.5:
		return "←←"
	else:
		return "←"

## Helper: Format rate with sign
func _format_rate(rate: float) -> String:
	if abs(rate) < 0.001:
		return "(~0)"
	elif rate > 0:
		return "(+%.3f mM/s)" % rate
	else:
		return "(%.3f mM/s)" % rate
