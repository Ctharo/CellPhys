## Core simulation engine with DECOUPLED subsystems
## Uses Resource-based data classes for save/load support
## Each system is orthogonal - can be disabled without breaking others
class_name Simulator
extends Node

#region Signals - Inter-system Communication

signal simulation_updated(data: Dictionary)
signal simulation_started()
signal simulation_stopped()

## Entity lifecycle signals
signal molecule_added(molecule: MoleculeData)
signal enzyme_added(enzyme: EnzymeData)
signal gene_added(gene: GeneData)
signal enzyme_depleted(enzyme: EnzymeData)

## Category lock signals (for reactive UI)
signal molecules_lock_changed(locked: bool)
signal enzymes_lock_changed(locked: bool)
signal genes_lock_changed(locked: bool)
signal reactions_lock_changed(locked: bool)
signal mutations_lock_changed(locked: bool)
signal evolution_lock_changed(locked: bool)

## Subsystem output signals
signal concentration_deltas_calculated(deltas: Dictionary)
signal enzyme_synthesis_calculated(synthesis: Dictionary)
signal enzyme_degradation_calculated(degradation: Dictionary)
signal mutations_generated(result: MutationSystem.MutationResult)
signal selection_calculated(result: EvolutionSystem.SelectionResult)

## Mutation event signals
signal mutation_applied(mutation_type: String, details: Dictionary)
signal selection_applied(selection_type: String, details: Dictionary)

## Save/Load signals
signal snapshot_saved(path: String)
signal snapshot_loaded(path: String)
signal pathway_loaded(preset: PathwayPreset)

#endregion

#region Configuration

@export var time_scale: float = 1.0
@export var paused: bool = true
@export var auto_generate: bool = false

#endregion

#region Simulation State

var is_initialized: bool = false
var is_running: bool = false

#endregion

#region Category Locks

var _lock_molecules: bool = false
var _lock_enzymes: bool = false
var _lock_genes: bool = false
var _lock_reactions: bool = false
var _lock_mutations: bool = true
var _lock_evolution: bool = true

var lock_molecules: bool:
	get: return _lock_molecules
	set(value):
		if _lock_molecules != value:
			_lock_molecules = value
			molecules_lock_changed.emit(value)

var lock_enzymes: bool:
	get: return _lock_enzymes
	set(value):
		if _lock_enzymes != value:
			_lock_enzymes = value
			enzymes_lock_changed.emit(value)

var lock_genes: bool:
	get: return _lock_genes
	set(value):
		if _lock_genes != value:
			_lock_genes = value
			genes_lock_changed.emit(value)

var lock_reactions: bool:
	get: return _lock_reactions
	set(value):
		if _lock_reactions != value:
			_lock_reactions = value
			reactions_lock_changed.emit(value)

var lock_mutations: bool:
	get: return _lock_mutations
	set(value):
		if _lock_mutations != value:
			_lock_mutations = value
			mutations_lock_changed.emit(value)

var lock_evolution: bool:
	get: return _lock_evolution
	set(value):
		if _lock_evolution != value:
			_lock_evolution = value
			evolution_lock_changed.emit(value)

#endregion

#region Core Data - Resource-based

var molecules: Dictionary = {}  ## {name: MoleculeData}
var enzymes: Dictionary = {}    ## {id: EnzymeData}
var reactions: Array[ReactionData] = []
var genes: Dictionary = {}      ## {id: GeneData}
var cell: CellData = null

#endregion

#region Subsystems

var mutation_system: MutationSystem = null
var evolution_system: EvolutionSystem = null

#endregion

#region Simulation State

var simulation_time: float = 0.0
var total_enzyme_synthesized: float = 0.0
var total_enzyme_degraded: float = 0.0
var total_mutations: int = 0
var mutation_history: Array[Dictionary] = []
var max_mutation_history: int = 50

#endregion

#region History

var history_length: int = 500
var molecule_history: Dictionary = {}
var enzyme_history: Dictionary = {}
var time_history: Array[float] = []

#endregion

#region Initialization

func _ready() -> void:
	cell = CellData.create_new()
	mutation_system = MutationSystem.new()
	evolution_system = EvolutionSystem.new()

func start_simulation() -> void:
	if not is_initialized:
		_generate_random_system()
		is_initialized = true
	
	paused = false
	is_running = true
	simulation_started.emit()

func stop_simulation() -> void:
	paused = true
	is_running = false
	simulation_stopped.emit()

func has_data() -> bool:
	return is_initialized and not molecules.is_empty()

func _generate_random_system() -> void:
	var num_molecules = randi_range(4, 6)
	var num_enzymes = randi_range(3, 5)
	
	var mol_names: Array[String] = []
	for i in range(num_molecules):
		var mol = MoleculeData.create_random()
		while molecules.has(mol.molecule_name):
			mol.molecule_name = MoleculeData.generate_random_name()
		add_molecule(mol)
		mol_names.append(mol.molecule_name)
	
	for i in range(num_enzymes):
		var enz_name = "Enz_%d" % (i + 1)
		var enzyme = EnzymeData.new("enz_%d" % i, enz_name)
		
		var rxn = ReactionData.new("rxn_%d" % i)
		
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

func add_molecule(molecule: MoleculeData) -> void:
	molecules[molecule.molecule_name] = molecule
	molecule_history[molecule.molecule_name] = []
	molecule_added.emit(molecule)

func remove_molecule(mol_name: String) -> void:
	molecules.erase(mol_name)
	molecule_history.erase(mol_name)

func add_enzyme(enzyme: EnzymeData) -> void:
	enzymes[enzyme.enzyme_id] = enzyme
	enzyme_history[enzyme.enzyme_id] = []
	enzyme_added.emit(enzyme)

func remove_enzyme(id: String) -> void:
	if genes.has(id):
		genes.erase(id)
	enzymes.erase(id)
	enzyme_history.erase(id)

func add_gene(gene: GeneData) -> void:
	genes[gene.enzyme_id] = gene
	gene_added.emit(gene)

func create_gene_for_enzyme(enzyme: EnzymeData, basal_rate: float = 0.0001) -> GeneData:
	var gene = GeneData.new(GeneData.generate_name_for_enzyme(enzyme.enzyme_name), enzyme.enzyme_id, basal_rate)
	add_gene(gene)
	return gene

func get_all_reactions() -> Array[ReactionData]:
	return reactions

#endregion

#region Simulation Loop

func _process(delta: float) -> void:
	if paused or not cell.is_alive or not is_initialized:
		return
	
	var scaled_delta = delta * time_scale
	simulation_time += scaled_delta
	
	var state_snapshot = _create_state_snapshot()
	
	## Phase 1: Calculate
	var concentration_deltas = _calculate_reaction_deltas(state_snapshot, scaled_delta)
	var synthesis_amounts = _calculate_gene_synthesis(state_snapshot, scaled_delta)
	var degradation_amounts = _calculate_enzyme_degradation(state_snapshot, scaled_delta)
	var mutation_result = _calculate_mutations(state_snapshot, scaled_delta)
	var selection_result = _calculate_selection(state_snapshot, scaled_delta)
	
	## Phase 2: Apply
	_apply_concentration_deltas(concentration_deltas)
	_apply_enzyme_changes(synthesis_amounts, degradation_amounts)
	_apply_mutations(mutation_result)
	_apply_selection(selection_result)
	
	## Phase 3: Update derived state
	cell.update(scaled_delta, reactions)
	_record_history()
	
	## Emit signals
	concentration_deltas_calculated.emit(concentration_deltas)
	enzyme_synthesis_calculated.emit(synthesis_amounts)
	enzyme_degradation_calculated.emit(degradation_amounts)
	if not mutation_result.is_empty():
		mutations_generated.emit(mutation_result)
	if not selection_result.is_empty():
		selection_calculated.emit(selection_result)
	simulation_updated.emit(get_simulation_data())

#endregion

#region State Snapshot

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

#region Subsystem: Reactions

func _calculate_reaction_deltas(snapshot: Dictionary, delta: float) -> Dictionary:
	var deltas: Dictionary = {}
	
	for enz_id in snapshot.enzymes:
		var enzyme: EnzymeData = snapshot.enzymes[enz_id]
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

func _calculate_reaction_rates(reaction: ReactionData, snapshot: Dictionary, enz_conc: float) -> void:
	reaction.calculate_forward_rate(snapshot.molecules, enz_conc)
	reaction.calculate_reverse_rate(snapshot.molecules, enz_conc)
	reaction.calculate_energy_partition(reaction.get_net_rate())

#endregion

#region Subsystem: Gene Expression

func _calculate_gene_synthesis(snapshot: Dictionary, delta: float) -> Dictionary:
	var synthesis: Dictionary = {}
	
	for gene_id in snapshot.genes:
		var gene: GeneData = snapshot.genes[gene_id]
		gene.calculate_expression_rate(snapshot.molecules)
	
	if lock_genes:
		return synthesis
	
	for gene_id in snapshot.genes:
		var gene: GeneData = snapshot.genes[gene_id]
		
		if not snapshot.enzymes.has(gene.enzyme_id):
			continue
		
		var enzyme: EnzymeData = snapshot.enzymes[gene.enzyme_id]
		if enzyme.is_locked:
			continue
		
		var amount = gene.current_expression_rate * delta
		if amount > 0:
			synthesis[gene.enzyme_id] = amount
	
	return synthesis

#endregion

#region Subsystem: Enzyme Degradation

func _calculate_enzyme_degradation(snapshot: Dictionary, delta: float) -> Dictionary:
	var degradation: Dictionary = {}
	
	if lock_enzymes:
		return degradation
	
	for enz_id in snapshot.enzymes:
		var enzyme: EnzymeData = snapshot.enzymes[enz_id]
		
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

#region Subsystem: Mutations

func _calculate_mutations(snapshot: Dictionary, delta: float) -> MutationSystem.MutationResult:
	if lock_mutations:
		return MutationSystem.MutationResult.new()
	
	return mutation_system.calculate_mutations(snapshot, delta, simulation_time)

#endregion

#region Subsystem: Evolution

func _calculate_selection(snapshot: Dictionary, delta: float) -> EvolutionSystem.SelectionResult:
	if lock_evolution:
		return EvolutionSystem.SelectionResult.new()
	
	return evolution_system.calculate_selection(snapshot, delta, simulation_time)

#endregion

#region Apply Changes

func _apply_concentration_deltas(deltas: Dictionary) -> void:
	if lock_molecules:
		return
	
	for mol_name in deltas:
		if not molecules.has(mol_name):
			continue
		
		var mol: MoleculeData = molecules[mol_name]
		if mol.is_locked:
			continue
		
		mol.concentration = max(0.0, mol.concentration + deltas[mol_name])

func _apply_enzyme_changes(synthesis: Dictionary, degradation: Dictionary) -> void:
	if lock_enzymes:
		return
	
	for enz_id in synthesis:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: EnzymeData = enzymes[enz_id]
		if enzyme.is_locked:
			continue
		
		enzyme.concentration += synthesis[enz_id]
		total_enzyme_synthesized += synthesis[enz_id]
	
	for enz_id in degradation:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: EnzymeData = enzymes[enz_id]
		if enzyme.is_locked:
			continue
		
		enzyme.concentration = max(0.0, enzyme.concentration - degradation[enz_id])
		total_enzyme_degraded += degradation[enz_id]
		
		if enzyme.concentration < 1e-6:
			enzyme_depleted.emit(enzyme)

func _apply_mutations(result: MutationSystem.MutationResult) -> void:
	if lock_mutations or result.is_empty():
		return
	
	## Apply enzyme modifications
	for enz_id in result.enzyme_modifications:
		if not enzymes.has(enz_id):
			continue
		
		var enzyme: EnzymeData = enzymes[enz_id]
		var mods: Dictionary = result.enzyme_modifications[enz_id]
		_apply_enzyme_modifications(enzyme, mods)
		
		mutation_applied.emit("point_mutation", {
			"enzyme_id": enz_id,
			"modifications": mods
		})
	
	## Add new enzymes
	for new_enz_data in result.new_enzymes:
		var new_enzyme = new_enz_data.enzyme
		var new_reaction = new_enz_data.reaction
		var new_gene = new_enz_data.gene
		
		enzymes[new_enzyme.id] = _convert_to_enzyme_data(new_enzyme)
		enzyme_history[new_enzyme.id] = []
		reactions.append(_convert_to_reaction_data(new_reaction))
		genes[new_enzyme.id] = _convert_to_gene_data(new_gene)
		
		var source_id = new_enz_data.get("source_id", "")
		evolution_system.register_birth(new_enzyme.id, source_id, simulation_time)
		
		enzyme_added.emit(enzymes[new_enzyme.id])
		gene_added.emit(genes[new_enzyme.id])
		
		mutation_applied.emit(new_enz_data.mutation_type, {
			"enzyme_id": new_enzyme.id,
			"enzyme_name": new_enzyme.name,
			"source_id": source_id
		})
	
	## Record history
	if not result.is_empty():
		total_mutations += result.point_mutations + result.duplications + result.novel_creations + result.regulatory_mutations
		
		mutation_history.append({
			"time": result.timestamp,
			"summary": result.get_summary()
		})
		
		while mutation_history.size() > max_mutation_history:
			mutation_history.pop_front()

func _convert_to_enzyme_data(enz: Enzyme) -> EnzymeData:
	## Convert old Enzyme to new EnzymeData
	var data = EnzymeData.new(enz.id, enz.name)
	data.concentration = enz.concentration
	data.initial_concentration = enz.initial_concentration
	data.half_life = enz.half_life
	data.is_degradable = enz.is_degradable
	data.is_locked = enz.is_locked
	data._update_degradation_rate()
	return data

func _convert_to_reaction_data(rxn: Reaction) -> ReactionData:
	var data = ReactionData.new(rxn.id, rxn.name)
	data.substrates = rxn.substrates.duplicate()
	data.products = rxn.products.duplicate()
	data.vmax = rxn.vmax
	data.km = rxn.km
	data.reaction_efficiency = rxn.reaction_efficiency
	data.delta_g = rxn.delta_g
	data.is_irreversible = rxn.is_irreversible
	return data

func _convert_to_gene_data(g: Gene) -> GeneData:
	var data = GeneData.new(g.id, g.enzyme_id, g.basal_rate)
	data.is_active = g.is_active
	return data

func _apply_enzyme_modifications(enzyme: EnzymeData, mods: Dictionary) -> void:
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

func _apply_selection(result: EvolutionSystem.SelectionResult) -> void:
	if lock_evolution or result.is_empty():
		return
	
	for enz_id in result.eliminations:
		if not enzymes.has(enz_id):
			continue
		
		evolution_system.register_death(enz_id, simulation_time)
		
		var rxn_to_remove: ReactionData = null
		for rxn in reactions:
			if enzymes.has(enz_id) and rxn.enzyme == enzymes[enz_id]:
				rxn_to_remove = rxn
				break
		
		if rxn_to_remove:
			reactions.erase(rxn_to_remove)
		
		enzymes.erase(enz_id)
		enzyme_history.erase(enz_id)
		genes.erase(enz_id)
		evolution_system.clear_history_for(enz_id)
		
		selection_applied.emit("elimination", {"enzyme_id": enz_id})
	
	for enz_id in result.boosts:
		if not genes.has(enz_id):
			continue
		
		var gene: GeneData = genes[enz_id]
		var boost_factor: float = result.boosts[enz_id]
		gene.basal_rate = clampf(gene.basal_rate * boost_factor, 1e-6, 0.01)
		
		selection_applied.emit("boost", {"enzyme_id": enz_id, "boost_factor": boost_factor})

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

#region Save/Load

## Save current state to a snapshot file
func save_snapshot(path: String, name: String = "", description: String = "") -> Error:
	var snapshot = SimulationSnapshot.capture_from(self)
	snapshot.snapshot_name = name if name != "" else "Snapshot %s" % Time.get_datetime_string_from_system()
	snapshot.description = description
	
	var err = snapshot.save_to_file(path)
	if err == OK:
		snapshot_saved.emit(path)
	return err

## Load state from a snapshot file
func load_snapshot(path: String) -> Error:
	var snapshot = SimulationSnapshot.load_from_file(path)
	if not snapshot:
		return ERR_FILE_NOT_FOUND
	
	snapshot.restore_to(self)
	snapshot_loaded.emit(path)
	return OK

## Load a pathway preset
func load_pathway(preset: PathwayPreset) -> void:
	preset.apply_to(self)
	pathway_loaded.emit(preset)

## Load a built-in pathway by name
func load_builtin_pathway(pathway_name: String) -> void:
	var preset: PathwayPreset
	
	match pathway_name.to_lower():
		"linear", "linear_pathway":
			preset = PathwayPreset.create_linear_pathway()
		"feedback", "feedback_inhibition":
			preset = PathwayPreset.create_feedback_inhibition()
		"branched", "branched_pathway":
			preset = PathwayPreset.create_branched_pathway()
		"oscillator", "metabolic_oscillator":
			preset = PathwayPreset.create_oscillator()
		_:
			push_error("Unknown builtin pathway: %s" % pathway_name)
			return
	
	load_pathway(preset)

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
	
	molecules.clear()
	enzymes.clear()
	reactions.clear()
	genes.clear()
	
	time_history.clear()
	molecule_history.clear()
	enzyme_history.clear()
	
	cell = CellData.create_new()
	
	is_initialized = false
	is_running = false
	paused = true

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
		"recent_mutations": mutation_history.slice(-5) if mutation_history.size() > 0 else [],
		"locks": {
			"molecules": lock_molecules,
			"enzymes": lock_enzymes,
			"genes": lock_genes,
			"reactions": lock_reactions,
			"mutations": lock_mutations,
			"evolution": lock_evolution
		},
		"is_running": is_running,
		"is_initialized": is_initialized
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
		var gene: GeneData = genes[gene_id]
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
		"fitness_ranking": fitness_ranking
	}

#endregion
