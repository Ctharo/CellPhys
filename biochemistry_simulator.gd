## Data-driven biochemistry simulator with ENZYME-CENTRIC architecture
## Enzymes are first-class citizens that actively transform molecules

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

## ENZYME: The active agent that catalyzes biochemical transformations
## Enzymes are substrate-specific and regulate their own catalytic rates
class Enzyme:
	var id: String
	var name: String
	var compartment: String
	var concentration: float  ## Enzyme concentration affects max reaction velocity
	
	## Kinetic parameters
	var vmax_per_unit: float  ## Max velocity per unit enzyme concentration
	var km_values: Dictionary  ## {"substrate_name": km_value}
	var kinetic_type: String  ## "michaelis_menten", "hill"
	
	## Substrate and product specifications
	var substrates: Dictionary  ## {"molecule_name": stoichiometry}
	var products: Dictionary    ## {"molecule_name": stoichiometry}
	
	## Regulatory mechanisms
	var allosteric_activators: Dictionary  ## {"molecule": {"Km_factor": 0.5, "Vmax_factor": 1.5}}
	var allosteric_inhibitors: Dictionary  ## {"molecule": {"Km_factor": 2.0, "Vmax_factor": 0.3}}
	var cofactors: Array[String]  ## Required cofactors (must be present)
	
	## State tracking
	var current_rate: float = 0.0  ## µmol/min
	var substrate_saturation: float = 0.0  ## 0-1, how saturated with substrate
	var is_active: bool = true
	
	func _init(p_id: String, p_name: String, p_compartment: String) -> void:
		id = p_id
		name = p_name
		compartment = p_compartment
		concentration = 0.01  ## Default low concentration
		vmax_per_unit = 100.0
		km_values = {}
		kinetic_type = "michaelis_menten"
		substrates = {}
		products = {}
		allosteric_activators = {}
		allosteric_inhibitors = {}
		cofactors = []
	
	func set_substrate(mol_name: String, stoich: float) -> void:
		substrates[mol_name] = stoich
	
	func set_product(mol_name: String, stoich: float) -> void:
		products[mol_name] = stoich
	
	func add_km(substrate_name: String, km: float) -> void:
		km_values[substrate_name] = km
	
	func add_activator(mol_name: String, vmax_factor: float, km_factor: float = 1.0) -> void:
		allosteric_activators[mol_name] = {"Vmax_factor": vmax_factor, "Km_factor": km_factor}
	
	func add_inhibitor(mol_name: String, vmax_factor: float, km_factor: float = 1.0) -> void:
		allosteric_inhibitors[mol_name] = {"Vmax_factor": vmax_factor, "Km_factor": km_factor}
	
	func get_effective_vmax(modulation_factor: float) -> float:
		return vmax_per_unit * concentration * modulation_factor

var compartments: Dictionary = {}  ## {"name": {"type": "organelle/cytoplasm", "volume": 1.0}}
var molecules: Dictionary = {}     ## {"molecule_name": Molecule}
var enzymes: Array[Enzyme] = []    ## PRIMARY: Enzyme-centric array

var timestep: float = 0.1
var total_time: float = 0.0
var iteration: int = 0
var is_paused: bool = false

func _ready() -> void:
	_initialize_compartments()
	initialize_molecules()
	initialize_enzymes()  ## Now initialize enzymes (not reactions)
	print("✅ Enzyme-Centric Biochemistry Simulator initialized")

func _process(delta: float) -> void:
	if is_paused:
		return
	
	total_time += delta
	if fmod(total_time, timestep) < delta:
		simulate_step()
		iteration += 1
		if iteration % 10 == 0:
			print_state()

## Defines all cellular compartments
func _initialize_compartments() -> void:
	compartments = {
		"cytoplasm": {"type": "compartment", "volume": 1.0, "color": Color.LIGHT_GRAY},
		"mitochondrion": {"type": "organelle", "volume": 0.5, "color": Color.ORANGE},
		"extracellular": {"type": "environment", "volume": 2.0, "color": Color.CYAN},
	}

## Initializes molecule concentrations
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

## ENZYME INITIALIZATION: Enzymes are the primary simulation units
func initialize_enzymes() -> void:
	_create_enzyme_pfk()
	_create_enzyme_pdh()
	_create_enzyme_citrate_synthase()
	_create_enzyme_isocitrate_dehydrogenase()
	_create_enzyme_alpha_kg_dehydrogenase()
	_create_enzyme_succinate_dehydrogenase()
	_create_enzyme_succinate_dehydrogenase_complex2() 
	_create_enzyme_fumarase()
	_create_enzyme_malate_dehydrogenase()
	_create_enzyme_electron_transport()

## Phosphofructokinase: ATP-inhibited glycolysis regulator
func _create_enzyme_pfk() -> void:
	var enzyme = Enzyme.new("pfk", "Phosphofructokinase", "cytoplasm")
	enzyme.concentration = 0.01
	enzyme.vmax_per_unit = 25.0
	enzyme.set_substrate("glucose", 1.0)
	enzyme.set_product("pyruvate", 2.0)
	enzyme.add_km("glucose", 0.5)
	enzyme.add_inhibitor("atp", 0.7)
	enzyme.add_activator("amp", 1.3)
	enzymes.append(enzyme)

## Pyruvate Dehydrogenase: Bridge between glycolysis and TCA cycle
func _create_enzyme_pdh() -> void:
	var enzyme = Enzyme.new("pdh", "Pyruvate Dehydrogenase", "mitochondrion")
	enzyme.concentration = 0.01
	enzyme.vmax_per_unit = 8.0
	enzyme.set_substrate("pyruvate", 1.0)
	enzyme.set_product("acetylcoa", 1.0)
	enzyme.set_product("co2", 1.0)
	enzyme.add_km("pyruvate", 0.2)
	enzyme.add_inhibitor("acetylcoa", 0.5)
	enzyme.add_inhibitor("nadh", 0.6)
	enzymes.append(enzyme)

## Citrate Synthase: TCA cycle entry point
func _create_enzyme_citrate_synthase() -> void:
	var enzyme = Enzyme.new("cs", "Citrate Synthase", "mitochondrion")
	enzyme.concentration = 0.015
	enzyme.vmax_per_unit = 12.0
	enzyme.set_substrate("acetylcoa", 1.0)
	enzyme.set_substrate("oxaloacetate", 1.0)
	enzyme.set_product("citrate", 1.0)
	enzyme.add_km("acetylcoa", 0.01)
	enzyme.add_km("oxaloacetate", 0.01)
	enzyme.add_inhibitor("succinylcoa", 0.4)
	enzyme.add_inhibitor("nadh", 0.5)
	enzymes.append(enzyme)

## Isocitrate Dehydrogenase: First oxidative step of TCA
func _create_enzyme_isocitrate_dehydrogenase() -> void:
	var enzyme = Enzyme.new("icdh", "Isocitrate Dehydrogenase", "mitochondrion")
	enzyme.concentration = 0.01
	enzyme.vmax_per_unit = 10.0
	enzyme.set_substrate("citrate", 1.0)
	enzyme.set_product("alphaketo", 1.0)
	enzyme.set_product("nadh", 1.0)
	enzyme.set_product("co2", 1.0)
	enzyme.add_km("citrate", 0.05)
	enzyme.add_activator("amp", 1.2)
	enzyme.add_inhibitor("nadh", 0.5)
	enzymes.append(enzyme)

## α-Ketoglutarate Dehydrogenase: TCA cycle continuation
func _create_enzyme_alpha_kg_dehydrogenase() -> void:
	var enzyme = Enzyme.new("akgdh", "α-Ketoglutarate Dehydrogenase", "mitochondrion")
	enzyme.concentration = 0.008
	enzyme.vmax_per_unit = 8.0
	enzyme.set_substrate("alphaketo", 1.0)
	enzyme.set_product("succinylcoa", 1.0)
	enzyme.set_product("nadh", 1.0)
	enzyme.set_product("co2", 1.0)
	enzyme.add_km("alphaketo", 0.08)
	enzyme.add_inhibitor("nadh", 0.6)
	enzyme.add_inhibitor("succinylcoa", 0.5)
	enzymes.append(enzyme)

## Succinate Dehydrogenase: TCA cycle continuation
func _create_enzyme_succinate_dehydrogenase() -> void:
	var enzyme = Enzyme.new("sdh", "Succinate Dehydrogenase", "mitochondrion")
	enzyme.concentration = 0.012
	enzyme.vmax_per_unit = 6.0
	enzyme.set_substrate("succinylcoa", 1.0)
	enzyme.set_product("succinate", 1.0)
	enzyme.add_km("succinylcoa", 0.02)
	enzymes.append(enzyme)

## Malate Dehydrogenase: TCA cycle completion
func _create_enzyme_malate_dehydrogenase() -> void:
	var enzyme = Enzyme.new("mdh", "Malate Dehydrogenase", "mitochondrion")
	enzyme.concentration = 0.02
	enzyme.vmax_per_unit = 15.0
	enzyme.set_substrate("malate", 1.0)
	enzyme.set_product("oxaloacetate", 1.0)
	enzyme.set_product("nadh", 1.0)
	enzyme.add_km("malate", 0.1)
	enzyme.add_inhibitor("nadh", 0.4)
	enzymes.append(enzyme)
	
## Succinate Dehydrogenase (Complex II): Converts Succinate to Fumarate
## This is the REAL succinate dehydrogenase - part of both TCA cycle and ETC
## NOTE: Your existing SDH actually does Succinyl-CoA → Succinate
## This enzyme does Succinate → Fumarate and produces FADH2
func _create_enzyme_succinate_dehydrogenase_complex2() -> void:
	var enzyme = Enzyme.new("sdh_c2", "Succinate Dehydrogenase (Complex II)", "mitochondrion")
	enzyme.concentration = 0.01
	enzyme.vmax_per_unit = 7.0
	enzyme.set_substrate("succinate", 1.0)
	enzyme.set_substrate("fad", 1.0)
	enzyme.set_product("fumarate", 1.0)
	enzyme.set_product("fadh2", 1.0)
	enzyme.add_km("succinate", 0.03)
	enzyme.add_km("fad", 0.5)
	enzyme.add_inhibitor("oxaloacetate", 0.6)
	enzymes.append(enzyme)

## Fumarase: Converts Fumarate to Malate
## Adds water (hydration reaction)
func _create_enzyme_fumarase() -> void:
	var enzyme = Enzyme.new("fum", "Fumarase", "mitochondrion")
	enzyme.concentration = 0.015
	enzyme.vmax_per_unit = 10.0
	enzyme.set_substrate("fumarate", 1.0)
	enzyme.set_product("malate", 1.0)
	enzyme.add_km("fumarate", 0.05)
	enzymes.append(enzyme)

## Electron Transport Chain: ATP generation
func _create_enzyme_electron_transport() -> void:
	var enzyme = Enzyme.new("etc", "Electron Transport Chain", "mitochondrion")
	enzyme.concentration = 0.005
	enzyme.vmax_per_unit = 50.0
	enzyme.set_substrate("nadh", 1.0)
	enzyme.set_substrate("oxygen", 0.5)
	enzyme.set_product("nad", 1.0)
	enzyme.set_product("atp", 2.5)
	enzyme.add_km("nadh", 0.1)
	enzyme.add_km("oxygen", 0.001)
	enzymes.append(enzyme)
	


## SIMULATION CORE: Each enzyme catalyzes its own transformation
func simulate_step() -> void:
	for enzyme in enzymes:
		if not enzyme.is_active:
			continue
		
		## Each enzyme calculates its own catalytic rate
		enzyme.current_rate = _calculate_enzyme_rate(enzyme)
		enzyme.substrate_saturation = _calculate_saturation(enzyme)
		
		## Each enzyme applies its own transformation
		_apply_enzyme_catalysis(enzyme, enzyme.current_rate)

## Enzyme calculates its reaction rate based on current conditions
func _calculate_enzyme_rate(enzyme: Enzyme) -> float:
	if not _check_cofactors_available(enzyme):
		return 0.0
	
	var vmax = enzyme.get_effective_vmax(1.0)
	var modulation = _calculate_modulation_factor(enzyme)
	vmax *= modulation
	
	match enzyme.kinetic_type:
		"michaelis_menten":
			return _calculate_mm_rate_for_enzyme(enzyme, vmax)
		"hill":
			return 0.0 ## TODO
		_:
			return 0.0

## Michaelis-Menten for enzyme with single or multiple substrates
func _calculate_mm_rate_for_enzyme(enzyme: Enzyme, vmax: float) -> float:
	if enzyme.substrates.size() == 1:
		var substrate_name = enzyme.substrates.keys()[0]
		if not molecules.has(substrate_name):
			return 0.0
		
		var substrate_conc = molecules[substrate_name].concentration
		var km = enzyme.km_values.get(substrate_name, 0.1)
		var rate = (vmax * substrate_conc) / (km + substrate_conc)
		return rate
	
	elif enzyme.substrates.size() == 2:
		var keys = enzyme.substrates.keys()
		if not molecules.has(keys[0]) or not molecules.has(keys[1]):
			return 0.0
		
		var s1_conc = molecules[keys[0]].concentration
		var s2_conc = molecules[keys[1]].concentration
		var km1 = enzyme.km_values.get(keys[0], 0.1)
		var km2 = enzyme.km_values.get(keys[1], 0.1)
		
		var rate = (vmax * s1_conc * s2_conc) / ((km1 + s1_conc) * (km2 + s2_conc))
		return rate
	
	return 0.0


## Calculate how regulatory molecules affect enzyme activity
func _calculate_modulation_factor(enzyme: Enzyme) -> float:
	var factor = 1.0
	
	## Allosteric inhibitors reduce activity
	for inhibitor_mol in enzyme.allosteric_inhibitors:
		if molecules.has(inhibitor_mol):
			var data = enzyme.allosteric_inhibitors[inhibitor_mol]
			factor *= data["Vmax_factor"]
	
	## Allosteric activators enhance activity
	for activator_mol in enzyme.allosteric_activators:
		if molecules.has(activator_mol):
			var data = enzyme.allosteric_activators[activator_mol]
			factor *= data["Vmax_factor"]
	
	return clamp(factor, 0.1, 1.5)

## Check if required cofactors are available
func _check_cofactors_available(enzyme: Enzyme) -> bool:
	for cofactor in enzyme.cofactors:
		if not molecules.has(cofactor):
			return false
		if molecules[cofactor].concentration < 0.001:
			return false
	return true

## Calculate substrate saturation (0-1 range)
func _calculate_saturation(enzyme: Enzyme) -> float:
	if enzyme.substrates.size() == 0:
		return 0.0
	
	var avg_saturation = 0.0
	for substrate_name in enzyme.substrates:
		if molecules.has(substrate_name):
			var conc = molecules[substrate_name].concentration
			var km = enzyme.km_values.get(substrate_name, 0.1)
			avg_saturation += conc / (km + conc)
	
	return avg_saturation / enzyme.substrates.size()

## ENZYME CATALYSIS: The enzyme actively transforms its substrates into products
func _apply_enzyme_catalysis(enzyme: Enzyme, rate: float) -> void:
	var dt = timestep
	
	## Enzyme consumes substrates
	for substrate_name in enzyme.substrates:
		if molecules.has(substrate_name):
			var amount = enzyme.substrates[substrate_name] * rate * dt
			molecules[substrate_name].concentration -= amount
	
	## Enzyme produces products
	for product_name in enzyme.products:
		if molecules.has(product_name):
			var amount = enzyme.products[product_name] * rate * dt
			molecules[product_name].concentration += amount
	
	## Prevent negative concentrations
	for mol_name in molecules:
		molecules[mol_name].concentration = max(molecules[mol_name].concentration, 0.0)

## Get current rate of an enzyme by ID
func get_enzyme_rate(enzyme_id: String) -> float:
	for enzyme in enzymes:
		if enzyme.id == enzyme_id:
			return enzyme.current_rate
	return 0.0

## Get enzyme by ID
func get_enzyme(enzyme_id: String) -> Enzyme:
	for enzyme in enzymes:
		if enzyme.id == enzyme_id:
			return enzyme
	return null

## Gets current concentration of a molecule
func get_molecule_conc(mol_name: String) -> float:
	if molecules.has(mol_name):
		return molecules[mol_name].concentration
	return 0.0

## Sets concentration of a molecule
func set_molecule_conc(mol_name: String, conc: float) -> void:
	if molecules.has(mol_name):
		molecules[mol_name].concentration = conc

## Prints current state of all molecules and enzymes
func print_state() -> void:
	print("\n=== Iteration %d (t=%.2fs) ===" % [iteration, total_time])
	print("\n📊 ENZYME ACTIVITY:")
	for enzyme in enzymes:
		print("  %s: %.2f µmol/min (saturation: %.1f%%)" % \
			[enzyme.name, enzyme.current_rate, enzyme.substrate_saturation * 100.0])
	
	print("\n🧬 MOLECULE CONCENTRATIONS:")
	for comp in compartments:
		print("\n  %s:" % comp)
		for mol_name in molecules:
			if molecules[mol_name].compartment == comp:
				print("    %s: %.4f mM" % [molecules[mol_name].name, molecules[mol_name].concentration])
