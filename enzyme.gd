## Enzyme that catalyzes reactions
class_name Enzyme
extends RefCounted

var id: String
var name: String
var concentration: float
var initial_concentration: float
var reactions: Array[Reaction] = []
var temperature: float = 310.0

## Runtime state
var current_total_forward_rate: float = 0.0
var current_total_reverse_rate: float = 0.0
var current_net_rate: float = 0.0

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

## Update rates for all reactions
func update_reaction_rates(molecules: Dictionary, available_energy: float) -> void:
	current_total_forward_rate = 0.0
	current_total_reverse_rate = 0.0
	
	for reaction in reactions:
		reaction.calculate_forward_rate(molecules, concentration, available_energy)
		reaction.calculate_reverse_rate(molecules, concentration)
		
		current_total_forward_rate += reaction.current_forward_rate
		current_total_reverse_rate += reaction.current_reverse_rate
	
	current_net_rate = current_total_forward_rate - current_total_reverse_rate

## Get summary of all reactions
func get_reactions_summary() -> String:
	var summary = ""
	for i in range(reactions.size()):
		if i > 0:
			summary += "\n"
		summary += reactions[i].get_summary()
	return summary
