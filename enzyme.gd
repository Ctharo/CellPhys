## Enzyme that catalyzes one or more reactions
## Enzymes degrade over time following first-order kinetics
class_name Enzyme
extends RefCounted

const LN2: float = 0.693147  ## ln(2) for half-life calculations

var id: String
var name: String
var concentration: float
var initial_concentration: float
var is_locked: bool = false  ## If true, concentration won't change during simulation
var reactions: Array[Reaction] = []

#region Degradation

var half_life: float = 300.0  ## Half-life in seconds (default ~5 min, typical for metabolic enzymes)
var degradation_rate: float = 0.0  ## Calculated from half_life: k = ln(2) / t_half
var is_degradable: bool = true  ## Source/sink enzymes may be non-degradable

#endregion

#region Initialization

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = randf_range(0.001, 0.01)
	initial_concentration = concentration
	half_life = randf_range(120.0, 600.0)  ## 2-10 minutes typical range
	_update_degradation_rate()

func _update_degradation_rate() -> void:
	## First-order degradation: d[E]/dt = -k[E], where k = ln(2)/t_half
	if half_life > 0.0:
		degradation_rate = LN2 / half_life
	else:
		degradation_rate = 0.0

func add_reaction(reaction: Reaction) -> void:
	reaction.enzyme = self
	reactions.append(reaction)

func remove_reaction(reaction: Reaction) -> void:
	reactions.erase(reaction)

#endregion

#region Degradation Update

## Apply degradation for this timestep, returns amount degraded
func apply_degradation(delta: float) -> float:
	if is_locked or not is_degradable or concentration <= 0.0:
		return 0.0
	
	## First-order kinetics: [E](t) = [E]_0 * e^(-kt)
	## For small dt: d[E] ≈ -k * [E] * dt
	var amount_degraded = degradation_rate * concentration * delta
	concentration = max(0.0, concentration - amount_degraded)
	return amount_degraded

#endregion

#region Type Checking

func is_source() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_source():
			return false
	return true

func is_sink() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_sink():
			return false
	return true

#endregion

#region Rate Updates

## Update rates for all reactions this enzyme catalyzes
func update_reaction_rates(molecules: Dictionary) -> void:
	for reaction in reactions:
		reaction.calculate_forward_rate(molecules, concentration)
		reaction.calculate_reverse_rate(molecules, concentration)
		reaction.calculate_energy_partition(reaction.get_net_rate())

#endregion

#region Display

func get_reactions_summary() -> String:
	var summary = ""
	for i in range(reactions.size()):
		if i > 0:
			summary += "\n"
		summary += reactions[i].get_summary()
	return summary

func get_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	return "%s [%.4f mM] - %d reaction(s)%s" % [name, concentration, reactions.size(), lock_str]

func get_detailed_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	var degrade_str = "t½=%.0fs" % half_life if is_degradable else "stable"
	return "%s [%.4f mM] (%s) - %d reaction(s)%s" % [
		name, concentration, degrade_str, reactions.size(), lock_str
	]

#endregion
