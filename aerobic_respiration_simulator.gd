extends Node

class_name AerobicRespirationSimulator

# ============= MOLECULE CONCENTRATIONS (mM) =============
var glucose: float = 5.0
var pyruvate: float = 0.1
var acetyl_coa: float = 0.05
var citrate: float = 0.1
var isocitrate: float = 0.05
var alpha_ketoglutarate: float = 0.08
var succinyl_coa: float = 0.02
var succinate: float = 0.1
var fumarate: float = 0.05
var malate: float = 0.1
var oxaloacetate: float = 0.15
var nadh: float = 0.5
var nad: float = 5.0
var fadh2: float = 0.3
var fad: float = 3.0
var atp: float = 2.0
var adp: float = 3.0
var amp: float = 0.5
var oxygen: float = 1.0
var water: float = 55.0
var co2: float = 0.1

# ============= ENZYME KINETIC PARAMETERS =============
# Vmax (μmol/min/mg protein) and Km (mM)
var vmax_hexokinase: float = 10.0
var km_hexokinase_glucose: float = 0.5

var vmax_pfk: float = 25.0  # Phosphofructokinase - rate limiting
var km_pfk_glucose6p: float = 1.0

var vmax_pyruvate_dehydrogenase: float = 8.0
var km_pdh_pyruvate: float = 0.2

var vmax_citrate_synthase: float = 12.0
var km_cs_acetyl_coa: float = 0.01
var km_cs_oxaloacetate: float = 0.01

var vmax_isocitrate_dehydrogenase: float = 10.0
var km_icdh_isocitrate: float = 0.05

var vmax_alpha_kg_dehydrogenase: float = 8.0
var km_akgdh_alpha_kg: float = 0.08

var vmax_succinate_dehydrogenase: float = 6.0
var km_sdh_succinate: float = 0.2

var vmax_malate_dehydrogenase: float = 15.0
var km_mdh_malate: float = 0.1

var vmax_electron_transport: float = 20.0
var km_nadh: float = 0.1
var km_oxygen: float = 0.001

# ============= ALLOSTERIC REGULATION FACTORS =============
var atp_threshold: float = 2.5
var nadh_threshold: float = 1.0
var citrate_feedback_threshold: float = 0.3

var inhibition_factor: float = 1.0

# ============= SIMULATION PARAMETERS =============
var timestep: float = 0.1  # seconds
var total_time: float = 0.0
var iteration: int = 0

# ============= DEBUG INFO =============
var reaction_rates: Dictionary = {}

func _ready() -> void:
	print("🧬 Aerobic Respiration Biochemistry Simulator initialized")
	print("Starting concentrations:")
	print_state()

func _process(delta: float) -> void:
	# Run simulation at fixed timestep
	total_time += delta
	
	if fmod(total_time, timestep) >= 0.0 and fmod(total_time, timestep) < timestep:
		simulate_step()
		iteration += 1
		
		# Print state every 10 iterations
		if iteration % 10 == 0:
			print("\n--- Iteration %d (t=%.2fs) ---" % [iteration, total_time])
			print_state()
			print("Reaction rates (μmol/min):")
			for rxn_name in reaction_rates:
				print("  %s: %.4f" % [rxn_name, reaction_rates[rxn_name]])

func simulate_step() -> void:
	"""Main simulation loop - execute all reactions"""
	
	# Calculate allosteric regulation
	calculate_inhibition_factors()
	
	# GLYCOLYSIS
	var r_hexokinase = michaelis_menten(vmax_hexokinase, km_hexokinase_glucose, glucose) * inhibition_factor
	var r_pfk = michaelis_menten(vmax_pfk, km_pfk_glucose6p, glucose) * inhibition_factor  # Rate limiting
	
	# PYRUVATE OXIDATION
	var r_pdh = michaelis_menten(vmax_pyruvate_dehydrogenase, km_pdh_pyruvate, pyruvate)
	
	# CITRIC ACID CYCLE
	var r_citrate_synthase = michaelis_menten_2substrate(
		vmax_citrate_synthase, 
		km_cs_acetyl_coa, acetyl_coa,
		km_cs_oxaloacetate, oxaloacetate
	)
	
	var r_icdh = michaelis_menten(vmax_isocitrate_dehydrogenase, km_icdh_isocitrate, isocitrate)
	var r_akgdh = michaelis_menten(vmax_alpha_kg_dehydrogenase, km_akgdh_alpha_kg, alpha_ketoglutarate)
	var r_sdh = michaelis_menten(vmax_succinate_dehydrogenase, km_sdh_succinate, succinate)
	var r_mdh = michaelis_menten(vmax_malate_dehydrogenase, km_mdh_malate, malate)
	
	# ELECTRON TRANSPORT CHAIN & OXIDATIVE PHOSPHORYLATION
	var r_etc = calculate_etc_rate()
	
	# Store rates for debugging
	reaction_rates["Hexokinase"] = r_hexokinase
	reaction_rates["PFK"] = r_pfk
	reaction_rates["PDH"] = r_pdh
	reaction_rates["Citrate Synthase"] = r_citrate_synthase
	reaction_rates["ICDH"] = r_icdh
	reaction_rates["αKGDH"] = r_akgdh
	reaction_rates["SDH"] = r_sdh
	reaction_rates["MDH"] = r_mdh
	reaction_rates["ETC"] = r_etc
	
	# Apply stoichiometric changes (Δconcentration = rate × timestep)
	# Glycolysis: 1 Glucose → 2 Pyruvate (simplified)
	glucose -= r_hexokinase * timestep
	pyruvate += 2.0 * r_pfk * timestep
	
	# Pyruvate oxidation: Pyruvate + CoA → Acetyl-CoA
	pyruvate -= r_pdh * timestep
	acetyl_coa += r_pdh * timestep
	co2 += r_pdh * timestep
	
	# Citric Acid Cycle reactions
	acetyl_coa -= r_citrate_synthase * timestep
	oxaloacetate -= r_citrate_synthase * timestep
	citrate += r_citrate_synthase * timestep
	
	citrate -= r_icdh * timestep
	isocitrate += r_icdh * timestep
	nadh += r_icdh * timestep
	nad -= r_icdh * timestep
	co2 += r_icdh * timestep
	
	isocitrate -= r_akgdh * timestep
	alpha_ketoglutarate += r_akgdh * timestep
	nadh += r_akgdh * timestep
	nad -= r_akgdh * timestep
	co2 += r_akgdh * timestep
	
	alpha_ketoglutarate -= r_sdh * timestep
	succinate += r_sdh * timestep
	
	succinate -= r_sdh * timestep
	fumarate += r_sdh * timestep
	fadh2 += r_sdh * timestep
	fad -= r_sdh * timestep
	
	fumarate -= r_mdh * timestep
	malate += r_mdh * timestep
	
	malate -= r_mdh * timestep
	oxaloacetate += r_mdh * timestep
	
	# Electron Transport Chain
	nadh -= r_etc * timestep
	nad += r_etc * timestep
	oxygen -= r_etc * 0.5 * timestep
	water += r_etc * 0.5 * timestep
	atp += r_etc * 2.5 * timestep  # ~2.5 ATP per NADH
	adp -= r_etc * 2.5 * timestep
	
	# Clamp negative concentrations
	clamp_concentrations()

func calculate_inhibition_factors() -> void:
	"""Calculate allosteric inhibition based on energy charge and product accumulation"""
	
	# Calculate energy charge: (ATP + 0.5*ADP) / (ATP + ADP + AMP)
	var total_adenine = atp + adp + amp
	var energy_charge = (atp + 0.5 * adp) / max(total_adenine, 0.1)
	
	# Calculate NADH/NAD ratio
	var nadh_nad_ratio = nadh / max(nad, 0.1)
	
	# PFK is inhibited by high ATP and low AMP
	var pfk_inhibition = clamp(energy_charge / atp_threshold, 0.0, 1.0)
	var citrate_inhibition = clamp(citrate / citrate_feedback_threshold, 0.0, 1.0)
	var nadh_inhibition = clamp(nadh_nad_ratio / nadh_threshold, 0.0, 1.0)
	
	# Combined inhibition (multiplicative)
	inhibition_factor = (1.0 - pfk_inhibition * 0.7) * (1.0 - citrate_inhibition * 0.5) * (1.0 - nadh_inhibition * 0.6)
	inhibition_factor = clamp(inhibition_factor, 0.1, 1.0)

func calculate_etc_rate() -> float:
	"""Electron Transport Chain rate depends on NADH, oxygen, and ATP/ADP ratio"""
	
	var nadh_term = michaelis_menten(1.0, km_nadh, nadh)
	var oxygen_term = michaelis_menten(1.0, km_oxygen, oxygen)
	
	# High ATP/ADP ratio inhibits ETC (respiratory control)
	var atp_adp_ratio = atp / max(adp, 0.1)
	var respiratory_control = 1.0 / (1.0 + atp_adp_ratio * 0.5)
	
	return vmax_electron_transport * nadh_term * oxygen_term * respiratory_control

func michaelis_menten(vmax: float, km: float, substrate: float) -> float:
	"""Classic Michaelis-Menten equation: v = (Vmax * [S]) / (Km + [S])"""
	return (vmax * substrate) / (km + substrate)

func michaelis_menten_2substrate(
	vmax: float, 
	km1: float, s1: float,
	km2: float, s2: float
) -> float:
	"""Two-substrate Michaelis-Menten (random order)"""
	return (vmax * s1 * s2) / ((km1 + s1) * (km2 + s2))

func clamp_concentrations() -> void:
	"""Prevent negative concentrations"""
	glucose = max(glucose, 0.0)
	pyruvate = max(pyruvate, 0.0)
	acetyl_coa = max(acetyl_coa, 0.0)
	citrate = max(citrate, 0.0)
	isocitrate = max(isocitrate, 0.0)
	alpha_ketoglutarate = max(alpha_ketoglutarate, 0.0)
	succinate = max(succinate, 0.0)
	fumarate = max(fumarate, 0.0)
	malate = max(malate, 0.0)
	oxaloacetate = max(oxaloacetate, 0.0)
	nadh = max(nadh, 0.0)
	nad = max(nad, 0.0)
	fadh2 = max(fadh2, 0.0)
	fad = max(fad, 0.0)
	atp = max(atp, 0.0)
	adp = max(adp, 0.0)
	amp = max(amp, 0.0)
	oxygen = max(oxygen, 0.0)
	co2 = max(co2, 0.0)

func print_state() -> void:
	"""Print current state to console"""
	print("💊 GLYCOLYTIC INTERMEDIATES:")
	print("  Glucose: %.3f mM" % glucose)
	print("  Pyruvate: %.3f mM" % pyruvate)
	
	print("🔄 CITRIC ACID CYCLE:")
	print("  Acetyl-CoA: %.3f mM | Citrate: %.3f mM | Isocitrate: %.3f mM" % [acetyl_coa, citrate, isocitrate])
	print("  α-Ketoglutarate: %.3f mM | Succinate: %.3f mM | Fumarate: %.3f mM" % [alpha_ketoglutarate, succinate, fumarate])
	print("  Malate: %.3f mM | Oxaloacetate: %.3f mM" % [malate, oxaloacetate])
	
	print("⚡ REDOX COFACTORS:")
	var nadh_nad_ratio = nadh / max(nad, 0.1)
	var fadh2_fad_ratio = fadh2 / max(fad, 0.1)
	print("  NADH: %.3f mM | NAD+: %.3f mM | Ratio: %.3f" % [nadh, nad, nadh_nad_ratio])
	print("  FADH2: %.3f mM | FAD: %.3f mM | Ratio: %.3f" % [fadh2, fad, fadh2_fad_ratio])
	
	print("🔋 ENERGY MOLECULES:")
	var total_adenine = atp + adp + amp
	var energy_charge = (atp + 0.5 * adp) / max(total_adenine, 0.1)
	print("  ATP: %.3f mM | ADP: %.3f mM | AMP: %.3f mM" % [atp, adp, amp])
	print("  Energy Charge: %.3f" % energy_charge)
	
	print("🌊 OTHER:")
	print("  O2: %.3f mM | CO2: %.3f mM | H2O: %.3f mM" % [oxygen, co2, water])
	print("  Inhibition Factor: %.3f" % inhibition_factor)

func get_energy_output() -> float:
	"""Calculate ATP yield per glucose (theoretical max: ~30-32 ATP)"""
	return atp

func get_nadh_accumulation() -> float:
	"""Get NADH/NAD ratio as indicator of oxidative state"""
	return nadh / max(nad, 0.1)

func stress_oxygen() -> void:
	"""Simulate hypoxia/anaerobic conditions"""
	oxygen = 0.01
	print("\n⚠️ OXYGEN DEPLETION - System switching to anaerobic metabolism!")

func add_glucose(amount: float) -> void:
	"""Simulate glucose feeding"""
	glucose += amount
	print("➕ Added %.2f mM glucose (now: %.2f mM)" % [amount, glucose])
