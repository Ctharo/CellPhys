## PathwayGenerator - Creates simulation entities from SimulationConfig
## Uses only Data-suffixed classes (no legacy RefCounted classes)
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
	for i in range(config.enzyme_count):
		var enz = _create_enzyme(config, i)
		
		## Pick random substrate(s) and product(s)
		var substrate_idx = randi() % mol_names.size()
		var product_idx = (substrate_idx + 1 + randi() % (mol_names.size() - 1)) % mol_names.size()
		
		var rxn = _create_reaction(config, i, mol_names[substrate_idx], mol_names[product_idx])
		enz.add_reaction(rxn)
		result.reactions.append(rxn)
		
		result.enzymes[enz.enzyme_id] = enz
		
		## Create gene if enabled
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene
	
	## Add sink reactions
	_add_sinks(config, result, mol_names)

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
		
		result.enzymes[enz.enzyme_id] = enz
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene
	
	## Add sink for last molecule
	_add_sinks(config, result, [mol_names[-1]])

static func _generate_branched_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Branched: Source → Hub → BranchA, BranchB, ...
	
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
	var branch_count = config.molecule_count - 2
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
	
	if config.create_genes_for_enzymes:
		var gene_source = _create_gene(config, enz_source, ["Source", "Hub"] + branch_names)
		result.genes[gene_source.enzyme_id] = gene_source
	
	## Hub → Branch enzymes
	var branch_enzymes = mini(config.enzyme_count - 1, branch_count)
	for i in range(branch_enzymes):
		var enz = _create_enzyme(config, i + 1)
		enz.enzyme_name = "Branch%sEnzyme" % char(65 + i)
		var rxn = _create_reaction(config, i + 1, "Hub", branch_names[i])
		enz.add_reaction(rxn)
		result.enzymes[enz.enzyme_id] = enz
		result.reactions.append(rxn)
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, ["Hub"] + branch_names)
			## Add competition: other branches repress this one
			if config.include_feedback_loops and i > 0:
				gene.add_repressor(branch_names[i - 1], 
					_vary(config.default_kd, config.kd_variance),
					_vary(config.default_max_fold, config.max_fold_variance),
					_vary(config.default_hill_coefficient, config.hill_variance))
			result.genes[gene.enzyme_id] = gene
	
	_add_sinks(config, result, branch_names)

static func _generate_cyclic_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Cyclic: M0 → M1 → M2 → ... → M0 (closes loop)
	var mol_names: Array[String] = []
	
	for i in range(config.molecule_count):
		var mol = _create_molecule(config, i)
		mol.molecule_name = "C%d" % i
		mol.concentration = config.default_molecule_concentration / config.molecule_count
		mol.initial_concentration = mol.concentration
		result.molecules[mol.molecule_name] = mol
		mol_names.append(mol.molecule_name)
	
	## Create enzymes connecting in a cycle
	var steps = mini(config.enzyme_count, config.molecule_count)
	for i in range(steps):
		var enz = _create_enzyme(config, i)
		enz.enzyme_name = "Cyc%d" % (i + 1)
		
		var substrate = mol_names[i]
		var product = mol_names[(i + 1) % mol_names.size()]
		
		var rxn = _create_reaction(config, i, substrate, product)
		enz.add_reaction(rxn)
		result.enzymes[enz.enzyme_id] = enz
		result.reactions.append(rxn)
		
		if config.create_genes_for_enzymes:
			var gene = _create_gene(config, enz, mol_names)
			result.genes[gene.enzyme_id] = gene

static func _generate_feedback_pathway(config: SimulationConfig, result: Dictionary) -> void:
	## Feedback: Linear with end-product inhibition of first step
	_generate_linear_pathway(config, result)
	
	if not config.include_feedback_loops or result.genes.is_empty():
		return
	
	## Get molecule names
	var mol_names = result.molecules.keys()
	mol_names.sort()
	
	if mol_names.size() < 2:
		return
	
	var end_product = mol_names[-1]
	
	## Add feedback regulation to first gene
	var first_gene_id = result.genes.keys()[0]
	var first_gene = result.genes[first_gene_id] as GeneData
	
	first_gene.add_repressor(end_product,
		_vary(config.default_kd, config.kd_variance),
		_vary(config.default_max_fold * 1.5, config.max_fold_variance),  ## Stronger inhibition
		_vary(config.default_hill_coefficient + 0.5, config.hill_variance))

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
		_vary(config.default_efficiency, config.efficiency_variance), 0.1, 1.0)
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
	return base + randf_range(-variance, variance)

static func _generate_code(length: int) -> Array[int]:
	var code: Array[int] = []
	for i in range(length):
		code.append(randi() % 10)
	return code

#endregion
