## Data-driven biochemistry simulator with modular, extensible architecture
## Supports multiple compartments, complex kinetics, and allosteric regulation

extends Node
class_name BiochemistrySimulator

## Represents a chemical molecule with concentration and location
class Molecule:
	var name: String
	var concentration: float  ## mM
	var compartment: String  ## e.g., "cytoplasm", "mitochondrion"
	
	func _init(p_name: String, p_conc: float, p_comp: String) -> void:
		name = p_name
		concentration = p_conc
		compartment = p_comp

## Data-driven chemical reaction definition with kinetic parameters
class Reaction:
	var id: String
	var name: String
	var enzyme: String
	var compartment: String
	var reactants: Dictionary  ## {"molecule_name": stoichiometry}
	var products: Dictionary   ## {"molecule_name": stoichiometry}
	var vmax: float
	var km_values: Dictionary  ## {"substrate": km}
	var kinetic_type: String   ## "michaelis_menten", "hill", "mass_action"
	var allosteric_mods: Dictionary  ## {"molecule": {"type": "inhibitor"/"activator", "factor": 0.7}}
	var reverse_enabled: bool = false
	var equilibrium_constant: float = 1000.0
	
	func _init(p_id: String, p_name: String, p_enzyme: String, p_compartment: String) -> void:
		id = p_id
		name = p_name
		enzyme = p_enzyme
		compartment = p_compartment
		reactants = {}
		products = {}
		km_values = {}
		allosteric_mods = {}

var compartments: Dictionary = {}  ## {"name": {"type": "organelle/cytoplasm", "volume": 1.0}}
var molecules: Dictionary = {}     ## {"molecule_name": Molecule}
var reactions: Array[Reaction] = []
var reaction_rates: Dictionary = {}

var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false

func _ready() -> void:
	_initialize_compartments()
	initialize_molecules()
	initialize_reactions()
	print("✅ Biochemistry Simulator initialized")

func _process(delta: float) -> void:
	if is_paused:
		return
	
	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		if iteration % 10 == 0:
			print_state()

## Defines all cellular compartments and their properties
func _initialize_compartments() -> void:
	compartments = {
		"cytoplasm": {"type": "compartment", "volume": 1.0, "color": Color.LIGHT_GRAY},
		"mitochondrion": {"type": "organelle", "volume": 0.5, "color": Color.ORANGE},
		"extracellular": {"type": "environment", "volume": 2.0, "color": Color.CYAN},
	}

## Initializes all molecule concentrations and compartments
func initialize_molecules() -> void:
	## Glycolysis (cytoplasm)
	molecules["glucose"] = Molecule.new("Glucose", 5.0, "cytoplasm")
	molecules["glucose6p"] = Molecule.new("Glucose-6-Phosphate", 0.05, "cytoplasm")
	molecules["pyruvate"] = Molecule.new("Pyruvate", 0.1, "cytoplasm")
	
	## TCA Cycle (mitochondrion)
	molecules["acetylcoa"] = Molecule.new("Acetyl-CoA", 0.05, "mitochondrion")
	molecules["citrate"] = Molecule.new("Citrate", 0.1, "mitochondrion")
	molecules["isocitrate"] = Molecule.new("Isocitrate", 0.05, "mitochondrion")
	molecules["alphaketo"] = Molecule.new("α-Ketoglutarate", 0.08, "mitochondrion")
	molecules["succinylcoa"] = Molecule.new("Succinyl-CoA", 0.02, "mitochondrion")
	molecules["succinate"] = Molecule.new("Succinate", 0.1, "mitochondrion")
	molecules["fumarate"] = Molecule.new("Fumarate", 0.05, "mitochondrion")
	molecules["malate"] = Molecule.new("Malate", 0.1, "mitochondrion")
	molecules["oxaloacetate"] = Molecule.new("Oxaloacetate", 0.15, "mitochondrion")
	
	## Redox cofactors
	molecules["nadh"] = Molecule.new("NADH", 0.5, "mitochondrion")
	molecules["nad"] = Molecule.new("NAD+", 5.0, "mitochondrion")
	molecules["fadh2"] = Molecule.new("FADH2", 0.3, "mitochondrion")
	molecules["fad"] = Molecule.new("FAD", 3.0, "mitochondrion")
	
	## Energy molecules
	molecules["atp"] = Molecule.new("ATP", 2.0, "cytoplasm")
	molecules["adp"] = Molecule.new("ADP", 3.0, "cytoplasm")
	molecules["amp"] = Molecule.new("AMP", 0.5, "cytoplasm")
	
	## Gases
	molecules["oxygen"] = Molecule.new("O₂", 1.0, "mitochondrion")
	molecules["co2"] = Molecule.new("CO₂", 0.1, "mitochondrion")

## Registers all reactions in the simulation
func initialize_reactions() -> void:
	## GLYCOLYSIS
	_add_reaction_pfk()
	_add_reaction_pyruvate_dehydrogenase()
	
	## TCA CYCLE
	_add_reaction_citrate_synthase()
	_add_reaction_isocitrate_dehydrogenase()
	_add_reaction_alpha_kg_dehydrogenase()
	_add_reaction_succinate_dehydrogenase()
	_add_reaction_malate_dehydrogenase()
	
	## ELECTRON TRANSPORT
	_add_reaction_electron_transport()

## Factory method for creating reaction objects
func create_base_reaction(id: String, name: String, enzyme: String, comp: String) -> Reaction:
	return Reaction.new(id, name, enzyme, comp)

## Phosphofructokinase: Glucose → Pyruvate (simplified glycolysis step)
func _add_reaction_pfk() -> void:
	var rxn = create_base_reaction("pfk", "Glycolysis (PFK)", "Phosphofructokinase", "cytoplasm")
	rxn.reactants = {"glucose": 1.0}
	rxn.products = {"pyruvate": 2.0}
	rxn.vmax = 25.0
	rxn.km_values = {"glucose": 0.5}
	rxn.kinetic_type = "michaelis_menten"
	rxn.allosteric_mods = {
		"atp": {"type": "inhibitor", "factor": 0.7},
		"amp": {"type": "activator", "factor": 1.3}
	}
	reactions.append(rxn)

## Pyruvate Dehydrogenase: Pyruvate → Acetyl-CoA
func _add_reaction_pyruvate_dehydrogenase() -> void:
	var rxn = create_base_reaction("pdh", "Pyruvate Dehydrogenase", "Pyruvate Dehydrogenase", "mitochondrion")
	rxn.reactants = {"pyruvate": 1.0}
	rxn.products = {"acetylcoa": 1.0, "co2": 1.0}
	rxn.vmax = 8.0
	rxn.km_values = {"pyruvate": 0.2}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Citrate Synthase: Acetyl-CoA + OAA → Citrate
func _add_reaction_citrate_synthase() -> void:
	var rxn = create_base_reaction("cs", "Citrate Synthase", "Citrate Synthase", "mitochondrion")
	rxn.reactants = {"acetylcoa": 1.0, "oxaloacetate": 1.0}
	rxn.products = {"citrate": 1.0}
	rxn.vmax = 12.0
	rxn.km_values = {"acetylcoa": 0.01, "oxaloacetate": 0.01}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Isocitrate Dehydrogenase: Citrate → Isocitrate → α-Ketoglutarate
func _add_reaction_isocitrate_dehydrogenase() -> void:
	var rxn = create_base_reaction("icdh", "Isocitrate Dehydrogenase", "Isocitrate Dehydrogenase", "mitochondrion")
	rxn.reactants = {"citrate": 1.0}
	rxn.products = {"alphaketo": 1.0, "nadh": 1.0, "co2": 1.0}
	rxn.vmax = 10.0
	rxn.km_values = {"citrate": 0.05}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## α-Ketoglutarate Dehydrogenase: α-Ketoglutarate → Succinyl-CoA
func _add_reaction_alpha_kg_dehydrogenase() -> void:
	var rxn = create_base_reaction("akgdh", "α-Ketoglutarate Dehydrogenase", "α-Ketoglutarate Dehydrogenase", "mitochondrion")
	rxn.reactants = {"alphaketo": 1.0}
	rxn.products = {"succinylcoa": 1.0, "nadh": 1.0, "co2": 1.0}
	rxn.vmax = 8.0
	rxn.km_values = {"alphaketo": 0.08}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Succinate Dehydrogenase: Succinate → Fumarate → Malate
func _add_reaction_succinate_dehydrogenase() -> void:
	var rxn = create_base_reaction("sdh", "Succinate Dehydrogenase", "Succinate Dehydrogenase", "mitochondrion")
	rxn.reactants = {"succinylcoa": 1.0}
	rxn.products = {"succinate": 1.0}
	rxn.vmax = 6.0
	rxn.km_values = {"succinylcoa": 0.02}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Malate Dehydrogenase: Malate → Oxaloacetate
func _add_reaction_malate_dehydrogenase() -> void:
	var rxn = create_base_reaction("mdh", "Malate Dehydrogenase", "Malate Dehydrogenase", "mitochondrion")
	rxn.reactants = {"malate": 1.0}
	rxn.products = {"oxaloacetate": 1.0, "nadh": 1.0}
	rxn.vmax = 15.0
	rxn.km_values = {"malate": 0.1}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Electron Transport Chain: NADH + O2 → NAD+ + ATP
func _add_reaction_electron_transport() -> void:
	var rxn = create_base_reaction("etc", "Electron Transport Chain", "ETC", "mitochondrion")
	rxn.reactants = {"nadh": 1.0, "oxygen": 0.5}
	rxn.products = {"nad": 1.0, "atp": 2.5}
	rxn.vmax = 20.0
	rxn.km_values = {"nadh": 0.1, "oxygen": 0.001}
	rxn.kinetic_type = "michaelis_menten"
	reactions.append(rxn)

## Main simulation loop: calculates rates and applies changes
func simulate_step() -> void:
	reaction_rates.clear()
	
	for rxn in reactions:
		var rate = _calculate_reaction_rate(rxn)
		reaction_rates[rxn.id] = rate
		_apply_reaction(rxn, rate)

## Calculates reaction rate based on kinetic model type
func _calculate_reaction_rate(rxn: Reaction) -> float:
	match rxn.kinetic_type:
		"michaelis_menten":
			return _calculate_mm_rate(rxn)
		"hill":
			return _calculate_hill_rate(rxn)
		_:
			return 0.0

## Michaelis-Menten kinetics for substrate-enzyme interactions
func _calculate_mm_rate(rxn: Reaction) -> float:
	if rxn.reactants.size() == 1:
		var substrate_name = rxn.reactants.keys()[0]
		var substrate = molecules[substrate_name]
		var km = rxn.km_values.get(substrate_name, 0.1)
		var rate = (rxn.vmax * substrate.concentration) / (km + substrate.concentration)
		
		## Apply allosteric regulation
		rate *= _calculate_allosteric_factor(rxn)
		return rate
	
	elif rxn.reactants.size() == 2:
		## Two-substrate kinetics
		var keys = rxn.reactants.keys()
		var s1 = molecules[keys[0]]
		var s2 = molecules[keys[1]]
		var km1 = rxn.km_values.get(keys[0], 0.1)
		var km2 = rxn.km_values.get(keys[1], 0.1)
		
		var rate = (rxn.vmax * s1.concentration * s2.concentration) / \
				   ((km1 + s1.concentration) * (km2 + s2.concentration))
		rate *= _calculate_allosteric_factor(rxn)
		return rate
	
	return 0.0

## Hill coefficient kinetics for cooperative binding
func _calculate_hill_rate(rxn: Reaction) -> float:
	## TODO: Implement Hill kinetics
	return 0.0

## Applies allosteric modulation factors to reaction rate
func _calculate_allosteric_factor(rxn: Reaction) -> float:
	var factor = 1.0
	
	for mod_molecule in rxn.allosteric_mods:
		if not molecules.has(mod_molecule):
			continue
		
		var mod_data = rxn.allosteric_mods[mod_molecule]
		var conc = molecules[mod_molecule].concentration
		
		if mod_data["type"] == "inhibitor":
			factor *= (1.0 - (conc * mod_data["factor"]))
		elif mod_data["type"] == "activator":
			factor *= mod_data["factor"]
	
	return clamp(factor, 0.1, 1.0)

## Applies stoichiometric changes based on reaction rate
func _apply_reaction(rxn: Reaction, rate: float) -> void:
	var dt = timestep
	
	## Consume reactants
	for reactant_name in rxn.reactants:
		if molecules.has(reactant_name):
			molecules[reactant_name].concentration -= rxn.reactants[reactant_name] * rate * dt
	
	## Produce products
	for product_name in rxn.products:
		if molecules.has(product_name):
			molecules[product_name].concentration += rxn.products[product_name] * rate * dt
	
	## Clamp negatives
	for mol_name in molecules:
		molecules[mol_name].concentration = max(molecules[mol_name].concentration, 0.0)

## Dynamically add a reaction to the simulation
func add_custom_reaction(rxn: Reaction) -> void:
	reactions.append(rxn)

## Gets current concentration of a molecule
func get_molecule_conc(mol_name: String) -> float:
	if molecules.has(mol_name):
		return molecules[mol_name].concentration
	return 0.0

## Sets concentration of a molecule
func set_molecule_conc(mol_name: String, conc: float) -> void:
	if molecules.has(mol_name):
		molecules[mol_name].concentration = conc

## Gets current reaction rate by reaction ID
func get_reaction_rate(rxn_id: String) -> float:
	return reaction_rates.get(rxn_id, 0.0)

## Prints current state of all molecules organized by compartment
func print_state() -> void:
	print("\n=== Iteration %d (t=%.2fs) ===" % [iteration, total_time])
	for comp in compartments:
		print("\n📍 %s:" % comp)
		for mol_name in molecules:
			if molecules[mol_name].compartment == comp:
				print("  %s: %.4f mM" % [molecules[mol_name].name, molecules[mol_name].concentration])
