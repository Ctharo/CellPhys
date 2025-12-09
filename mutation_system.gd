## Mutation System - Generates variations in enzymes, reactions, and molecules
## Orthogonal module: calculates mutations, does NOT apply them
## Selection pressure is handled by a separate Evolution module
class_name MutationSystem
extends RefCounted

#region Mutation Configuration

## Base rates (per second)
var enzyme_mutation_rate: float = 0.01      ## Chance per enzyme per second to mutate
var duplication_rate: float = 0.005         ## Chance to duplicate an enzyme
var novel_enzyme_rate: float = 0.002        ## Chance to create entirely new enzyme
var gene_mutation_rate: float = 0.008       ## Chance to mutate gene regulation

## Parameter drift ranges (multipliers applied to current values)
var kinetic_drift: float = 0.2              ## ±20% change to Vmax, Km
var efficiency_drift: float = 0.15          ## ±15% change to efficiency
var thermodynamic_drift: float = 0.1        ## ±10% change to delta_g
var halflife_drift: float = 0.25            ## ±25% change to half-life
var regulatory_drift: float = 0.2           ## ±20% change to Kd, fold-change

## Structural mutation parameters
var code_mutation_rate: float = 0.1         ## Chance per digit to mutate
var code_insertion_rate: float = 0.02       ## Chance to insert a digit
var code_deletion_rate: float = 0.02        ## Chance to delete a digit

## Limits
var max_enzymes: int = 20                   ## Don't create more than this
var max_molecules: int = 30                 ## Don't create more than this
var min_efficiency: float = 0.05            ## Minimum reaction efficiency
var max_efficiency: float = 0.98            ## Maximum reaction efficiency

#endregion

#region Mutation Result Structure

## Container for all proposed mutations this frame
class MutationResult:
	var timestamp: float = 0.0
	
	## EnzymeData modifications: {enz_id: {param: new_value}}
	var enzyme_modifications: Dictionary = {}
	
	## New enzymes to add (with their reactions)
	var new_enzymes: Array[Dictionary] = []  ## [{enzyme: EnzymeData, reaction: ReactionData, gene: GeneData}]
	
	## GeneData regulation modifications: {gene_id: {param: new_value}}
	var gene_modifications: Dictionary = {}
	
	## New molecules discovered through reactions
	var new_molecules: Array[MoleculeData] = []
	
	## Statistics
	var point_mutations: int = 0
	var duplications: int = 0
	var novel_creations: int = 0
	var regulatory_mutations: int = 0
	
	func is_empty() -> bool:
		return (enzyme_modifications.is_empty() and 
				new_enzymes.is_empty() and 
				gene_modifications.is_empty() and
				new_molecules.is_empty())
	
	func get_summary() -> String:
		var parts: Array[String] = []
		if point_mutations > 0:
			parts.append("%d point" % point_mutations)
		if duplications > 0:
			parts.append("%d dup" % duplications)
		if novel_creations > 0:
			parts.append("%d novel" % novel_creations)
		if regulatory_mutations > 0:
			parts.append("%d reg" % regulatory_mutations)
		if parts.is_empty():
			return "none"
		return ", ".join(parts)

#endregion

#region Main Calculation (Pure Function)

## Calculate mutations for this frame - does NOT modify any state
func calculate_mutations(snapshot: Dictionary, delta: float, current_time: float) -> MutationResult:
	var result = MutationResult.new()
	result.timestamp = current_time
	
	var enzymes: Dictionary = snapshot.enzymes
	var molecules: Dictionary = snapshot.molecules
	var genes: Dictionary = snapshot.genes
	
	## Skip if at capacity
	var at_enzyme_capacity = enzymes.size() >= max_enzymes
	var at_molecule_capacity = molecules.size() >= max_molecules
	
	## Process each enzyme for potential mutations
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		
		## Point mutations (parameter drift)
		if _roll(enzyme_mutation_rate * delta):
			var mods = _generate_enzyme_point_mutation(enzyme)
			if not mods.is_empty():
				result.enzyme_modifications[enz_id] = mods
				result.point_mutations += 1
		
		## Duplication (copy with variation)
		if not at_enzyme_capacity and _roll(duplication_rate * delta):
			var dup = _generate_enzyme_duplication(enzyme, enzymes, molecules)
			if not dup.is_empty():
				result.new_enzymes.append(dup)
				result.duplications += 1
	
	## Novel enzyme creation
	if not at_enzyme_capacity and _roll(novel_enzyme_rate * delta):
		var novel = _generate_novel_enzyme(enzymes, molecules)
		if not novel.is_empty():
			result.new_enzymes.append(novel)
			result.novel_creations += 1
	
	## GeneData regulation mutations
	for gene_id in genes:
		var gene: GeneData = genes[gene_id]
		if _roll(gene_mutation_rate * delta):
			var mods = _generate_gene_mutation(gene, molecules)
			if not mods.is_empty():
				result.gene_modifications[gene_id] = mods
				result.regulatory_mutations += 1
	
	## Check for new molecules from novel reactions
	if not at_molecule_capacity:
		for new_enz_data in result.new_enzymes:
			var new_mols = _check_for_new_molecules(new_enz_data.reaction, molecules)
			for mol in new_mols:
				result.new_molecules.append(mol)
	
	return result

#endregion

#region EnzymeData Point Mutations

## Generate small parameter changes to an existing enzyme
func _generate_enzyme_point_mutation(enzyme: EnzymeData) -> Dictionary:
	var mods: Dictionary = {}
	
	## Pick which parameter(s) to mutate
	var param_roll = randf()
	
	if param_roll < 0.3 and not enzyme.reactions.is_empty():
		## Mutate kinetic parameters
		var rxn = enzyme.reactions[0]
		mods["vmax"] = _drift(rxn.vmax, kinetic_drift, 0.1, 100.0)
		if randf() < 0.5:
			mods["km"] = _drift(rxn.km, kinetic_drift, 0.01, 10.0)
	
	elif param_roll < 0.6 and not enzyme.reactions.is_empty():
		## Mutate efficiency
		var rxn = enzyme.reactions[0]
		mods["efficiency"] = _drift(rxn.reaction_efficiency, efficiency_drift, min_efficiency, max_efficiency)
	
	elif param_roll < 0.8 and enzyme.is_degradable:
		## Mutate stability (half-life)
		mods["half_life"] = _drift(enzyme.half_life, halflife_drift, 30.0, 1800.0)
	
	else:
		## Mutate thermodynamics
		if not enzyme.reactions.is_empty():
			var rxn = enzyme.reactions[0]
			mods["delta_g"] = _drift(rxn.delta_g, thermodynamic_drift, -30.0, 10.0)
	
	return mods

#endregion

#region EnzymeData Duplication

## Create a copy of an enzyme with variations
func _generate_enzyme_duplication(source: EnzymeData, existing_enzymes: Dictionary, molecules: Dictionary) -> Dictionary:
	## Create new enzyme
	var new_id = _generate_unique_id("enz", existing_enzymes)
	var new_name = source.enzyme_name + "_v" + str(randi() % 100)
	var new_enzyme = EnzymeData.new(new_id, new_name)
	
	## Copy and mutate properties
	new_enzyme.concentration = source.concentration * randf_range(0.1, 0.5)  ## Start with less
	new_enzyme.initial_concentration = new_enzyme.concentration
	new_enzyme.half_life = _drift(source.half_life, halflife_drift * 2, 30.0, 1800.0)
	new_enzyme.is_degradable = source.is_degradable
	new_enzyme._update_degradation_rate()
	
	## Copy and mutate reaction
	if source.reactions.is_empty():
		return {}
	
	var source_rxn = source.reactions[0]
	var new_rxn = ReactionData.new(new_id + "_rxn", source_rxn.name + "_var")
	
	## Copy stoichiometry (maybe with substrate switching)
	new_rxn.substrates = source_rxn.substrates.duplicate()
	new_rxn.products = source_rxn.products.duplicate()
	
	## Small chance to switch a substrate or product
	if randf() < 0.3 and molecules.size() > 2:
		_maybe_switch_molecule(new_rxn, molecules)
	
	## Mutate kinetic parameters
	new_rxn.vmax = _drift(source_rxn.vmax, kinetic_drift * 1.5, 0.1, 100.0)
	new_rxn.km = _drift(source_rxn.km, kinetic_drift * 1.5, 0.01, 10.0)
	new_rxn.reaction_efficiency = _drift(source_rxn.reaction_efficiency, efficiency_drift * 1.5, min_efficiency, max_efficiency)
	new_rxn.delta_g = _drift(source_rxn.delta_g, thermodynamic_drift * 1.5, -30.0, 10.0)
	new_rxn.is_irreversible = source_rxn.is_irreversible
	
	new_enzyme.add_reaction(new_rxn)
	
	## Create gene for new enzyme
	var new_gene = GeneData.new(
		GeneData.generate_name_for_enzyme(new_name),
		new_id,
		randf_range(0.00005, 0.0002)  ## Low basal rate initially
	)
	
	return {
		"enzyme": new_enzyme,
		"reaction": new_rxn,
		"gene": new_gene,
		"source_id": source.id,
		"mutation_type": "duplication"
	}

#endregion

#region Novel EnzymeData Creation

## Generate a completely new enzyme with a new reaction
func _generate_novel_enzyme(existing_enzymes: Dictionary, molecules: Dictionary) -> Dictionary:
	if molecules.size() < 2:
		return {}
	
	var new_id = _generate_unique_id("enz", existing_enzymes)
	var new_name = _generate_enzyme_name()
	var new_enzyme = EnzymeData.new(new_id, new_name)
	
	## Random properties
	new_enzyme.concentration = randf_range(0.0001, 0.001)
	new_enzyme.initial_concentration = new_enzyme.concentration
	new_enzyme.half_life = randf_range(60.0, 600.0)
	new_enzyme.is_degradable = true
	new_enzyme._update_degradation_rate()
	
	## Create novel reaction
	var new_rxn = ReactionData.new(new_id + "_rxn", new_name + "_rxn")
	
	## Pick random substrate(s) and product(s)
	var mol_names = molecules.keys()
	mol_names.shuffle()
	
	## Simple reaction: A → B
	var substrate = mol_names[0]
	var product = mol_names[1] if mol_names.size() > 1 else mol_names[0]
	
	## Avoid identity reactions
	if substrate == product and mol_names.size() > 1:
		product = mol_names[1]
	
	new_rxn.substrates[substrate] = 1.0
	new_rxn.products[product] = 1.0
	
	## Random kinetics
	new_rxn.vmax = randf_range(1.0, 20.0)
	new_rxn.km = randf_range(0.1, 5.0)
	new_rxn.reaction_efficiency = randf_range(0.2, 0.7)
	new_rxn.delta_g = randf_range(-15.0, 5.0)
	new_rxn.is_irreversible = randf() < 0.3
	
	new_enzyme.add_reaction(new_rxn)
	
	## Create gene
	var new_gene = GeneData.new(
		GeneData.generate_name_for_enzyme(new_name),
		new_id,
		randf_range(0.00001, 0.0001)  ## Very low basal rate
	)
	
	## Maybe add regulation based on reaction
	if randf() < 0.4:
		## Product repression
		new_gene.add_repressor(product, randf_range(0.5, 3.0), randf_range(5.0, 15.0), randf_range(1.0, 2.0))
	
	if randf() < 0.3:
		## Substrate activation
		new_gene.add_activator(substrate, randf_range(0.5, 2.0), randf_range(3.0, 8.0), randf_range(1.0, 2.0))
	
	return {
		"enzyme": new_enzyme,
		"reaction": new_rxn,
		"gene": new_gene,
		"source_id": "",
		"mutation_type": "novel"
	}

#endregion

#region GeneData Mutations

## Generate mutations to gene regulatory elements
func _generate_gene_mutation(gene: GeneData, molecules: Dictionary) -> Dictionary:
	var mods: Dictionary = {}
	var mutation_type = randi() % 4
	
	match mutation_type:
		0:
			## Mutate basal rate
			mods["basal_rate"] = _drift(gene.basal_rate, regulatory_drift, 1e-6, 0.01)
		
		1:
			## Mutate existing activator
			if not gene.activators.is_empty():
				var idx = randi() % gene.activators.size()
				var act = gene.activators[idx]
				mods["activator_mod"] = {
					"index": idx,
					"kd": _drift(act.kd, regulatory_drift, 0.01, 20.0),
					"max_fold": _drift(act.max_fold_change, regulatory_drift, 1.5, 50.0),
					"hill": _drift(act.hill_coefficient, 0.1, 0.5, 4.0)
				}
		
		2:
			## Mutate existing repressor
			if not gene.repressors.is_empty():
				var idx = randi() % gene.repressors.size()
				var rep = gene.repressors[idx]
				mods["repressor_mod"] = {
					"index": idx,
					"kd": _drift(rep.kd, regulatory_drift, 0.01, 20.0),
					"max_fold": _drift(rep.max_fold_change, regulatory_drift, 1.5, 50.0),
					"hill": _drift(rep.hill_coefficient, 0.1, 0.5, 4.0)
				}
		
		3:
			## Add new regulatory element
			if molecules.size() > 0 and (gene.activators.size() + gene.repressors.size()) < 4:
				var mol_names = molecules.keys()
				var mol_name = mol_names[randi() % mol_names.size()]
				
				if randf() < 0.5:
					mods["new_activator"] = {
						"molecule": mol_name,
						"kd": randf_range(0.5, 5.0),
						"max_fold": randf_range(2.0, 10.0),
						"hill": randf_range(1.0, 2.0)
					}
				else:
					mods["new_repressor"] = {
						"molecule": mol_name,
						"kd": randf_range(0.5, 5.0),
						"max_fold": randf_range(2.0, 10.0),
						"hill": randf_range(1.0, 2.0)
					}
	
	return mods

#endregion

#region New MoleculeData Generation

## Check if a reaction introduces molecules not yet in the system
func _check_for_new_molecules(reaction: ReactionData, existing: Dictionary) -> Array[MoleculeData]:
	var new_mols: Array[MoleculeData] = []
	
	## Check products
	for product_name in reaction.products:
		if not existing.has(product_name):
			## Create new molecule with derived properties
			var new_mol = _generate_derived_molecule(product_name, reaction, existing)
			new_mols.append(new_mol)
	
	return new_mols

## Generate a new molecule based on reaction context
func _generate_derived_molecule(mol_name: String, reaction: ReactionData, existing: Dictionary) -> MoleculeData:
	var new_mol = MoleculeData.new(mol_name, 0.0)  ## Start at 0 concentration
	
	## Try to derive structural code from substrate
	if not reaction.substrates.is_empty():
		var substrate_name = reaction.substrates.keys()[0]
		if existing.has(substrate_name):
			var substrate: MoleculeData = existing[substrate_name]
			new_mol.structural_code = _mutate_structural_code(substrate.structural_code)
			## Energy roughly conserved with some loss
			new_mol.potential_energy = substrate.potential_energy * randf_range(0.7, 1.1)
	
	return new_mol

## Mutate a structural code to create variation
func _mutate_structural_code(original: Array[int]) -> Array[int]:
	var mutated: Array[int] = original.duplicate()
	
	for i in range(mutated.size()):
		if randf() < code_mutation_rate:
			## Point mutation
			mutated[i] = (mutated[i] + randi_range(-2, 2)) % 10
			if mutated[i] < 0:
				mutated[i] += 10
	
	## Insertion
	if randf() < code_insertion_rate and mutated.size() < 12:
		var pos = randi() % (mutated.size() + 1)
		mutated.insert(pos, randi() % 10)
	
	## Deletion
	if randf() < code_deletion_rate and mutated.size() > 3:
		var pos = randi() % mutated.size()
		mutated.remove_at(pos)
	
	return mutated

#endregion

#region Utility Functions

func _roll(probability: float) -> bool:
	return randf() < probability

func _drift(value: float, drift_amount: float, min_val: float, max_val: float) -> float:
	var multiplier = 1.0 + randf_range(-drift_amount, drift_amount)
	return clampf(value * multiplier, min_val, max_val)

func _generate_unique_id(prefix: String, existing: Dictionary) -> String:
	var id = "%s_%d" % [prefix, randi() % 10000]
	while existing.has(id):
		id = "%s_%d" % [prefix, randi() % 10000]
	return id

func _generate_enzyme_name() -> String:
	const PREFIXES = ["Neo", "Alt", "Iso", "Para", "Meta", "Pseudo", "Crypto"]
	const ROOTS = ["synthase", "kinase", "lyase", "mutase", "reductase", "oxidase", "transferase"]
	return PREFIXES[randi() % PREFIXES.size()] + ROOTS[randi() % ROOTS.size()]

func _maybe_switch_molecule(reaction: ReactionData, molecules: Dictionary) -> void:
	var mol_names = molecules.keys()
	if mol_names.is_empty():
		return
	
	var new_mol = mol_names[randi() % mol_names.size()]
	
	if randf() < 0.5 and not reaction.substrates.is_empty():
		## Switch substrate
		var old_sub = reaction.substrates.keys()[0]
		var stoich = reaction.substrates[old_sub]
		reaction.substrates.erase(old_sub)
		reaction.substrates[new_mol] = stoich
	elif not reaction.products.is_empty():
		## Switch product
		var old_prod = reaction.products.keys()[0]
		var stoich = reaction.products[old_prod]
		reaction.products.erase(old_prod)
		reaction.products[new_mol] = stoich

#endregion

#region Configuration

func set_mutation_rates(enzyme: float, duplication: float, novel: float, gene: float) -> void:
	enzyme_mutation_rate = enzyme
	duplication_rate = duplication
	novel_enzyme_rate = novel
	gene_mutation_rate = gene

func set_drift_amounts(kinetic: float, efficiency: float, thermo: float, halflife: float) -> void:
	kinetic_drift = kinetic
	efficiency_drift = efficiency
	thermodynamic_drift = thermo
	halflife_drift = halflife

#endregion
