## Core simulation engine using Resource-based data classes
## No legacy RefCounted classes - all entities are *Data types
class_name Simulator
extends Node

#region Signals

signal simulation_updated(data: Dictionary)
signal simulation_started
signal simulation_stopped
signal molecule_added(molecule: MoleculeData)
signal enzyme_added(enzyme: EnzymeData)
signal gene_added(gene: GeneData)
signal enzyme_depleted(enzyme: EnzymeData)
signal snapshot_saved(path: String)
signal snapshot_loaded(path: String)
signal pathway_loaded(preset: PathwayPreset)
signal config_applied(config: SimulationConfig)

signal molecules_lock_changed(locked: bool)
signal enzymes_lock_changed(locked: bool)
signal genes_lock_changed(locked: bool)
signal reactions_lock_changed(locked: bool)
signal mutations_lock_changed(locked: bool)
signal evolution_lock_changed(locked: bool)

#endregion

#region Configuration

@export var time_scale: float = 1.0
@export var paused: bool = true
@export var auto_generate: bool = false

var current_config: SimulationConfig = null

#endregion

#region State Flags

var is_initialized: bool = false
var is_running: bool = false

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

#region Core Data (Resource-based only)

var molecules: Dictionary = {}      ## {name: MoleculeData}
var enzymes: Dictionary = {}        ## {id: EnzymeData}
var reactions: Array[ReactionData] = []
var genes: Dictionary = {}          ## {id: GeneData}
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
	
	if auto_generate:
		apply_config(SimulationConfig.create_default())

## Apply a simulation configuration and generate pathway
func apply_config(config: SimulationConfig) -> void:
	reset()
	current_config = config
	
	## Generate pathway from config
	var generated = PathwayGenerator.generate_from_config(config)
	
	## Add all generated entities
	for mol_name in generated.molecules:
		add_molecule(generated.molecules[mol_name])
	
	for enz_id in generated.enzymes:
		add_enzyme(generated.enzymes[enz_id])
	
	for gene_id in generated.genes:
		add_gene(generated.genes[gene_id])
	
	## Collect reactions from enzymes
	reactions.clear()
	for enz_id in enzymes:
		var enz = enzymes[enz_id] as EnzymeData
		for rxn in enz.reactions:
			reactions.append(rxn)
	
	## Apply config settings
	time_scale = config.default_time_scale
	history_length = config.history_length
	paused = config.start_paused
	lock_mutations = not config.enable_mutations
	lock_evolution = not config.enable_evolution
	
	## Configure mutation system
	if mutation_system:
		mutation_system.enzyme_mutation_rate = config.enzyme_mutation_rate
		mutation_system.duplication_rate = config.duplication_rate
		mutation_system.novel_enzyme_rate = config.novel_enzyme_rate
		mutation_system.gene_mutation_rate = config.gene_mutation_rate
	
	## Configure evolution system
	if evolution_system:
		evolution_system.selection_interval = config.selection_interval
		evolution_system.elimination_threshold = config.elimination_threshold
		evolution_system.fitness_boost_factor = config.fitness_boost_factor
	
	is_initialized = true
	config_applied.emit(config)

func start_simulation() -> void:
	if not is_initialized:
		apply_config(current_config if current_config else SimulationConfig.create_default())
	
	paused = false
	is_running = true
	simulation_started.emit()

func stop_simulation() -> void:
	paused = true
	is_running = false
	simulation_stopped.emit()

func has_data() -> bool:
	return is_initialized and not molecules.is_empty()

#endregion

#region Entity Management

func add_molecule(mol: MoleculeData) -> void:
	molecules[mol.molecule_name] = mol
	molecule_history[mol.molecule_name] = []
	molecule_added.emit(mol)

func remove_molecule(name: String) -> void:
	molecules.erase(name)
	molecule_history.erase(name)

func add_enzyme(enz: EnzymeData) -> void:
	enzymes[enz.enzyme_id] = enz
	enzyme_history[enz.enzyme_id] = []
	enzyme_added.emit(enz)

func remove_enzyme(id: String) -> void:
	if genes.has(id):
		genes.erase(id)
	enzymes.erase(id)
	enzyme_history.erase(id)

func add_gene(gene: GeneData) -> void:
	genes[gene.enzyme_id] = gene
	gene_added.emit(gene)

func get_all_reactions() -> Array[ReactionData]:
	return reactions

#endregion

#region Simulation Loop

func _process(delta: float) -> void:
	if paused or not cell or not cell.is_alive:
		return
	
	var scaled_delta = delta * time_scale
	simulation_time += scaled_delta
	
	## 1. Update gene expression
	if not lock_genes:
		_update_gene_expression(scaled_delta)
	
	## 2. Apply enzyme degradation
	if not lock_enzymes:
		_apply_enzyme_degradation(scaled_delta)
	
	## 3. Apply enzyme synthesis
	if not lock_enzymes and not lock_genes:
		_apply_enzyme_synthesis(scaled_delta)
	
	## 4. Update reaction rates
	if not lock_reactions:
		_update_reaction_rates()
	
	## 5. Apply reactions
	if not lock_molecules and not lock_reactions:
		_apply_reactions(scaled_delta)
	
	## 6. Update cell state
	cell.update(scaled_delta, reactions)
	
	## 7. Record history
	_record_history()
	
	## 8. Emit update
	simulation_updated.emit(get_simulation_data())

func _update_gene_expression(_delta: float) -> void:
	for gene_id in genes:
		var gene: GeneData = genes[gene_id]
		if not gene.is_active:
			continue
		gene.calculate_expression_rate(molecules)

func _apply_enzyme_degradation(delta: float) -> void:
	for enz_id in enzymes:
		var enzyme: EnzymeData = enzymes[enz_id]
		if enzyme.is_locked or not enzyme.is_degradable:
			continue
		
		var degraded = enzyme.concentration * enzyme.degradation_rate * delta
		enzyme.concentration = maxf(0.0, enzyme.concentration - degraded)
		total_enzyme_degraded += degraded
		
		if enzyme.concentration < 1e-9:
			enzyme_depleted.emit(enzyme)

func _apply_enzyme_synthesis(delta: float) -> void:
	for gene_id in genes:
		var gene: GeneData = genes[gene_id]
		if not gene.is_active:
			continue
		
		if enzymes.has(gene.enzyme_id):
			var enzyme: EnzymeData = enzymes[gene.enzyme_id]
			if enzyme.is_locked:
				continue
			
			var synthesized = gene.current_expression_rate * delta
			enzyme.concentration += synthesized
			total_enzyme_synthesized += synthesized

func _update_reaction_rates() -> void:
	for rxn in reactions:
		rxn.calculate_rates(molecules, enzymes, cell.temperature if cell else 310.0)

func _apply_reactions(delta: float) -> void:
	var changes: Dictionary = {}
	
	for rxn in reactions:
		var net_rate = rxn.current_forward_rate - rxn.current_reverse_rate
		
		for substrate in rxn.substrates:
			var stoich = rxn.substrates[substrate]
			if not changes.has(substrate):
				changes[substrate] = 0.0
			changes[substrate] -= net_rate * stoich * delta
		
		for product in rxn.products:
			var stoich = rxn.products[product]
			if not changes.has(product):
				changes[product] = 0.0
			changes[product] += net_rate * stoich * delta
	
	## Apply changes to molecules
	for mol_name in changes:
		if not molecules.has(mol_name):
			continue
		var mol: MoleculeData = molecules[mol_name]
		if mol.is_locked:
			continue
		mol.concentration = maxf(0.0, mol.concentration + changes[mol_name])

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

#region Save/Load

func save_snapshot(path: String, name: String = "", description: String = "") -> Error:
	var snapshot = SimulationSnapshot.capture_from(self)
	snapshot.snapshot_name = name if name != "" else "Snapshot %s" % Time.get_datetime_string_from_system()
	snapshot.description = description
	
	var err = snapshot.save_to_file(path)
	if err == OK:
		snapshot_saved.emit(path)
	return err

func load_snapshot(path: String) -> Error:
	var snapshot = SimulationSnapshot.load_from_file(path)
	if not snapshot:
		return ERR_FILE_NOT_FOUND
	
	snapshot.restore_to(self)
	snapshot_loaded.emit(path)
	return OK

func load_pathway(preset: PathwayPreset) -> void:
	preset.apply_to(self)
	pathway_loaded.emit(preset)

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
		"is_initialized": is_initialized,
		"current_config": current_config
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
			"enzyme": mutation_system.enzyme_mutation_rate if mutation_system else 0.0,
			"duplication": mutation_system.duplication_rate if mutation_system else 0.0,
			"novel": mutation_system.novel_enzyme_rate if mutation_system else 0.0,
			"gene": mutation_system.gene_mutation_rate if mutation_system else 0.0
		}
	}

func get_evolution_stats() -> Dictionary:
	if not evolution_system:
		return {}
	
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
