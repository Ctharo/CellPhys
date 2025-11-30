## Core simulation engine with DECOUPLED subsystems
## Each system is orthogonal - can be disabled without breaking others
## Systems communicate via signals, not direct mutation
class_name Simulator
extends Node

#region Signals - Inter-system Communication

signal simulation_updated(data: Dictionary)

## Entity lifecycle signals
signal molecule_added(molecule: Molecule)
signal enzyme_added(enzyme: Enzyme)
signal gene_added(gene: Gene)
signal enzyme_depleted(enzyme: Enzyme)

## Category lock signals (for reactive UI)
signal molecules_lock_changed(locked: bool)
signal enzymes_lock_changed(locked: bool)
signal genes_lock_changed(locked: bool)
signal reactions_lock_changed(locked: bool)
signal mutations_lock_changed(locked: bool)
signal evolution_lock_changed(locked: bool)

## Subsystem output signals - these are the ONLY way systems affect each other
signal concentration_deltas_calculated(deltas: Dictionary)
signal enzyme_synthesis_calculated(synthesis: Dictionary)
signal enzyme_degradation_calculated(degradation: Dictionary)
signal mutations_generated(result: MutationSystem.MutationResult)
signal selection_calculated(result: EvolutionSystem.SelectionResult)

## Mutation event signals (for UI/logging)
signal mutation_applied(mutation_type: String, details: Dictionary)
signal selection_applied(selection_type: String, details: Dictionary)

#endregion

#region Configuration

@export var time_scale: float = 1.0
@export var paused: bool = false
@export var auto_generate: bool = true

#endregion

#region Category Locks - Makes Systems Independent

var _lock_molecules: bool = false
var _lock_enzymes: bool = false
var _lock_genes: bool = false
var _lock_reactions: bool = false
var _lock_mutations: bool = false

## When locked, molecule concentrations won't change (ignores reaction deltas)
var lock_molecules: bool:
	get: return _lock_molecules
	set(value):
		if _lock_molecules != value:
			_lock_molecules = value
			molecules_lock_changed.emit(value)

## When locked, enzyme concentrations won't change (ignores synthesis/degradation)
var lock_enzymes: bool:
	get: return _lock_enzymes
	set(value):
		if _lock_enzymes != value:
			_lock_enzymes = value
			enzymes_lock_changed.emit(value)

## When locked, genes won't calculate synthesis (synthesis dict will be empty)
var lock_genes: bool:
	get: return _lock_genes
	set(value):
		if _lock_genes != value:
			_lock_genes = value
			genes_lock_changed.emit(value)

## When locked, reactions won't calculate deltas (deltas dict will be empty)
var lock_reactions: bool:
	get: return _lock_reactions
	set(value):
		if _lock_reactions != value:
			_lock_reactions = value
			reactions_lock_changed.emit(value)

## When locked, no mutations will be generated or applied
var lock_mutations: bool:
	get: return _lock_mutations
	set(value):
		if _lock_mutations != value:
			_lock_mutations = value
			mutations_lock_changed.emit(value)

var _lock_evolution: bool = false

## When locked, no selection pressure will be applied
var lock_evolution: bool:
	get: return _lock_evolution
	set(value):
		if _lock_evolution != value:
			_lock_evolution = value
			evolution_lock_changed.emit(value)

#endregion

#region Core Data - Shared State (Read-Only for subsystems)

var molecules: Dictionary = {}  ## {name: Molecule}
var enzymes: Dictionary = {}    ## {id: Enzyme}
var reactions: Array[Reaction] = []
var genes: Dictionary = {}      ## {id: Gene}
var cell: Cell = null

#endregion

#region Subsystems

var mutation_system: MutationSystem = null
var evolution_system: EvolutionSystem = null

#endregion

#region Simulation State

var simulation_time: float = 0.0
var total_enzyme_synthesized: float = 0.0
var total_enzyme_degraded: float = 0.0

## Mutation statistics
var total_mutations: int = 0
var mutation_history: Array[Dictionary] = []  ## Recent mutation events
var max_mutation_history: int = 50

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
	mutation_system = MutationSystem.new()
	evolution_system = EvolutionSystem.new()
	
	if auto_generate:
		_generate_random_system()

func _generate_random_system() -> void:
	var num_molecules = randi_range(4, 6)
	var num_enzymes = randi_range(3, 5)
	
	## Generate molecules
	var mol_names: Array[String] = []
	for i in range(num_molecules):
		var mol = Molecule.new(Molecule.generate_random_name(), randf_range(0.5, 5.0))
		while molecules.has(mol.name):
			mol.name = Molecule.generate_random_name()
		add_molecule(mol)
		mol_names.append(mol.name)
	
	## Generate enzymes with reactions and genes
	for i in range(num_enzymes):
		var enz_name = "Enz_%d" % (i + 1)
		var enzyme = Enzyme.new("enz_%d" % i, enz_name)
		
		var rxn = Reaction.new("rxn_%d" % i)
		
		if i == 0:
			rxn.products[mol_names[0]] = 1.0
			rxn.delta_g = randf_range(-15.0, -5.0)
			rxn.is_irreversible = true
			enzyme.is_degradable = false
		elif i == num_enzymes - 1:
			rxn.substrates[mol_names[mol_names.size() - 1]] = 1.0
			rxn.delta_g = randf_range(-20.0, -10.0)
			rxn.is_irreversible = true
			enzyme.is_degradable = false
		else:
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
		
		var gene = create_gene_for_enzyme(enzyme)
		
		if not enzyme.is_source() and not enzyme.is_sink():
			if randf() > 0.5 and not rxn.products.is_empty():
				var product_name = rxn.products.keys()[0]
				gene.add_repressor(product_name, randf_range(1.0, 5.0), randf_range(5.0, 20.0), randf_range(1.0, 2.0))
			
			if randf() > 0.5 and not rxn.substrates.is_empty():
				var substrate_name = rxn.substrates.keys()[0]
				gene.add_activator(substrate_name, randf_range(0.5, 2.0), randf_range(3.0, 10.0), randf_range(1.0, 2.0))

#endregion

#region Entity Management

func add_molecule(molecule: Molecule) -> void:
	molecules[molecule.name] = molecule
	molecule_history[molecule.name] = []
	molecule_added.emit(molecule)

func remove_molecule(mol_name: String) -> void:
	molecules.erase(mol_name)
	molecule_history.erase(mol_name)

func add_enzyme(enzyme: Enzyme) -> void:
	enzymes[enzyme.id] = enzyme
	enzyme_history[enzyme.id] = []
	enzyme_added.emit(enzyme)

func remove_enzyme(id: String) -> void:
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

#region Simulation Loop - Orchestrates Independent Subsystems

func _process(delta: float) -> void:
	if paused or not cell.is_alive:
		return
	
	var scaled_delta = delta * time_scale
	simulation_time += scaled_delta
	
	## Take a SNAPSHOT of current state for subsystems to read
	var state_snapshot = _create_state_snapshot()
	
	## ═══════════════════════════════════════════════════════════════════
	## PHASE 1: Calculate (each system reads snapshot, outputs deltas)
	## Systems are INDEPENDENT - they don't modify shared state yet
	## ═══════════════════════════════════════════════════════════════════
	
	## Reaction system: calculates concentration deltas
	var concentration_deltas = _calculate_reaction_deltas(state_snapshot, scaled_delta)
	
	## Gene system: calculates enzyme synthesis amounts
	var synthesis_amounts = _calculate_gene_synthesis(state_snapshot, scaled_delta)
	
	## Enzyme system: calculates degradation amounts
	var degradation_amounts = _calculate_enzyme_degradation(state_snapshot, scaled_delta)
	
	## Mutation system: calculates mutations (new enzymes, parameter changes, etc)
	var mutation_result = _calculate_mutations(state_snapshot, scaled_delta)
	
	## Evolution system: calculates fitness and selection pressure
	var selection_result = _calculate_selection(state_snapshot, scaled_delta)
	
	## ═══════════════════════════════════════════════════════════════════
	## PHASE 2: Apply (coordinator applies deltas based on lock state)
	## Only the coordinator modifies shared state
	## ═══════════════════════════════════════════════════════════════════
	
	_apply_concentration_deltas(concentration_deltas)
	_apply_enzyme_changes(synthesis_amounts, degradation_amounts)
	_apply_mutations(mutation_result)
	_apply_selection(selection_result)
	
	## ═══════════════════════════════════════════════════════════════════
	## PHASE 3: Update derived state
	## ═══════════════════════════════════════════════════════════════════
	
	cell.update(scaled_delta, reactions)
	_record_history()
	
	## Emit signals for UI
	concentration_deltas_calculated.emit(concentration_deltas)
	enzyme_synthesis_calculated.emit(synthesis_amounts)
	enzyme_degradation_calculated.emit(degradation_amounts)
	if not mutation_result.is_empty():
		mutations_generated.emit(mutation_result)
	if not selection_result.is_empty():
		selection_calculated.emit(selection_result)
	simulation_updated.emit(get_simulation_data())

#endregion

#region State Snapshot - Immutable view for subsystems

func _create_state_snapshot() -> Dictionary:
	var mol_concs: Dictionary = {}
	for mol_name in molecules:
		mol_concs[mol_name] = molecules[mol_name].concentration
	
	var enz_concs: Dictionary = {}
	for enz_id in enzymes:
		enz_concs[enz_id] = enzymes[enz_id].concentration
	
	return {
		"molecule_concentrations": mol_concs,
		"enzyme_concentrations": enz_concs,
		"molecules": molecules,
		"enzymes": enzymes,
		"genes": genes,
		"reactions": reactions
	}

#endregion

#region Subsystem: Reactions (Independent)

func _calculate_reaction_deltas(snapshot: Dictionary, delta: float) -> Dictionary:
	var deltas: Dictionary = {}
	
	## Always calculate rates for display purposes
	for enz_id in snapshot.enzymes:
		var enzyme: Enzyme = snapshot.enzymes[enz_id]
		var enz_conc = snapshot.enzyme_concentrations.get(enz_id, 0.0)
		
		for reaction in enzyme.reactions:
			_calculate_reaction_rates(reaction, snapshot, enz_conc)
	
	if lock_reactions:
		return deltas
	
	for reaction in snapshot.reactions:
		var net_rate = reaction.get_net_rate()
		
		for substrate in reaction.substrates:
			if not deltas.has(substrate):
				deltas[substrate] = 0.0
			deltas[substrate] -= net_rate * reaction.substrates[substrate] * delta
		
		for product in reaction.products:
			if not deltas.has(product):
				deltas[product] = 0.0
			deltas[product] += net_rate * reaction.products[product] * delta
	
	return deltas

func _calculate_reaction_rates(reaction: Reaction, snapshot: Dictionary, enz_conc: float) -> void:
	var temp_molecules: Dictionary = {}
	for mol_name in snapshot.molecules:
		temp_molecules[mol_name] = snapshot.molecules[mol_name]
	
	reaction.calculate_forward_rate(temp_molecules, enz_conc)
	reaction.calculate_reverse_rate(temp_molecules, enz_conc)
	reaction.calculate_energy_partition(reaction.get_net_rate())

#endregion

#region Subsystem: Gene Expression (Independent)

func _calculate_gene_synthesis(snapshot: Dictionary, delta: float) -> Dictionary:
	var synthesis: Dictionary = {}
	
	for gene_id in snapshot.genes:
		var gene: Gene = snapshot.genes[gene_id]
		gene.calculate_expression_rate(snapshot.molecules)
	
	if lock_genes:
		return synthesis
	
	for gene_id in snapshot.genes:
		var gene: Gene = snapshot.genes[gene_id]
		
		if not snapshot.enzymes.has(gene.enzyme_id):
			continue
		
		var enzyme: Enzyme = snapshot.enzymes[gene.enzyme_id]
		if enzyme.is_locked:
			continue
		
		var amount = gene.current_expression_rate * delta
		if amount > 0:
			synthesis[gene.enzyme_id] = amount
	
	return synthesis

#endregion

#region Subsystem: Enzyme Degradation (Independent)

func _calculate_enzyme_degradation(snapshot: Dictionary, delta: float) -> Dictionary:
	var degradation: Dictionary = {}
	
	if lock_enzymes:
		return degradation
	
	for enz_id in snapshot.enzymes:
		var enzyme: Enzyme = snapshot.enzymes[enz_id]
		
		if enzyme.is_locked or not enzyme.is_degradable:
			continue
		
		var enz_conc = snapshot.enzyme_concentrations.get(enz_id, 0.0)
		if enz_conc <= 0.0:
			continue
		
		var amount = enzyme.degradation_rate * enz_conc * delta
		if amount > 0:
			degradation[enz_id] = amount
	
	return degradation

#endregion

#region Subsystem: Mutations (Independent)

func _calculate_mutations(snapshot: Dictionary, delta: float) -> MutationSystem.MutationResult:
	if lock_mutations:
		return MutationSystem.MutationResult.new()
	
	return mutation_system.calculate_mutations(snapshot, delta, simulation_time)

#endregion

#region Subsystem: Evolution (Independent)

func _calculate_selection(snapshot: Dictionary, delta: float) -> EvolutionSystem.SelectionResult:
	if lock_evolution:
		return EvolutionSystem.SelectionResult.new()
	
	return evolution_system.calculate_selection(snapshot, delta, simulation_time)

#endregion

#region Coordinator: Apply Changes

func _apply_concentration_deltas(deltas: Dictionary) -> void:
	if lock_molecules:
		return
	
	for mol_name in deltas:
		if not molecules.has(mol_name):
			continue
		
		var mol: Molecule = molecules[mol_name]
		if mol.is_locked:
			continue
		
		mol.concentration = max(0.0, mol.concentration + deltas[mol_name])

func _apply_enzyme_changes(synthesis: Dictionary, degradation: Dictionary) -> void:
	if lock_enzymes:
		return
	
	for enz_id in synthesis:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: Enzyme = enzymes[enz_id]
		if enzyme.is_locked:
			continue
		
		enzyme.concentration += synthesis[enz_id]
		total_enzyme_synthesized += synthesis[enz_id]
	
	for enz_id in degradation:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: Enzyme = enzymes[enz_id]
		if enzyme.is_locked:
			continue
		
		enzyme.concentration = max(0.0, enzyme.concentration - degradation[enz_id])
		total_enzyme_degraded += degradation[enz_id]
		
		if enzyme.concentration < 1e-6:
			enzyme_depleted.emit(enzyme)

func _apply_mutations(result: MutationSystem.MutationResult) -> void:
	if lock_mutations or result.is_empty():
		return
	
	## Apply enzyme parameter modifications
	for enz_id in result.enzyme_modifications:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: Enzyme = enzymes[enz_id]
		var mods: Dictionary = result.enzyme_modifications[enz_id]
		
		_apply_enzyme_modifications(enzyme, mods)
		
		mutation_applied.emit("point_mutation", {
			"enzyme_id": enz_id,
			"modifications": mods
		})
	
	## Add new enzymes
	for new_enz_data in result.new_enzymes:
		var new_enzyme: Enzyme = new_enz_data.enzyme
		var new_reaction: Reaction = new_enz_data.reaction
		var new_gene: Gene = new_enz_data.gene
		
		## Add to collections
		enzymes[new_enzyme.id] = new_enzyme
		enzyme_history[new_enzyme.id] = []
		reactions.append(new_reaction)
		genes[new_enzyme.id] = new_gene
		
		## Register in lineage tracker
		var source_id = new_enz_data.get("source_id", "")
		evolution_system.register_birth(new_enzyme.id, source_id, simulation_time)
		
		## Emit signals
		enzyme_added.emit(new_enzyme)
		gene_added.emit(new_gene)
		
		mutation_applied.emit(new_enz_data.mutation_type, {
			"enzyme_id": new_enzyme.id,
			"enzyme_name": new_enzyme.name,
			"source_id": source_id,
			"reaction": new_reaction.get_summary()
		})
	
	## Apply gene modifications
	for gene_id in result.gene_modifications:
		if not genes.has(gene_id):
			continue
		
		var gene: Gene = genes[gene_id]
		var mods: Dictionary = result.gene_modifications[gene_id]
		
		_apply_gene_modifications(gene, mods)
		
		mutation_applied.emit("gene_mutation", {
			"gene_id": gene_id,
			"modifications": mods
		})
	
	## Add new molecules
	for new_mol in result.new_molecules:
		if not molecules.has(new_mol.name):
			molecules[new_mol.name] = new_mol
			molecule_history[new_mol.name] = []
			molecule_added.emit(new_mol)
			
			mutation_applied.emit("new_molecule", {
				"molecule_name": new_mol.name
			})
	
	## Record in history
	if not result.is_empty():
		total_mutations += result.point_mutations + result.duplications + result.novel_creations + result.regulatory_mutations
		
		mutation_history.append({
			"time": result.timestamp,
			"summary": result.get_summary(),
			"point": result.point_mutations,
			"dup": result.duplications,
			"novel": result.novel_creations,
			"reg": result.regulatory_mutations
		})
		
		while mutation_history.size() > max_mutation_history:
			mutation_history.pop_front()

func _apply_enzyme_modifications(enzyme: Enzyme, mods: Dictionary) -> void:
	if enzyme.reactions.is_empty():
		return
	
	var rxn = enzyme.reactions[0]
	
	if mods.has("vmax"):
		rxn.vmax = mods.vmax
	if mods.has("km"):
		rxn.km = mods.km
	if mods.has("efficiency"):
		rxn.reaction_efficiency = mods.efficiency
	if mods.has("delta_g"):
		rxn.delta_g = mods.delta_g
	if mods.has("half_life"):
		enzyme.half_life = mods.half_life
		enzyme._update_degradation_rate()

func _apply_gene_modifications(gene: Gene, mods: Dictionary) -> void:
	if mods.has("basal_rate"):
		gene.basal_rate = mods.basal_rate
	
	if mods.has("activator_mod"):
		var act_mod = mods.activator_mod
		var idx = act_mod.index
		if idx < gene.activators.size():
			var act = gene.activators[idx]
			act.kd = act_mod.kd
			act.max_fold_change = act_mod.max_fold
			act.hill_coefficient = act_mod.hill
	
	if mods.has("repressor_mod"):
		var rep_mod = mods.repressor_mod
		var idx = rep_mod.index
		if idx < gene.repressors.size():
			var rep = gene.repressors[idx]
			rep.kd = rep_mod.kd
			rep.max_fold_change = rep_mod.max_fold
			rep.hill_coefficient = rep_mod.hill
	
	if mods.has("new_activator"):
		var new_act = mods.new_activator
		gene.add_activator(new_act.molecule, new_act.kd, new_act.max_fold, new_act.hill)
	
	if mods.has("new_repressor"):
		var new_rep = mods.new_repressor
		gene.add_repressor(new_rep.molecule, new_rep.kd, new_rep.max_fold, new_rep.hill)

func _apply_selection(result: EvolutionSystem.SelectionResult) -> void:
	if lock_evolution or result.is_empty():
		return
	
	## Apply eliminations (remove low-fitness enzymes)
	for enz_id in result.eliminations:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: Enzyme = enzymes[enz_id]
		var reason: String = result.eliminations[enz_id]
		
		## Record death in lineage
		evolution_system.register_death(enz_id, simulation_time)
		
		## Remove enzyme and associated data
		var rxn_to_remove: Reaction = null
		for rxn in reactions:
			if rxn.enzyme == enzyme:
				rxn_to_remove = rxn
				break
		
		if rxn_to_remove:
			reactions.erase(rxn_to_remove)
		
		enzymes.erase(enz_id)
		enzyme_history.erase(enz_id)
		genes.erase(enz_id)
		evolution_system.clear_history_for(enz_id)
		
		selection_applied.emit("elimination", {
			"enzyme_id": enz_id,
			"reason": reason
		})
	
	## Apply expression boosts (increase basal rate for high-fitness enzymes)
	for enz_id in result.boosts:
		if not genes.has(enz_id):
			continue
		
		var gene: Gene = genes[enz_id]
		var boost_factor: float = result.boosts[enz_id]
		
		gene.basal_rate *= boost_factor
		gene.basal_rate = clampf(gene.basal_rate, 1e-6, 0.01)
		
		selection_applied.emit("boost", {
			"enzyme_id": enz_id,
			"boost_factor": boost_factor,
			"new_basal_rate": gene.basal_rate
		})
	
	## Apply competition losses (reduce expression of losing enzymes)
	for loser_id in result.competition_losses:
		if not genes.has(loser_id):
			continue
		
		var gene: Gene = genes[loser_id]
		var winner_id: String = result.competition_losses[loser_id]
		
		## Reduce basal rate by 30%
		gene.basal_rate *= 0.7
		gene.basal_rate = max(gene.basal_rate, 1e-6)
		
		selection_applied.emit("competition_loss", {
			"loser_id": loser_id,
			"winner_id": winner_id,
			"new_basal_rate": gene.basal_rate
		})
	
	## Apply adaptive gene regulation adjustments
	for gene_id in result.gene_adjustments:
		if not genes.has(gene_id):
			continue
		
		var gene: Gene = genes[gene_id]
		var adjustments: Dictionary = result.gene_adjustments[gene_id]
		
		if adjustments.has("basal_rate"):
			gene.basal_rate = adjustments.basal_rate
		
		selection_applied.emit("regulation_adjustment", {
			"gene_id": gene_id,
			"adjustments": adjustments
		})

#endregion

#region History Recording

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
	total_mutations = 0
	mutation_history.clear()
	
	for mol_name in molecules:
		molecules[mol_name].concentration = molecules[mol_name].initial_concentration
	
	for enz_id in enzymes:
		enzymes[enz_id].concentration = enzymes[enz_id].initial_concentration
	
	cell = Cell.new()
	
	time_history.clear()
	for mol_name in molecule_history:
		molecule_history[mol_name].clear()
	for enz_id in enzyme_history:
		enzyme_history[enz_id].clear()

## Lock all categories except the specified one (for isolated testing)
func isolate_system(system: String) -> void:
	lock_molecules = system != "molecules"
	lock_enzymes = system != "enzymes"
	lock_genes = system != "genes"
	lock_reactions = system != "reactions"
	lock_mutations = system != "mutations"
	lock_evolution = system != "evolution"

func unlock_all() -> void:
	lock_molecules = false
	lock_enzymes = false
	lock_genes = false
	lock_reactions = false
	lock_mutations = false
	lock_evolution = false

func lock_all() -> void:
	lock_molecules = true
	lock_enzymes = true
	lock_genes = true
	lock_reactions = true
	lock_mutations = true
	lock_evolution = true

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
		"protein_stats": get_protein_expression_stats(),
		"mutation_stats": get_mutation_stats(),
		"evolution_stats": get_evolution_stats(),
		"locks": {
			"molecules": lock_molecules,
			"enzymes": lock_enzymes,
			"genes": lock_genes,
			"reactions": lock_reactions,
			"mutations": lock_mutations,
			"evolution": lock_evolution
		}
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

func get_mutation_stats() -> Dictionary:
	return {
		"total_mutations": total_mutations,
		"enzyme_count": enzymes.size(),
		"molecule_count": molecules.size(),
		"gene_count": genes.size(),
		"reaction_count": reactions.size(),
		"recent_history": mutation_history,
		"mutation_rates": {
			"enzyme": mutation_system.enzyme_mutation_rate,
			"duplication": mutation_system.duplication_rate,
			"novel": mutation_system.novel_enzyme_rate,
			"gene": mutation_system.gene_mutation_rate
		}
	}

func get_evolution_stats() -> Dictionary:
	var fitness_summary = evolution_system.get_fitness_summary()
	var fitness_ranking = evolution_system.get_fitness_ranking()
	
	return {
		"average_fitness": fitness_summary.average_fitness,
		"max_fitness": fitness_summary.max_fitness,
		"min_fitness": fitness_summary.min_fitness,
		"elite_count": fitness_summary.elite_count,
		"struggling_count": fitness_summary.struggling_count,
		"generation": fitness_summary.generation,
		"fitness_ranking": fitness_ranking,
		"selection_rates": {
			"selection": evolution_system.selection_rate,
			"elimination": evolution_system.elimination_rate,
			"boost": evolution_system.boost_rate
		},
		"thresholds": {
			"elimination": evolution_system.elimination_threshold,
			"boost": evolution_system.boost_threshold
		}
	}

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
