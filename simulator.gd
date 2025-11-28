## Core simulation engine with metabolic dynamics and protein expression
## Integrates molecules, enzymes, reactions, genes, and cell state
class_name Simulator
extends Node

signal simulation_updated(data: Dictionary)
signal molecule_added(molecule: Molecule)
signal enzyme_added(enzyme: Enzyme)
signal gene_added(gene: Gene)
signal enzyme_depleted(enzyme: Enzyme)

#region Configuration

@export var time_scale: float = 1.0
@export var paused: bool = false
@export var auto_generate: bool = true  ## Auto-generate random molecules/reactions on start

#endregion

#region Core Data

var molecules: Dictionary = {}  ## {name: Molecule}
var enzymes: Dictionary = {}    ## {id: Enzyme}
var reactions: Array[Reaction] = []
var genes: Dictionary = {}      ## {id: Gene}
var cell: Cell = null

#endregion

#region Simulation State

var simulation_time: float = 0.0
var total_enzyme_synthesized: float = 0.0
var total_enzyme_degraded: float = 0.0

#endregion

#region History (for charting)

var history_length: int = 500
var molecule_history: Dictionary = {}  ## {name: Array[float]}
var enzyme_history: Dictionary = {}    ## {id: Array[float]}
var time_history: Array[float] = []

#endregion

#region Initialization

func _ready() -> void:
	cell = Cell.new()
	if auto_generate:
		_generate_random_system()

func _generate_random_system() -> void:
	## Create a small metabolic network with interesting regulation
	var num_molecules = randi_range(4, 6)
	var num_enzymes = randi_range(3, 5)
	
	## Generate molecules
	var mol_names: Array[String] = []
	for i in range(num_molecules):
		var mol = Molecule.new(Molecule.generate_random_name(), randf_range(0.5, 5.0))
		## Ensure unique names
		while molecules.has(mol.name):
			mol.name = Molecule.generate_random_name()
		add_molecule(mol)
		mol_names.append(mol.name)
	
	## Generate enzymes with reactions and genes
	for i in range(num_enzymes):
		var enz_name = "Enz_%d" % (i + 1)
		var enzyme = Enzyme.new("enz_%d" % i, enz_name)
		
		## Create a reaction for this enzyme
		var rxn = Reaction.new("rxn_%d" % i)
		
		if i == 0:
			## First enzyme is a source
			rxn.products[mol_names[0]] = 1.0
			rxn.delta_g = randf_range(-15.0, -5.0)
			rxn.is_irreversible = true
			enzyme.is_degradable = false  ## Source enzymes don't degrade
		elif i == num_enzymes - 1:
			## Last enzyme is a sink
			rxn.substrates[mol_names[mol_names.size() - 1]] = 1.0
			rxn.delta_g = randf_range(-20.0, -10.0)
			rxn.is_irreversible = true
			enzyme.is_degradable = false  ## Sink enzymes don't degrade
		else:
			## Middle enzymes convert one molecule to another
			var sub_idx = (i - 1) % mol_names.size()
			var prod_idx = i % mol_names.size()
			if sub_idx == prod_idx:
				prod_idx = (prod_idx + 1) % mol_names.size()
			rxn.substrates[mol_names[sub_idx]] = 1.0
			rxn.products[mol_names[prod_idx]] = 1.0
			rxn.delta_g = randf_range(-10.0, 5.0)
		
		enzyme.add_reaction(rxn)
		add_enzyme(enzyme)
		reactions.append(rxn)
		
		## Create gene for this enzyme with some regulation
		var gene = create_gene_for_enzyme(enzyme)
		
		## Add regulatory elements (50% chance for each type)
		if not enzyme.is_source() and not enzyme.is_sink():
			## Product inhibition (negative feedback)
			if randf() > 0.5 and not rxn.products.is_empty():
				var product_name = rxn.products.keys()[0]
				gene.add_repressor(product_name, randf_range(1.0, 5.0), randf_range(5.0, 20.0), randf_range(1.0, 2.0))
			
			## Substrate activation (feedforward)
			if randf() > 0.5 and not rxn.substrates.is_empty():
				var substrate_name = rxn.substrates.keys()[0]
				gene.add_activator(substrate_name, randf_range(0.5, 2.0), randf_range(3.0, 10.0), randf_range(1.0, 2.0))

#endregion

#region Entity Management

func add_molecule(molecule: Molecule) -> void:
	molecules[molecule.name] = molecule
	molecule_history[molecule.name] = []
	molecule_added.emit(molecule)

func remove_molecule(name: String) -> void:
	molecules.erase(name)
	molecule_history.erase(name)

func add_enzyme(enzyme: Enzyme) -> void:
	enzymes[enzyme.id] = enzyme
	enzyme_history[enzyme.id] = []
	enzyme_added.emit(enzyme)

func remove_enzyme(id: String) -> void:
	## Also remove associated gene
	if genes.has(id):
		genes.erase(id)
	enzymes.erase(id)
	enzyme_history.erase(id)

func add_gene(gene: Gene) -> void:
	genes[gene.enzyme_id] = gene
	gene_added.emit(gene)

func create_gene_for_enzyme(enzyme: Enzyme, basal_rate: float = 0.0001) -> Gene:
	var gene = Gene.new(Gene.generate_name_for_enzyme(enzyme.name), enzyme.id, basal_rate)
	add_gene(gene)
	return gene

func get_all_reactions() -> Array[Reaction]:
	return reactions

#endregion

#region Simulation Loop

func _process(delta: float) -> void:
	if paused or not cell.is_alive:
		return
	
	var scaled_delta = delta * time_scale
	simulation_time += scaled_delta
	
	## 1. Update gene expression rates based on current molecule concentrations
	_update_gene_expression(scaled_delta)
	
	## 2. Apply enzyme degradation
	_apply_enzyme_degradation(scaled_delta)
	
	## 3. Apply enzyme synthesis from gene expression
	_apply_enzyme_synthesis(scaled_delta)
	
	## 4. Update reaction rates based on current enzyme/molecule concentrations
	_update_reaction_rates()
	
	## 5. Apply concentration changes from reactions
	_apply_reactions(scaled_delta)
	
	## 6. Update cell state
	cell.update(scaled_delta, reactions)
	
	## 7. Record history
	_record_history()
	
	## 8. Emit update signal
	simulation_updated.emit(get_simulation_data())

func _update_gene_expression(delta: float) -> void:
	for gene_id in genes:
		var gene: Gene = genes[gene_id]
		gene.calculate_expression_rate(molecules)

func _apply_enzyme_degradation(delta: float) -> void:
	for enz_id in enzymes:
		var enzyme: Enzyme = enzymes[enz_id]
		var degraded = enzyme.apply_degradation(delta)
		total_enzyme_degraded += degraded
		
		## Emit signal if enzyme is nearly depleted
		if enzyme.concentration < 1e-6 and enzyme.is_degradable:
			enzyme_depleted.emit(enzyme)

func _apply_enzyme_synthesis(delta: float) -> void:
	for gene_id in genes:
		var gene: Gene = genes[gene_id]
		if not enzymes.has(gene.enzyme_id):
			continue
		
		var enzyme: Enzyme = enzymes[gene.enzyme_id]
		if enzyme.is_locked:
			continue
		
		var synthesis_amount = gene.get_synthesis_amount(delta, molecules)
		enzyme.concentration += synthesis_amount
		total_enzyme_synthesized += synthesis_amount

func _update_reaction_rates() -> void:
	for enz_id in enzymes:
		var enzyme: Enzyme = enzymes[enz_id]
		enzyme.update_reaction_rates(molecules)

func _apply_reactions(delta: float) -> void:
	## Calculate concentration changes
	var changes: Dictionary = {}  ## {molecule_name: change}
	
	for reaction in reactions:
		var net_rate = reaction.get_net_rate()
		
		## Consume substrates
		for substrate in reaction.substrates:
			if not changes.has(substrate):
				changes[substrate] = 0.0
			changes[substrate] -= net_rate * reaction.substrates[substrate] * delta
		
		## Produce products
		for product in reaction.products:
			if not changes.has(product):
				changes[product] = 0.0
			changes[product] += net_rate * reaction.products[product] * delta
	
	## Apply changes
	for mol_name in changes:
		if not molecules.has(mol_name):
			continue
		var mol: Molecule = molecules[mol_name]
		if mol.is_locked:
			continue
		mol.concentration = max(0.0, mol.concentration + changes[mol_name])

func _record_history() -> void:
	time_history.append(simulation_time)
	if time_history.size() > history_length:
		time_history.pop_front()
	
	for mol_name in molecules:
		if not molecule_history.has(mol_name):
			molecule_history[mol_name] = []
		molecule_history[mol_name].append(molecules[mol_name].concentration)
		if molecule_history[mol_name].size() > history_length:
			molecule_history[mol_name].pop_front()
	
	for enz_id in enzymes:
		if not enzyme_history.has(enz_id):
			enzyme_history[enz_id] = []
		enzyme_history[enz_id].append(enzymes[enz_id].concentration)
		if enzyme_history[enz_id].size() > history_length:
			enzyme_history[enz_id].pop_front()

#endregion

#region Control

func set_paused(p: bool) -> void:
	paused = p

func set_time_scale(scale: float) -> void:
	time_scale = clampf(scale, 0.1, 100.0)

func reset() -> void:
	simulation_time = 0.0
	total_enzyme_synthesized = 0.0
	total_enzyme_degraded = 0.0
	
	## Reset molecules
	for mol_name in molecules:
		var mol: Molecule = molecules[mol_name]
		mol.concentration = mol.initial_concentration
	
	## Reset enzymes
	for enz_id in enzymes:
		var enzyme: Enzyme = enzymes[enz_id]
		enzyme.concentration = enzyme.initial_concentration
	
	## Reset cell
	cell = Cell.new()
	
	## Clear histories
	time_history.clear()
	for mol_name in molecule_history:
		molecule_history[mol_name].clear()
	for enz_id in enzyme_history:
		enzyme_history[enz_id].clear()

#endregion

#region Data Access

func get_simulation_data() -> Dictionary:
	return {
		"time": simulation_time,
		"molecules": molecules,
		"enzymes": enzymes,
		"reactions": reactions,
		"genes": genes,
		"cell": cell,
		"molecule_history": molecule_history,
		"enzyme_history": enzyme_history,
		"time_history": time_history,
		"protein_stats": get_protein_expression_stats()
	}

func get_protein_expression_stats() -> Dictionary:
	var stats = {
		"total_synthesized": total_enzyme_synthesized,
		"total_degraded": total_enzyme_degraded,
		"net_synthesis": total_enzyme_synthesized - total_enzyme_degraded,
		"active_genes": 0,
		"upregulated_genes": 0,
		"downregulated_genes": 0
	}
	
	for gene_id in genes:
		var gene: Gene = genes[gene_id]
		if gene.is_active:
			stats.active_genes += 1
		if gene.is_upregulated():
			stats.upregulated_genes += 1
		if gene.is_downregulated():
			stats.downregulated_genes += 1
	
	return stats

func get_gene_regulation_summary() -> String:
	var lines: Array[String] = []
	lines.append("=== Gene Regulation Summary ===")
	
	for gene_id in genes:
		var gene: Gene = genes[gene_id]
		var enzyme: Enzyme = enzymes.get(gene.enzyme_id)
		if not enzyme:
			continue
		
		var status = "●" if gene.is_active else "○"
		var fold = gene.get_fold_change()
		var arrow = "↑" if fold > 1.1 else ("↓" if fold < 0.9 else "→")
		
		lines.append("%s %s → %s: %.2fx %s [%.4f mM]" % [
			status, gene.name, enzyme.name, fold, arrow, enzyme.concentration
		])
		
		## Show regulation details
		if not gene.activators.is_empty():
			for act in gene.activators:
				var occ = act.get_occupancy(molecules) * 100.0
				lines.append("    + %s (%.0f%% occupied)" % [act.molecule_name, occ])
		
		if not gene.repressors.is_empty():
			for rep in gene.repressors:
				var occ = rep.get_occupancy(molecules) * 100.0
				lines.append("    - %s (%.0f%% occupied)" % [rep.molecule_name, occ])
	
	return "\n".join(lines)

#endregion
