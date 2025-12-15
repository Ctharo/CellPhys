## PathwayValidator - Validates pathway configurations for biochemical correctness
## Checks for issues like shared intermediates, orphan molecules, thermodynamic impossibilities
class_name PathwayValidator
extends RefCounted

#region Validation Results

class ValidationResult:
	var valid: bool = true
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var suggestions: Array[Dictionary] = []
	
	func add_error(category: String, message: String, context: Dictionary = {}) -> void:
		valid = false
		errors.append({
			"category": category,
			"message": message,
			"context": context
		})
	
	func add_warning(category: String, message: String, context: Dictionary = {}) -> void:
		warnings.append({
			"category": category,
			"message": message,
			"context": context
		})
	
	func add_suggestion(category: String, message: String, context: Dictionary = {}) -> void:
		suggestions.append({
			"category": category,
			"message": message,
			"context": context
		})
	
	func get_summary() -> String:
		var lines: Array[String] = []
		
		if valid:
			lines.append("✓ Pathway validation passed")
		else:
			lines.append("✗ Pathway validation failed with %d error(s)" % errors.size())
		
		if not errors.is_empty():
			lines.append("\nErrors:")
			for err in errors:
				lines.append("  • [%s] %s" % [err.category, err.message])
		
		if not warnings.is_empty():
			lines.append("\nWarnings:")
			for warn in warnings:
				lines.append("  • [%s] %s" % [warn.category, warn.message])
		
		if not suggestions.is_empty():
			lines.append("\nSuggestions:")
			for sug in suggestions:
				lines.append("  • [%s] %s" % [sug.category, sug.message])
		
		return "\n".join(lines)

#endregion

#region Full Pathway Validation

## Validate a complete pathway (molecules, enzymes, reactions)
static func validate_pathway(
	molecules: Dictionary,  ## {name: MoleculeData}
	enzymes: Dictionary,    ## {id: EnzymeData}
	reactions: Array = []   ## Optional standalone reactions
) -> ValidationResult:
	var result = ValidationResult.new()
	
	## 1. Validate multi-reaction enzymes
	_validate_enzyme_reactions(enzymes, result)
	
	## 2. Check for missing molecules
	_validate_molecule_references(molecules, enzymes, reactions, result)
	
	## 3. Check for orphan molecules (not involved in any reaction)
	_validate_orphan_molecules(molecules, enzymes, reactions, result)
	
	## 4. Check thermodynamic consistency
	_validate_thermodynamics(enzymes, reactions, result)
	
	## 5. Check for pathway connectivity
	_validate_connectivity(molecules, enzymes, reactions, result)
	
	## 6. Check for mass balance in cycles
	_validate_mass_balance(enzymes, reactions, result)
	
	return result


## Validate just enzyme configurations
static func validate_enzymes_only(enzymes: Dictionary) -> ValidationResult:
	var result = ValidationResult.new()
	_validate_enzyme_reactions(enzymes, result)
	return result

#endregion

#region Individual Validators

## Check that multi-reaction enzymes don't have shared molecules
static func _validate_enzyme_reactions(enzymes: Dictionary, result: ValidationResult) -> void:
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		
		if enzyme.reactions.size() < 2:
			continue  ## Single reaction enzymes are always valid
		
		var validation = enzyme.validate_all_reactions()
		
		if not validation.valid:
			for issue in validation.issues:
				result.add_error(
					"shared_intermediate",
					"Enzyme '%s' has reactions sharing molecules %s: '%s' and '%s'. " % [
						enzyme.enzyme_name,
						issue.shared_molecules,
						issue.summary_a,
						issue.summary_b
					] + "Consider if these are intermediate steps of a single reaction.",
					{
						"enzyme_id": enz_id,
						"reaction_a": issue.reaction_a,
						"reaction_b": issue.reaction_b,
						"shared": issue.shared_molecules
					}
				)
			
			## Add suggestion for overall reaction
			var suggestion = enzyme.suggest_split()
			if suggestion.has("suggested_overall_reaction"):
				result.add_suggestion(
					"combine_reactions",
					"Consider combining into single reaction: %s" % suggestion.suggested_overall_reaction,
					{"enzyme_id": enz_id}
				)


## Check that all referenced molecules exist
static func _validate_molecule_references(
	molecules: Dictionary, 
	enzymes: Dictionary,
	reactions: Array,
	result: ValidationResult
) -> void:
	## Collect all referenced molecules
	var referenced: Dictionary = {}  ## {mol_name: [reaction_ids]}
	
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		for rxn in enzyme.reactions:
			for mol in rxn.get_all_molecules():
				if not referenced.has(mol):
					referenced[mol] = []
				referenced[mol].append(rxn.reaction_id)
	
	for rxn in reactions:
		for mol in rxn.get_all_molecules():
			if not referenced.has(mol):
				referenced[mol] = []
			referenced[mol].append(rxn.reaction_id)
	
	## Check each referenced molecule exists
	for mol_name in referenced:
		if not molecules.has(mol_name):
			result.add_error(
				"missing_molecule",
				"Molecule '%s' is used in reactions but not defined" % mol_name,
				{
					"molecule": mol_name,
					"used_in": referenced[mol_name]
				}
			)


## Check for molecules not involved in any reaction
static func _validate_orphan_molecules(
	molecules: Dictionary,
	enzymes: Dictionary,
	reactions: Array,
	result: ValidationResult
) -> void:
	## Collect all molecules involved in reactions
	var involved: Dictionary = {}
	
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		for rxn in enzyme.reactions:
			for mol in rxn.get_all_molecules():
				involved[mol] = true
	
	for rxn in reactions:
		for mol in rxn.get_all_molecules():
			involved[mol] = true
	
	## Check for orphans
	for mol_name in molecules:
		if not involved.has(mol_name):
			result.add_warning(
				"orphan_molecule",
				"Molecule '%s' is not involved in any reaction" % mol_name,
				{"molecule": mol_name}
			)


## Check thermodynamic feasibility
static func _validate_thermodynamics(
	enzymes: Dictionary,
	reactions: Array,
	result: ValidationResult
) -> void:
	## Check individual reactions
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		for rxn in enzyme.reactions:
			_check_reaction_thermodynamics(rxn, result)
	
	for rxn in reactions:
		_check_reaction_thermodynamics(rxn, result)


static func _check_reaction_thermodynamics(rxn: ReactionData, result: ValidationResult) -> void:
	## Very endergonic reactions (ΔG° > 30) are suspicious
	if rxn.delta_g > 30.0:
		result.add_warning(
			"endergonic_reaction",
			"Reaction '%s' has very high ΔG° (%.1f kJ/mol), unlikely to proceed without coupling" % [
				rxn.get_summary(), rxn.delta_g
			],
			{"reaction_id": rxn.reaction_id, "delta_g": rxn.delta_g}
		)
	
	## Efficiency checks
	if rxn.reaction_efficiency > 0.95:
		result.add_warning(
			"high_efficiency",
			"Reaction '%s' has unrealistically high efficiency (%.0f%%)" % [
				rxn.get_summary(), rxn.reaction_efficiency * 100
			],
			{"reaction_id": rxn.reaction_id, "efficiency": rxn.reaction_efficiency}
		)


## Check pathway connectivity (can molecules flow through?)
static func _validate_connectivity(
	molecules: Dictionary,
	enzymes: Dictionary,
	reactions: Array,
	result: ValidationResult
) -> void:
	## Build graph of molecule connections
	var produced_by: Dictionary = {}  ## {mol: [reaction_ids]}
	var consumed_by: Dictionary = {}  ## {mol: [reaction_ids]}
	
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		for rxn in enzyme.reactions:
			for sub in rxn.substrates:
				if not consumed_by.has(sub):
					consumed_by[sub] = []
				consumed_by[sub].append(rxn.reaction_id)
			for prod in rxn.products:
				if not produced_by.has(prod):
					produced_by[prod] = []
				produced_by[prod].append(rxn.reaction_id)
	
	for rxn in reactions:
		for sub in rxn.substrates:
			if not consumed_by.has(sub):
				consumed_by[sub] = []
			consumed_by[sub].append(rxn.reaction_id)
		for prod in rxn.products:
			if not produced_by.has(prod):
				produced_by[prod] = []
			produced_by[prod].append(rxn.reaction_id)
	
	## Check for dead-end molecules (consumed but never produced, and not locked)
	for mol_name in molecules:
		var mol: MoleculeData = molecules[mol_name]
		var is_consumed = consumed_by.has(mol_name)
		var is_produced = produced_by.has(mol_name)
		
		if is_consumed and not is_produced and not mol.is_locked:
			result.add_warning(
				"dead_end_substrate",
				"Molecule '%s' is consumed but never produced (and not locked as source)" % mol_name,
				{"molecule": mol_name, "consumed_by": consumed_by.get(mol_name, [])}
			)
		
		if is_produced and not is_consumed:
			result.add_warning(
				"accumulating_product",
				"Molecule '%s' is produced but never consumed (will accumulate)" % mol_name,
				{"molecule": mol_name, "produced_by": produced_by.get(mol_name, [])}
			)


## Check for mass balance in reaction cycles
static func _validate_mass_balance(
	enzymes: Dictionary,
	reactions: Array,
	result: ValidationResult
) -> void:
	## This is a simplified check - full mass balance would require atomic composition
	## For now, just warn about cycles with unbalanced stoichiometry
	
	## Collect all reactions
	var all_reactions: Array[ReactionData] = []
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		for rxn in enzyme.reactions:
			all_reactions.append(rxn)
	for rxn in reactions:
		all_reactions.append(rxn)
	
	## Look for simple cycles (A→B→A) with different stoichiometries
	for rxn in all_reactions:
		for sub_name in rxn.substrates:
			for prod_name in rxn.products:
				## Find reverse reaction
				for other_rxn in all_reactions:
					if other_rxn == rxn:
						continue
					if other_rxn.substrates.has(prod_name) and other_rxn.products.has(sub_name):
						## Found a cycle, check stoichiometry
						var forward_sub = rxn.substrates[sub_name]
						var forward_prod = rxn.products[prod_name]
						var reverse_sub = other_rxn.substrates[prod_name]
						var reverse_prod = other_rxn.products[sub_name]
						
						## In a balanced cycle: forward_sub * reverse_prod == forward_prod * reverse_sub
						var balance = forward_sub * reverse_prod - forward_prod * reverse_sub
						if absf(balance) > 0.01:
							result.add_warning(
								"unbalanced_cycle",
								"Cycle %s ⇄ %s may have stoichiometric imbalance" % [sub_name, prod_name],
								{
									"molecule_a": sub_name,
									"molecule_b": prod_name,
									"reaction_forward": rxn.reaction_id,
									"reaction_reverse": other_rxn.reaction_id
								}
							)

#endregion

#region Utility Methods

## Quick validation - just checks for critical errors
static func quick_validate(molecules: Dictionary, enzymes: Dictionary) -> bool:
	var result = validate_enzymes_only(enzymes)
	return result.valid


## Validate and print report
static func validate_and_report(
	molecules: Dictionary,
	enzymes: Dictionary,
	reactions: Array = []
) -> bool:
	var result = validate_pathway(molecules, enzymes, reactions)
	print(result.get_summary())
	return result.valid

#endregion
