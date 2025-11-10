## Generates random molecules and enzymes for the simulator
class_name MolecularGenerator
extends RefCounted

var cell: Cell
var rng: RandomNumberGenerator

func _init(p_cell: Cell) -> void:
	cell = p_cell
	rng = RandomNumberGenerator.new()
	rng.randomize()

## Generate a random molecule
func generate_random_molecule(concentration: float = 1.0) -> Molecule:
	var mol_id = randi() % 10000
	var mol_name = "Mol%d" % mol_id
	var mol = Molecule.new(mol_name, concentration)
	return mol

## Initialize starting molecules
func initialize_starting_molecules(count: int) -> void:
	for i in range(count):
		var mol = generate_random_molecule(rng.randf_range(0.5, 3.0))
		cell.molecules[mol.name] = mol
		print("  ✅ Created molecule: %s (%.2f mM)" % [mol.name, mol.concentration])

## Generate an enzyme with a random reaction
func generate_enzyme_with_reaction(template: String = "random") -> Enzyme:
	var enzyme_id = randi() % 10000
	var enzyme = Enzyme.new("enz_%d" % enzyme_id, "Enzyme%d" % enzyme_id)
	enzyme.concentration = rng.randf_range(0.001, 0.01)
	
	## Create a simple reaction for this enzyme
	if cell.molecules.size() >= 2:
		var mol_names = cell.molecules.keys()
		var reaction = Reaction.new("rxn_%d" % enzyme_id, "Reaction%d" % enzyme_id)
		
		## Pick random substrate and product
		var substrate_idx = randi() % mol_names.size()
		var product_idx = (substrate_idx + 1) % mol_names.size()
		
		reaction.substrates[mol_names[substrate_idx]] = 1.0
		reaction.products[mol_names[product_idx]] = 1.0
		
		## Random kinetics
		reaction.vmax = rng.randf_range(1.0, 5.0)
		reaction.initial_vmax = reaction.vmax
		reaction.km = rng.randf_range(0.1, 1.0)
		reaction.initial_km = reaction.km
		reaction.delta_g = rng.randf_range(-30.0, 10.0)
		reaction.energy_efficiency = rng.randf_range(0.5, 0.8)
		
		enzyme.add_reaction(reaction)
	
	return enzyme

## Initialize starting enzymes
func initialize_starting_enzymes(count: int) -> void:
	for i in range(count):
		var enzyme = generate_enzyme_with_reaction()
		cell.enzymes.append(enzyme)
		print("  ✅ Created enzyme: %s with %d reaction(s)" % [enzyme.name, enzyme.reactions.size()])

## Generate a linear pathway
func generate_linear_pathway(length: int) -> void:
	print("  🧬 Generating linear pathway with %d steps..." % length)
	
	var current_mol = ""
	if cell.molecules.size() > 0:
		current_mol = cell.molecules.keys()[0]
	else:
		var mol = generate_random_molecule(2.0)
		cell.molecules[mol.name] = mol
		current_mol = mol.name
	
	for i in range(length):
		## Create next molecule
		var next_mol = generate_random_molecule(0.1)
		cell.molecules[next_mol.name] = next_mol
		
		## Create enzyme for step
		var enzyme = Enzyme.new("path_enz_%d" % i, "PathEnz%d" % i)
		enzyme.concentration = rng.randf_range(0.01, 0.05)
		
		## Create reaction
		var reaction = Reaction.new("path_rxn_%d" % i, "PathStep%d" % (i + 1))
		reaction.substrates[current_mol] = 1.0
		reaction.products[next_mol.name] = 1.0
		reaction.vmax = rng.randf_range(2.0, 6.0)
		reaction.initial_vmax = reaction.vmax
		reaction.km = rng.randf_range(0.1, 0.8)
		reaction.initial_km = reaction.km
		reaction.delta_g = rng.randf_range(-20.0, -5.0)
		reaction.energy_efficiency = rng.randf_range(0.6, 0.85)
		
		enzyme.add_reaction(reaction)
		cell.enzymes.append(enzyme)
		
		current_mol = next_mol.name
	
	print("  ✅ Pathway complete")
