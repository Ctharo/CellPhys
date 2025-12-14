## Evolution System - Calculates fitness scores and selection decisions
## Orthogonal module: evaluates fitness, proposes selections, does NOT apply them
## Works with MutationSystem output to create evolutionary pressure
class_name EvolutionSystem
extends RefCounted

#region Fitness Weights (configurable selection pressure)

## How much each metric contributes to fitness (0-1, should sum to ~1)
var weight_efficiency: float = 0.30       ## Reaction efficiency (useful work / total energy)
var weight_flux: float = 0.25             ## Pathway throughput (net reaction rate)
var weight_cost: float = 0.20             ## Protein cost (lower is better)
var weight_thermal: float = 0.15          ## Thermal efficiency (less heat waste)
var weight_regulation: float = 0.10       ## Regulatory responsiveness

## Selection thresholds
var elimination_threshold: float = 0.15   ## Fitness below this = marked for removal
var boost_threshold: float = 0.75         ## Fitness above this = expression boost
var competition_window: float = 0.1       ## Enzymes within this fitness range compete

## Selection rates
var selection_rate: float = 0.1           ## How often selection occurs (per second)
var elimination_rate: float = 0.02        ## Chance to eliminate low-fitness enzyme
var boost_rate: float = 0.05              ## Chance to boost high-fitness enzyme

## Selection timing (referenced by SimulationConfig)
var selection_interval: float = 10.0      ## Seconds between selection events
var fitness_boost_factor: float = 1.2     ## Expression multiplier for high-fitness enzymes

## Population limits
var min_enzymes: int = 3                  ## Don't eliminate below this count
var max_enzymes: int = 20                 ## Encourage elimination above this

#endregion

#region Fitness Tracking

## Rolling fitness history for each enzyme
var fitness_history: Dictionary = {}      ## {enz_id: Array[float]}
var fitness_window: int = 100             ## How many samples to average

## Current fitness scores
var current_fitness: Dictionary = {}      ## {enz_id: float}

## Lineage tracking (for evolutionary analysis)
var lineage_tree: Dictionary = {}         ## {enz_id: {parent: id, generation: int, born: time}}
var generation_count: int = 0

#endregion

#region Selection Result Structure

class SelectionResult:
	var timestamp: float = 0.0
	
	## Enzymes marked for elimination: {enz_id: reason}
	var eliminations: Dictionary = {}
	
	## Enzymes to receive expression boost: {enz_id: boost_factor}
	var boosts: Dictionary = {}
	
	## Competition results (when similar enzymes compete): {loser_id: winner_id}
	var competition_losses: Dictionary = {}
	
	## Gene regulation adjustments: {gene_id: {param: new_value}}
	var gene_adjustments: Dictionary = {}
	
	## Fitness report for UI
	var fitness_report: Dictionary = {}   ## {enz_id: {fitness: f, breakdown: {...}}}
	
	## Statistics
	var eliminations_count: int = 0
	var boosts_count: int = 0
	var competitions_resolved: int = 0
	
	func is_empty() -> bool:
		return eliminations.is_empty() and boosts.is_empty() and competition_losses.is_empty() and gene_adjustments.is_empty()
	
	func get_summary() -> String:
		var parts: Array[String] = []
		if eliminations_count > 0:
			parts.append("-%d" % eliminations_count)
		if boosts_count > 0:
			parts.append("+%d boost" % boosts_count)
		if competitions_resolved > 0:
			parts.append("%d competed" % competitions_resolved)
		if parts.is_empty():
			return "stable"
		return ", ".join(parts)

#endregion

#region Main Calculation (Pure Function)

## Calculate selection decisions - does NOT modify any state
func calculate_selection(snapshot: Dictionary, delta: float, current_time: float) -> SelectionResult:
	var result = SelectionResult.new()
	result.timestamp = current_time
	
	var enzymes: Dictionary = snapshot.enzymes
	var molecules: Dictionary = snapshot.molecules
	var genes: Dictionary = snapshot.genes
	var _reactions: Array = snapshot.reactions
	
	## Step 1: Calculate fitness for all enzymes
	var fitness_scores: Dictionary = {}
	for enz_id in enzymes:
		var enzyme = enzymes[enz_id]
		var breakdown = _calculate_enzyme_fitness(enzyme, molecules, genes)
		fitness_scores[enz_id] = breakdown.total
		result.fitness_report[enz_id] = breakdown
		
		## Update rolling history
		_update_fitness_history(enz_id, breakdown.total)
	
	current_fitness = fitness_scores
	
	## Step 2: Selection events (probabilistic based on delta)
	if not _roll(selection_rate * delta):
		return result
	
	## Step 3: Identify elimination candidates
	var dominated_enzymes = _find_elimination_candidates(enzymes, fitness_scores)
	
	for enz_id in dominated_enzymes:
		if _roll(elimination_rate):
			result.eliminations[enz_id] = dominated_enzymes[enz_id]
			result.eliminations_count += 1
	
	## Step 4: Identify enzymes deserving expression boost
	var elite_enzymes = _find_elite_enzymes(enzymes, fitness_scores)
	
	for enz_id in elite_enzymes:
		if _roll(boost_rate):
			var boost_factor_calc = fitness_boost_factor + (fitness_scores[enz_id] - boost_threshold) * 2.0
			result.boosts[enz_id] = clampf(boost_factor_calc, 1.2, 3.0)
			result.boosts_count += 1
	
	## Step 5: Resolve competition between similar enzymes
	var competitions = _find_competing_enzymes(enzymes, fitness_scores)
	
	for competition in competitions:
		var winner_id = competition.winner
		var loser_id = competition.loser
		
		## Loser gets reduced expression, not immediate elimination
		if not result.eliminations.has(loser_id):
			result.competition_losses[loser_id] = winner_id
			result.competitions_resolved += 1
	
	## Step 6: Adaptive gene regulation based on fitness landscape
	var gene_changes = _calculate_adaptive_regulation(genes, enzymes, fitness_scores, molecules)
	result.gene_adjustments = gene_changes
	
	return result

#endregion

#region Fitness Calculation

## Calculate comprehensive fitness score for an enzyme
func _calculate_enzyme_fitness(enzyme, molecules: Dictionary, genes: Dictionary) -> Dictionary:
	var breakdown = {
		"total": 0.0,
		"efficiency": 0.0,
		"flux": 0.0,
		"cost": 0.0,
		"thermal": 0.0,
		"regulation": 0.0
	}
	
	if enzyme.reactions.is_empty():
		return breakdown
	
	var rxn = enzyme.reactions[0]
	
	## 1. Efficiency score (reaction efficiency + thermodynamic favorability)
	var eff_score = rxn.reaction_efficiency
	if rxn.current_delta_g_actual < 0:
		## Bonus for thermodynamically favorable reactions
		eff_score += min(0.2, -rxn.current_delta_g_actual / 50.0)
	breakdown.efficiency = clampf(eff_score, 0.0, 1.0)
	
	## 2. Flux score (normalized reaction rate)
	var net_rate = abs(rxn.get_net_rate())
	var flux_score = 0.0
	if net_rate > 0.001:
		## Log scale for flux - small flux is bad, large flux saturates
		flux_score = clampf(log(net_rate + 1.0) / log(10.0) + 0.5, 0.0, 1.0)
	breakdown.flux = flux_score
	
	## 3. Cost score (protein cost vs output)
	## Lower concentration for same flux = more efficient
	var cost_score = 0.0
	if enzyme.concentration > 0 and net_rate > 0:
		var specific_activity = net_rate / enzyme.concentration
		cost_score = clampf(specific_activity / 100.0, 0.0, 1.0)
	elif enzyme.concentration < 0.0001:
		## Very low concentration = low cost anyway
		cost_score = 0.5
	breakdown.cost = cost_score
	
	## 4. Thermal score (useful work vs heat)
	var thermal_score = 0.5  ## Neutral default
	if rxn.current_useful_work > 0 or rxn.current_heat_generated > 0:
		var total_energy = abs(rxn.current_useful_work) + rxn.current_heat_generated
		if total_energy > 0:
			thermal_score = abs(rxn.current_useful_work) / total_energy
	breakdown.thermal = clampf(thermal_score, 0.0, 1.0)
	
	## 5. Regulation score (is the enzyme well-regulated?)
	var reg_score = 0.5  ## Neutral for unregulated
	var enz_id = enzyme.enzyme_id if "enzyme_id" in enzyme else enzyme.id
	if genes.has(enz_id):
		var gene = genes[enz_id]
		reg_score = _calculate_regulation_fitness(gene, molecules)
	breakdown.regulation = reg_score
	
	## Weighted total
	breakdown.total = (
		breakdown.efficiency * weight_efficiency +
		breakdown.flux * weight_flux +
		breakdown.cost * weight_cost +
		breakdown.thermal * weight_thermal +
		breakdown.regulation * weight_regulation
	)
	
	return breakdown

## Calculate how well a gene's regulation matches metabolic needs
func _calculate_regulation_fitness(gene, molecules: Dictionary) -> float:
	if gene.activators.is_empty() and gene.repressors.is_empty():
		return 0.4  ## Constitutive = mediocre
	
	var score = 0.5
	
	## Check if activators are responding appropriately
	for act in gene.activators:
		var occupancy = act.get_occupancy(molecules)
		## Good: high occupancy when substrate is high
		if occupancy > 0.5:
			score += 0.15
		elif occupancy > 0.2:
			score += 0.05
	
	## Check if repressors provide useful feedback
	for rep in gene.repressors:
		var occupancy = rep.get_occupancy(molecules)
		## Good: repressor active when product accumulates
		if occupancy > 0.3 and occupancy < 0.8:
			score += 0.1  ## Moderate repression = good feedback
	
	## Penalty for too many regulators (complexity cost)
	var num_regulators = gene.activators.size() + gene.repressors.size()
	if num_regulators > 3:
		score -= (num_regulators - 3) * 0.1
	
	return clampf(score, 0.0, 1.0)

#endregion

#region Selection Logic

## Find enzymes that should be eliminated
func _find_elimination_candidates(enzymes: Dictionary, fitness: Dictionary) -> Dictionary:
	var candidates: Dictionary = {}  ## {enz_id: reason}
	
	## Don't eliminate below minimum
	if enzymes.size() <= min_enzymes:
		return candidates
	
	## More aggressive elimination when over capacity
	var pressure_multiplier = 1.0
	if enzymes.size() > max_enzymes:
		pressure_multiplier = 1.0 + (enzymes.size() - max_enzymes) * 0.2
	
	var adjusted_threshold = elimination_threshold * pressure_multiplier
	
	for enz_id in enzymes:
		var enzyme = enzymes[enz_id]
		
		## Never eliminate source/sink enzymes
		if enzyme.is_source() or enzyme.is_sink():
			continue
		
		## Never eliminate locked enzymes
		if enzyme.is_locked:
			continue
		
		var fit = fitness.get(enz_id, 0.0)
		var avg_fit = _get_average_fitness(enz_id)
		
		## Check for consistently low fitness
		if fit < adjusted_threshold and avg_fit < adjusted_threshold:
			candidates[enz_id] = "low_fitness (%.2f)" % fit
		
		## Check for near-zero concentration (already dying)
		elif enzyme.concentration < 1e-5 and enzyme.is_degradable:
			candidates[enz_id] = "depleted"
		
		## Check for redundancy with better alternative
		elif _is_redundant(enzyme, enzymes, fitness):
			candidates[enz_id] = "redundant"
	
	return candidates

## Find high-performing enzymes
func _find_elite_enzymes(enzymes: Dictionary, fitness: Dictionary) -> Array[String]:
	var elite: Array[String] = []
	
	for enz_id in enzymes:
		var enzyme = enzymes[enz_id]
		
		## Skip source/sink
		if enzyme.is_source() or enzyme.is_sink():
			continue
		
		var fit = fitness.get(enz_id, 0.0)
		var avg_fit = _get_average_fitness(enz_id)
		
		if fit > boost_threshold and avg_fit > boost_threshold * 0.9:
			elite.append(enz_id)
	
	return elite

## Find pairs of enzymes competing for the same niche
func _find_competing_enzymes(enzymes: Dictionary, fitness: Dictionary) -> Array[Dictionary]:
	var competitions: Array[Dictionary] = []
	var checked: Dictionary = {}
	
	for enz_id_a in enzymes:
		var enzyme_a = enzymes[enz_id_a]
		if enzyme_a.reactions.is_empty():
			continue
		
		var rxn_a = enzyme_a.reactions[0]
		
		for enz_id_b in enzymes:
			if enz_id_a == enz_id_b:
				continue
			
			var pair_key = [enz_id_a, enz_id_b]
			pair_key.sort()
			var pair_str = "%s_%s" % [pair_key[0], pair_key[1]]
			
			if checked.has(pair_str):
				continue
			checked[pair_str] = true
			
			var enzyme_b = enzymes[enz_id_b]
			if enzyme_b.reactions.is_empty():
				continue
			
			var rxn_b = enzyme_b.reactions[0]
			
			## Check if they catalyze similar reactions
			if _reactions_compete(rxn_a, rxn_b):
				var fit_a = fitness.get(enz_id_a, 0.0)
				var fit_b = fitness.get(enz_id_b, 0.0)
				
				## Only compete if fitness is close
				if abs(fit_a - fit_b) < competition_window:
					## Randomly pick winner weighted by fitness
					var total_fit = fit_a + fit_b
					if total_fit > 0 and randf() < fit_a / total_fit:
						competitions.append({"winner": enz_id_a, "loser": enz_id_b})
					else:
						competitions.append({"winner": enz_id_b, "loser": enz_id_a})
	
	return competitions

## Check if two reactions compete for same substrates/products
func _reactions_compete(rxn_a, rxn_b) -> bool:
	## Same substrates?
	for sub in rxn_a.substrates:
		if rxn_b.substrates.has(sub):
			return true
	
	## Same products?
	for prod in rxn_a.products:
		if rxn_b.products.has(prod):
			return true
	
	return false

## Check if enzyme is redundant with a better alternative
func _is_redundant(enzyme, enzymes: Dictionary, fitness: Dictionary) -> bool:
	if enzyme.reactions.is_empty():
		return false
	
	var rxn = enzyme.reactions[0]
	var enz_id = enzyme.enzyme_id if "enzyme_id" in enzyme else enzyme.id
	var my_fitness = fitness.get(enz_id, 0.0)
	
	for other_id in enzymes:
		if other_id == enz_id:
			continue
		
		var other = enzymes[other_id]
		if other.reactions.is_empty():
			continue
		
		var other_rxn = other.reactions[0]
		
		## Check if they catalyze exactly the same reaction
		if _reactions_identical(rxn, other_rxn):
			var other_fitness = fitness.get(other_id, 0.0)
			## Redundant if other is significantly better
			if other_fitness > my_fitness + 0.2:
				return true
	
	return false

## Check if two reactions are identical
func _reactions_identical(rxn_a, rxn_b) -> bool:
	if rxn_a.substrates.size() != rxn_b.substrates.size():
		return false
	if rxn_a.products.size() != rxn_b.products.size():
		return false
	
	for sub in rxn_a.substrates:
		if not rxn_b.substrates.has(sub):
			return false
	
	for prod in rxn_a.products:
		if not rxn_b.products.has(prod):
			return false
	
	return true

#endregion

#region Adaptive Regulation

## Calculate gene regulation adjustments based on fitness landscape
func _calculate_adaptive_regulation(genes: Dictionary, enzymes: Dictionary, fitness: Dictionary, _molecules: Dictionary) -> Dictionary:
	var adjustments: Dictionary = {}
	
	for gene_id in genes:
		var gene = genes[gene_id]
		
		## Skip if gene doesn't control an enzyme we're tracking
		if not enzymes.has(gene_id):
			continue
		
		var fit = fitness.get(gene_id, 0.5)
		
		## High fitness enzyme: maybe increase basal rate
		if fit > 0.7 and gene.basal_rate < 0.001:
			if randf() < 0.1:
				adjustments[gene_id] = {
					"basal_rate": gene.basal_rate * 1.5
				}
		
		## Low fitness enzyme: maybe decrease basal rate
		elif fit < 0.3 and gene.basal_rate > 0.00001:
			if randf() < 0.1:
				adjustments[gene_id] = {
					"basal_rate": gene.basal_rate * 0.7
				}
	
	return adjustments

#endregion

#region Fitness History

func _update_fitness_history(enz_id: String, fit: float) -> void:
	if not fitness_history.has(enz_id):
		fitness_history[enz_id] = []
	
	fitness_history[enz_id].append(fit)
	
	while fitness_history[enz_id].size() > fitness_window:
		fitness_history[enz_id].pop_front()

func _get_average_fitness(enz_id: String) -> float:
	if not fitness_history.has(enz_id):
		return 0.5
	
	var history: Array = fitness_history[enz_id]
	if history.is_empty():
		return 0.5
	
	var total = 0.0
	for f in history:
		total += f
	
	return total / history.size()

func clear_history_for(enz_id: String) -> void:
	fitness_history.erase(enz_id)

#endregion

#region Lineage Tracking

func register_birth(enz_id: String, parent_id: String, birth_time: float) -> void:
	var parent_gen = 0
	if lineage_tree.has(parent_id):
		parent_gen = lineage_tree[parent_id].generation
	
	lineage_tree[enz_id] = {
		"parent": parent_id,
		"generation": parent_gen + 1,
		"born": birth_time,
		"died": -1.0
	}
	
	generation_count = max(generation_count, parent_gen + 1)

func register_death(enz_id: String, death_time: float) -> void:
	if lineage_tree.has(enz_id):
		lineage_tree[enz_id].died = death_time

func get_lineage(enz_id: String) -> Array[String]:
	var lineage: Array[String] = []
	var current = enz_id
	
	while lineage_tree.has(current):
		lineage.append(current)
		current = lineage_tree[current].parent
		if current.is_empty():
			break
	
	return lineage

func get_generation(enz_id: String) -> int:
	if lineage_tree.has(enz_id):
		return lineage_tree[enz_id].generation
	return 0

#endregion

#region Utility

func _roll(probability: float) -> bool:
	return randf() < probability

#endregion

#region Configuration

func set_fitness_weights(efficiency: float, flux: float, cost: float, thermal: float, regulation: float) -> void:
	weight_efficiency = efficiency
	weight_flux = flux
	weight_cost = cost
	weight_thermal = thermal
	weight_regulation = regulation

func set_selection_thresholds(elimination: float, boost: float, competition: float) -> void:
	elimination_threshold = elimination
	boost_threshold = boost
	competition_window = competition

func set_selection_rates(selection: float, elimination: float, boost: float) -> void:
	selection_rate = selection
	elimination_rate = elimination
	boost_rate = boost

#endregion

#region Analysis

func get_fitness_summary() -> Dictionary:
	var summary = {
		"enzyme_count": current_fitness.size(),
		"average_fitness": 0.0,
		"max_fitness": 0.0,
		"min_fitness": 1.0,
		"elite_count": 0,
		"struggling_count": 0,
		"generation": generation_count
	}
	
	if current_fitness.is_empty():
		return summary
	
	var total = 0.0
	for enz_id in current_fitness:
		var fit = current_fitness[enz_id]
		total += fit
		summary.max_fitness = max(summary.max_fitness, fit)
		summary.min_fitness = min(summary.min_fitness, fit)
		
		if fit > boost_threshold:
			summary.elite_count += 1
		elif fit < elimination_threshold:
			summary.struggling_count += 1
	
	summary.average_fitness = total / current_fitness.size()
	return summary

func get_fitness_ranking() -> Array[Dictionary]:
	var ranking: Array[Dictionary] = []
	
	for enz_id in current_fitness:
		ranking.append({
			"id": enz_id,
			"fitness": current_fitness[enz_id],
			"generation": get_generation(enz_id)
		})
	
	ranking.sort_custom(func(a, b): return a.fitness > b.fitness)
	return ranking

#endregion
