## PathwayPreset - defines a reusable metabolic pathway template
## Can be designed in the editor and loaded into simulations
## Examples: glycolysis, citric acid cycle, simple feedback loops
class_name PathwayPreset
extends Resource

#region Metadata

@export var pathway_name: String = "Unnamed Pathway"
@export_multiline var description: String = ""
@export var author: String = ""
@export var tags: Array[String] = []  ## e.g., ["glycolysis", "energy", "educational"]
@export var difficulty: int = 1  ## 1-5 complexity rating

#endregion

#region Pathway Components

@export_group("Molecules")
@export var molecules: Array[MoleculeData] = []

@export_group("Enzymes & Reactions")
@export var enzymes: Array[EnzymeData] = []

@export_group("Gene Regulation")
@export var genes: Array[GeneData] = []

#endregion

#region Pathway Behavior Settings

@export_group("Simulation Settings")
@export var suggested_time_scale: float = 1.0
@export var suggested_duration: float = 60.0  ## Recommended run time to see behavior
@export var start_paused: bool = true

@export_group("Lock Suggestions")
@export var suggest_lock_mutations: bool = true
@export var suggest_lock_evolution: bool = true

#endregion

#region Static Factory - Built-in Pathways

## Create a simple A→B→C linear pathway
static func create_linear_pathway(steps: int = 3) -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Linear Pathway (%d steps)" % steps
	preset.description = "A simple linear metabolic pathway demonstrating sequential reactions."
	preset.tags = ["linear", "basic", "educational"] as Array[String]
	preset.difficulty = 1
	
	## Create molecules
	var mol_names: Array[String] = []
	for i in range(steps + 1):
		var mol = MoleculeData.create_random()
		mol.molecule_name = "M%d" % i
		mol.concentration = 5.0 if i == 0 else 0.1
		mol.initial_concentration = mol.concentration
		preset.molecules.append(mol)
		mol_names.append(mol.molecule_name)
	
	## Create enzymes and reactions
	for i in range(steps):
		var enz = EnzymeData.new("enz_%d" % i, "E%d" % (i + 1))
		enz.concentration = 0.01
		enz.initial_concentration = 0.01
		
		var rxn = ReactionData.new("rxn_%d" % i)
		rxn.substrates[mol_names[i]] = 1.0
		rxn.products[mol_names[i + 1]] = 1.0
		rxn.delta_g = -5.0
		rxn.vmax = 10.0
		rxn.km = 1.0
		
		enz.add_reaction(rxn)
		preset.enzymes.append(enz)
		
		## Create gene for enzyme
		var gene = GeneData.new("gene_%d" % i, enz.enzyme_id, 0.0001)
		preset.genes.append(gene)
	
	return preset

## Create a pathway with product feedback inhibition
static func create_feedback_inhibition() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Feedback Inhibition Loop"
	preset.description = "Demonstrates negative feedback where the end product inhibits the first enzyme, creating homeostasis."
	preset.tags = ["feedback", "regulation", "homeostasis", "educational"] as Array[String]
	preset.difficulty = 2
	
	## Molecules: Substrate → Intermediate → Product
	var substrate = MoleculeData.create_random()
	substrate.molecule_name = "Substrate"
	substrate.concentration = 10.0
	substrate.initial_concentration = 10.0
	substrate.is_locked = true  ## Constant supply
	preset.molecules.append(substrate)
	
	var intermediate = MoleculeData.create_random()
	intermediate.molecule_name = "Intermediate"
	intermediate.concentration = 0.1
	intermediate.initial_concentration = 0.1
	preset.molecules.append(intermediate)
	
	var product = MoleculeData.create_random()
	product.molecule_name = "Product"
	product.concentration = 0.1
	product.initial_concentration = 0.1
	preset.molecules.append(product)
	
	## First enzyme - regulated by product
	var enz1 = EnzymeData.new("enz_1", "FirstEnzyme")
	enz1.concentration = 0.01
	enz1.initial_concentration = 0.01
	var rxn1 = ReactionData.new("rxn_1")
	rxn1.substrates["Substrate"] = 1.0
	rxn1.products["Intermediate"] = 1.0
	rxn1.delta_g = -8.0
	rxn1.vmax = 15.0
	enz1.add_reaction(rxn1)
	preset.enzymes.append(enz1)
	
	## First gene - repressed by product
	var gene1 = GeneData.new("gene_1", "enz_1", 0.0002)
	gene1.add_repressor("Product", 2.0, 10.0, 2.0)
	preset.genes.append(gene1)
	
	## Second enzyme
	var enz2 = EnzymeData.new("enz_2", "SecondEnzyme")
	enz2.concentration = 0.01
	enz2.initial_concentration = 0.01
	var rxn2 = ReactionData.new("rxn_2")
	rxn2.substrates["Intermediate"] = 1.0
	rxn2.products["Product"] = 1.0
	rxn2.delta_g = -5.0
	rxn2.vmax = 10.0
	enz2.add_reaction(rxn2)
	preset.enzymes.append(enz2)
	
	var gene2 = GeneData.new("gene_2", "enz_2", 0.0001)
	preset.genes.append(gene2)
	
	## Add sink for product (degradation/export)
	var enz_sink = EnzymeData.new("enz_sink", "ProductExport")
	enz_sink.concentration = 0.005
	enz_sink.initial_concentration = 0.005
	enz_sink.is_degradable = false
	var rxn_sink = ReactionData.new("rxn_sink")
	rxn_sink.substrates["Product"] = 1.0
	rxn_sink.delta_g = -10.0
	rxn_sink.vmax = 5.0
	rxn_sink.is_irreversible = true
	enz_sink.add_reaction(rxn_sink)
	preset.enzymes.append(enz_sink)
	
	var gene_sink = GeneData.new("gene_sink", "enz_sink", 0.0001)
	preset.genes.append(gene_sink)
	
	preset.suggested_duration = 120.0
	return preset

## Create a branched pathway
static func create_branched_pathway() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Branched Pathway"
	preset.description = "A pathway where one intermediate feeds into two different branches, demonstrating metabolic decision points."
	preset.tags = ["branched", "competition", "intermediate"] as Array[String]
	preset.difficulty = 3
	
	## Molecules
	var source = MoleculeData.create_random()
	source.molecule_name = "Source"
	source.concentration = 10.0
	source.initial_concentration = 10.0
	source.is_locked = true
	preset.molecules.append(source)
	
	var hub = MoleculeData.create_random()
	hub.molecule_name = "Hub"
	hub.concentration = 1.0
	hub.initial_concentration = 1.0
	preset.molecules.append(hub)
	
	var branch_a = MoleculeData.create_random()
	branch_a.molecule_name = "BranchA"
	branch_a.concentration = 0.1
	branch_a.initial_concentration = 0.1
	preset.molecules.append(branch_a)
	
	var branch_b = MoleculeData.create_random()
	branch_b.molecule_name = "BranchB"
	branch_b.concentration = 0.1
	branch_b.initial_concentration = 0.1
	preset.molecules.append(branch_b)
	
	## Source → Hub
	var enz_source = EnzymeData.new("enz_source", "SourceEnzyme")
	enz_source.concentration = 0.01
	enz_source.is_degradable = false
	var rxn_source = ReactionData.new("rxn_source")
	rxn_source.substrates["Source"] = 1.0
	rxn_source.products["Hub"] = 1.0
	rxn_source.delta_g = -5.0
	rxn_source.vmax = 10.0
	enz_source.add_reaction(rxn_source)
	preset.enzymes.append(enz_source)
	
	var gene_source = GeneData.new("gene_source", "enz_source", 0.0001)
	preset.genes.append(gene_source)
	
	## Hub → BranchA (activated by Hub itself)
	var enz_a = EnzymeData.new("enz_a", "BranchA_Enzyme")
	enz_a.concentration = 0.008
	var rxn_a = ReactionData.new("rxn_a")
	rxn_a.substrates["Hub"] = 1.0
	rxn_a.products["BranchA"] = 1.0
	rxn_a.delta_g = -7.0
	rxn_a.vmax = 12.0
	enz_a.add_reaction(rxn_a)
	preset.enzymes.append(enz_a)
	
	var gene_a = GeneData.new("gene_a", "enz_a", 0.0001)
	gene_a.add_activator("Hub", 2.0, 5.0, 1.5)
	preset.genes.append(gene_a)
	
	## Hub → BranchB (repressed by BranchA - competition)
	var enz_b = EnzymeData.new("enz_b", "BranchB_Enzyme")
	enz_b.concentration = 0.008
	var rxn_b = ReactionData.new("rxn_b")
	rxn_b.substrates["Hub"] = 1.0
	rxn_b.products["BranchB"] = 1.0
	rxn_b.delta_g = -6.0
	rxn_b.vmax = 10.0
	enz_b.add_reaction(rxn_b)
	preset.enzymes.append(enz_b)
	
	var gene_b = GeneData.new("gene_b", "enz_b", 0.00015)
	gene_b.add_repressor("BranchA", 1.5, 8.0, 1.0)
	preset.genes.append(gene_b)
	
	preset.suggested_duration = 90.0
	return preset

## Create oscillator pathway
static func create_oscillator() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Metabolic Oscillator"
	preset.description = "A repressilator-style circuit that creates oscillating concentrations through delayed negative feedback."
	preset.tags = ["oscillator", "dynamics", "advanced", "repressilator"] as Array[String]
	preset.difficulty = 4
	
	## Three molecules in a cycle
	var mol_a = MoleculeData.create_random()
	mol_a.molecule_name = "OscA"
	mol_a.concentration = 2.0
	mol_a.initial_concentration = 2.0
	preset.molecules.append(mol_a)
	
	var mol_b = MoleculeData.create_random()
	mol_b.molecule_name = "OscB"
	mol_b.concentration = 0.5
	mol_b.initial_concentration = 0.5
	preset.molecules.append(mol_b)
	
	var mol_c = MoleculeData.create_random()
	mol_c.molecule_name = "OscC"
	mol_c.concentration = 0.5
	mol_c.initial_concentration = 0.5
	preset.molecules.append(mol_c)
	
	## A represses B, B represses C, C represses A
	## Plus degradation to allow oscillation
	
	## Source for A (constitutive)
	var enz_src_a = EnzymeData.new("enz_src_a", "SourceA")
	enz_src_a.concentration = 0.01
	enz_src_a.is_degradable = false
	var rxn_src_a = ReactionData.new("rxn_src_a")
	rxn_src_a.products["OscA"] = 1.0
	rxn_src_a.delta_g = -10.0
	rxn_src_a.vmax = 5.0
	rxn_src_a.is_irreversible = true
	enz_src_a.add_reaction(rxn_src_a)
	preset.enzymes.append(enz_src_a)
	
	## Gene for A source - repressed by C
	var gene_src_a = GeneData.new("gene_src_a", "enz_src_a", 0.0003)
	gene_src_a.add_repressor("OscC", 1.0, 15.0, 2.0)
	preset.genes.append(gene_src_a)
	
	## A → B conversion
	var enz_a_b = EnzymeData.new("enz_a_b", "ConvertAtoB")
	enz_a_b.concentration = 0.01
	var rxn_a_b = ReactionData.new("rxn_a_b")
	rxn_a_b.substrates["OscA"] = 1.0
	rxn_a_b.products["OscB"] = 1.0
	rxn_a_b.delta_g = -3.0
	rxn_a_b.vmax = 8.0
	enz_a_b.add_reaction(rxn_a_b)
	preset.enzymes.append(enz_a_b)
	
	var gene_a_b = GeneData.new("gene_a_b", "enz_a_b", 0.0002)
	gene_a_b.add_activator("OscA", 1.5, 8.0, 1.5)
	preset.genes.append(gene_a_b)
	
	## B → C conversion
	var enz_b_c = EnzymeData.new("enz_b_c", "ConvertBtoC")
	enz_b_c.concentration = 0.01
	var rxn_b_c = ReactionData.new("rxn_b_c")
	rxn_b_c.substrates["OscB"] = 1.0
	rxn_b_c.products["OscC"] = 1.0
	rxn_b_c.delta_g = -3.0
	rxn_b_c.vmax = 8.0
	enz_b_c.add_reaction(rxn_b_c)
	preset.enzymes.append(enz_b_c)
	
	var gene_b_c = GeneData.new("gene_b_c", "enz_b_c", 0.0002)
	gene_b_c.add_activator("OscB", 1.5, 8.0, 1.5)
	preset.genes.append(gene_b_c)
	
	## Degradation sinks
	for mol_name in ["OscA", "OscB", "OscC"]:
		var enz_deg = EnzymeData.new("enz_deg_%s" % mol_name, "Degrade%s" % mol_name)
		enz_deg.concentration = 0.005
		enz_deg.is_degradable = false
		var rxn_deg = ReactionData.new("rxn_deg_%s" % mol_name)
		rxn_deg.substrates[mol_name] = 1.0
		rxn_deg.delta_g = -8.0
		rxn_deg.vmax = 3.0
		rxn_deg.is_irreversible = true
		enz_deg.add_reaction(rxn_deg)
		preset.enzymes.append(enz_deg)
		
		var gene_deg = GeneData.new("gene_deg_%s" % mol_name, enz_deg.enzyme_id, 0.0001)
		preset.genes.append(gene_deg)
	
	preset.suggested_duration = 300.0
	preset.suggested_time_scale = 2.0
	return preset

#endregion

#region Application

## Apply this preset to a simulator, replacing its current state
func apply_to(sim: Node) -> void:
	## Clear existing state
	sim.molecules.clear()
	sim.enzymes.clear()
	sim.genes.clear()
	sim.reactions.clear()
	sim.molecule_history.clear()
	sim.enzyme_history.clear()
	sim.time_history.clear()
	sim.simulation_time = 0.0
	sim.total_enzyme_synthesized = 0.0
	sim.total_enzyme_degraded = 0.0
	sim.total_mutations = 0
	
	## Apply molecules
	for mol in molecules:
		var instance = mol.create_instance()
		sim.molecules[instance.molecule_name] = instance
		sim.molecule_history[instance.molecule_name] = []
	
	## Apply enzymes and reactions
	for enz in enzymes:
		var instance = enz.create_instance()
		sim.enzymes[instance.enzyme_id] = instance
		sim.enzyme_history[instance.enzyme_id] = []
		for rxn in instance.reactions:
			sim.reactions.append(rxn)
	
	## Apply genes
	for gene in genes:
		var instance = gene.create_instance()
		sim.genes[instance.enzyme_id] = instance
	
	## Apply suggested settings
	sim.time_scale = suggested_time_scale
	if suggest_lock_mutations:
		sim.lock_mutations = true
	if suggest_lock_evolution:
		sim.lock_evolution = true
	
	sim.is_initialized = true
	sim.paused = start_paused

#endregion

#region Save/Load

func save_to_file(path: String) -> Error:
	return ResourceSaver.save(self, path)

static func load_from_file(path: String) -> PathwayPreset:
	if not ResourceLoader.exists(path):
		push_error("Pathway preset file not found: %s" % path)
		return null
	
	var resource = ResourceLoader.load(path)
	if resource is PathwayPreset:
		return resource
	
	push_error("Invalid pathway preset file: %s" % path)
	return null

#endregion

#region Display

func get_summary() -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % pathway_name)
	lines.append("Difficulty: %s" % "★".repeat(difficulty))
	if not tags.is_empty():
		lines.append("Tags: %s" % ", ".join(tags))
	lines.append("")
	lines.append(description)
	lines.append("")
	lines.append("Components: %d molecules, %d enzymes, %d genes" % [
		molecules.size(), enzymes.size(), genes.size()
	])
	return "\n".join(lines)

func _to_string() -> String:
	return "PathwayPreset(%s, %d mol, %d enz)" % [pathway_name, molecules.size(), enzymes.size()]

#endregion
