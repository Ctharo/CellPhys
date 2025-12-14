## PathwayGenerator - Creates simulation entities from SimulationConfig
## Uses only Data-suffixed classes (no legacy RefCounted classes)
## Supports multi-reaction enzymes for more realistic metabolism
class_name PathwayGenerator
extends RefCounted

#region Generation

## Generate a complete pathway from configuration
static func generate_from_config(config: SimulationConfig) -> Dictionary:
	var result = {
		"molecules": {},      ## {name: MoleculeData}
		"enzymes": {},        ## {id: EnzymeData}
		"genes": {},          ## {id: GeneData}
		"reactions": []       ## Array[ReactionData]
	}
	
	## Validate config has minimum values
	if config.molecule_count < 2:
		config.molecule_count = 2
	if config.enzyme_count < 1:
		config.enzyme_count = 1
	
	match config.pathway_type:
		0:  ## Random
			_generate_random_pathway(config, result)
		1:  ## Linear
			_generate_linear_pathway(config, result)
		2:  ## Branched
			_generate_branched_pathway(config, result)
		3:  ## Cyclic
			_generate_cyclic_pathway(config, result)
		4:  ## Feedback
			_generate_feedback_pathway(config, result)
		_:  ## Default to random if unknown
			_generate_random_pathway(config, result)
	
	return result

#endregion

#region Pathway Generators

static func _generate_random_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Generate molecules
	var mol_names: Array[String] = []
	for i in range(config.molecule_count):
		var mol = _create_molecule(config, i)
		result.molecules[mol.molecule_name] = mol
		mol_names.append(mol.molecule_name)
	
	## Mark some as sources (locked, constant supply)
	for i in range(mini(config.source_count, mol_names.size())):
		var mol = result.molecules[mol_names[i]]
		mol.is_locked = true
		mol.concentration = config.default_molecule_concentration * 2.0
		mol.initial_concentration = mol.concentration
	
	## Generate enzymes with random reactions
	## Some enzymes may get multiple reactions
	var reaction_idx = 0
	for i in range(config.enzyme_count):
		var enz = _create_enzyme(config, i)
		
		## Determine number of reactions for this enzyme (usually 1, sometimes 2-3)
		var num_reactions = 1
		if randf() < config.branching_probability * 0.5:
			num_reactions = 2
		if randf() < config.branching_probability * 0.1:
			num_reactions = 3
		
		## Create reactions for this enzyme
		for r in range(num_reactions):
			## Pick random substrate(s) and product(s)
			var substrate_idx = randi() % mol_names.size()
			var product_idx = (substrate_idx + 1 + randi() % (mol_names.size() - 1)) % mol_names.size()
			
			## Make sure we don't create duplicate reactions
			var rxn = _create_reaction(config, reaction_idx, mol_names[substrate_idx], mol_names[product_idx])
			enz.add_reaction(rxn)
			result.reactions.append(rxn)
			reaction_idx += 1
		
		result.enzymes[enz.enzyme_id] = enz
		
		## Create gene if enabled
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene
	
	## Add sink reactions
	var sink_targets = mol_names.slice(maxi(0, mol_names.size() - config.sink_count), mol_names.size())
	_add_sinks(config, result, sink_targets)

static func _generate_linear_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Linear: M0 → M1 → M2 → ... → Mn
	var mol_names: Array[String] = []
	
	for i in range(config.molecule_count):
		var mol = _create_molecule(config, i)
		mol.molecule_name = "M%d" % i
		
		## First molecule is source
		if i == 0:
			mol.concentration = config.default_molecule_concentration * 2.0
			mol.is_locked = true
		else:
			mol.concentration = 0.1
		
		mol.initial_concentration = mol.concentration
		result.molecules[mol.molecule_name] = mol
		mol_names.append(mol.molecule_name)
	
	## Create enzymes for each step
	var steps = mini(config.enzyme_count, config.molecule_count - 1)
	for i in range(steps):
		var enz = _create_enzyme(config, i)
		enz.enzyme_name = "E%d" % (i + 1)
		
		var rxn = _create_reaction(config, i, mol_names[i], mol_names[i + 1])
		enz.add_reaction(rxn)
		result.reactions.append(rxn)
		
		## Optionally add a second reaction to some enzymes (bifunctional)
		if config.branching_probability > 0 and randf() < config.branching_probability * 0.3:
			## Add reverse or side reaction
			if i + 2 < mol_names.size() and randf() > 0.5:
				var rxn2 = _create_reaction(config, 100 + i, mol_names[i], mol_names[i + 2])
				rxn2.vmax *= 0.3  ## Lower rate for secondary reaction
				enz.add_reaction(rxn2)
				result.reactions.append(rxn2)
		
		result.enzymes[enz.enzyme_id] = enz
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene
	
	## Add sink for last molecule
	if mol_names.size() > 0:
		_add_sinks(config, result, [mol_names[-1]])

static func _generate_branched_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Branched: Source → Hub → BranchA, BranchB, ...
	## Ensure we have enough molecules
	var actual_mol_count = maxi(config.molecule_count, 3)
	
	## Source molecule
	var source = _create_molecule(config, 0)
	source.molecule_name = "Source"
	source.concentration = config.default_molecule_concentration * 2.0
	source.is_locked = true
	source.initial_concentration = source.concentration
	result.molecules["Source"] = source
	
	## Hub molecule
	var hub = _create_molecule(config, 1)
	hub.molecule_name = "Hub"
	hub.concentration = 1.0
	hub.initial_concentration = hub.concentration
	result.molecules["Hub"] = hub
	
	## Branch endpoints
	var branch_count = maxi(actual_mol_count - 2, 1)
	var branch_names: Array[String] = []
	for i in range(branch_count):
		var branch = _create_molecule(config, i + 2)
		branch.molecule_name = "Branch%s" % char(65 + i)  ## A, B, C, ...
		branch.concentration = 0.1
		branch.initial_concentration = branch.concentration
		result.molecules[branch.molecule_name] = branch
		branch_names.append(branch.molecule_name)
	
	## Source → Hub enzyme
	var enz_source = _create_enzyme(config, 0)
	enz_source.enzyme_name = "SourceEnzyme"
	enz_source.is_degradable = false
	var rxn_source = _create_reaction(config, 0, "Source", "Hub")
	enz_source.add_reaction(rxn_source)
	result.enzymes[enz_source.enzyme_id] = enz_source
	result.reactions.append(rxn_source)
	
	var all_mol_names: Array[String] = ["Source", "Hub"]
	all_mol_names.append_array(branch_names)
	
	if config.create_genes_for_enzymes:
		var gene_source = _create_gene(config, enz_source, all_mol_names)
		result.genes[gene_source.enzyme_id] = gene_source
	
	## Hub → Branch enzymes
	## Can create one enzyme per branch, or one multi-functional enzyme
	var use_multifunctional = config.enzyme_count < branch_count and branch_count > 1
	
	if use_multifunctional:
		## Single enzyme catalyzes multiple branches
		var enz = _create_enzyme(config, 1)
		enz.enzyme_name = "BranchingEnzyme"
		
		for i in range(branch_count):
			var rxn = _create_reaction(config, i + 1, "Hub", branch_names[i])
			enz.add_reaction(rxn)
			result.reactions.append(rxn)
		
		result.enzymes[enz.enzyme_id] = enz
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, all_mol_names)
			result.genes[gene.enzyme_id] = gene
	else:
		## Separate enzyme for each branch
		var branch_enzymes = mini(config.enzyme_count - 1, branch_count)
		branch_enzymes = maxi(branch_enzymes, 1)
		
		for i in range(branch_enzymes):
			var branch_idx = i % branch_names.size()
			var enz = _create_enzyme(config, i + 1)
			enz.enzyme_name = "Branch%sEnzyme" % char(65 + branch_idx)
			var rxn = _create_reaction(config, i + 1, "Hub", branch_names[branch_idx])
			enz.add_reaction(rxn)
			result.enzymes[enz.enzyme_id] = enz
			result.reactions.append(rxn)
			
			if config.create_genes_for_enzymes:
				var gene = _create_gene(config, enz, all_mol_names)
				## Add competition: other branches repress this one
				if config.include_feedback_loops and i > 0 and branch_names.size() > 1:
					var repressor_idx = (branch_idx - 1) % branch_names.size()
					gene.add_repressor(branch_names[repressor_idx], 
						_vary(config.default_kd, config.kd_variance),
						_vary(config.default_max_fold, config.max_fold_variance),
						_vary(config.default_hill_coefficient, config.hill_variance))
				result.genes[gene.enzyme_id] = gene
	
	_add_sinks(config, result, branch_names)

static func _generate_cyclic_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Cyclic: C0 → C1 → C2 → ... → C0 (closes loop)
	## Needs at least 3 molecules to form a cycle
	var actual_mol_count = maxi(config.molecule_count, 3)
	var mol_names: Array[String] = []
	
	for i in range(actual_mol_count):
		var mol = _create_molecule(config, i)
		mol.molecule_name = "C%d" % i
		## Distribute concentration evenly, with slight boost to first
		mol.concentration = config.default_molecule_concentration / actual_mol_count
		if i == 0:
			mol.concentration *= 1.5
		mol.initial_concentration = mol.concentration
		result.molecules[mol.molecule_name] = mol
		mol_names.append(mol.molecule_name)
	
	## Create enzymes connecting in a cycle
	var steps = mini(config.enzyme_count, actual_mol_count)
	steps = maxi(steps, actual_mol_count)  ## Need at least mol_count enzymes to close cycle
	
	for i in range(steps):
		var enz = _create_enzyme(config, i)
		enz.enzyme_name = "Cyc%d" % (i + 1)
		
		var substrate_idx = i % mol_names.size()
		var product_idx = (i + 1) % mol_names.size()
		var substrate = mol_names[substrate_idx]
		var product = mol_names[product_idx]
		
		var rxn = _create_reaction(config, i, substrate, product)
		enz.add_reaction(rxn)
		result.enzymes[enz.enzyme_id] = enz
		result.reactions.append(rxn)
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene
	
	## Cycles don't usually need explicit sinks - energy dissipates as heat
	## But add one if configured
	if config.sink_count > 0:
		_add_sinks(config, result, [mol_names[mol_names.size() / 2]])

static func _generate_feedback_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Feedback: Linear pathway with end-product inhibition of first step
	## First generate a linear pathway
	_generate_linear_pathway(config, result)
	
	## Then add feedback regulation
	if not config.include_feedback_loops or result.genes.is_empty():
		return
	
	## Get molecule names sorted
	var mol_names = result.molecules.keys()
	mol_names.sort()
	
	if mol_names.size() < 2:
		return
	
	## Find the end product (last non-source molecule)
	var end_product = ""
	for i in range(mol_names.size() - 1, -1, -1):
		var mol = result.molecules[mol_names[i]]
		if not mol.is_locked:
			end_product = mol_names[i]
			break
	
	if end_product == "":
		end_product = mol_names[-1]
	
	## Add feedback repression to first gene
	var gene_keys = result.genes.keys()
	if gene_keys.is_empty():
		return
	
	var first_gene = result.genes[gene_keys[0]] as GeneData
	
	## Strong feedback inhibition
	first_gene.add_repressor(end_product,
		_vary(config.default_kd, config.kd_variance),
		_vary(config.default_max_fold * 1.5, config.max_fold_variance),
		_vary(config.default_hill_coefficient + 0.5, config.hill_variance))
	
	## Optionally add feedforward activation on later enzymes
	if config.feedback_loop_count > 1 and gene_keys.size() > 1:
		var mid_gene = result.genes[gene_keys[gene_keys.size() / 2]] as GeneData
		mid_gene.add_activator(mol_names[0],  ## Activated by first substrate
			_vary(config.default_kd, config.kd_variance),
			_vary(config.default_max_fold * 0.5, config.max_fold_variance),
			_vary(config.default_hill_coefficient, config.hill_variance))

#endregion

#region Entity Creators

static func _create_molecule(config: SimulationConfig, index: int) -> MoleculeData:
	var mol = MoleculeData.new()
	mol.molecule_name = "Mol_%d" % index
	mol.concentration = _vary(config.default_molecule_concentration, config.molecule_concentration_variance)
	mol.initial_concentration = mol.concentration
	mol.potential_energy = _vary(config.default_potential_energy, config.potential_energy_variance)
	mol.structural_code = _generate_code(config.structural_code_length)
	mol.is_locked = false
	return mol

static func _create_enzyme(config: SimulationConfig, index: int) -> EnzymeData:
	var enz = EnzymeData.new("enz_%d" % index, "Enzyme_%d" % (index + 1))
	enz.concentration = _vary(config.default_enzyme_concentration, config.enzyme_concentration_variance)
	enz.initial_concentration = enz.concentration
	enz.is_degradable = randf() < config.degradable_fraction
	if enz.is_degradable:
		enz.half_life = _vary(config.default_half_life, config.default_half_life * 0.3)
	else:
		enz.half_life = 3600.0  ## 1 hour for "stable" enzymes
	enz.is_locked = false
	return enz

static func _create_reaction(config: SimulationConfig, index: int, 
		substrate: String, product: String) -> ReactionData:
	var rxn = ReactionData.new("rxn_%d" % index)
	rxn.reaction_name = "%s→%s" % [substrate, product]
	rxn.substrates[substrate] = 1.0
	rxn.products[product] = 1.0
	rxn.vmax = _vary(config.default_vmax, config.vmax_variance)
	rxn.km = _vary(config.default_km, config.km_variance)
	rxn.delta_g = _vary(config.default_delta_g, config.delta_g_variance)
	rxn.reaction_efficiency = clampf(
		_vary(config.default_efficiency, config.efficiency_variance), 0.1, 0.98)
	rxn.is_irreversible = randf() < config.irreversible_fraction
	return rxn

## Create a reaction with multiple substrates or products
static func _create_complex_reaction(config: SimulationConfig, index: int,
		substrates_dict: Dictionary, products_dict: Dictionary) -> ReactionData:
	var rxn = ReactionData.new("rxn_%d" % index)
	
	## Build reaction name
	var sub_names: Array[String] = []
	for s in substrates_dict:
		sub_names.append(s)
	var prod_names: Array[String] = []
	for p in products_dict:
		prod_names.append(p)
	rxn.reaction_name = "%s→%s" % [" + ".join(sub_names), " + ".join(prod_names)]
	
	rxn.substrates = substrates_dict.duplicate()
	rxn.products = products_dict.duplicate()
	rxn.vmax = _vary(config.default_vmax, config.vmax_variance)
	rxn.km = _vary(config.default_km, config.km_variance)
	rxn.delta_g = _vary(config.default_delta_g, config.delta_g_variance)
	rxn.reaction_efficiency = clampf(
		_vary(config.default_efficiency, config.efficiency_variance), 0.1, 0.98)
	rxn.is_irreversible = randf() < config.irreversible_fraction
	return rxn

static func _create_gene(config: SimulationConfig, enzyme: EnzymeData, 
		mol_names: Array) -> GeneData:
	var gene = GeneData.new("gene_%s" % enzyme.enzyme_id, enzyme.enzyme_id,
		_vary(config.default_basal_rate, config.basal_rate_variance))
	gene.gene_name = "gene_%s" % enzyme.enzyme_name.to_lower()
	gene.is_active = true
	
	## Maybe add regulation
	if randf() < config.regulation_probability and not mol_names.is_empty():
		var regulator = mol_names[randi() % mol_names.size()]
		
		if randf() < config.activator_vs_repressor:
			gene.add_activator(regulator,
				_vary(config.default_kd, config.kd_variance),
				_vary(config.default_max_fold, config.max_fold_variance),
				_vary(config.default_hill_coefficient, config.hill_variance))
		else:
			gene.add_repressor(regulator,
				_vary(config.default_kd, config.kd_variance),
				_vary(config.default_max_fold, config.max_fold_variance),
				_vary(config.default_hill_coefficient, config.hill_variance))
	
	return gene

static func _add_sinks(config: SimulationConfig, result: Dictionary, 
		target_molecules: Array) -> void:
	if config.sink_count <= 0 or target_molecules.is_empty():
		return
	
	var sink_targets = target_molecules.slice(0, mini(config.sink_count, target_molecules.size()))
	
	for i in range(sink_targets.size()):
		var target = sink_targets[i]
		
		## Skip if target doesn't exist in molecules
		if not result.molecules.has(target):
			continue
		
		var enz = EnzymeData.new("enz_sink_%d" % i, "Sink_%d" % (i + 1))
		enz.concentration = config.default_enzyme_concentration * 0.5
		enz.initial_concentration = enz.concentration
		enz.is_degradable = false
		
		var rxn = ReactionData.new("rxn_sink_%d" % i)
		rxn.reaction_name = "%s→∅" % target
		rxn.substrates[target] = 1.0
		## No products (sink)
		rxn.vmax = config.default_vmax * 0.5
		rxn.km = config.default_km
		rxn.delta_g = -10.0
		rxn.is_irreversible = true
		
		enz.add_reaction(rxn)
		result.enzymes[enz.enzyme_id] = enz
		result.reactions.append(rxn)
		
		if config.create_genes_for_enzymes:
			var gene = GeneData.new("gene_sink_%d" % i, enz.enzyme_id, 
				config.default_basal_rate * 0.5)
			gene.gene_name = "gene_sink_%d" % (i + 1)
			result.genes[gene.enzyme_id] = gene

#endregion

#region Utility

static func _vary(base: float, variance: float) -> float:
	if variance <= 0:
		return base
	return base + randf_range(-variance, variance)

static func _generate_code(length: int) -> Array[int]:
	var code: Array[int] = []
	for i in range(length):
		code.append(randi() % 10)
	return code

#endregion
