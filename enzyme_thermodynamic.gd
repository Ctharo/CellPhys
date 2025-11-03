## Thermodynamically-aware enzyme with realistic regulation
class_name EnzymeThermodynamic
extends RefCounted

var id: String
var name: String
var concentration: float
var initial_concentration: float

## Catalytic parameters
var kcat_forward: float = 10.0    ## Forward catalytic rate constant (s⁻¹)
var kcat_reverse: float = 1.0     ## Reverse catalytic rate constant (s⁻¹)
var km_substrates: Dictionary = {} ## {"molecule": Km value in mM}
var km_products: Dictionary = {}   ## {"molecule": Km value in mM}

## Thermodynamic parameters
var delta_g_standard: float = -5.0  ## ΔG° in kJ/mol (negative = favorable forward)
var temperature: float = 310.0      ## Temperature in Kelvin (37°C)

## Stoichiometry
var substrates: Dictionary = {}     ## {"molecule_name": stoichiometry}
var products: Dictionary = {}       ## {"molecule_name": stoichiometry}

## Competitive inhibitors (bind to active site)
var competitive_inhibitors: Dictionary = {}  ## {"molecule": Ki in mM}

## Non-competitive inhibitors (bind elsewhere, reduce Vmax)
var noncompetitive_inhibitors: Dictionary = {}  ## {"molecule": Ki in mM}

## Allosteric regulators (bind to regulatory sites)
var allosteric_activators: Dictionary = {}   ## {"molecule": {"kd": Kd, "fold": max fold-change}}
var allosteric_inhibitors: Dictionary = {}   ## {"molecule": {"kd": Kd, "fold": min fold-change}}

## Enzyme dynamics (creation/degradation)
var creation_rate: float = 0.0
var degradation_rate: float = 0.0
var creation_regulators: Dictionary = {}     ## {"molecule": {"kd": Kd, "type": "activator"/"inhibitor", "max_effect": float}}
var degradation_regulators: Dictionary = {}  ## {"molecule": {"kd": Kd, "type": "activator"/"inhibitor", "max_effect": float}}

## Runtime state
var current_forward_rate: float = 0.0
var current_reverse_rate: float = 0.0
var current_delta_g: float = 0.0
var current_keq: float = 0.0

const R: float = 8.314e-3  ## Gas constant in kJ/(mol·K)

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = 0.01
	initial_concentration = 0.01

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()

## Calculate equilibrium constant from standard free energy
func calculate_keq() -> float:
	# ΔG° = -RT ln(Keq)
	# Keq = exp(-ΔG°/RT)
	return exp(-delta_g_standard / (R * temperature))

## Calculate actual ΔG based on current concentrations
func calculate_actual_delta_g(molecules: Dictionary) -> float:
	current_keq = calculate_keq()
	
	# For sources and sinks, don't apply thermodynamic constraints
	if is_source() or is_sink():
		current_delta_g = delta_g_standard
		return current_delta_g
	
	# Calculate reaction quotient Q = [products]^stoich / [substrates]^stoich
	var q: float = 1.0
	
	# Products in numerator
	for product in products:
		if molecules.has(product):
			var conc = max(molecules[product].concentration, 1e-6)  # Avoid log(0)
			var stoich = products[product]
			q *= pow(conc, stoich)
	
	# Substrates in denominator
	for substrate in substrates:
		if molecules.has(substrate):
			var conc = max(molecules[substrate].concentration, 1e-6)
			var stoich = substrates[substrate]
			q /= pow(conc, stoich)
	
	# ΔG = ΔG° + RT ln(Q)
	current_delta_g = delta_g_standard + R * temperature * log(q)
	return current_delta_g

## Calculate forward rate with all regulation
func calculate_forward_rate(molecules: Dictionary) -> float:
	if concentration <= 0.0:
		return 0.0
	
	# Sources produce regardless of thermodynamics
	if is_source():
		var vmax = kcat_forward * concentration
		vmax = apply_allosteric_regulation(vmax, molecules)
		return vmax
	
	# Check thermodynamics - can't proceed if ΔG > 0 significantly
	var delta_g = calculate_actual_delta_g(molecules)
	if delta_g > 5.0:  # Too unfavorable (> 5 kJ/mol)
		return 0.0
	
	# Base Vmax
	var vmax = kcat_forward * concentration
	
	# Apply allosteric regulation
	vmax = apply_allosteric_regulation(vmax, molecules)
	
	# Apply non-competitive inhibition
	vmax = apply_noncompetitive_inhibition(vmax, molecules)
	
	# Calculate apparent Km with competitive inhibition
	var km_app = calculate_apparent_km(molecules)
	
	# Michaelis-Menten kinetics with limiting substrate
	var min_saturation = 1.0
	for substrate in substrates:
		if not molecules.has(substrate):
			return 0.0
		var substrate_conc = molecules[substrate].concentration
		var km = km_substrates.get(substrate, 0.5)
		var saturation = substrate_conc / (km_app * km + substrate_conc)
		min_saturation = min(min_saturation, saturation)
	
	return vmax * min_saturation

## Calculate reverse rate (products → substrates)
func calculate_reverse_rate(molecules: Dictionary) -> float:
	if concentration <= 0.0 or is_source() or is_sink():
		return 0.0
	
	# Check thermodynamics for reverse reaction
	var delta_g = calculate_actual_delta_g(molecules)
	if delta_g < -5.0:  # Too unfavorable for reverse
		return 0.0
	
	# Base reverse Vmax
	var vmax_rev = kcat_reverse * concentration
	
	# Apply allosteric regulation (affects both directions)
	vmax_rev = apply_allosteric_regulation(vmax_rev, molecules)
	
	# Michaelis-Menten for products as "substrates"
	var min_saturation = 1.0
	for product in products:
		if not molecules.has(product):
			return 0.0
		var product_conc = molecules[product].concentration
		var km = km_products.get(product, 0.5)
		var saturation = product_conc / (km + product_conc)
		min_saturation = min(min_saturation, saturation)
	
	return vmax_rev * min_saturation

## Apply allosteric activators and inhibitors
func apply_allosteric_regulation(vmax: float, molecules: Dictionary) -> float:
	# Activators increase activity
	for regulator in allosteric_activators:
		if molecules.has(regulator):
			var params = allosteric_activators[regulator]
			var kd = params.get("kd", 0.5)
			var max_fold = params.get("fold", 2.0)
			var conc = molecules[regulator].concentration
			
			# Fractional occupancy
			var occupancy = conc / (kd + conc)
			# Effect ranges from 1.0 (no effect) to max_fold
			var fold_change = 1.0 + (max_fold - 1.0) * occupancy
			vmax *= fold_change
	
	# Inhibitors decrease activity
	for regulator in allosteric_inhibitors:
		if molecules.has(regulator):
			var params = allosteric_inhibitors[regulator]
			var kd = params.get("kd", 0.5)
			var min_fold = params.get("fold", 0.1)  # e.g., 0.1 = reduce to 10%
			var conc = molecules[regulator].concentration
			
			var occupancy = conc / (kd + conc)
			var fold_change = 1.0 - (1.0 - min_fold) * occupancy
			vmax *= fold_change
	
	return max(0.0, vmax)

## Calculate apparent Km with competitive inhibition
func calculate_apparent_km(molecules: Dictionary) -> float:
	var km_factor = 1.0
	
	for inhibitor in competitive_inhibitors:
		if molecules.has(inhibitor):
			var ki = competitive_inhibitors[inhibitor]
			var inhibitor_conc = molecules[inhibitor].concentration
			# Km_app = Km * (1 + [I]/Ki)
			km_factor *= (1.0 + inhibitor_conc / ki)
	
	return km_factor

## Apply non-competitive inhibition (reduces Vmax)
func apply_noncompetitive_inhibition(vmax: float, molecules: Dictionary) -> float:
	for inhibitor in noncompetitive_inhibitors:
		if molecules.has(inhibitor):
			var ki = noncompetitive_inhibitors[inhibitor]
			var inhibitor_conc = molecules[inhibitor].concentration
			# Vmax_app = Vmax / (1 + [I]/Ki)
			vmax /= (1.0 + inhibitor_conc / ki)
	
	return vmax

## Update enzyme concentration with regulated creation/degradation
func update_enzyme_concentration(molecules: Dictionary, timestep: float) -> void:
	var creation = creation_rate
	
	# Apply creation regulators
	for mol_name in creation_regulators:
		if molecules.has(mol_name):
			var params = creation_regulators[mol_name]
			var kd = params.get("kd", 0.5)
			var reg_type = params.get("type", "activator")
			var max_effect = params.get("max_effect", 0.1)
			
			var conc = molecules[mol_name].concentration
			var occupancy = conc / (kd + conc)
			var effect = max_effect * occupancy
			
			if reg_type == "activator":
				creation += effect
			else:  # inhibitor
				creation -= effect
	
	var degradation = degradation_rate * concentration
	
	# Apply degradation regulators
	for mol_name in degradation_regulators:
		if molecules.has(mol_name):
			var params = degradation_regulators[mol_name]
			var kd = params.get("kd", 0.5)
			var reg_type = params.get("type", "activator")
			var max_effect = params.get("max_effect", 0.1)
			
			var conc = molecules[mol_name].concentration
			var occupancy = conc / (kd + conc)
			var effect = max_effect * occupancy * concentration
			
			if reg_type == "activator":
				degradation += effect
			else:  # inhibitor
				degradation -= effect
	
	creation = max(0.0, creation)
	degradation = max(0.0, degradation)
	
	concentration += (creation - degradation) * timestep
	concentration = max(0.0, concentration)
