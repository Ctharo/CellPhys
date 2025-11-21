## Main biochemistry simulator with random generation
class_name Simulator
extends Node

var molecules: Dictionary = {}  ## {name: Molecule}
var enzymes: Array[Enzyme] = []
var cell: Cell = null

var timestep: float = 0.1  ## Simulation timestep in seconds
var accumulated_time: float = 0.0
var update_interval: float = 1.0  ## Print stats every second

var reaction_counter: int = 0
var enzyme_counter: int = 0

func _init() -> void:
	cell = Cell.new()
	cell.molecules = molecules
	cell.enzymes = enzymes

func _ready() -> void:
	## Generate initial random system
	generate_random_system()
	print_system_state()

func _process(delta: float) -> void:
	if not cell.is_alive:
		set_process(false)
		return
	
	## Run simulation step
	update_simulation(delta)
	
	## Periodic printouts
	accumulated_time += delta
	if accumulated_time >= update_interval:
		print_system_state()
		accumulated_time = 0.0

#region Random Generation

## Generate a random biochemical system
func generate_random_system() -> void:
	print("\n🧬 Generating Random Biochemical System...")
	
	## Create 5-10 random molecules
	var num_molecules = randi_range(5, 10)
	for i in range(num_molecules):
		var mol_name = Molecule.generate_random_name()
		var initial_conc = randf_range(0.1, 5.0)
		var molecule = Molecule.new(mol_name, initial_conc)
		molecules[mol_name] = molecule
		print("  ✓ Molecule: %s" % molecule.get_summary())
	
	## Create 3-6 enzymes
	var num_enzymes = randi_range(3, 6)
	for i in range(num_enzymes):
		var enzyme = generate_random_enzyme()
		enzymes.append(enzyme)
	
	print("✅ Generated %d molecules and %d enzymes\n" % [molecules.size(), enzymes.size()])

## Generate a random enzyme with reactions
func generate_random_enzyme() -> Enzyme:
	enzyme_counter += 1
	var enzyme_name = "Enzyme_%d" % enzyme_counter
	var enzyme = Enzyme.new("enz_%d" % enzyme_counter, enzyme_name)
	enzyme.concentration = randf_range(0.001, 0.01)
	
	## Each enzyme catalyzes 1-3 reactions
	var num_reactions = randi_range(1, 3)
	for i in range(num_reactions):
		var reaction = generate_random_reaction()
		enzyme.add_reaction(reaction)
	
	return enzyme

## Generate a random reaction
func generate_random_reaction() -> Reaction:
	reaction_counter += 1
	var reaction_name = "Rxn_%d" % reaction_counter
	var reaction = Reaction.new("rxn_%d" % reaction_counter, reaction_name)
	
	## Randomly decide if this is a source or sink (10% chance each)
	var rand_val = randf()
	if rand_val < 0.1:
		## Source reaction (no substrates)
		generate_source_reaction(reaction)
	elif rand_val < 0.2:
		## Sink reaction (no products)
		generate_sink_reaction(reaction)
	else:
		## Normal reaction
		generate_normal_reaction(reaction)
	
	## Random thermodynamics
	reaction.delta_g = randf_range(-30.0, 15.0)  ## Favor exergonic reactions
	
	## Random kinetics
	reaction.vmax = randf_range(0.5, 10.0)
	reaction.initial_vmax = reaction.vmax
	reaction.km = randf_range(0.1, 2.0)
	reaction.initial_km = reaction.km
	
	## Small chance of irreversibility
	if randf() < 0.15:
		reaction.is_irreversible = true
	
	return reaction

## Generate source reaction (creates molecules)
func generate_source_reaction(reaction: Reaction) -> void:
	## Pick 1-2 random existing molecules as products
	var available_molecules = molecules.keys()
	var num_products = randi_range(1, min(2, available_molecules.size()))
	
	for i in range(num_products):
		var mol_name = available_molecules[randi() % available_molecules.size()]
		var stoich = randf_range(0.5, 2.0)
		reaction.products[mol_name] = stoich

## Generate sink reaction (consumes molecules)
func generate_sink_reaction(reaction: Reaction) -> void:
	## Pick 1-2 random existing molecules as substrates
	var available_molecules = molecules.keys()
	var num_substrates = randi_range(1, min(2, available_molecules.size()))
	
	for i in range(num_substrates):
		var mol_name = available_molecules[randi() % available_molecules.size()]
		var stoich = randf_range(0.5, 2.0)
		reaction.substrates[mol_name] = stoich

## Generate normal reaction (substrates → products)
func generate_normal_reaction(reaction: Reaction) -> void:
	var available_molecules = molecules.keys()
	
	## Pick 1-3 substrates
	var num_substrates = randi_range(1, min(3, available_molecules.size()))
	var used_substrates = []
	
	for i in range(num_substrates):
		var mol_name = available_molecules[randi() % available_molecules.size()]
		## Avoid duplicates
		if mol_name not in used_substrates:
			used_substrates.append(mol_name)
			var stoich = randf_range(0.5, 2.0)
			reaction.substrates[mol_name] = stoich
	
	## Pick 1-3 products
	## 50% chance to create new molecules, 50% use existing
	var num_products = randi_range(1, 3)
	
	for i in range(num_products):
		if randf() < 0.5 and available_molecules.size() > 0:
			## Use existing molecule
			var mol_name = available_molecules[randi() % available_molecules.size()]
			var stoich = randf_range(0.5, 2.0)
			reaction.products[mol_name] = stoich
		else:
			## Create new molecule as product
			## Base it on a random substrate for similarity
			if used_substrates.size() > 0:
				var substrate_name = used_substrates[randi() % used_substrates.size()]
				var substrate_mol = molecules[substrate_name]
				var product_mol = Molecule.create_product_from_substrate(
					substrate_mol,
					reaction.reaction_efficiency
				)
				molecules[product_mol.name] = product_mol
				
				var stoich = randf_range(0.5, 2.0)
				reaction.products[product_mol.name] = stoich

#endregion

#region Simulation Update

func update_simulation(delta: float) -> void:
	## Get all reactions from all enzymes
	var all_reactions: Array[Reaction] = []
	for enzyme in enzymes:
		all_reactions.append_array(enzyme.reactions)
	
	## Update reaction rates
	for enzyme in enzymes:
		enzyme.update_reaction_rates(molecules, cell.usable_energy_pool)
	
	## Apply concentration changes
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			apply_reaction(reaction, delta)
	
	## Update product energies based on thermodynamics
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			reaction.update_product_energies(molecules)
	
	## Update energy partitioning
	for reaction in all_reactions:
		var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
		reaction.calculate_energy_partition(net_rate, molecules)
	
	## Update cell thermal and energy state
	cell.update_heat(delta, all_reactions)
	cell.update_energy_pool(delta, all_reactions)

func apply_reaction(reaction: Reaction, delta: float) -> void:
	var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
	
	if abs(net_rate) < 1e-9:
		return
	
	var amount = net_rate * delta
	
	## Consume substrates
	for substrate_name in reaction.substrates:
		if molecules.has(substrate_name):
			var stoich = reaction.substrates[substrate_name]
			molecules[substrate_name].concentration -= amount * stoich
			molecules[substrate_name].concentration = max(
				molecules[substrate_name].concentration,
				0.0
			)
	
	## Produce products
	for product_name in reaction.products:
		if molecules.has(product_name):
			var stoich = reaction.products[product_name]
			molecules[product_name].concentration += amount * stoich

#endregion

#region Printout Methods

func print_system_state() -> void:
	print("\n" + "=".repeat(80))
	print("🔬 BIOCHEMICAL SYSTEM STATE (t=%.1fs)" % get_process_delta_time())
	print("=".repeat(80))
	
	print_cell_status()
	print_molecule_summary()
	print_enzyme_details()
	print_energy_summary()
	
	print("=".repeat(80) + "\n")

func print_cell_status() -> void:
	print("\n📊 CELL STATUS:")
	var thermal = cell.get_thermal_status()
	var energy = cell.get_energy_status()
	
	print("  Alive: %s" % ("✅ YES" if cell.is_alive else "💀 NO"))
	if not cell.is_alive:
		print("  Death Reason: %s" % cell.death_reason)
	
	print("  Heat: %.2f / %.2f (%.1f%%)" % [
		thermal.heat,
		thermal.max_threshold,
		thermal.heat_ratio * 100.0
	])
	print("  Usable Energy Pool: %.2f kJ" % energy.usable_energy)
	print("  Total Generated: %.2f kJ" % energy.total_generated)
	print("  Total Consumed: %.2f kJ" % energy.total_consumed)
	print("  Total Heat Waste: %.2f kJ" % energy.total_heat)

func print_molecule_summary() -> void:
	print("\n🧪 MOLECULES (%d total):" % molecules.size())
	
	## Sort by concentration (descending)
	var mol_list = molecules.values()
	mol_list.sort_custom(func(a, b): return a.concentration > b.concentration)
	
	for molecule in mol_list:
		print("  • %s" % molecule.get_summary())

func print_enzyme_details() -> void:
	print("\n⚗️ ENZYMES (%d total):" % enzymes.size())
	
	for enzyme: Enzyme in enzymes:
		print("\n  ┌─ %s (%.4f mM)" % [enzyme.name, enzyme.concentration])
		print("  │  Net Rate: %.3f mM/s (Fwd: %.3f, Rev: %.3f)" % [
			enzyme.current_net_rate,
			enzyme.current_total_forward_rate,
			enzyme.current_total_reverse_rate
		])
		
		## Print each reaction
		for reaction in enzyme.reactions:
			print("  │")
			print("  ├─ Reaction: %s" % reaction.get_summary())
			print("  │  Efficiency: %.1f, ΔG°: %.1f kJ/mol, ΔG: %.1f kJ/mol, Keq: %.2f" % [
				reaction.reaction_efficiency * 100.0,
				reaction.delta_g,
				reaction.current_delta_g_actual,
				reaction.current_keq
			])
			print("  │  Vmax: %.2f mM/s, Km: %.2f mM" % [
				reaction.vmax,
				reaction.km
			])
			print("  │  Rates - Forward: %.3f, Reverse: %.3f, Net: %.3f mM/s" % [
				reaction.current_forward_rate,
				reaction.current_reverse_rate,
				reaction.current_forward_rate - reaction.current_reverse_rate
			])
			print("  │  Energy - Released: %.2f, Work: %.2f, Heat: %.2f kJ/s" % [
				reaction.current_energy_released,
				reaction.current_useful_work,
				reaction.current_heat_generated
			])
			
			## Show substrate-product similarity for non-source/sink reactions
			if not reaction.is_source() and not reaction.is_sink():
				print_reaction_similarity(reaction)
		
		print("  └─")

func print_reaction_similarity(reaction: Reaction) -> void:
	## Calculate average similarity between substrates and products
	var total_similarity = 0.0
	var comparison_count = 0
	
	for substrate_name in reaction.substrates:
		if not molecules.has(substrate_name):
			continue
		var substrate = molecules[substrate_name]
		
		for product_name in reaction.products:
			if not molecules.has(product_name):
				continue
			var product = molecules[product_name]
			
			var similarity = substrate.similarity_to(product)
			total_similarity += similarity
			comparison_count += 1
	
	if comparison_count > 0:
		var avg_similarity = total_similarity / comparison_count
		print("  │  Substrate-Product Similarity: %.1f%% (efficiency: %.1f%%)" % [
			avg_similarity * 100.0,
			reaction.reaction_efficiency * 100.0
		])

func print_energy_summary() -> void:
	print("\n⚡ ENERGY FLOW SUMMARY:")
	
	var total_forward = 0.0
	var total_reverse = 0.0
	var total_work = 0.0
	var total_heat = 0.0
	var favorable_count = 0
	var unfavorable_count = 0
	var equilibrium_count = 0
	
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			total_forward += reaction.current_forward_rate
			total_reverse += reaction.current_reverse_rate
			total_work += reaction.current_useful_work
			total_heat += reaction.current_heat_generated
			
			if reaction.current_delta_g_actual < -1.0:
				favorable_count += 1
			elif reaction.current_delta_g_actual > 1.0:
				unfavorable_count += 1
			else:
				equilibrium_count += 1
	
	var total_net = total_forward - total_reverse
	
	print("  Total Forward Rate: %.3f mM/s" % total_forward)
	print("  Total Reverse Rate: %.3f mM/s" % total_reverse)
	print("  Total Net Rate: %.3f mM/s" % total_net)
	print("  Total Useful Work: %.2f kJ/s" % total_work)
	print("  Total Heat Waste: %.2f kJ/s" % total_heat)
	
	if total_work + total_heat > 0:
		var efficiency = total_work / (total_work + total_heat) * 100.0
		print("  System Efficiency: %.1f%%" % efficiency)
	
	print("  Reaction Status: %d Favorable | %d Equilibrium | %d Unfavorable" % [
		favorable_count,
		equilibrium_count,
		unfavorable_count
	])

#endregion
