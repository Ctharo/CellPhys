## Individual reaction catalyzed by an enzyme
## Now with genetic efficiency based on molecular similarity
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

## Genetic efficiency properties
var genetic_similarity: float = 0.0  ## Similarity between primary substrate and product (0-1)
var genetic_efficiency: float = 0.0  ## Overall genetic efficiency (0-1)
var energy_waste: float = 0.0        ## Energy wasted due to genetic distance (kJ/mol)

## Energy partitioning
var energy_efficiency: float = 0.7  ## 70% → useful work, 30% → heat (thermodynamic efficiency)
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

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()

## Calculate genetic efficiency based on molecular similarity
func calculate_genetic_efficiency(molecules: Dictionary) -> void:
	if is_source() or is_sink():
		genetic_similarity = 1.0
		genetic_efficiency = 1.0
		energy_waste = 0.0
		return
	
	if substrates.is_empty() or products.is_empty():
		genetic_similarity = 0.0
		genetic_efficiency = 0.0
		energy_waste = 0.0
		return
	
	## Get primary substrate and product (first in each dictionary)
	var primary_substrate_name = substrates.keys()[0]
	var primary_product_name = products.keys()[0]
	
	if not molecules.has(primary_substrate_name) or not molecules.has(primary_product_name):
		genetic_similarity = 0.0
		genetic_efficiency = 0.0
		energy_waste = 0.0
		return
	
	var substrate_mol: Molecule = molecules[primary_substrate_name]
	var product_mol: Molecule = molecules[primary_product_name]
	
	## Calculate similarity between substrate and product
	genetic_similarity = substrate_mol.similarity_to(product_mol)
	
	## Genetic efficiency equals similarity (high similarity = high efficiency)
	genetic_efficiency = genetic_similarity
	
	## Calculate energy waste based on genetic distance
	## More dissimilar molecules waste more energy in transformation
	var substrate_energy = 0.0
	for substrate_name in substrates:
		if molecules.has(substrate_name):
			var stoich = substrates[substrate_name]
			substrate_energy += molecules[substrate_name].potential_energy * stoich
	
	## Waste increases with genetic distance (inverse of similarity)
	var genetic_distance = 1.0 - genetic_similarity
	energy_waste = substrate_energy * genetic_distance * 0.1  ## 10% max waste

## Calculate total efficiency combining thermodynamics and genetics
func get_total_efficiency() -> float:
	## Thermodynamic efficiency
	var thermo_eff = 0.0
	if current_delta_g_actual < 0:
		var substrate_energy_total = 0.0
		for substrate_name in substrates:
			var stoich = substrates[substrate_name]
			substrate_energy_total += stoich  ## Approximation
		
		if substrate_energy_total > 0:
			thermo_eff = abs(current_delta_g_actual) / (substrate_energy_total * 50.0)  ## Normalize
			thermo_eff = clamp(thermo_eff, 0.0, 1.0)
	
	## Combine thermodynamic and genetic efficiency (equal weight)
	return (thermo_eff + genetic_efficiency) / 2.0

## Calculate how much energy goes to work vs heat
func calculate_energy_partition(net_rate: float, molecules: Dictionary) -> void:
	## First calculate genetic efficiency
	calculate_genetic_efficiency(molecules)
	
	## For exergonic reactions (ΔG < 0)
	if current_delta_g_actual < 0:
		current_energy_released = -current_delta_g_actual * net_rate
		
		## Reduce useful work by both thermodynamic AND genetic inefficiency
		var combined_efficiency = energy_efficiency * genetic_efficiency
		current_useful_work = current_energy_released * combined_efficiency
		
		## Heat = thermodynamic waste + genetic waste
		var thermo_waste = current_energy_released * (1.0 - energy_efficiency)
		var genetic_waste_rate = energy_waste * net_rate
		current_heat_generated = thermo_waste + genetic_waste_rate
	## For endergonic reactions (ΔG > 0)  
	else:
		current_energy_released = 0.0
		current_useful_work = -current_delta_g_actual * net_rate  ## Energy consumed
		
		## Genetic waste still applies
		var genetic_waste_rate = energy_waste * net_rate
		current_heat_generated = abs(current_useful_work) * 0.1 + genetic_waste_rate

## Check if reaction can proceed given available resources
func can_proceed(molecules: Dictionary, available_energy: float) -> bool:
	## Check substrates
	for substrate_name in substrates:
		if not molecules.has(substrate_name):
			return false
		var required = substrates[substrate_name]
		if molecules[substrate_name].concentration < required * 0.01:  ## Minimum concentration
			return false
	
	## Check energy requirements (including genetic waste)
	calculate_genetic_efficiency(molecules)
	var required_energy = energy_waste
	
	if not is_source():
		var dg = calculate_actual_delta_g(molecules)
		if dg > 0:
			required_energy += dg
	
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
	
	## Calculate genetic efficiency for this reaction
	calculate_genetic_efficiency(molecules)
	
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
	
	## Apply genetic efficiency - lower similarity reduces rate
	rate *= genetic_efficiency
	
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
	
	## Calculate genetic efficiency
	calculate_genetic_efficiency(molecules)
	
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
	
	## Apply genetic efficiency
	rate *= genetic_efficiency
	
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
