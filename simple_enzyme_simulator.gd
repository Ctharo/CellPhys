### Simplified 3-enzyme feedback loop with source-sink dynamics
### Product C inhibits Enzyme 1, creating negative feedback regulation
### A → B → C → [sink], with continuous A replenishment
#class_name SimpleEnzymeSimulator
#extends Node
#
### Represents a chemical molecule with concentration
#class Molecule:
	#var name: String
	#var concentration: float  ## mM
	#
	#func _init(p_name: String, p_conc: float) -> void:
		#name = p_name
		#concentration = p_conc
#
### Enzyme that catalyzes biochemical transformations
#class Enzyme:
	#var id: String
	#var name: String
	#var concentration: float
	#var vmax: float  ## Max velocity
	#var km: float  ## Michaelis constant
	#
	#var substrate: String
	#var product: String
	#var inhibitor: String = ""  ## Optional feedback inhibitor
	#var inhibition_factor: float = 0.3  ## How much inhibitor reduces activity
	#
	#var current_rate: float = 0.0
	#
	#func _init(p_id: String, p_name: String, p_sub: String, p_prod: String) -> void:
		#id = p_id
		#name = p_name
		#substrate = p_sub
		#product = p_prod
		#concentration = 0.01
		#vmax = 10.0
		#km = 0.5
#
#var molecules: Dictionary = {}  ## {"name": Molecule}
#var enzymes: Array[Enzyme] = []
#
### Source-sink parameters
#var source_rate: float = 2.0  ## Rate of A production (mM/s)
#var sink_rate: float = 1.5  ## Rate of C removal (mM/s)
#
#var timestep: float = 0.1
#var total_time: float = 0.0
#var iteration: int = 0
#var is_paused: bool = false
#
#func _ready() -> void:
	#initialize_molecules()
	#initialize_enzymes()
	#print("✅ Simple 3-Enzyme Feedback Simulator initialized")
	#print("   A → B → C → [sink]")
	#print("   C inhibits Enzyme 1 (negative feedback)")
#
#func _process(delta: float) -> void:
	#if is_paused:
		#return
	#
	#total_time += delta
	#if fmod(total_time, timestep) < delta:
		#simulate_step()
		#iteration += 1
		#if iteration % 10 == 0:
			#print_state()
#
### Initialize the three molecules in the pathway
#func initialize_molecules() -> void:
	#molecules["A"] = Molecule.new("A", 5.0)  ## Starting substrate
	#molecules["B"] = Molecule.new("B", 0.1)  ## Intermediate
	#molecules["C"] = Molecule.new("C", 0.05) ## Final product (inhibitor)
#
### Initialize the three enzymes
#func initialize_enzymes() -> void:
	### Enzyme 1: A → B (inhibited by C)
	#var e1 = Enzyme.new("e1", "Enzyme 1", "A", "B")
	#e1.vmax = 8.0
	#e1.km = 0.5
	#e1.inhibitor = "C"
	#e1.inhibition_factor = 0.3
	#enzymes.append(e1)
	#
	### Enzyme 2: B → C
	#var e2 = Enzyme.new("e2", "Enzyme 2", "B", "C")
	#e2.vmax = 6.0
	#e2.km = 0.3
	#enzymes.append(e2)
	#
	### Enzyme 3: C → [degradation/export]
	#var e3 = Enzyme.new("e3", "Enzyme 3", "C", "C")  ## C is both substrate and product (acts as sink)
	#e3.vmax = 4.0
	#e3.km = 0.2
	#enzymes.append(e3)
#
### Main simulation step
#func simulate_step() -> void:
	### Apply source: continuously produce A
	#apply_source()
	#
	### Each enzyme catalyzes its reaction
	#for enzyme in enzymes:
		#enzyme.current_rate = calculate_enzyme_rate(enzyme)
		#apply_catalysis(enzyme)
	#
	### Apply sink: remove C
	#apply_sink()
	#
	### Prevent negative concentrations
	#for mol in molecules.values():
		#mol.concentration = max(mol.concentration, 0.0)
#
### Source: Continuously produce molecule A
#func apply_source() -> void:
	#molecules["A"].concentration += source_rate * timestep
#
### Sink: Remove molecule C (degradation/export)
#func apply_sink() -> void:
	#var removal = sink_rate * timestep
	#molecules["C"].concentration = max(0.0, molecules["C"].concentration - removal)
#
### Calculate enzyme reaction rate using Michaelis-Menten kinetics with inhibition
#func calculate_enzyme_rate(enzyme: Enzyme) -> float:
	#if not molecules.has(enzyme.substrate):
		#return 0.0
	#
	#var substrate_conc = molecules[enzyme.substrate].concentration
	#var vmax = enzyme.vmax * enzyme.concentration
	#
	### Apply feedback inhibition if present
	#if enzyme.inhibitor != "" and molecules.has(enzyme.inhibitor):
		#var inhibitor_conc = molecules[enzyme.inhibitor].concentration
		#var inhibition_strength = inhibitor_conc / (inhibitor_conc + 0.5)  ## Hill-like
		#vmax *= (1.0 - inhibition_strength * (1.0 - enzyme.inhibition_factor))
	#
	### Michaelis-Menten equation
	#var rate = (vmax * substrate_conc) / (enzyme.km + substrate_conc)
	#return rate
#
### Apply enzyme catalysis: consume substrate, produce product
#func apply_catalysis(enzyme: Enzyme) -> void:
	#var amount = enzyme.current_rate * timestep
	#
	### For enzyme 3, act as a sink (consume C without producing)
	#if enzyme.id == "e3":
		#molecules[enzyme.substrate].concentration -= amount
		#return
	#
	### Normal catalysis
	#molecules[enzyme.substrate].concentration -= amount
	#molecules[enzyme.product].concentration += amount
#
### Print current state
#func print_state() -> void:
	#print("\n=== Iteration %d (t=%.1fs) ===" % [iteration, total_time])
	#
	#print("\n🧬 MOLECULES:")
	#for mol_name in ["A", "B", "C"]:
		#if molecules.has(mol_name):
			#print("  %s: %.3f mM" % [mol_name, molecules[mol_name].concentration])
	#
	#print("\n⚗️  ENZYME RATES:")
	#for enzyme in enzymes:
		#var inhibition_info = ""
		#if enzyme.inhibitor != "":
			#var c_conc = molecules["C"].concentration
			#inhibition_info = " (inhibited by C=%.3f)" % c_conc
		#print("  %s (%s→%s): %.3f mM/s%s" % \
			#[enzyme.name, enzyme.substrate, enzyme.product, enzyme.current_rate, inhibition_info])
#
### Getters for external access
#func get_molecule_conc(mol_name: String) -> float:
	#if molecules.has(mol_name):
		#return molecules[mol_name].concentration
	#return 0.0
#
#func set_molecule_conc(mol_name: String, conc: float) -> void:
	#if molecules.has(mol_name):
		#molecules[mol_name].concentration = conc
#
#func get_enzyme_rate(enzyme_id: String) -> float:
	#for enzyme in enzymes:
		#if enzyme.id == enzyme_id:
			#return enzyme.current_rate
	#return 0.0
#
#func set_source_rate(rate: float) -> void:
	#source_rate = rate
#
#func set_sink_rate(rate: float) -> void:
	#sink_rate = rate
#
#func pause() -> void:
	#is_paused = true
#
#func resume() -> void:
	#is_paused = false
