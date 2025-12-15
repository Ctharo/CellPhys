## Enzyme resource - catalyzes one or more reactions with degradation kinetics
## Multi-reaction enzymes must have non-overlapping molecule sets (no shared intermediates)
## Can be saved as .tres for enzyme libraries
class_name EnzymeData
extends Resource

const LN2: float = 0.693147  ## ln(2) for half-life calculations

#region Exported Properties

@export var enzyme_id: String = ""
@export var enzyme_name: String = ""

@export_group("Concentration")
@export var concentration: float = 0.005:
	set(value):
		concentration = maxf(0.0, value)
		emit_changed()

@export var initial_concentration: float = 0.005
@export var is_locked: bool = false  ## If true, concentration won't change during simulation

@export_group("Degradation")
@export var half_life: float = 300.0  ## Half-life in seconds (default ~5 min)
@export var is_degradable: bool = true  ## Source/sink enzymes may be non-degradable

@export_group("Reactions")
@export var reactions: Array[ReactionData] = []

#endregion

#region Runtime State

var degradation_rate: float = 0.0  ## Calculated from half_life: k = ln(2) / t_half

#endregion

#region Initialization

func _init(p_id: String = "", p_name: String = "") -> void:
	if p_id != "":
		enzyme_id = p_id
		enzyme_name = p_name if p_name != "" else p_id
		concentration = randf_range(0.001, 0.01)
		initial_concentration = concentration
		half_life = randf_range(120.0, 600.0)
		_update_degradation_rate()


func _update_degradation_rate() -> void:
	if half_life > 0.0:
		degradation_rate = LN2 / half_life
	else:
		degradation_rate = 0.0


## Create a runtime instance from this resource template
func create_instance() -> EnzymeData:
	var instance = duplicate(false) as EnzymeData
	instance.reactions = [] as Array[ReactionData]
	for rxn in reactions:
		var rxn_instance = rxn.create_instance()
		rxn_instance.enzyme = instance
		instance.reactions.append(rxn_instance)
	instance.concentration = initial_concentration
	instance._update_degradation_rate()
	return instance


## Reset to initial state
func reset() -> void:
	concentration = initial_concentration
	_update_degradation_rate()
	for rxn in reactions:
		rxn.reset()

#endregion

#region Reaction Management

## Add a reaction with optional validation
## Returns true if added successfully, false if validation failed
func add_reaction(reaction: ReactionData, validate: bool = false) -> bool:
	if validate and not reactions.is_empty():
		var validation = validate_new_reaction(reaction)
		if not validation.valid:
			push_warning("EnzymeData.add_reaction: %s" % validation.reason)
			return false
	
	reaction.enzyme = self
	reactions.append(reaction)
	emit_changed()
	return true


## Add reaction with strict validation - fails if reactions share molecules
func add_reaction_strict(reaction: ReactionData) -> bool:
	return add_reaction(reaction, true)


## Validate if a new reaction can be added without sharing molecules
func validate_new_reaction(new_reaction: ReactionData) -> Dictionary:
	var new_molecules = new_reaction.get_all_molecules()
	
	for existing_rxn in reactions:
		var existing_molecules = existing_rxn.get_all_molecules()
		var shared = _get_shared_molecules(new_molecules, existing_molecules)
		
		if not shared.is_empty():
			return {
				"valid": false,
				"reason": "Reaction '%s' shares molecules %s with existing reaction '%s'. " % [
					new_reaction.get_summary(),
					shared,
					existing_rxn.get_summary()
				] + "This suggests intermediate steps rather than independent reactions.",
				"shared_molecules": shared,
				"conflicting_reaction": existing_rxn.reaction_id
			}
	
	return {"valid": true, "reason": ""}


## Validate all current reactions for molecule overlap
func validate_all_reactions() -> Dictionary:
	var issues: Array[Dictionary] = []
	
	for i in range(reactions.size()):
		var rxn_i = reactions[i]
		var mols_i = rxn_i.get_all_molecules()
		
		for j in range(i + 1, reactions.size()):
			var rxn_j = reactions[j]
			var mols_j = rxn_j.get_all_molecules()
			var shared = _get_shared_molecules(mols_i, mols_j)
			
			if not shared.is_empty():
				issues.append({
					"reaction_a": rxn_i.reaction_id,
					"reaction_b": rxn_j.reaction_id,
					"shared_molecules": shared,
					"summary_a": rxn_i.get_summary(),
					"summary_b": rxn_j.get_summary()
				})
	
	return {
		"valid": issues.is_empty(),
		"issue_count": issues.size(),
		"issues": issues
	}


## Get molecules shared between two arrays
func _get_shared_molecules(mols_a: Array, mols_b: Array) -> Array[String]:
	var shared: Array[String] = []
	for mol in mols_a:
		if mol in mols_b:
			shared.append(mol)
	return shared


## Remove a reaction
func remove_reaction(reaction: ReactionData) -> void:
	reaction.enzyme = null
	reactions.erase(reaction)
	emit_changed()


## Remove reaction by index
func remove_reaction_at(index: int) -> void:
	if index >= 0 and index < reactions.size():
		reactions[index].enzyme = null
		reactions.remove_at(index)
		emit_changed()


## Clear all reactions
func clear_reactions() -> void:
	for rxn in reactions:
		rxn.enzyme = null
	reactions.clear()
	emit_changed()


## Get reaction by ID
func get_reaction(reaction_id: String) -> ReactionData:
	for rxn in reactions:
		if rxn.reaction_id == reaction_id:
			return rxn
	return null


## Get all molecules this enzyme interacts with
func get_all_molecules() -> Array[String]:
	var molecules: Array[String] = []
	for rxn in reactions:
		for mol in rxn.get_all_molecules():
			if mol not in molecules:
				molecules.append(mol)
	return molecules


## Get substrate molecules only (across all reactions)
func get_all_substrates() -> Array[String]:
	var substrates: Array[String] = []
	for rxn in reactions:
		for mol in rxn.get_substrate_names():
			if mol not in substrates:
				substrates.append(mol)
	return substrates


## Get product molecules only (across all reactions)
func get_all_products() -> Array[String]:
	var products: Array[String] = []
	for rxn in reactions:
		for mol in rxn.get_product_names():
			if mol not in products:
				products.append(mol)
	return products

#endregion

#region Reaction Analysis

## Suggest if reactions should be split into separate enzymes
func suggest_split() -> Dictionary:
	var validation = validate_all_reactions()
	
	if validation.valid:
		return {
			"should_split": false,
			"reason": "All reactions are independent (no shared molecules)"
		}
	
	## Build suggestion for splitting
	var groups: Array[Array] = []
	var assigned: Array[int] = []
	
	for i in range(reactions.size()):
		if i in assigned:
			continue
		
		var group: Array = [i]
		var group_mols = reactions[i].get_all_molecules()
		assigned.append(i)
		
		## Find all reactions that share molecules with this group
		var changed = true
		while changed:
			changed = false
			for j in range(reactions.size()):
				if j in assigned:
					continue
				var j_mols = reactions[j].get_all_molecules()
				if not _get_shared_molecules(group_mols, j_mols).is_empty():
					group.append(j)
					assigned.append(j)
					for mol in j_mols:
						if mol not in group_mols:
							group_mols.append(mol)
					changed = true
		
		groups.append(group)
	
	## If we have multiple groups, no splitting needed (they're independent)
	## If single group with overlaps, these are likely intermediates
	if groups.size() == 1 and not validation.valid:
		return {
			"should_split": true,
			"reason": "Reactions share molecules, suggesting they describe steps of a single overall reaction",
			"shared_issues": validation.issues,
			"suggested_overall_reaction": _suggest_overall_reaction()
		}
	
	return {
		"should_split": false,
		"reason": "Reactions form independent groups",
		"groups": groups
	}


## Attempt to determine the overall reaction from intermediate steps
func _suggest_overall_reaction() -> String:
	if reactions.size() < 2:
		return ""
	
	## Collect all substrates that aren't products of other reactions
	## and all products that aren't substrates of other reactions
	var all_substrates: Dictionary = {}
	var all_products: Dictionary = {}
	
	for rxn in reactions:
		for sub in rxn.substrates:
			if not all_substrates.has(sub):
				all_substrates[sub] = 0.0
			all_substrates[sub] += rxn.substrates[sub]
		for prod in rxn.products:
			if not all_products.has(prod):
				all_products[prod] = 0.0
			all_products[prod] += rxn.products[prod]
	
	## Net substrates (consumed but not produced)
	var net_substrates: Dictionary = {}
	for sub in all_substrates:
		var produced = all_products.get(sub, 0.0)
		var consumed = all_substrates[sub]
		if consumed > produced:
			net_substrates[sub] = consumed - produced
	
	## Net products (produced but not consumed)
	var net_products: Dictionary = {}
	for prod in all_products:
		var consumed = all_substrates.get(prod, 0.0)
		var produced = all_products[prod]
		if produced > consumed:
			net_products[prod] = produced - consumed
	
	## Format as reaction
	var sub_parts: Array[String] = []
	for mol in net_substrates:
		var stoich = net_substrates[mol]
		if absf(stoich - 1.0) < 0.01:
			sub_parts.append(mol)
		else:
			sub_parts.append("%.3g %s" % [stoich, mol])
	
	var prod_parts: Array[String] = []
	for mol in net_products:
		var stoich = net_products[mol]
		if absf(stoich - 1.0) < 0.01:
			prod_parts.append(mol)
		else:
			prod_parts.append("%.3g %s" % [stoich, mol])
	
	var sub_str = " + ".join(sub_parts) if not sub_parts.is_empty() else "∅"
	var prod_str = " + ".join(prod_parts) if not prod_parts.is_empty() else "∅"
	
	return "%s → %s" % [sub_str, prod_str]

#endregion

#region Degradation

## Apply degradation for this timestep, returns amount degraded
func apply_degradation(delta: float) -> float:
	if is_locked or not is_degradable or concentration <= 0.0:
		return 0.0
	
	## First-order kinetics: d[E] = -k * [E] * dt
	var amount_degraded = degradation_rate * concentration * delta
	concentration = maxf(0.0, concentration - amount_degraded)
	return amount_degraded

#endregion

#region Type Checking

func is_source() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_source():
			return false
	return true


func is_sink() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_sink():
			return false
	return true


func is_multi_reaction() -> bool:
	return reactions.size() > 1


func has_valid_reactions() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_valid():
			return false
	return true

#endregion

#region Rate Updates

## Update rates for all reactions this enzyme catalyzes
func update_reaction_rates(molecules: Dictionary) -> void:
	for reaction in reactions:
		reaction.calculate_forward_rate(molecules, concentration)
		reaction.calculate_reverse_rate(molecules, concentration)
		reaction.calculate_energy_partition(reaction.get_net_rate())

#endregion

#region Display

func get_reactions_summary() -> String:
	if reactions.is_empty():
		return "(no reactions)"
	
	var summaries: Array[String] = []
	for rxn in reactions:
		summaries.append(rxn.get_summary())
	return "\n".join(summaries)


func get_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	return "%s [%.4f mM] - %d reaction(s)%s" % [enzyme_name, concentration, reactions.size(), lock_str]


func get_detailed_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	var degrade_str = "t½=%.0fs" % half_life if is_degradable else "stable"
	var validation = validate_all_reactions()
	var valid_str = "" if validation.valid else " ⚠️"
	return "%s [%.4f mM] (%s) - %d reaction(s)%s%s" % [
		enzyme_name, concentration, degrade_str, reactions.size(), lock_str, valid_str
	]


func _to_string() -> String:
	return "EnzymeData(%s: %s, %d reactions)" % [enzyme_id, enzyme_name, reactions.size()]

#endregion
