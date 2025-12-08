## SimulationSnapshot - saves the complete state of a simulation
## Can be saved as .tres files for sharing or loading later
class_name SimulationSnapshot
extends Resource

#region Metadata

@export var snapshot_name: String = "Untitled Simulation"
@export var description: String = ""
@export var author: String = ""
@export var created_at: String = ""  ## ISO 8601 timestamp
@export var version: String = "1.0"

#endregion

#region Simulation State

@export_group("Entities")
@export var molecules: Array[MoleculeData] = []
@export var enzymes: Array[EnzymeData] = []
@export var genes: Array[GeneData] = []

@export_group("Cell State")
@export var cell_heat: float = 50.0
@export var cell_usable_energy: float = 100.0
@export var cell_is_alive: bool = true

@export_group("Timing")
@export var simulation_time: float = 0.0
@export var total_enzyme_synthesized: float = 0.0
@export var total_enzyme_degraded: float = 0.0
@export var total_mutations: int = 0

@export_group("Lock States")
@export var lock_molecules: bool = false
@export var lock_enzymes: bool = false
@export var lock_genes: bool = false
@export var lock_reactions: bool = false
@export var lock_mutations: bool = true

#endregion

#region Static Factory Methods

## Create a snapshot from the current simulator state
static func capture_from(sim: Node) -> SimulationSnapshot:
	var snapshot = SimulationSnapshot.new()
	snapshot.created_at = Time.get_datetime_string_from_system(true)
	
	## Capture molecules
	for mol_name in sim.molecules:
		var mol: MoleculeData = sim.molecules[mol_name]
		snapshot.molecules.append(mol.duplicate(true))
	
	## Capture enzymes (with their reactions)
	for enz_id in sim.enzymes:
		var enz: EnzymeData = sim.enzymes[enz_id]
		snapshot.enzymes.append(enz.duplicate(true))
	
	## Capture genes
	for gene_id in sim.genes:
		var gene: GeneData = sim.genes[gene_id]
		snapshot.genes.append(gene.duplicate(true))
	
	## Capture cell state
	if sim.cell:
		snapshot.cell_heat = sim.cell.heat
		snapshot.cell_usable_energy = sim.cell.usable_energy
		snapshot.cell_is_alive = sim.cell.is_alive
	
	## Capture timing
	snapshot.simulation_time = sim.simulation_time
	snapshot.total_enzyme_synthesized = sim.total_enzyme_synthesized
	snapshot.total_enzyme_degraded = sim.total_enzyme_degraded
	snapshot.total_mutations = sim.total_mutations
	
	## Capture lock states
	snapshot.lock_molecules = sim.lock_molecules
	snapshot.lock_enzymes = sim.lock_enzymes
	snapshot.lock_genes = sim.lock_genes
	snapshot.lock_reactions = sim.lock_reactions
	snapshot.lock_mutations = sim.lock_mutations
	
	return snapshot

## Restore snapshot state to a simulator
func restore_to(sim: Node) -> void:
	## Clear existing state
	sim.molecules.clear()
	sim.enzymes.clear()
	sim.genes.clear()
	sim.reactions.clear()
	sim.molecule_history.clear()
	sim.enzyme_history.clear()
	sim.time_history.clear()
	
	## Restore molecules
	for mol in molecules:
		var instance = mol.create_instance()
		sim.molecules[instance.molecule_name] = instance
		sim.molecule_history[instance.molecule_name] = []
	
	## Restore enzymes and reactions
	for enz in enzymes:
		var instance = enz.create_instance()
		sim.enzymes[instance.enzyme_id] = instance
		sim.enzyme_history[instance.enzyme_id] = []
		for rxn in instance.reactions:
			sim.reactions.append(rxn)
	
	## Restore genes
	for gene in genes:
		var instance = gene.create_instance()
		sim.genes[instance.enzyme_id] = instance
	
	## Restore cell state
	if sim.cell:
		sim.cell.heat = cell_heat
		sim.cell.usable_energy = cell_usable_energy
		sim.cell.is_alive = cell_is_alive
	
	## Restore timing
	sim.simulation_time = simulation_time
	sim.total_enzyme_synthesized = total_enzyme_synthesized
	sim.total_enzyme_degraded = total_enzyme_degraded
	sim.total_mutations = total_mutations
	
	## Restore lock states
	sim.lock_molecules = lock_molecules
	sim.lock_enzymes = lock_enzymes
	sim.lock_genes = lock_genes
	sim.lock_reactions = lock_reactions
	sim.lock_mutations = lock_mutations
	
	sim.is_initialized = true

#endregion

#region Save/Load Helpers

## Save this snapshot to a file
func save_to_file(path: String) -> Error:
	return ResourceSaver.save(self, path)

## Load a snapshot from a file
static func load_from_file(path: String) -> SimulationSnapshot:
	if not ResourceLoader.exists(path):
		push_error("Snapshot file not found: %s" % path)
		return null
	
	var resource = ResourceLoader.load(path)
	if resource is SimulationSnapshot:
		return resource
	
	push_error("Invalid snapshot file: %s" % path)
	return null

#endregion

#region Display

func get_summary() -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % snapshot_name)
	if description != "":
		lines.append(description)
	lines.append("Created: %s" % created_at)
	lines.append("")
	lines.append("Molecules: %d" % molecules.size())
	lines.append("Enzymes: %d" % enzymes.size())
	lines.append("Genes: %d" % genes.size())
	lines.append("Simulation time: %.1f s" % simulation_time)
	return "\n".join(lines)

func _to_string() -> String:
	return "SimulationSnapshot(%s, %d mol, %d enz)" % [snapshot_name, molecules.size(), enzymes.size()]

#endregion
