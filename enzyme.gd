## Enzyme that catalyzes one or more reactions
class_name Enzyme
extends RefCounted

var id: String
var name: String
var concentration: float
var initial_concentration: float
var is_locked: bool = false  ## If true, concentration won't change during simulation
var reactions: Array[Reaction] = []

#region Initialization

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = randf_range(0.001, 0.01)
	initial_concentration = concentration

func add_reaction(reaction: Reaction) -> void:
	reaction.enzyme = self
	reactions.append(reaction)

func remove_reaction(reaction: Reaction) -> void:
	reactions.erase(reaction)

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

#endregion
