## Individual reaction catalyzed by an enzyme
class_name Reaction
extends RefCounted

var id: String
var name: String = ""

## Stoichiometry
var substrates: Dictionary = {}  ## {"molecule_name": stoichiometry}
var products: Dictionary = {}    ## {"molecule_name": stoichiometry}

## Kinetic parameters (specific to this reaction)
var kcat_forward: float = 10.0   ## Forward catalytic rate constant (s⁻¹)
var kcat_reverse: float = 1.0    ## Reverse catalytic rate constant (s⁻¹)
var km_substrates: Dictionary = {} ## {"molecule": Km value in mM}
var km_products: Dictionary = {}   ## {"molecule": Km value in mM}

## Thermodynamic parameters (specific to this reaction)
var delta_g_standard: float = -5.0  ## ΔG° in kJ/mol
var temperature: float = 310.0      ## Temperature in Kelvin (37°C)

## Runtime state
var current_forward_rate: float = 0.0
var current_reverse_rate: float = 0.0
var current_delta_g: float = 0.0
var current_keq: float = 0.0

const R: float = 8.314e-3  ## Gas constant in kJ/(mol·K)

func _init(p_id: String, p_name: String = "") -> void:
	id = p_id
	name = p_name if p_name != "" else p_id

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()

## Calculate equilibrium constant from standard free energy
func calculate_keq() -> float:
	return exp(-delta_g_standard / (R * temperature))

## Calculate actual ΔG based on current concentrations
func calculate_actual_delta_g(molecules: Dictionary) -> float:
	current_keq = calculate_keq()
	
	if is_source() or is_sink():
		current_delta_g = delta_g_standard
		return current_delta_g
	
	var q: float = 1.0
	
	## Products in numerator
	for product in products:
		if molecules.has(product):
			var conc = max(molecules[product].concentration, 1e-6)
			var stoich = products[product]
			q *= pow(conc, stoich)
	
	## Substrates in denominator
	for substrate in substrates:
		if molecules.has(substrate):
			var conc = max(molecules[substrate].concentration, 1e-6)
			var stoich = substrates[substrate]
			q /= pow(conc, stoich)
	
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


## Get a readable summary of this reaction
func get_summary() -> String:
	var substrate_str = ""
	for substrate in substrates:
		var stoich = substrates[substrate]
		if substrate_str != "":
			substrate_str += " + "
		if stoich != 1.0:
			substrate_str += "%.1f " % stoich
		substrate_str += substrate
	
	var product_str = ""
	for product in products:
		var stoich = products[product]
		if product_str != "":
			product_str += " + "
		if stoich != 1.0:
			product_str += "%.1f " % stoich
		product_str += product
	
	if substrate_str == "":
		substrate_str = "∅"
	if product_str == "":
		product_str = "∅"
	
	return "%s → %s" % [substrate_str, product_str]
