## Enzyme that can catalyze multiple reactions
class_name Enzyme
extends RefCounted

var id: String
var name: String
var concentration: float
var initial_concentration: float
var reactions: Array[Reaction] = []
var temperature: float = 310.0

## Enzyme dynamics
var creation_rate: float = 0.0      ## Base rate of enzyme production
var degradation_rate: float = 0.0   ## Base rate of enzyme degradation

## Regulation (applied to all reactions of this enzyme)
var inhibitors: Dictionary = {}     ## {"molecule": Ki} - competitive inhibition
var activators: Dictionary = {}     ## {"molecule": fold_increase}

## Runtime state
var current_total_forward_rate: float = 0.0
var current_total_reverse_rate: float = 0.0
var current_net_rate: float = 0.0

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = 0.01
	initial_concentration = 0.01

func add_reaction(reaction: Reaction) -> void:
	reaction.enzyme = self
	reactions.append(reaction)

func remove_reaction(reaction: Reaction) -> void:
	reactions.erase(reaction)

func is_source() -> bool:
	## An enzyme is a source if all its reactions are sources
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_source():
			return false
	return true

func is_sink() -> bool:
	## An enzyme is a sink if all its reactions are sinks
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_sink():
			return false
	return true

## Update rates for all reactions
func update_reaction_rates(molecules: Dictionary) -> void:
	current_total_forward_rate = 0.0
	current_total_reverse_rate = 0.0
	
	for reaction in reactions:
		## Apply enzyme-level regulation
		var effective_conc = concentration
		
		## Apply activators
		for activator in activators:
			if molecules.has(activator):
				var activator_conc = molecules[activator].concentration
				var fold = activators[activator]
				## Simple activation: multiply by fold if activator present
				if activator_conc > 0.1:
					effective_conc *= fold
		
		## Apply inhibitors
		for inhibitor in inhibitors:
			if molecules.has(inhibitor):
				var inhibitor_conc = molecules[inhibitor].concentration
				var ki = inhibitors[inhibitor]
				## Competitive inhibition factor
				var inhibition_factor = 1.0 / (1.0 + inhibitor_conc / ki)
				effective_conc *= inhibition_factor
		
		## Calculate rates for this reaction
		reaction.calculate_forward_rate(molecules, effective_conc)
		reaction.calculate_reverse_rate(molecules, effective_conc)
		
		current_total_forward_rate += reaction.current_forward_rate
		current_total_reverse_rate += reaction.current_reverse_rate
	
	current_net_rate = current_total_forward_rate - current_total_reverse_rate

## Update enzyme concentration based on creation/degradation
func update_enzyme_concentration(molecules: Dictionary, timestep: float) -> void:
	var creation = creation_rate
	var degradation = degradation_rate * concentration
	
	var net_change = (creation - degradation) * timestep
	concentration += net_change

## Get summary of all reactions
func get_reactions_summary() -> String:
	var summary = ""
	for i in range(reactions.size()):
		if i > 0:
			summary += "\n"
		summary += reactions[i].get_summary()
	return summary
