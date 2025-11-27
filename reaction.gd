## Individual reaction catalyzed by an enzyme
## Efficiency affects both heat waste and product similarity
class_name Reaction
extends RefCounted

const R: float = 8.314e-3  ## Gas constant in kJ/(mol·K)

var id: String
var name: String = ""
var enzyme: Enzyme = null

#region Stoichiometry

var substrates: Dictionary = {}  ## {"molecule_name": stoichiometry}
var products: Dictionary = {}    ## {"molecule_name": stoichiometry}

#endregion

#region Kinetic Parameters

var vmax: float = 10.0           ## Maximum velocity (mM/s)
var km: float = 0.5              ## Michaelis constant (mM)
var reaction_efficiency: float = 0.7  ## How efficiently reaction proceeds (0-1)
var is_irreversible: bool = false

#endregion

#region Thermodynamic Parameters

var delta_g: float = -5.0        ## ΔG° in kJ/mol (standard free energy change)
var temperature: float = 310.0   ## Temperature in Kelvin (37°C)

#endregion

#region Runtime State

var current_forward_rate: float = 0.0
var current_reverse_rate: float = 0.0
var current_delta_g_actual: float = 0.0
var current_keq: float = 0.0
var current_useful_work: float = 0.0
var current_heat_generated: float = 0.0

#endregion

#region Initialization

func _init(p_id: String, p_name: String = "") -> void:
	id = p_id
	name = p_name if p_name != "" else p_id
	reaction_efficiency = randf_range(0.3, 0.95)

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()

#endregion

#region Thermodynamic Calculations

## Calculate equilibrium constant from standard free energy
func calculate_keq() -> float:
	current_keq = exp(-delta_g / (R * temperature))
	return current_keq

## Calculate actual ΔG based on current concentrations
func calculate_actual_delta_g(molecules: Dictionary) -> float:
	calculate_keq()
	
	if is_source() or is_sink():
		current_delta_g_actual = delta_g
		return current_delta_g_actual
	
	## Calculate reaction quotient Q = [products]/[substrates]
	var q: float = 1.0
	
	for product in products:
		if molecules.has(product):
			var conc = max(molecules[product].concentration, 1e-6)
			q *= pow(conc, products[product])
	
	for substrate in substrates:
		if molecules.has(substrate):
			var conc = max(molecules[substrate].concentration, 1e-6)
			q /= pow(conc, substrates[substrate])
	
	## ΔG = ΔG° + RT ln(Q)
	current_delta_g_actual = delta_g + R * temperature * log(q)
	return current_delta_g_actual

## Calculate energy partitioning between work and heat
func calculate_energy_partition(net_rate: float) -> void:
	if current_delta_g_actual < 0:
		var energy_released = -current_delta_g_actual * net_rate
		current_useful_work = energy_released * reaction_efficiency
		current_heat_generated = energy_released * (1.0 - reaction_efficiency)
	else:
		current_useful_work = -current_delta_g_actual * net_rate
		current_heat_generated = abs(current_useful_work) * (1.0 - reaction_efficiency)

#endregion

#region Rate Calculations

## Calculate forward rate (substrates → products)
func calculate_forward_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	if enzyme_conc <= 0.0:
		current_forward_rate = 0.0
		return 0.0
	
	## Sources produce at constant rate
	if is_source():
		current_forward_rate = vmax * enzyme_conc * reaction_efficiency
		return current_forward_rate
	
	var dg_actual = calculate_actual_delta_g(molecules)
	
	## Can't go forward if too unfavorable
	if dg_actual > 10.0:
		current_forward_rate = 0.0
		return 0.0
	
	## Michaelis-Menten kinetics
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
	
	rate *= min_saturation * reaction_efficiency
	
	## Thermodynamic damping for unfavorable reactions
	if dg_actual > 0.0:
		rate *= exp(-dg_actual / (R * temperature))
	
	current_forward_rate = rate
	return current_forward_rate

## Calculate reverse rate (products → substrates)
func calculate_reverse_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	if is_irreversible or enzyme_conc <= 0.0 or is_source() or is_sink():
		current_reverse_rate = 0.0
		return 0.0
	
	var dg_actual = calculate_actual_delta_g(molecules)
	
	if dg_actual < -10.0:
		current_reverse_rate = 0.0
		return 0.0
	
	## Vmax_rev = Vmax_fwd / Keq (Haldane relationship)
	var vmax_reverse = vmax / max(current_keq, 0.01)
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
	
	rate *= min_saturation * reaction_efficiency
	
	if dg_actual < 0.0:
		rate *= exp(dg_actual / (R * temperature))
	
	current_reverse_rate = rate
	return current_reverse_rate

func get_net_rate() -> float:
	return current_forward_rate - current_reverse_rate

#endregion

#region Display

func get_summary() -> String:
	var substrate_str = ""
	for substrate in substrates:
		if substrate_str != "":
			substrate_str += " + "
		var stoich = substrates[substrate]
		if stoich != 1.0:
			substrate_str += "%.1f " % stoich
		substrate_str += substrate
	
	var product_str = ""
	for product in products:
		if product_str != "":
			product_str += " + "
		var stoich = products[product]
		if stoich != 1.0:
			product_str += "%.1f " % stoich
		product_str += product
	
	if substrate_str == "":
		substrate_str = "∅"
	if product_str == "":
		product_str = "∅"
	
	var arrow = "→" if is_irreversible else "⇄"
	return "%s %s %s" % [substrate_str, arrow, product_str]

func get_detailed_stats() -> String:
	var stats = "%s\n" % get_summary()
	stats += "  Efficiency: %.0f%%, ΔG°: %.1f, ΔG: %.1f kJ/mol\n" % [
		reaction_efficiency * 100.0, delta_g, current_delta_g_actual
	]
	stats += "  Rates: Fwd=%.3f, Rev=%.3f, Net=%.3f mM/s\n" % [
		current_forward_rate, current_reverse_rate, get_net_rate()
	]
	stats += "  Energy: Work=%.2f, Heat=%.2f kJ/s" % [
		current_useful_work, current_heat_generated
	]
	return stats

#endregion
