## Individual reaction catalyzed by an enzyme
class_name Reaction
extends RefCounted

var id: String
var name: String = ""
var enzyme: Enzyme = null  ## Reference to parent enzyme

## Stoichiometry
var substrates: Dictionary = {}  ## {"molecule_name": stoichiometry}
var products: Dictionary = {}    ## {"molecule_name": stoichiometry}

## Kinetic parameters
var vmax: float = 10.0           ## Maximum velocity (mM/s)
var initial_vmax: float = 10.0   ## Initial vmax for reset
var km: float = 0.5              ## Michaelis constant (mM)
var initial_km: float = 0.5      ## Initial Km for reset

## Thermodynamic parameters
var delta_g: float = -5.0        ## ΔG° in kJ/mol (standard free energy change)
var temperature: float = 310.0   ## Temperature in Kelvin (37°C)

## Reaction constraints
var is_irreversible: bool = false  ## If true, reaction cannot go in reverse

## Runtime state
var current_forward_rate: float = 0.0
var current_reverse_rate: float = 0.0
var current_delta_g_actual: float = 0.0
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
	current_keq = exp(-delta_g / (R * temperature))
	return current_keq

## Calculate actual ΔG based on current concentrations (reaction quotient Q)
func calculate_actual_delta_g(molecules: Dictionary) -> float:
	calculate_keq()
	
	## Source/sink reactions use standard ΔG
	if is_source() or is_sink():
		current_delta_g_actual = delta_g
		return current_delta_g_actual
	
	## Calculate reaction quotient Q = [products]/[substrates]
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
	
	## ΔG = ΔG° + RT ln(Q)
	current_delta_g_actual = delta_g + R * temperature * log(q)
	return current_delta_g_actual

## Calculate forward rate (substrates → products)
func calculate_forward_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	if enzyme_conc <= 0.0:
		return 0.0
	
	## Sources produce at constant rate regardless of thermodynamics
	if is_source():
		current_forward_rate = vmax * enzyme_conc
		return current_forward_rate
	
	## Calculate thermodynamics
	var dg_actual = calculate_actual_delta_g(molecules)
	
	## Thermodynamic constraint: can't go forward if too unfavorable
	if dg_actual > 10.0:
		current_forward_rate = 0.0
		return 0.0
	
	## Michaelis-Menten kinetics with limiting substrate
	var rate = vmax * enzyme_conc
	var min_saturation = 1.0
	
	for substrate in substrates:
		if not molecules.has(substrate):
			current_forward_rate = 0.0
			return 0.0
		
		var substrate_conc = molecules[substrate].concentration
		if substrate_conc <= 0.0:
			current_forward_rate = 0.0
			return 0.0
		
		var saturation = substrate_conc / (km + substrate_conc)
		min_saturation = min(min_saturation, saturation)
	
	rate *= min_saturation
	
	## Apply thermodynamic damping for slightly unfavorable reactions
	if dg_actual > 0.0:
		var damping = exp(-dg_actual / (R * temperature))
		rate *= damping
	
	current_forward_rate = rate
	return current_forward_rate

## Calculate reverse rate (products → substrates)
func calculate_reverse_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	## Check for irreversibility first
	if is_irreversible:
		current_reverse_rate = 0.0
		return 0.0
	
	if enzyme_conc <= 0.0 or is_source() or is_sink():
		current_reverse_rate = 0.0
		return 0.0
	
	## Calculate thermodynamics
	var dg_actual = calculate_actual_delta_g(molecules)
	
	## Thermodynamic constraint: can't go reverse if too favorable forward
	if dg_actual < -10.0:
		current_reverse_rate = 0.0
		return 0.0
	
	## Reverse Vmax is related to forward Vmax by equilibrium constant
	## Vmax_rev = Vmax_fwd / Keq (Haldane relationship)
	var vmax_reverse = vmax / max(current_keq, 0.01)
	
	## Michaelis-Menten for products as "substrates"
	var rate = vmax_reverse * enzyme_conc
	var min_saturation = 1.0
	
	for product in products:
		if not molecules.has(product):
			current_reverse_rate = 0.0
			return 0.0
		
		var product_conc = molecules[product].concentration
		if product_conc <= 0.0:
			current_reverse_rate = 0.0
			return 0.0
		
		var saturation = product_conc / (km + product_conc)
		min_saturation = min(min_saturation, saturation)
	
	rate *= min_saturation
	
	## Apply thermodynamic damping for slightly unfavorable reverse reactions
	if dg_actual < 0.0:
		var damping = exp(dg_actual / (R * temperature))
		rate *= damping
	
	current_reverse_rate = rate
	return current_reverse_rate

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
	
	## Use arrow to indicate irreversibility
	var arrow = "→" if is_irreversible else "⇄"
	return "%s %s %s" % [substrate_str, arrow, product_str]
