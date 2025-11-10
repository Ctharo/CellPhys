## Generates molecules and reactions dynamically at runtime
## Creates novel biochemistry through random generation
class_name MolecularGenerator
extends RefCounted

var cell: Cell
var next_molecule_id: int = 1
var next_reaction_id: int = 1
var next_enzyme_id: int = 1

func _init(p_cell: Cell) -> void:
	cell = p_cell

## ============================================================================
## MOLECULE GENERATION
## ============================================================================

## Generate a completely random molecule
func generate_random_molecule(initial_conc: float = -1.0) -> Molecule:
	var mol = Molecule.new()
	mol.name = "%s-%d" % [mol.name, next_molecule_id]
	next_molecule_id += 1
	
	if initial_conc < 0:
		mol.concentration = randf_range(0.01, 2.0)
	else:
		mol.concentration = initial_conc
	
	mol.initial_concentration = mol.concentration
	
	return mol

## Generate a derivative of an existing molecule
func generate_derivative(base_mol: Molecule, mod_type: String = "random") -> Molecule:
	var derivative = base_mol.create_derivative(mod_type)
	derivative.name = "%s-%d" % [derivative.name, next_molecule_id]
	next_molecule_id += 1
	derivative.concentration = randf_range(0.01, 0.5)
	derivative.initial_concentration = derivative.concentration
	return derivative

## ============================================================================
## REACTION GENERATION
## ============================================================================

## Generate a random exergonic reaction (energy-releasing)
func generate_exergonic_reaction() -> Reaction:
	var available_molecules = cell.molecules.keys()
	if available_molecules.size() < 2:
		return null
	
	var rxn = Reaction.new("r%d" % next_reaction_id, "Exergonic-%d" % next_reaction_id)
	next_reaction_id += 1
	
	## 1-2 substrates
	var num_substrates = randi_range(1, 2)
	for i in range(num_substrates):
		var mol = available_molecules[randi() % available_molecules.size()]
		rxn.substrates[mol] = 1.0
	
	## 1-3 products (breaking down releases energy)
	var num_products = randi_range(1, 3)
	for i in range(num_products):
		var product = generate_random_molecule(0.01)
		cell.molecules[product.name] = product
		rxn.products[product.name] = 1.0
	
	## Set kinetics
	rxn.vmax = randf_range(0.5, 3.0)
	rxn.initial_vmax = rxn.vmax
	rxn.km = randf_range(0.1, 1.0)
	rxn.initial_km = rxn.km
	rxn.temperature = 310.0
	
	## Calculate ΔG from molecules
	rxn.calculate_delta_g_standard(cell.molecules)
	
	## Make it more exergonic if needed
	if rxn.delta_g > -10.0:
		rxn.delta_g -= randf_range(10.0, 30.0)
	
	return rxn

## Generate a random endergonic reaction (energy-consuming)
func generate_endergonic_reaction() -> Reaction:
	var available_molecules = cell.molecules.keys()
	if available_molecules.size() < 2:
		return null
	
	var rxn = Reaction.new("r%d" % next_reaction_id, "Endergonic-%d" % next_reaction_id)
	next_reaction_id += 1
	
	## 1-3 substrates
	var num_substrates = randi_range(1, 3)
	for i in range(num_substrates):
		var mol = available_molecules[randi() % available_molecules.size()]
		rxn.substrates[mol] = 1.0
	
	## 1 product (synthesis requires energy)
	var product = generate_random_molecule(0.01)
	cell.molecules[product.name] = product
	rxn.products[product.name] = 1.0
	
	## Set kinetics
	rxn.vmax = randf_range(0.3, 2.0)
	rxn.initial_vmax = rxn.vmax
	rxn.km = randf_range(0.1, 1.0)
	rxn.initial_km = rxn.km
	rxn.temperature = 310.0
	
	## Calculate ΔG and make endergonic
	rxn.calculate_delta_g_standard(cell.molecules)
	if rxn.delta_g < 10.0:
		rxn.delta_g += randf_range(10.0, 40.0)
	
	rxn.requires_energy_input = true
	
	return rxn

## Generate a simple conversion reaction (neutral or slightly favorable)
func generate_conversion_reaction() -> Reaction:
	var available_molecules = cell.molecules.keys()
	if available_molecules.size() < 1:
		return null
	
	var rxn = Reaction.new("r%d" % next_reaction_id, "Convert-%d" % next_reaction_id)
	next_reaction_id += 1
	
	## 1 substrate
	var substrate = available_molecules[randi() % available_molecules.size()]
	rxn.substrates[substrate] = 1.0
	
	## 1 product (similar structure for efficiency)
	var substrate_mol: Molecule = cell.molecules[substrate]
	var product = substrate_mol.create_derivative("random")
	product.name = "%s-%d" % [product.name, next_molecule_id]
	next_molecule_id += 1
	product.concentration = 0.01
	product.initial_concentration = 0.01
	cell.molecules[product.name] = product
	rxn.products[product.name] = 1.0
	
	## Set kinetics
	rxn.vmax = randf_range(1.0, 4.0)
	rxn.initial_vmax = rxn.vmax
	rxn.km = randf_range(0.2, 0.8)
	rxn.initial_km = rxn.km
	rxn.temperature = 310.0
	
	## Calculate ΔG (should be small due to similarity)
	rxn.calculate_delta_g_standard(cell.molecules)
	
	return rxn

## Generate a source reaction (imports molecules)
func generate_source_reaction() -> Reaction:
	var rxn = Reaction.new("r%d" % next_reaction_id, "Source-%d" % next_reaction_id)
	next_reaction_id += 1
	
	## No substrates, one product
	var product = generate_random_molecule(1.0)
	cell.molecules[product.name] = product
	rxn.products[product.name] = 1.0
	
	rxn.vmax = randf_range(0.5, 2.0)
	rxn.initial_vmax = rxn.vmax
	rxn.km = 0.5
	rxn.initial_km = 0.5
	rxn.delta_g = randf_range(-15.0, -5.0)
	rxn.temperature = 310.0
	
	return rxn

## ============================================================================
## ENZYME GENERATION
## ============================================================================

## Generate an enzyme with a random reaction
func generate_enzyme_with_reaction(reaction_type: String = "random") -> Enzyme:
	var enzyme = Enzyme.new("e%d" % next_enzyme_id, "Enz-%d" % next_enzyme_id)
	next_enzyme_id += 1
	enzyme.temperature = 310.0
	
	var reaction: Reaction = null
	
	match reaction_type:
		"exergonic":
			reaction = generate_exergonic_reaction()
		"endergonic":
			reaction = generate_endergonic_reaction()
		"conversion":
			reaction = generate_conversion_reaction()
		"source":
			reaction = generate_source_reaction()
		_:
			## Random choice
			var types = ["exergonic", "endergonic", "conversion"]
			reaction_type = types[randi() % types.size()]
			match reaction_type:
				"exergonic":
					reaction = generate_exergonic_reaction()
				"endergonic":
					reaction = generate_endergonic_reaction()
				"conversion":
					reaction = generate_conversion_reaction()
	
	if reaction:
		enzyme.add_reaction(reaction)
	
	return enzyme

## ============================================================================
## INITIALIZATION HELPERS
## ============================================================================

## Create initial molecular inventory
func initialize_starting_molecules(count: int = 5) -> void:
	for i in range(count):
		var mol = generate_random_molecule(randf_range(1.0, 5.0))
		cell.molecules[mol.name] = mol
		print("🧪 Generated starting molecule: %s" % mol.get_summary())

## Create initial enzyme set
func initialize_starting_enzymes(count: int = 3) -> void:
	## At least one source
	var source_enzyme = generate_enzyme_with_reaction("source")
	cell.enzymes.append(source_enzyme)
	print("⚗️ Generated source enzyme: %s" % source_enzyme.name)
	
	## Rest are mixed
	for i in range(count - 1):
		var enzyme = generate_enzyme_with_reaction("random")
		cell.enzymes.append(enzyme)
		print("⚗️ Generated enzyme: %s with %s reaction" % [enzyme.name, enzyme.reactions[0].name if not enzyme.reactions.is_empty() else "no"])

## ============================================================================
## PATHWAY GENERATION
## ============================================================================

## Generate a simple linear pathway
func generate_linear_pathway(length: int = 3) -> void:
	var current_mol = generate_random_molecule(2.0)
	cell.molecules[current_mol.name] = current_mol
	
	for i in range(length):
		var enzyme = Enzyme.new("e%d" % next_enzyme_id, "Path-Enz-%d" % (i+1))
		next_enzyme_id += 1
		
		var rxn = Reaction.new("r%d" % next_reaction_id, "Step-%d" % (i+1))
		next_reaction_id += 1
		
		## Current -> Next
		rxn.substrates[current_mol.name] = 1.0
		
		var next_mol = current_mol.create_derivative("random")
		next_mol.name = "%s-%d" % [next_mol.name, next_molecule_id]
		next_molecule_id += 1
		next_mol.concentration = 0.1
		next_mol.initial_concentration = 0.1
		cell.molecules[next_mol.name] = next_mol
		
		rxn.products[next_mol.name] = 1.0
		
		rxn.vmax = randf_range(1.0, 3.0)
		rxn.initial_vmax = rxn.vmax
		rxn.km = randf_range(0.2, 0.8)
		rxn.initial_km = rxn.km
		rxn.temperature = 310.0
		rxn.calculate_delta_g_standard(cell.molecules)
		
		enzyme.add_reaction(rxn)
		cell.enzymes.append(enzyme)
		
		current_mol = next_mol
	
	print("🧬 Generated linear pathway with %d steps" % length)
