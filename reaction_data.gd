## Reaction resource - represents a biochemical reaction with kinetic and thermodynamic parameters
## Supports multiple substrates and products with stoichiometric coefficients
## Can be saved as .tres for reusable reaction templates
class_name ReactionData
extends Resource

const R: float = 8.314e-3  ## Gas constant in kJ/(mol·K)

#region Exported Properties

@export var reaction_id: String = ""
@export var reaction_name: String = ""

@export_group("Stoichiometry")
## Dictionary mapping molecule names to stoichiometric coefficients
## Example: {"ATP": 1.0, "Glucose": 1.0} for substrates
@export var substrates: Dictionary = {}  ## {molecule_name: stoichiometry}
@export var products: Dictionary = {}    ## {molecule_name: stoichiometry}

@export_group("Kinetic Parameters")
@export var vmax: float = 10.0           ## Maximum velocity (mM/s)
@export var km: float = 0.5              ## Michaelis constant (mM)
@export var reaction_efficiency: float = 0.7  ## How efficiently reaction proceeds (0-1)
@export var is_irreversible: bool = false

@export_group("Thermodynamic Parameters")
@export var delta_g: float = -5.0        ## ΔG° in kJ/mol (standard free energy change)
@export var temperature: float = 310.0   ## Temperature in Kelvin (37°C)

#endregion

#region Runtime State

var enzyme: Resource = null  ## Reference to parent EnzymeData (set at runtime)
var current_forward_rate: float = 0.0
var current_reverse_rate: float = 0.0
var current_delta_g_actual: float = 0.0
var current_keq: float = 0.0
var current_useful_work: float = 0.0
var current_heat_generated: float = 0.0

#endregion

#region Initialization

func _init(p_id: String = "", p_name: String = "") -> void:
	if p_id != "":
		reaction_id = p_id
		reaction_name = p_name if p_name != "" else p_id
		reaction_efficiency = randf_range(0.3, 0.95)


## Create a runtime instance from this resource template
func create_instance() -> ReactionData:
	var instance = duplicate(true) as ReactionData
	instance._reset_runtime_state()
	return instance


func _reset_runtime_state() -> void:
	current_forward_rate = 0.0
	current_reverse_rate = 0.0
	current_delta_g_actual = 0.0
	current_keq = 0.0
	current_useful_work = 0.0
	current_heat_generated = 0.0


func reset() -> void:
	_reset_runtime_state()

#endregion

#region Stoichiometry Helpers

## Add a substrate with stoichiometry (default 1.0)
func add_substrate(mol_name: String, stoich: float = 1.0) -> ReactionData:
	substrates[mol_name] = stoich
	_update_reaction_name()
	return self


## Add a product with stoichiometry (default 1.0)
func add_product(mol_name: String, stoich: float = 1.0) -> ReactionData:
	products[mol_name] = stoich
	_update_reaction_name()
	return self


## Set multiple substrates at once
func set_substrates(substrate_dict: Dictionary) -> ReactionData:
	substrates = substrate_dict.duplicate()
	_update_reaction_name()
	return self


## Set multiple products at once
func set_products(product_dict: Dictionary) -> ReactionData:
	products = product_dict.duplicate()
	_update_reaction_name()
	return self


## Get all molecule names involved in this reaction
func get_all_molecules() -> Array[String]:
	var molecules: Array[String] = []
	for mol in substrates.keys():
		molecules.append(mol)
	for mol in products.keys():
		if mol not in molecules:
			molecules.append(mol)
	return molecules


## Get substrate names only
func get_substrate_names() -> Array[String]:
	var names: Array[String] = []
	for mol in substrates.keys():
		names.append(mol)
	return names


## Get product names only
func get_product_names() -> Array[String]:
	var names: Array[String] = []
	for mol in products.keys():
		names.append(mol)
	return names


## Check if molecule is involved in this reaction (either side)
func involves_molecule(mol_name: String) -> bool:
	return substrates.has(mol_name) or products.has(mol_name)


## Auto-generate reaction name from stoichiometry
func _update_reaction_name() -> void:
	if reaction_name == "" or reaction_name == reaction_id:
		reaction_name = get_summary()

#endregion

#region Reaction Type Checks

func is_source() -> bool:
	## Source reactions have no substrates (produce from nothing)
	return substrates.is_empty() and not products.is_empty()


func is_sink() -> bool:
	## Sink reactions have no products (consume to nothing)
	return not substrates.is_empty() and products.is_empty()


func is_valid() -> bool:
	## A reaction must have at least one substrate or product
	return not (substrates.is_empty() and products.is_empty())


func is_bimolecular_substrate() -> bool:
	## Two or more distinct substrate molecules
	return substrates.size() >= 2


func is_bimolecular_product() -> bool:
	## Two or more distinct product molecules
	return products.size() >= 2


func get_total_substrate_stoich() -> float:
	var total: float = 0.0
	for stoich in substrates.values():
		total += stoich
	return total


func get_total_product_stoich() -> float:
	var total: float = 0.0
	for stoich in products.values():
		total += stoich
	return total

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
	
	## Calculate reaction quotient Q = Π[products]^n / Π[substrates]^n
	var q: float = 1.0
	
	for product in products:
		if molecules.has(product):
			var mol = molecules[product]
			var conc = maxf(mol.concentration, 1e-9)
			q *= pow(conc, products[product])
		else:
			q *= pow(1e-9, products[product])
	
	for substrate in substrates:
		if molecules.has(substrate):
			var mol = molecules[substrate]
			var conc = maxf(mol.concentration, 1e-9)
			q /= pow(conc, substrates[substrate])
		else:
			q /= pow(1e-9, substrates[substrate])
	
	## ΔG = ΔG° + RT ln(Q)
	current_delta_g_actual = delta_g + R * temperature * log(maxf(q, 1e-30))
	return current_delta_g_actual

#endregion

#region Rate Calculations

## Calculate all rates for this reaction
func calculate_rates(molecules: Dictionary, enzymes: Dictionary, temp: float) -> void:
	if temp > 0:
		temperature = temp
	
	var enzyme_conc: float = 0.0
	if enzyme:
		enzyme_conc = enzyme.concentration
	else:
		## Find enzyme from dictionary if not already set
		for enz_id in enzymes:
			var enz = enzymes[enz_id]
			for rxn in enz.reactions:
				if rxn == self or rxn.reaction_id == reaction_id:
					enzyme_conc = enz.concentration
					enzyme = enz
					break
			if enzyme_conc > 0:
				break
	
	calculate_forward_rate(molecules, enzyme_conc)
	calculate_reverse_rate(molecules, enzyme_conc)
	calculate_energy_partition(get_net_rate())


## Forward rate using multi-substrate Michaelis-Menten
func calculate_forward_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	calculate_actual_delta_g(molecules)
	
	if substrates.is_empty():
		## Source reaction - constant production
		current_forward_rate = vmax * enzyme_conc * reaction_efficiency
		return current_forward_rate
	
	## Check thermodynamic favorability
	var dg_actual = current_delta_g_actual
	if dg_actual > 10.0:
		current_forward_rate = 0.0
		return 0.0
	
	## Multi-substrate rate: v = Vmax * [E] * Π(Si / (Km + Si))
	var rate = vmax * enzyme_conc
	var min_saturation: float = 1.0
	
	for substrate in substrates:
		if not molecules.has(substrate):
			current_forward_rate = 0.0
			return 0.0
		
		var mol: MoleculeData = molecules[substrate]
		var conc = mol.concentration
		if conc <= 0.0:
			current_forward_rate = 0.0
			return 0.0
		
		## Use limiting substrate approach (min saturation)
		var saturation = conc / (km + conc)
		min_saturation = minf(min_saturation, saturation)
	
	rate *= min_saturation * reaction_efficiency
	
	## Apply thermodynamic factor if near equilibrium
	if dg_actual > 0.0:
		rate *= exp(-dg_actual / (R * temperature))
	
	current_forward_rate = rate
	return current_forward_rate


## Reverse rate using Haldane relationship
func calculate_reverse_rate(molecules: Dictionary, enzyme_conc: float) -> float:
	if is_irreversible or products.is_empty():
		current_reverse_rate = 0.0
		return 0.0
	
	var dg_actual = current_delta_g_actual
	
	## Highly favorable forward - no reverse
	if dg_actual < -10.0:
		current_reverse_rate = 0.0
		return 0.0
	
	## Vmax_rev = Vmax_fwd / Keq (Haldane relationship)
	var vmax_reverse = vmax / maxf(current_keq, 0.01)
	var rate = vmax_reverse * enzyme_conc
	var min_saturation: float = 1.0
	
	for product in products:
		if not molecules.has(product):
			current_reverse_rate = 0.0
			return 0.0
		
		var mol: MoleculeData = molecules[product]
		var conc = mol.concentration
		if conc <= 0.0:
			current_reverse_rate = 0.0
			return 0.0
		
		var saturation = conc / (km + conc)
		min_saturation = minf(min_saturation, saturation)
	
	rate *= min_saturation * reaction_efficiency
	
	## Apply thermodynamic factor
	if dg_actual < 0.0:
		rate *= exp(dg_actual / (R * temperature))
	
	current_reverse_rate = rate
	return current_reverse_rate


func get_net_rate() -> float:
	return current_forward_rate - current_reverse_rate

#endregion

#region Energy Partition

## Calculate energy distribution between useful work and waste heat
func calculate_energy_partition(net_rate: float) -> void:
	if absf(net_rate) < 1e-12:
		current_useful_work = 0.0
		current_heat_generated = 0.0
		return
	
	## Total energy flux (kJ/s) = |ΔG_actual| * rate
	var total_energy = absf(current_delta_g_actual) * absf(net_rate)
	
	## Useful work = efficiency fraction of total
	current_useful_work = total_energy * reaction_efficiency
	
	## Heat = inefficiency fraction
	current_heat_generated = total_energy * (1.0 - reaction_efficiency)

#endregion

#region Display

func get_summary() -> String:
	var substrate_str = _format_side(substrates)
	var product_str = _format_side(products)
	
	if substrate_str == "":
		substrate_str = "∅"
	if product_str == "":
		product_str = "∅"
	
	var arrow = "→" if is_irreversible else "⇄"
	return "%s %s %s" % [substrate_str, arrow, product_str]


func _format_side(side: Dictionary) -> String:
	if side.is_empty():
		return ""
	
	var parts: Array[String] = []
	for mol_name in side:
		var stoich = side[mol_name]
		if absf(stoich - 1.0) < 0.01:
			parts.append(mol_name)
		else:
			parts.append("%.3f %s" % [stoich, mol_name])
	
	return " + ".join(parts)


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


func _to_string() -> String:
	return "ReactionData(%s: %s)" % [reaction_id, get_summary()]

#endregion
