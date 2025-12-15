## PathwayPreset - defines a reusable metabolic pathway template
## Includes real biochemistry pathways: Glycolysis, Krebs Cycle, etc.
class_name PathwayPreset
extends Resource

#region Metadata

@export var pathway_name: String = "Unnamed Pathway"
@export_multiline var description: String = ""
@export var author: String = ""
@export var tags: Array[String] = []
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
@export var suggested_duration: float = 60.0
@export var start_paused: bool = true

@export_group("Lock Suggestions")
@export var suggest_lock_mutations: bool = true
@export var suggest_lock_evolution: bool = true

#endregion

#region Static Factory - Built-in Pathways

## Default pathway - simple linear chain for testing/random generation
static func create_default(steps: int = 4) -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Default Linear"
	preset.description = "Simple linear pathway for testing. Substrate flows through sequential reactions."
	preset.tags = ["default", "linear", "basic"] as Array[String]
	preset.difficulty = 1
	
	var mol_names: Array[String] = []
	for i in range(steps + 1):
		var mol = MoleculeData.new("M%d" % i)
		mol.concentration = 5.0 if i == 0 else 0.1
		mol.initial_concentration = mol.concentration
		mol.is_locked = (i == 0)
		preset.molecules.append(mol)
		mol_names.append(mol.molecule_name)
	
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
		
		var gene = GeneData.new("gene_%d" % i, enz.enzyme_id, 0.0001)
		preset.genes.append(gene)
	
	preset.suggested_duration = 60.0
	return preset


## Glycolysis - glucose breakdown to pyruvate
## Simplified to key regulatory steps
static func create_glycolysis() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Glycolysis"
	preset.description = "Glucose catabolism to pyruvate. The fundamental energy-yielding pathway in nearly all organisms. Produces 2 ATP and 2 NADH per glucose."
	preset.tags = ["glycolysis", "metabolism", "energy", "real"] as Array[String]
	preset.difficulty = 3
	preset.author = "Biochemistry"
	
	## Molecules
	var glucose = _mol("Glucose", 5.0, true)
	var g6p = _mol("G6P", 0.1)  ## Glucose-6-phosphate
	var f6p = _mol("F6P", 0.05)  ## Fructose-6-phosphate
	var fbp = _mol("FBP", 0.05)  ## Fructose-1,6-bisphosphate
	var g3p = _mol("G3P", 0.02)  ## Glyceraldehyde-3-phosphate
	var bpg = _mol("1,3-BPG", 0.01)  ## 1,3-bisphosphoglycerate
	var pg3 = _mol("3PG", 0.02)  ## 3-phosphoglycerate
	var pep = _mol("PEP", 0.02)  ## Phosphoenolpyruvate
	var pyruvate = _mol("Pyruvate", 0.1)
	
	## Cofactors (locked as constant pools)
	var atp = _mol("ATP", 3.0, true)
	var adp = _mol("ADP", 1.0, true)
	var nad = _mol("NAD+", 1.0, true)
	var nadh = _mol("NADH", 0.1, true)
	var pi = _mol("Pi", 5.0, true)
	
	preset.molecules = [glucose, g6p, f6p, fbp, g3p, bpg, pg3, pep, pyruvate, atp, adp, nad, nadh, pi] as Array[MoleculeData]
	
	## Step 1: Hexokinase - Glucose + ATP → G6P + ADP (ΔG°' = -16.7 kJ/mol)
	var hexokinase = EnzymeData.new("hexokinase", "Hexokinase")
	hexokinase.concentration = 0.005
	hexokinase.initial_concentration = 0.005
	var rxn1 = ReactionData.new("rxn_hk")
	rxn1.substrates = {"Glucose": 1.0, "ATP": 1.0}
	rxn1.products = {"G6P": 1.0, "ADP": 1.0}
	rxn1.delta_g = -16.7
	rxn1.vmax = 15.0
	rxn1.km = 0.1
	rxn1.is_irreversible = true
	hexokinase.add_reaction(rxn1)
	
	## Step 2: Phosphoglucose isomerase - G6P ⇄ F6P (ΔG°' = +1.7 kJ/mol)
	var pgi = EnzymeData.new("pgi", "Phosphoglucose Isomerase")
	pgi.concentration = 0.01
	pgi.initial_concentration = 0.01
	var rxn2 = ReactionData.new("rxn_pgi")
	rxn2.substrates = {"G6P": 1.0}
	rxn2.products = {"F6P": 1.0}
	rxn2.delta_g = 1.7
	rxn2.vmax = 20.0
	rxn2.km = 0.5
	pgi.add_reaction(rxn2)
	
	## Step 3: PFK-1 - F6P + ATP → FBP + ADP (ΔG°' = -14.2 kJ/mol) - KEY REGULATORY
	var pfk = EnzymeData.new("pfk1", "Phosphofructokinase-1")
	pfk.concentration = 0.003
	pfk.initial_concentration = 0.003
	var rxn3 = ReactionData.new("rxn_pfk")
	rxn3.substrates = {"F6P": 1.0, "ATP": 1.0}
	rxn3.products = {"FBP": 1.0, "ADP": 1.0}
	rxn3.delta_g = -14.2
	rxn3.vmax = 12.0
	rxn3.km = 0.2
	rxn3.is_irreversible = true
	pfk.add_reaction(rxn3)
	
	## Step 4: Aldolase - FBP ⇄ 2 G3P (ΔG°' = +23.8 kJ/mol, but driven forward)
	var aldolase = EnzymeData.new("aldolase", "Aldolase")
	aldolase.concentration = 0.008
	aldolase.initial_concentration = 0.008
	var rxn4 = ReactionData.new("rxn_aldo")
	rxn4.substrates = {"FBP": 1.0}
	rxn4.products = {"G3P": 2.0}
	rxn4.delta_g = 23.8
	rxn4.vmax = 18.0
	rxn4.km = 0.3
	aldolase.add_reaction(rxn4)
	
	## Step 5: GAPDH - G3P + NAD+ + Pi ⇄ 1,3-BPG + NADH (ΔG°' = +6.3 kJ/mol)
	var gapdh = EnzymeData.new("gapdh", "GAPDH")
	gapdh.concentration = 0.015
	gapdh.initial_concentration = 0.015
	var rxn5 = ReactionData.new("rxn_gapdh")
	rxn5.substrates = {"G3P": 1.0, "NAD+": 1.0, "Pi": 1.0}
	rxn5.products = {"1,3-BPG": 1.0, "NADH": 1.0}
	rxn5.delta_g = 6.3
	rxn5.vmax = 25.0
	rxn5.km = 0.1
	gapdh.add_reaction(rxn5)
	
	## Step 6: PGK - 1,3-BPG + ADP ⇄ 3PG + ATP (ΔG°' = -18.5 kJ/mol)
	var pgk = EnzymeData.new("pgk", "Phosphoglycerate Kinase")
	pgk.concentration = 0.01
	pgk.initial_concentration = 0.01
	var rxn6 = ReactionData.new("rxn_pgk")
	rxn6.substrates = {"1,3-BPG": 1.0, "ADP": 1.0}
	rxn6.products = {"3PG": 1.0, "ATP": 1.0}
	rxn6.delta_g = -18.5
	rxn6.vmax = 20.0
	rxn6.km = 0.2
	pgk.add_reaction(rxn6)
	
	## Steps 7-8 combined: 3PG → PEP (via 2PG, simplified)
	var enolase = EnzymeData.new("enolase", "Enolase")
	enolase.concentration = 0.008
	enolase.initial_concentration = 0.008
	var rxn7 = ReactionData.new("rxn_enolase")
	rxn7.substrates = {"3PG": 1.0}
	rxn7.products = {"PEP": 1.0}
	rxn7.delta_g = 1.8
	rxn7.vmax = 15.0
	rxn7.km = 0.3
	enolase.add_reaction(rxn7)
	
	## Step 9: Pyruvate kinase - PEP + ADP → Pyruvate + ATP (ΔG°' = -31.4 kJ/mol)
	var pk = EnzymeData.new("pk", "Pyruvate Kinase")
	pk.concentration = 0.006
	pk.initial_concentration = 0.006
	var rxn8 = ReactionData.new("rxn_pk")
	rxn8.substrates = {"PEP": 1.0, "ADP": 1.0}
	rxn8.products = {"Pyruvate": 1.0, "ATP": 1.0}
	rxn8.delta_g = -31.4
	rxn8.vmax = 18.0
	rxn8.km = 0.15
	rxn8.is_irreversible = true
	pk.add_reaction(rxn8)
	
	## Pyruvate sink (represents further metabolism)
	var pyr_sink = EnzymeData.new("pyr_sink", "Pyruvate Export")
	pyr_sink.concentration = 0.002
	pyr_sink.initial_concentration = 0.002
	pyr_sink.is_degradable = false
	var rxn_sink = ReactionData.new("rxn_pyr_sink")
	rxn_sink.substrates = {"Pyruvate": 1.0}
	rxn_sink.delta_g = -5.0
	rxn_sink.vmax = 8.0
	rxn_sink.is_irreversible = true
	pyr_sink.add_reaction(rxn_sink)
	
	preset.enzymes = [hexokinase, pgi, pfk, aldolase, gapdh, pgk, enolase, pk, pyr_sink]  as Array[EnzymeData]
	
	## Gene regulation - PFK is inhibited by ATP (allosteric), activated by AMP
	var gene_hk = GeneData.new("gene_hk", "hexokinase", 0.0001)
	var gene_pgi = GeneData.new("gene_pgi", "pgi", 0.0001)
	var gene_pfk = GeneData.new("gene_pfk", "pfk1", 0.00015)
	gene_pfk.add_repressor("ATP", 5.0, 5.0, 2.0)  ## ATP inhibits PFK expression
	var gene_aldo = GeneData.new("gene_aldo", "aldolase", 0.0001)
	var gene_gapdh = GeneData.new("gene_gapdh", "gapdh", 0.0002)
	var gene_pgk = GeneData.new("gene_pgk", "pgk", 0.0001)
	var gene_eno = GeneData.new("gene_eno", "enolase", 0.0001)
	var gene_pk = GeneData.new("gene_pk", "pk", 0.0001)
	
	preset.genes = [gene_hk, gene_pgi, gene_pfk, gene_aldo, gene_gapdh, gene_pgk, gene_eno, gene_pk] as Array[GeneData]
	
	preset.suggested_duration = 120.0
	preset.suggested_time_scale = 1.0
	return preset


## Krebs Cycle (Citric Acid Cycle / TCA Cycle)
static func create_krebs_cycle() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Krebs Cycle"
	preset.description = "The citric acid cycle oxidizes acetyl-CoA to CO2, generating NADH, FADH2, and GTP. Central hub of aerobic metabolism."
	preset.tags = ["krebs", "tca", "citric acid", "metabolism", "real"] as Array[String]
	preset.difficulty = 4
	preset.author = "Biochemistry"
	
	## Cycle intermediates
	var acetyl_coa = _mol("Acetyl-CoA", 0.5, true)  ## Input (locked as constant supply)
	var oxaloacetate = _mol("Oxaloacetate", 0.02)
	var citrate = _mol("Citrate", 0.1)
	var isocitrate = _mol("Isocitrate", 0.05)
	var alpha_kg = _mol("α-Ketoglutarate", 0.05)
	var succinyl_coa = _mol("Succinyl-CoA", 0.02)
	var succinate = _mol("Succinate", 0.05)
	var fumarate = _mol("Fumarate", 0.03)
	var malate = _mol("Malate", 0.04)
	
	## Cofactors
	var coa = _mol("CoA-SH", 0.5, true)
	var nad = _mol("NAD+", 2.0, true)
	var nadh = _mol("NADH", 0.2, true)
	var fad = _mol("FAD", 0.5, true)
	var fadh2 = _mol("FADH2", 0.1, true)
	var gdp = _mol("GDP", 0.5, true)
	var gtp = _mol("GTP", 0.1, true)
	var co2 = _mol("CO2", 0.1)
	
	preset.molecules = [acetyl_coa, oxaloacetate, citrate, isocitrate, alpha_kg, 
		succinyl_coa, succinate, fumarate, malate, coa, nad, nadh, fad, fadh2, gdp, gtp, co2] as Array[MoleculeData]
	
	## 1. Citrate synthase: Acetyl-CoA + Oxaloacetate + H2O → Citrate + CoA-SH (ΔG°' = -32.2)
	var cs = EnzymeData.new("cs", "Citrate Synthase")
	cs.concentration = 0.005
	cs.initial_concentration = 0.005
	var rxn1 = ReactionData.new("rxn_cs")
	rxn1.substrates = {"Acetyl-CoA": 1.0, "Oxaloacetate": 1.0}
	rxn1.products = {"Citrate": 1.0, "CoA-SH": 1.0}
	rxn1.delta_g = -32.2
	rxn1.vmax = 10.0
	rxn1.km = 0.02
	rxn1.is_irreversible = true
	cs.add_reaction(rxn1)
	
	## 2. Aconitase: Citrate ⇄ Isocitrate (ΔG°' = +6.3)
	var acon = EnzymeData.new("acon", "Aconitase")
	acon.concentration = 0.008
	acon.initial_concentration = 0.008
	var rxn2 = ReactionData.new("rxn_acon")
	rxn2.substrates = {"Citrate": 1.0}
	rxn2.products = {"Isocitrate": 1.0}
	rxn2.delta_g = 6.3
	rxn2.vmax = 15.0
	rxn2.km = 0.2
	acon.add_reaction(rxn2)
	
	## 3. Isocitrate dehydrogenase: Isocitrate + NAD+ → α-KG + NADH + CO2 (ΔG°' = -20.9)
	var idh = EnzymeData.new("idh", "Isocitrate Dehydrogenase")
	idh.concentration = 0.004
	idh.initial_concentration = 0.004
	var rxn3 = ReactionData.new("rxn_idh")
	rxn3.substrates = {"Isocitrate": 1.0, "NAD+": 1.0}
	rxn3.products = {"α-Ketoglutarate": 1.0, "NADH": 1.0, "CO2": 1.0}
	rxn3.delta_g = -20.9
	rxn3.vmax = 8.0
	rxn3.km = 0.05
	rxn3.is_irreversible = true
	idh.add_reaction(rxn3)
	
	## 4. α-KG dehydrogenase: α-KG + NAD+ + CoA → Succinyl-CoA + NADH + CO2 (ΔG°' = -33.5)
	var akgdh = EnzymeData.new("akgdh", "α-KG Dehydrogenase")
	akgdh.concentration = 0.003
	akgdh.initial_concentration = 0.003
	var rxn4 = ReactionData.new("rxn_akgdh")
	rxn4.substrates = {"α-Ketoglutarate": 1.0, "NAD+": 1.0, "CoA-SH": 1.0}
	rxn4.products = {"Succinyl-CoA": 1.0, "NADH": 1.0, "CO2": 1.0}
	rxn4.delta_g = -33.5
	rxn4.vmax = 6.0
	rxn4.km = 0.03
	rxn4.is_irreversible = true
	akgdh.add_reaction(rxn4)
	
	## 5. Succinyl-CoA synthetase: Succinyl-CoA + GDP + Pi ⇄ Succinate + GTP + CoA (ΔG°' = -2.9)
	var scs = EnzymeData.new("scs", "Succinyl-CoA Synthetase")
	scs.concentration = 0.006
	scs.initial_concentration = 0.006
	var rxn5 = ReactionData.new("rxn_scs")
	rxn5.substrates = {"Succinyl-CoA": 1.0, "GDP": 1.0}
	rxn5.products = {"Succinate": 1.0, "GTP": 1.0, "CoA-SH": 1.0}
	rxn5.delta_g = -2.9
	rxn5.vmax = 12.0
	rxn5.km = 0.1
	scs.add_reaction(rxn5)
	
	## 6. Succinate dehydrogenase: Succinate + FAD ⇄ Fumarate + FADH2 (ΔG°' = 0)
	var sdh = EnzymeData.new("sdh", "Succinate Dehydrogenase")
	sdh.concentration = 0.005
	sdh.initial_concentration = 0.005
	var rxn6 = ReactionData.new("rxn_sdh")
	rxn6.substrates = {"Succinate": 1.0, "FAD": 1.0}
	rxn6.products = {"Fumarate": 1.0, "FADH2": 1.0}
	rxn6.delta_g = 0.0
	rxn6.vmax = 10.0
	rxn6.km = 0.15
	sdh.add_reaction(rxn6)
	
	## 7. Fumarase: Fumarate + H2O ⇄ Malate (ΔG°' = -3.8)
	var fum = EnzymeData.new("fum", "Fumarase")
	fum.concentration = 0.01
	fum.initial_concentration = 0.01
	var rxn7 = ReactionData.new("rxn_fum")
	rxn7.substrates = {"Fumarate": 1.0}
	rxn7.products = {"Malate": 1.0}
	rxn7.delta_g = -3.8
	rxn7.vmax = 18.0
	rxn7.km = 0.2
	fum.add_reaction(rxn7)
	
	## 8. Malate dehydrogenase: Malate + NAD+ ⇄ Oxaloacetate + NADH (ΔG°' = +29.7)
	var mdh = EnzymeData.new("mdh", "Malate Dehydrogenase")
	mdh.concentration = 0.012
	mdh.initial_concentration = 0.012
	var rxn8 = ReactionData.new("rxn_mdh")
	rxn8.substrates = {"Malate": 1.0, "NAD+": 1.0}
	rxn8.products = {"Oxaloacetate": 1.0, "NADH": 1.0}
	rxn8.delta_g = 29.7  ## Highly unfavorable, but pulled by citrate synthase
	rxn8.vmax = 20.0
	rxn8.km = 0.1
	mdh.add_reaction(rxn8)
	
	## CO2 sink
	var co2_sink = EnzymeData.new("co2_sink", "CO2 Export")
	co2_sink.concentration = 0.01
	co2_sink.initial_concentration = 0.01
	co2_sink.is_degradable = false
	var rxn_co2 = ReactionData.new("rxn_co2_sink")
	rxn_co2.substrates = {"CO2": 1.0}
	rxn_co2.delta_g = -10.0
	rxn_co2.vmax = 20.0
	rxn_co2.is_irreversible = true
	co2_sink.add_reaction(rxn_co2)
	
	preset.enzymes = [cs, acon, idh, akgdh, scs, sdh, fum, mdh, co2_sink] as Array[EnzymeData]
	
	## Genes with regulation
	var gene_cs = GeneData.new("gene_cs", "cs", 0.0001)
	gene_cs.add_repressor("ATP", 3.0, 3.0, 1.5)  ## ATP inhibits
	gene_cs.add_repressor("NADH", 0.5, 4.0, 1.5)  ## NADH inhibits
	var gene_idh = GeneData.new("gene_idh", "idh", 0.00008)
	gene_idh.add_activator("ADP", 1.0, 3.0, 1.0)  ## ADP activates (simulated)
	var gene_akgdh = GeneData.new("gene_akgdh", "akgdh", 0.00006)
	
	preset.genes = [gene_cs, GeneData.new("gene_acon", "acon", 0.0001), gene_idh, gene_akgdh,
		GeneData.new("gene_scs", "scs", 0.0001), GeneData.new("gene_sdh", "sdh", 0.0001),
		GeneData.new("gene_fum", "fum", 0.0001), GeneData.new("gene_mdh", "mdh", 0.00015)] as Array[GeneData]
	
	preset.suggested_duration = 180.0
	return preset


## Pentose Phosphate Pathway - oxidative branch
static func create_pentose_phosphate() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Pentose Phosphate Pathway"
	preset.description = "Generates NADPH for biosynthesis and ribose-5-phosphate for nucleotide synthesis. Alternative glucose oxidation route."
	preset.tags = ["ppp", "nadph", "biosynthesis", "real"] as Array[String]
	preset.difficulty = 3
	preset.author = "Biochemistry"
	
	## Molecules
	var g6p = _mol("G6P", 1.0, true)
	var gluconolactone = _mol("6-Phosphoglucono-δ-lactone", 0.01)
	var gluconate = _mol("6-Phosphogluconate", 0.05)
	var ribulose5p = _mol("Ribulose-5P", 0.02)
	var ribose5p = _mol("Ribose-5P", 0.05)
	var xylulose5p = _mol("Xylulose-5P", 0.02)
	var co2 = _mol("CO2", 0.1)
	
	var nadp = _mol("NADP+", 1.0, true)
	var nadph = _mol("NADPH", 0.2, true)
	
	preset.molecules = [g6p, gluconolactone, gluconate, ribulose5p, ribose5p, xylulose5p, co2, nadp, nadph] as Array[MoleculeData]
	
	## G6P dehydrogenase (rate-limiting)
	var g6pdh = EnzymeData.new("g6pdh", "G6P Dehydrogenase")
	g6pdh.concentration = 0.003
	g6pdh.initial_concentration = 0.003
	var rxn1 = ReactionData.new("rxn_g6pdh")
	rxn1.substrates = {"G6P": 1.0, "NADP+": 1.0}
	rxn1.products = {"6-Phosphoglucono-δ-lactone": 1.0, "NADPH": 1.0}
	rxn1.delta_g = -17.6
	rxn1.vmax = 5.0
	rxn1.km = 0.05
	rxn1.is_irreversible = true
	g6pdh.add_reaction(rxn1)
	
	## Lactonase
	var lactonase = EnzymeData.new("lactonase", "6-Phosphogluconolactonase")
	lactonase.concentration = 0.01
	lactonase.initial_concentration = 0.01
	var rxn2 = ReactionData.new("rxn_lactonase")
	rxn2.substrates = {"6-Phosphoglucono-δ-lactone": 1.0}
	rxn2.products = {"6-Phosphogluconate": 1.0}
	rxn2.delta_g = -6.0
	rxn2.vmax = 15.0
	rxn2.km = 0.1
	lactonase.add_reaction(rxn2)
	
	## 6-Phosphogluconate dehydrogenase
	var pgdh = EnzymeData.new("pgdh", "6-Phosphogluconate Dehydrogenase")
	pgdh.concentration = 0.005
	pgdh.initial_concentration = 0.005
	var rxn3 = ReactionData.new("rxn_pgdh")
	rxn3.substrates = {"6-Phosphogluconate": 1.0, "NADP+": 1.0}
	rxn3.products = {"Ribulose-5P": 1.0, "NADPH": 1.0, "CO2": 1.0}
	rxn3.delta_g = -8.9
	rxn3.vmax = 8.0
	rxn3.km = 0.08
	pgdh.add_reaction(rxn3)
	
	## Phosphopentose isomerase
	var ppi = EnzymeData.new("ppi", "Phosphopentose Isomerase")
	ppi.concentration = 0.008
	ppi.initial_concentration = 0.008
	var rxn4 = ReactionData.new("rxn_ppi")
	rxn4.substrates = {"Ribulose-5P": 1.0}
	rxn4.products = {"Ribose-5P": 1.0}
	rxn4.delta_g = 0.5
	rxn4.vmax = 12.0
	rxn4.km = 0.2
	ppi.add_reaction(rxn4)
	
	## Phosphopentose epimerase
	var ppe = EnzymeData.new("ppe", "Phosphopentose Epimerase")
	ppe.concentration = 0.008
	ppe.initial_concentration = 0.008
	var rxn5 = ReactionData.new("rxn_ppe")
	rxn5.substrates = {"Ribulose-5P": 1.0}
	rxn5.products = {"Xylulose-5P": 1.0}
	rxn5.delta_g = 0.0
	rxn5.vmax = 12.0
	rxn5.km = 0.2
	ppe.add_reaction(rxn5)
	
	## Sinks
	var r5p_sink = EnzymeData.new("r5p_sink", "Ribose-5P Utilization")
	r5p_sink.concentration = 0.002
	r5p_sink.is_degradable = false
	var rxn_r5p = ReactionData.new("rxn_r5p_sink")
	rxn_r5p.substrates = {"Ribose-5P": 1.0}
	rxn_r5p.delta_g = -5.0
	rxn_r5p.vmax = 3.0
	rxn_r5p.is_irreversible = true
	r5p_sink.add_reaction(rxn_r5p)
	
	var co2_sink = EnzymeData.new("co2_sink", "CO2 Export")
	co2_sink.concentration = 0.01
	co2_sink.is_degradable = false
	var rxn_co2 = ReactionData.new("rxn_co2_sink")
	rxn_co2.substrates = {"CO2": 1.0}
	rxn_co2.delta_g = -10.0
	rxn_co2.vmax = 15.0
	rxn_co2.is_irreversible = true
	co2_sink.add_reaction(rxn_co2)
	
	preset.enzymes = [g6pdh, lactonase, pgdh, ppi, ppe, r5p_sink, co2_sink] as Array[EnzymeData]
	
	var gene_g6pdh = GeneData.new("gene_g6pdh", "g6pdh", 0.00005)
	gene_g6pdh.add_repressor("NADPH", 0.3, 5.0, 2.0)  ## NADPH inhibits
	
	preset.genes = [gene_g6pdh, GeneData.new("gene_lactonase", "lactonase", 0.0001), 
		GeneData.new("gene_pgdh", "pgdh", 0.00008), GeneData.new("gene_ppi", "ppi", 0.0001),
		GeneData.new("gene_ppe", "ppe", 0.0001)] as Array[GeneData]
	
	preset.suggested_duration = 90.0
	return preset


## Beta-oxidation of fatty acids
static func create_beta_oxidation() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "β-Oxidation"
	preset.description = "Fatty acid catabolism in mitochondria. Each cycle removes 2 carbons as Acetyl-CoA, generating FADH2 and NADH."
	preset.tags = ["beta-oxidation", "fatty acid", "lipid", "real"] as Array[String]
	preset.difficulty = 3
	preset.author = "Biochemistry"
	
	## Simplified: one cycle with C16 fatty acyl-CoA
	var acyl_coa = _mol("Palmitoyl-CoA", 0.5, true)  ## C16
	var enoyl_coa = _mol("Enoyl-CoA", 0.02)
	var hydroxyacyl = _mol("L-3-Hydroxyacyl-CoA", 0.02)
	var ketoacyl = _mol("3-Ketoacyl-CoA", 0.02)
	var acetyl_coa = _mol("Acetyl-CoA", 0.1)
	var shorter_acyl = _mol("Myristoyl-CoA", 0.05)  ## C14 (product)
	
	var fad = _mol("FAD", 1.0, true)
	var fadh2 = _mol("FADH2", 0.1, true)
	var nad = _mol("NAD+", 2.0, true)
	var nadh = _mol("NADH", 0.2, true)
	var coa = _mol("CoA-SH", 0.5, true)
	
	preset.molecules = [acyl_coa, enoyl_coa, hydroxyacyl, ketoacyl, acetyl_coa, 
		shorter_acyl, fad, fadh2, nad, nadh, coa] as Array[MoleculeData]
	
	## Acyl-CoA dehydrogenase
	var acad = EnzymeData.new("acad", "Acyl-CoA Dehydrogenase")
	acad.concentration = 0.005
	acad.initial_concentration = 0.005
	var rxn1 = ReactionData.new("rxn_acad")
	rxn1.substrates = {"Palmitoyl-CoA": 1.0, "FAD": 1.0}
	rxn1.products = {"Enoyl-CoA": 1.0, "FADH2": 1.0}
	rxn1.delta_g = -4.0
	rxn1.vmax = 8.0
	rxn1.km = 0.05
	acad.add_reaction(rxn1)
	
	## Enoyl-CoA hydratase
	var ech = EnzymeData.new("ech", "Enoyl-CoA Hydratase")
	ech.concentration = 0.008
	ech.initial_concentration = 0.008
	var rxn2 = ReactionData.new("rxn_ech")
	rxn2.substrates = {"Enoyl-CoA": 1.0}
	rxn2.products = {"L-3-Hydroxyacyl-CoA": 1.0}
	rxn2.delta_g = -3.0
	rxn2.vmax = 12.0
	rxn2.km = 0.1
	ech.add_reaction(rxn2)
	
	## 3-Hydroxyacyl-CoA dehydrogenase
	var had = EnzymeData.new("had", "3-Hydroxyacyl-CoA Dehydrogenase")
	had.concentration = 0.006
	had.initial_concentration = 0.006
	var rxn3 = ReactionData.new("rxn_had")
	rxn3.substrates = {"L-3-Hydroxyacyl-CoA": 1.0, "NAD+": 1.0}
	rxn3.products = {"3-Ketoacyl-CoA": 1.0, "NADH": 1.0}
	rxn3.delta_g = 6.0
	rxn3.vmax = 10.0
	rxn3.km = 0.08
	had.add_reaction(rxn3)
	
	## Thiolase
	var thiolase = EnzymeData.new("thiolase", "β-Ketothiolase")
	thiolase.concentration = 0.005
	thiolase.initial_concentration = 0.005
	var rxn4 = ReactionData.new("rxn_thiolase")
	rxn4.substrates = {"3-Ketoacyl-CoA": 1.0, "CoA-SH": 1.0}
	rxn4.products = {"Acetyl-CoA": 1.0, "Myristoyl-CoA": 1.0}
	rxn4.delta_g = -8.0
	rxn4.vmax = 8.0
	rxn4.km = 0.05
	thiolase.add_reaction(rxn4)
	
	## Acetyl-CoA sink (enters TCA)
	var acetyl_sink = EnzymeData.new("acetyl_sink", "Acetyl-CoA to TCA")
	acetyl_sink.concentration = 0.003
	acetyl_sink.is_degradable = false
	var rxn_acetyl = ReactionData.new("rxn_acetyl_sink")
	rxn_acetyl.substrates = {"Acetyl-CoA": 1.0}
	rxn_acetyl.delta_g = -5.0
	rxn_acetyl.vmax = 6.0
	rxn_acetyl.is_irreversible = true
	acetyl_sink.add_reaction(rxn_acetyl)
	
	## Shorter acyl-CoA sink (continues cycling)
	var shorter_sink = EnzymeData.new("shorter_sink", "Continue β-Oxidation")
	shorter_sink.concentration = 0.002
	shorter_sink.is_degradable = false
	var rxn_shorter = ReactionData.new("rxn_shorter_sink")
	rxn_shorter.substrates = {"Myristoyl-CoA": 1.0}
	rxn_shorter.delta_g = -3.0
	rxn_shorter.vmax = 4.0
	rxn_shorter.is_irreversible = true
	shorter_sink.add_reaction(rxn_shorter)
	
	preset.enzymes = [acad, ech, had, thiolase, acetyl_sink, shorter_sink] as Array[EnzymeData]
	
	preset.genes = [GeneData.new("gene_acad", "acad", 0.0001),
		GeneData.new("gene_ech", "ech", 0.0001),
		GeneData.new("gene_had", "had", 0.0001),
		GeneData.new("gene_thiolase", "thiolase", 0.0001)] as Array[GeneData]
	
	preset.suggested_duration = 120.0
	return preset


## Urea Cycle
static func create_urea_cycle() -> PathwayPreset:
	var preset = PathwayPreset.new()
	preset.pathway_name = "Urea Cycle"
	preset.description = "Converts toxic ammonia to urea for excretion. Occurs primarily in liver. Links to TCA cycle via fumarate."
	preset.tags = ["urea", "nitrogen", "ammonia", "liver", "real"] as Array[String]
	preset.difficulty = 4
	preset.author = "Biochemistry"
	
	## Cycle intermediates
	var ammonia = _mol("NH3", 0.5, true)
	var carbamoyl_p = _mol("Carbamoyl-P", 0.02)
	var ornithine = _mol("Ornithine", 0.1)
	var citrulline = _mol("Citrulline", 0.05)
	var argininosuccinate = _mol("Argininosuccinate", 0.02)
	var arginine = _mol("Arginine", 0.05)
	var urea = _mol("Urea", 0.1)
	var fumarate = _mol("Fumarate", 0.05)
	
	## Cofactors
	var atp = _mol("ATP", 3.0, true)
	var adp = _mol("ADP", 1.0, true)
	var amp = _mol("AMP", 0.5, true)
	var pi = _mol("Pi", 5.0, true)
	var ppi = _mol("PPi", 0.1, true)
	var aspartate = _mol("Aspartate", 1.0, true)
	var co2 = _mol("CO2", 1.0, true)
	
	preset.molecules = [ammonia, carbamoyl_p, ornithine, citrulline, argininosuccinate, 
		arginine, urea, fumarate, atp, adp, amp, pi, ppi, aspartate, co2] as Array[MoleculeData]
	
	## CPS I: NH3 + CO2 + 2ATP → Carbamoyl-P + 2ADP + Pi
	var cps1 = EnzymeData.new("cps1", "Carbamoyl Phosphate Synthetase I")
	cps1.concentration = 0.003
	cps1.initial_concentration = 0.003
	var rxn1 = ReactionData.new("rxn_cps1")
	rxn1.substrates = {"NH3": 1.0, "CO2": 1.0, "ATP": 2.0}
	rxn1.products = {"Carbamoyl-P": 1.0, "ADP": 2.0, "Pi": 1.0}
	rxn1.delta_g = -24.0
	rxn1.vmax = 5.0
	rxn1.km = 0.1
	rxn1.is_irreversible = true
	cps1.add_reaction(rxn1)
	
	## OTC: Carbamoyl-P + Ornithine → Citrulline + Pi
	var otc = EnzymeData.new("otc", "Ornithine Transcarbamylase")
	otc.concentration = 0.006
	otc.initial_concentration = 0.006
	var rxn2 = ReactionData.new("rxn_otc")
	rxn2.substrates = {"Carbamoyl-P": 1.0, "Ornithine": 1.0}
	rxn2.products = {"Citrulline": 1.0, "Pi": 1.0}
	rxn2.delta_g = -9.0
	rxn2.vmax = 10.0
	rxn2.km = 0.05
	otc.add_reaction(rxn2)
	
	## ASS: Citrulline + Aspartate + ATP → Argininosuccinate + AMP + PPi
	var ass = EnzymeData.new("ass", "Argininosuccinate Synthetase")
	ass.concentration = 0.004
	ass.initial_concentration = 0.004
	var rxn3 = ReactionData.new("rxn_ass")
	rxn3.substrates = {"Citrulline": 1.0, "Aspartate": 1.0, "ATP": 1.0}
	rxn3.products = {"Argininosuccinate": 1.0, "AMP": 1.0, "PPi": 1.0}
	rxn3.delta_g = -7.0
	rxn3.vmax = 8.0
	rxn3.km = 0.08
	ass.add_reaction(rxn3)
	
	## ASL: Argininosuccinate → Arginine + Fumarate
	var asl = EnzymeData.new("asl", "Argininosuccinate Lyase")
	asl.concentration = 0.005
	asl.initial_concentration = 0.005
	var rxn4 = ReactionData.new("rxn_asl")
	rxn4.substrates = {"Argininosuccinate": 1.0}
	rxn4.products = {"Arginine": 1.0, "Fumarate": 1.0}
	rxn4.delta_g = -4.0
	rxn4.vmax = 10.0
	rxn4.km = 0.1
	asl.add_reaction(rxn4)
	
	## Arginase: Arginine → Urea + Ornithine
	var arginase = EnzymeData.new("arginase", "Arginase")
	arginase.concentration = 0.008
	arginase.initial_concentration = 0.008
	var rxn5 = ReactionData.new("rxn_arginase")
	rxn5.substrates = {"Arginine": 1.0}
	rxn5.products = {"Urea": 1.0, "Ornithine": 1.0}
	rxn5.delta_g = -12.0
	rxn5.vmax = 12.0
	rxn5.km = 0.15
	arginase.add_reaction(rxn5)
	
	## Urea sink (excretion)
	var urea_sink = EnzymeData.new("urea_sink", "Urea Excretion")
	urea_sink.concentration = 0.005
	urea_sink.is_degradable = false
	var rxn_urea = ReactionData.new("rxn_urea_sink")
	rxn_urea.substrates = {"Urea": 1.0}
	rxn_urea.delta_g = -8.0
	rxn_urea.vmax = 10.0
	rxn_urea.is_irreversible = true
	urea_sink.add_reaction(rxn_urea)
	
	## Fumarate sink (returns to TCA)
	var fum_sink = EnzymeData.new("fum_sink", "Fumarate to TCA")
	fum_sink.concentration = 0.003
	fum_sink.is_degradable = false
	var rxn_fum = ReactionData.new("rxn_fum_sink")
	rxn_fum.substrates = {"Fumarate": 1.0}
	rxn_fum.delta_g = -3.0
	rxn_fum.vmax = 6.0
	rxn_fum.is_irreversible = true
	fum_sink.add_reaction(rxn_fum)
	
	preset.enzymes = [cps1, otc, ass, asl, arginase, urea_sink, fum_sink] as Array[EnzymeData]
	
	var gene_cps1 = GeneData.new("gene_cps1", "cps1", 0.00005)
	gene_cps1.add_activator("NH3", 0.2, 4.0, 1.5)  ## Activated by substrate
	
	preset.genes = [gene_cps1, GeneData.new("gene_otc", "otc", 0.0001),
		GeneData.new("gene_ass", "ass", 0.00008), GeneData.new("gene_asl", "asl", 0.0001),
		GeneData.new("gene_arginase", "arginase", 0.00012)] as Array[GeneData]
	
	preset.suggested_duration = 150.0
	return preset

#endregion

#region Helpers

## Helper to create a molecule with common defaults
static func _mol(mol_name: String, conc: float, locked: bool = false) -> MoleculeData:
	var mol = MoleculeData.new(mol_name)
	mol.concentration = conc
	mol.initial_concentration = conc
	mol.is_locked = locked
	return mol

#endregion

#region Application

## Apply this preset to a simulator
func apply_to(sim) -> void:
	sim.reset()
	sim.molecules.clear()
	sim.enzymes.clear()
	sim.reactions.clear()
	sim.genes.clear()
	sim.molecule_history.clear()
	sim.enzyme_history.clear()
	sim.time_history.clear()
	
	for mol in molecules:
		var instance = mol.create_instance()
		sim.molecules[instance.molecule_name] = instance
		sim.molecule_history[instance.molecule_name] = []
	
	for enz in enzymes:
		var instance = enz.create_instance()
		sim.enzymes[instance.enzyme_id] = instance
		sim.enzyme_history[instance.enzyme_id] = []
		for rxn in instance.reactions:
			sim.reactions.append(rxn)
	
	for gene in genes:
		var instance = gene.create_instance()
		sim.genes[instance.enzyme_id] = instance
	
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
