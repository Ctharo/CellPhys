## Generates new reactions and pathways dynamically
## Can create novel biochemistry not based on real-world pathways
class_name PathwayGenerator
extends RefCounted

var cell: Cell
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Molecule generation parameters
var molecule_name_prefixes: Array[String] = ["Mol", "Comp", "Sub", "Met", "Enz"]
var molecule_name_suffixes: Array[String] = ["A", "B", "X", "Y", "Z", "Prime", "Star"]
var next_molecule_id: int = 1

## Reaction generation parameters
var reaction_types: Array[String] = [
	"Synthesis",
	"Degradation", 
	"Phosphorylation",
	"Oxidation",
	"Reduction",
	"Condensation",
	"Hydrolysis",
	"Isomerization"
]
var next_reaction_id: int = 1

func _init(p_cell: Cell) -> void:
	cell = p_cell
	rng.randomize()

## ============================================================================
## MOLECULE GENERATION
## ============================================================================

func generate_random_molecule() -> String:
	"""Create a new molecule with a random name"""
	var prefix = molecule_name_prefixes[rng.randi() % molecule_name_prefixes.size()]
	var suffix = molecule_name_suffixes[rng.randi() % molecule_name_suffixes.size()]
	var name = "%s%s-%d" % [prefix, suffix, next_molecule_id]
	next_molecule_id += 1
	
	# Random initial concentration
	var concentration = rng.randf_range(0.1, 5.0)
	cell.add_molecule(name, concentration)
	
	print("🧪 Generated molecule: %s (%.2f mM)" % [name, concentration])
	return name

func generate_molecule_derivative(base_molecule: String, modification: String = "") -> String:
	"""Create a derivative of an existing molecule"""
	if modification == "":
		modification = ["P", "2P", "3P", "ox", "red", "CoA", "AMP", "prime"].pick_random()
	
	var name = "%s-%s" % [base_molecule, modification]
	
	# Derivatives usually start at low concentration
	var concentration = rng.randf_range(0.01, 0.5)
	cell.add_molecule(name, concentration)
	
	print("🧪 Generated derivative: %s (%.2f mM)" % [name, concentration])
	return name

## ============================================================================
## REACTION GENERATION
## ============================================================================

func generate_random_reaction(enzyme: Enzyme = null) -> Reaction:
	"""Create a completely random reaction"""
	var available_molecules = cell.molecules.keys()
	if available_molecules.is_empty():
		push_error("No molecules available for reaction generation")
		return null
	
	var rxn_type = reaction_types[rng.randi() % reaction_types.size()]
	var rxn_name = "%s-%d" % [rxn_type, next_reaction_id]
	next_reaction_id += 1
	
	var reaction = Reaction.new("auto_r%d" % next_reaction_id, rxn_name)
	
	# Random number of substrates (1-3)
	var num_substrates = rng.randi_range(1, 3)
	for i in range(num_substrates):
		var mol = available_molecules[rng.randi() % available_molecules.size()]
		var stoich = [1.0, 2.0].pick_random()  # Usually 1 or 2
		reaction.substrates[mol] = stoich
	
	# Random number of products (1-3)
	var num_products = rng.randi_range(1, 3)
	for i in range(num_products):
		var mol = available_molecules[rng.randi() % available_molecules.size()]
		var stoich = [1.0, 2.0].pick_random()
		reaction.products[mol] = stoich
	
	# Random kinetic parameters
	reaction.vmax = rng.randf_range(0.1, 10.0)
	reaction.initial_vmax = reaction.vmax
	reaction.km = rng.randf_range(0.05, 2.0)
	reaction.initial_km = reaction.km
	
	# Random thermodynamics (favor slightly exergonic)
	reaction.delta_g = rng.randf_range(-50.0, 30.0)
	reaction.energy_efficiency = rng.randf_range(0.4, 0.9)
	
	# Random chance of irreversibility
	reaction.is_irreversible = rng.randf() < 0.2  # 20% chance
	
	if enzyme:
		enzyme.add_reaction(reaction)
	
	print("⚗️ Generated reaction: %s" % reaction.get_summary())
	return reaction

func generate_synthesis_reaction(product: String, enzyme: Enzyme = null) -> Reaction:
	"""Generate a reaction that synthesizes a target molecule"""
	var available_molecules = cell.molecules.keys()
	available_molecules.erase(product)  # Don't use product as substrate
	
	if available_molecules.is_empty():
		push_error("No substrates available for synthesis")
		return null
	
	var rxn_name = "Synthesize-%s" % product
	var reaction = Reaction.new("synth_r%d" % next_reaction_id, rxn_name)
	next_reaction_id += 1
	
	# Random substrates (1-2)
	var num_substrates = rng.randi_range(1, 2)
	for i in range(num_substrates):
		var mol = available_molecules[rng.randi() % available_molecules.size()]
		reaction.substrates[mol] = 1.0
		available_molecules.erase(mol)  # Don't reuse
	
	# Product
	reaction.products[product] = 1.0
	
	# Synthesis parameters
	reaction.vmax = rng.randf_range(1.0, 5.0)
	reaction.initial_vmax = reaction.vmax
	reaction.km = rng.randf_range(0.1, 1.0)
	reaction.initial_km = reaction.km
	reaction.delta_g = rng.randf_range(-30.0, 10.0)  # Slightly favorable on average
	reaction.energy_efficiency = rng.randf_range(0.5, 0.8)
	
	if enzyme:
		enzyme.add_reaction(reaction)
	
	print("⚗️ Generated synthesis: %s" % reaction.get_summary())
	return reaction

func generate_degradation_reaction(substrate: String, enzyme: Enzyme = null) -> Reaction:
	"""Generate a reaction that breaks down a molecule"""
	var rxn_name = "Degrade-%s" % substrate
	var reaction = Reaction.new("degr_r%d" % next_reaction_id, rxn_name)
	next_reaction_id += 1
	
	# Substrate
	reaction.substrates[substrate] = 1.0
	
	# Generate breakdown products
	var num_products = rng.randi_range(1, 3)
	for i in range(num_products):
		var product = generate_random_molecule()
		reaction.products[product] = 1.0
	
	# Degradation is usually exergonic
	reaction.vmax = rng.randf_range(2.0, 8.0)
	reaction.initial_vmax = reaction.vmax
	reaction.km = rng.randf_range(0.2, 1.5)
	reaction.initial_km = reaction.km
	reaction.delta_g = rng.randf_range(-60.0, -10.0)
	reaction.energy_efficiency = rng.randf_range(0.3, 0.7)
	reaction.is_irreversible = true
	
	if enzyme:
		enzyme.add_reaction(reaction)
	
	print("⚗️ Generated degradation: %s" % reaction.get_summary())
	return reaction

func generate_phosphorylation_reaction(substrate: String, phosphate_donor: String, enzyme: Enzyme = null) -> Reaction:
	"""Generate a phosphorylation reaction (substrate + ATP → substrate-P + ADP)"""
	var product = generate_molecule_derivative(substrate, "P")
	
	var rxn_name = "Phosphorylate-%s" % substrate
	var reaction = Reaction.new("phos_r%d" % next_reaction_id, rxn_name)
	next_reaction_id += 1
	
	# Substrates
	reaction.substrates[substrate] = 1.0
	reaction.substrates[phosphate_donor] = 1.0
	
	# Products
	reaction.products[product] = 1.0
	var acceptor = "ADP" if phosphate_donor == "ATP" else "Acceptor"
	if cell.molecules.has(acceptor):
		reaction.products[acceptor] = 1.0
	
	# Phosphorylation powered by ATP is favorable
	reaction.vmax = rng.randf_range(3.0, 8.0)
	reaction.initial_vmax = reaction.vmax
	reaction.km = rng.randf_range(0.1, 0.5)
	reaction.initial_km = reaction.km
	reaction.delta_g = rng.randf_range(-25.0, -10.0)
	reaction.energy_efficiency = rng.randf_range(0.6, 0.85)
	reaction.is_irreversible = true
	
	if enzyme:
		enzyme.add_reaction(reaction)
	
	print("⚗️ Generated phosphorylation: %s" % reaction.get_summary())
	return reaction

## ============================================================================
## PATHWAY GENERATION
## ============================================================================

func generate_linear_pathway(length: int, start_molecule: String = "") -> Array[Reaction]:
	"""Generate a linear pathway: A → B → C → D..."""
	var pathway: Array[Reaction] = []
	
	var current_molecule = start_molecule
	if current_molecule == "":
		current_molecule = generate_random_molecule()
	
	for i in range(length):
		var next_molecule = generate_random_molecule()
		
		var enzyme = Enzyme.new("path_e%d" % i, "Enzyme-%d" % i)
		enzyme.concentration = rng.randf_range(0.01, 0.05)
		cell.add_enzyme(enzyme)
		
		var rxn_name = "Step-%d" % (i + 1)
		var reaction = Reaction.new("path_r%d" % i, rxn_name)
		
		reaction.substrates[current_molecule] = 1.0
		reaction.products[next_molecule] = 1.0
		reaction.vmax = rng.randf_range(2.0, 6.0)
		reaction.initial_vmax = reaction.vmax
		reaction.km = rng.randf_range(0.1, 0.8)
		reaction.initial_km = reaction.km
		reaction.delta_g = rng.randf_range(-20.0, -5.0)
		reaction.energy_efficiency = rng.randf_range(0.5, 0.8)
		
		enzyme.add_reaction(reaction)
		pathway.append(reaction)
		
		current_molecule = next_molecule
	
	print("🧬 Generated linear pathway with %d steps" % length)
	return pathway

func generate_cycle(length: int) -> Array[Reaction]:
	"""Generate a metabolic cycle: A → B → C → A"""
	var molecules: Array[String] = []
	
	# Generate molecules for the cycle
	for i in range(length):
		molecules.append(generate_random_molecule())
	
	var cycle: Array[Reaction] = []
	
	for i in range(length):
		var current = molecules[i]
		var next = molecules[(i + 1) % length]
		
		var enzyme = Enzyme.new("cycle_e%d" % i, "Cycle-Enzyme-%d" % i)
		enzyme.concentration = rng.randf_range(0.01, 0.05)
		cell.add_enzyme(enzyme)
		
		var rxn_name = "Cycle-Step-%d" % (i + 1)
		var reaction = Reaction.new("cycle_r%d" % i, rxn_name)
		
		reaction.substrates[current] = 1.0
		reaction.products[next] = 1.0
		reaction.vmax = rng.randf_range(2.0, 6.0)
		reaction.initial_vmax = reaction.vmax
		reaction.km = rng.randf_range(0.1, 0.8)
		reaction.initial_km = reaction.km
		
		# Make the cycle slightly exergonic overall
		reaction.delta_g = rng.randf_range(-15.0, -3.0)
		reaction.energy_efficiency = rng.randf_range(0.5, 0.75)
		
		enzyme.add_reaction(reaction)
		cycle.append(reaction)
	
	print("🔄 Generated metabolic cycle with %d steps" % length)
	return cycle

func generate_branched_pathway(branches: int, steps_per_branch: int, common_substrate: String = "") -> Array[Reaction]:
	"""Generate a branched pathway: A → B → C and A → D → E"""
	var all_reactions: Array[Reaction] = []
	
	var start = common_substrate
	if start == "":
		start = generate_random_molecule()
	
	for branch_idx in range(branches):
		var current = start
		
		for step in range(steps_per_branch):
			var next_mol = generate_random_molecule()
			
			var enzyme = Enzyme.new("branch%d_e%d" % [branch_idx, step], 
									"Branch-%d-Enzyme-%d" % [branch_idx, step])
			enzyme.concentration = rng.randf_range(0.01, 0.05)
			cell.add_enzyme(enzyme)
			
			var rxn_name = "Branch-%d-Step-%d" % [branch_idx, step + 1]
			var reaction = Reaction.new("branch%d_r%d" % [branch_idx, step], rxn_name)
			
			reaction.substrates[current] = 1.0
			reaction.products[next_mol] = 1.0
			reaction.vmax = rng.randf_range(1.5, 5.0)
			reaction.initial_vmax = reaction.vmax
			reaction.km = rng.randf_range(0.1, 1.0)
			reaction.initial_km = reaction.km
			reaction.delta_g = rng.randf_range(-25.0, -5.0)
			reaction.energy_efficiency = rng.randf_range(0.5, 0.8)
			
			enzyme.add_reaction(reaction)
			all_reactions.append(reaction)
			
			current = next_mol
	
	print("🌳 Generated branched pathway with %d branches, %d steps each" % [branches, steps_per_branch])
	return all_reactions

## ============================================================================
## REGULATION GENERATION
## ============================================================================

func add_feedback_inhibition(pathway: Array[Reaction]) -> void:
	"""Add product inhibition to the first enzyme in a pathway"""
	if pathway.is_empty():
		return
	
	var first_reaction = pathway[0]
	if not first_reaction.enzyme:
		return
	
	var last_reaction = pathway[pathway.size() - 1]
	var end_product = ""
	
	if not last_reaction.products.is_empty():
		end_product = last_reaction.products.keys()[0]
		first_reaction.enzyme.inhibitors[end_product] = rng.randf_range(0.1, 1.0)
		print("🔁 Added feedback inhibition: %s inhibits %s" % [end_product, first_reaction.enzyme.name])

func add_allosteric_activation(enzyme: Enzyme, activator: String) -> void:
	"""Add allosteric activation to an enzyme"""
	var fold = rng.randf_range(2.0, 10.0)
	enzyme.activators[activator] = fold
	print("⚡ Added activation: %s activates %s (%.1fx)" % [activator, enzyme.name, fold])
