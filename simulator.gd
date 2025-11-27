## Simulator manages the biochemistry simulation
class_name Simulator
extends Node

#region Simulation State

var molecules: Dictionary = {}  ## {name: Molecule}
var enzymes: Array[Enzyme] = []
var cell: Cell = null
var simulation_time: float = 0.0
var time_scale: float = 1.0
var is_paused: bool = false

#endregion

#region Configuration

const NUM_MOLECULES: int = 8
const NUM_ENZYMES: int = 5
const REACTIONS_PER_ENZYME: int = 2

#endregion

func _ready() -> void:
	_generate_random_system()

func _process(delta: float) -> void:
	if is_paused:
		return
	
	var scaled_delta = delta * time_scale
	simulation_time += scaled_delta
	
	_update_reactions(scaled_delta)
	
	if cell:
		var all_reactions: Array[Reaction] = []
		for enzyme in enzymes:
			for rxn in enzyme.reactions:
				all_reactions.append(rxn)
		cell.update(scaled_delta, all_reactions)

#region Simulation Control

func set_paused(paused: bool) -> void:
	is_paused = paused

func reset_simulation() -> void:
	simulation_time = 0.0
	
	## Reset molecule concentrations (preserve lock state)
	for mol_name in molecules:
		molecules[mol_name].concentration = molecules[mol_name].initial_concentration
	
	## Reset enzyme concentrations (preserve lock state)
	for enzyme in enzymes:
		enzyme.concentration = enzyme.initial_concentration
	
	## Reset cell
	if cell:
		cell.heat = 50.0
		cell.usable_energy = 100.0
		cell.total_energy_generated = 0.0
		cell.total_energy_consumed = 0.0
		cell.total_heat_generated = 0.0
		cell.is_alive = true
		cell.death_reason = ""
	
	print("🔄 Simulation reset")

#endregion

#region System Generation

func _generate_random_system() -> void:
	print("🎲 Generating random biochemistry system...")
	
	cell = Cell.new()
	_generate_molecules()
	_generate_enzymes()
	_assign_reactions_to_pathways()
	
	print("✅ Generated %d molecules, %d enzymes" % [molecules.size(), enzymes.size()])

func _generate_molecules() -> void:
	var used_names: Array[String] = []
	
	for i in range(NUM_MOLECULES):
		var mol_name = Molecule.generate_random_name()
		while mol_name in used_names:
			mol_name = Molecule.generate_random_name()
		used_names.append(mol_name)
		
		## Vary initial concentrations to create gradients
		var base_conc = randf_range(0.5, 5.0)
		## Some molecules start high, others low - creates driving force
		if randf() > 0.5:
			base_conc *= randf_range(2.0, 5.0)
		
		var mol = Molecule.new(mol_name, base_conc)
		molecules[mol_name] = mol
		print("  📦 %s" % mol.get_summary())

func _generate_enzymes() -> void:
	var used_names: Array[String] = []
	
	for i in range(NUM_ENZYMES):
		var enz_name = _generate_enzyme_name()
		while enz_name in used_names:
			enz_name = _generate_enzyme_name()
		used_names.append(enz_name)
		
		var enzyme = Enzyme.new("enz_%d" % i, enz_name)
		enzymes.append(enzyme)
		print("  🔷 %s [%.4f mM]" % [enz_name, enzyme.concentration])

func _generate_enzyme_name() -> String:
	const PREFIXES = ["Keto", "Oxido", "Hydro", "Phospho", "Trans", "Iso", "Aldo"]
	const MIDDLES = ["reduct", "oxid", "mutan", "transfer", "lyase", "hydrol"]
	const SUFFIXES = ["ase", "kinase", "synthase", "dehydrogenase"]
	
	var enz_name = PREFIXES[randi() % PREFIXES.size()]
	enz_name += MIDDLES[randi() % MIDDLES.size()]
	enz_name += SUFFIXES[randi() % SUFFIXES.size()]
	return enz_name

#endregion

#region Reaction Assignment

func _assign_reactions_to_pathways() -> void:
	var mol_names = molecules.keys()
	
	if mol_names.size() < 2:
		return
	
	## Create a source reaction (∅ → molecule)
	var source_enzyme = enzymes[0]
	var source_product = mol_names[randi() % mol_names.size()]
	var source_rxn = _create_source_reaction(source_product)
	source_enzyme.add_reaction(source_rxn)
	print("  ⚡ Source: %s" % source_rxn.get_summary())
	
	## Create a sink reaction (molecule → ∅)
	var sink_enzyme = enzymes[enzymes.size() - 1]
	var sink_substrate = mol_names[randi() % mol_names.size()]
	while sink_substrate == source_product and mol_names.size() > 1:
		sink_substrate = mol_names[randi() % mol_names.size()]
	var sink_rxn = _create_sink_reaction(sink_substrate)
	sink_enzyme.add_reaction(sink_rxn)
	print("  🔥 Sink: %s" % sink_rxn.get_summary())
	
	## Create internal reactions
	for i in range(1, enzymes.size() - 1):
		var enzyme = enzymes[i]
		
		for j in range(REACTIONS_PER_ENZYME):
			var rxn = _create_internal_reaction(mol_names)
			if rxn:
				enzyme.add_reaction(rxn)
				print("  ⇄ %s catalyzes: %s" % [enzyme.name, rxn.get_summary()])

func _create_source_reaction(product_name: String) -> Reaction:
	var rxn = Reaction.new("source_%s" % product_name, "Source → %s" % product_name)
	rxn.products[product_name] = 1.0
	rxn.delta_g = randf_range(-15.0, -5.0)  ## Favorable
	rxn.vmax = randf_range(1.0, 5.0)
	rxn.is_irreversible = true
	return rxn

func _create_sink_reaction(substrate_name: String) -> Reaction:
	var rxn = Reaction.new("sink_%s" % substrate_name, "%s → Sink" % substrate_name)
	rxn.substrates[substrate_name] = 1.0
	rxn.delta_g = randf_range(-20.0, -10.0)  ## Very favorable
	rxn.vmax = randf_range(0.5, 2.0)
	rxn.is_irreversible = true
	return rxn

func _create_internal_reaction(mol_names: Array) -> Reaction:
	if mol_names.size() < 2:
		return null
	
	## Pick random substrate and product
	var substrate = mol_names[randi() % mol_names.size()]
	var product = mol_names[randi() % mol_names.size()]
	
	## Ensure they're different
	var attempts = 0
	while product == substrate and attempts < 10:
		product = mol_names[randi() % mol_names.size()]
		attempts += 1
	
	if product == substrate:
		return null
	
	var rxn = Reaction.new(
		"rxn_%s_%s" % [substrate, product],
		"%s ⇄ %s" % [substrate, product]
	)
	
	rxn.substrates[substrate] = 1.0
	rxn.products[product] = 1.0
	
	## Calculate ΔG based on structural similarity
	var sub_mol = molecules[substrate]
	var prod_mol = molecules[product]
	var similarity = sub_mol.similarity_to(prod_mol)
	
	## Similar molecules = small |ΔG|, dissimilar = larger |ΔG|
	var energy_diff = prod_mol.potential_energy - sub_mol.potential_energy
	rxn.delta_g = energy_diff * (1.0 - similarity * 0.5) + randf_range(-2.0, 2.0)
	
	rxn.vmax = randf_range(2.0, 15.0)
	rxn.km = randf_range(0.1, 2.0)
	
	return rxn

#endregion

#region Simulation Update

func _update_reactions(delta: float) -> void:
	## Update enzyme rates
	for enzyme in enzymes:
		enzyme.update_reaction_rates(molecules)
	
	## Calculate concentration changes
	var delta_concentrations: Dictionary = {}
	for mol_name in molecules:
		delta_concentrations[mol_name] = 0.0
	
	for enzyme in enzymes:
		for rxn in enzyme.reactions:
			var net_rate = rxn.get_net_rate()
			
			## Substrates consumed
			for substrate in rxn.substrates:
				if delta_concentrations.has(substrate):
					delta_concentrations[substrate] -= net_rate * rxn.substrates[substrate]
			
			## Products produced
			for product in rxn.products:
				if delta_concentrations.has(product):
					delta_concentrations[product] += net_rate * rxn.products[product]
	
	## Apply changes only to unlocked molecules
	for mol_name in molecules:
		var mol = molecules[mol_name]
		if not mol.is_locked:
			mol.concentration += delta_concentrations[mol_name] * delta
			mol.concentration = max(mol.concentration, 0.0)

#endregion
