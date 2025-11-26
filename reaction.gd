## Individual reaction catalyzed by an enzyme
## Efficiency affects both heat waste and product similarity
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

## Reaction efficiency properties
var reaction_efficiency: float = 0.7  ## How efficiently this reaction proceeds (0-1)
var energy_waste: float = 0.0         ## Energy wasted as heat (kJ/mol)

## Energy partitioning
var coupled_work: float = 0.0       ## Energy used to drive other reactions

## Runtime energy tracking
var current_energy_released: float = 0.0  ## kJ/s
var current_useful_work: float = 0.0      ## kJ/s  
var current_heat_generated: float = 0.0   ## kJ/s

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
	
	## Randomize efficiency (0.3 to 0.95)
	reaction_efficiency = randf_range(0.3, 0.95)

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()

## Calculate how much energy goes to work vs heat
func calculate_energy_partition(net_rate: float, _molecules: Dictionary) -> void:
	## For exergonic reactions (ΔG < 0)
	if current_delta_g_actual < 0:
		current_energy_released = -current_delta_g_actual * net_rate
		
		## Useful work proportional to efficiency
		current_useful_work = current_energy_released * reaction_efficiency
		
		## Heat = total energy - useful work
		current_heat_generated = current_energy_released * (1.0 - reaction_efficiency)
		
		## Track waste
		energy_waste = current_heat_generated / max(net_rate, 0.001)
		
	## For endergonic reactions (ΔG > 0)  
	else:
		current_energy_released = 0.0
		current_useful_work = -current_delta_g_actual * net_rate  ## Energy consumed
		
		## Inefficiency generates heat even in endergonic reactions
		current_heat_generated = abs(current_useful_work) * (1.0 - reaction_efficiency)

## Update product potential energy based on energetics
## Endergonic reactions increase product energy, exergonic decrease it
func update_product_energies(molecules: Dictionary) -> void:
	if is_source() or is_sink():
		return
	
	## Get average substrate energy
	var avg_substrate_energy = 0.0
	var substrate_count = 0
	for substrate_name in substrates:
		if molecules.has(substrate_name):
			avg_substrate_energy += molecules[substrate_name].potential_energy
			substrate_count += 1
	
	if substrate_count > 0:
		avg_substrate_energy /= substrate_count
	else:
		return
	
	## Adjust product energies based on ΔG
	## Endergonic (ΔG > 0): products have MORE energy
	## Exergonic (ΔG < 0): products have LESS energy
	for product_name in products:
		if molecules.has(product_name):
			var energy_change_per_molecule = current_delta_g_actual / products.size()
			molecules[product_name].potential_energy = avg_substrate_energy + energy_change_per_molecule
			
			## Clamp to reasonable range
			molecules[product_name].potential_energy = clamp(
				molecules[product_name].potential_energy,
				10.0,
				150.0
			)

## Check if reaction can proceed given available resources
func can_proceed(molecules: Dictionary, available_energy: float) -> bool:
	## Check substrates
	for substrate_name in substrates:
		if not molecules.has(substrate_name):
			return false
		var required = substrates[substrate_name]
		if molecules[substrate_name].concentration < required * 0.01:  ## Minimum concentration
			return false
	
	## Check energy requirements
	var required_energy = 0.0
	
	if not is_source():
		var dg = calculate_actual_delta_g(molecules)
		if dg > 0:
			required_energy = dg
	
	return available_energy >= required_energy

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
		current_forward_rate = vmax * enzyme_conc * reaction_efficiency
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
	
	## Apply reaction efficiency - lower efficiency reduces rate
	rate *= reaction_efficiency
	
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
	
	## Apply reaction efficiency
	rate *= reaction_efficiency
	
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

## Get detailed stats for this reaction
func get_detailed_stats() -> String:
	var stats = "  %s\n" % get_summary()
	stats += "    Efficiency: %.1f%%, ΔG°: %.1f kJ/mol, ΔG: %.1f kJ/mol\n" % [
		reaction_efficiency * 100.0,
		delta_g,
		current_delta_g_actual
	]
	stats += "    Rates - Fwd: %.3f, Rev: %.3f, Net: %.3f mM/s\n" % [
		current_forward_rate,
		current_reverse_rate,
		current_forward_rate - current_reverse_rate
	]
	stats += "    Energy - Work: %.2f, Heat: %.2f kJ/s\n" % [
		current_useful_work,
		current_heat_generated
	]
	return stats
