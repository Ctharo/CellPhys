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
var creation_activators: Dictionary = {}  ## {"molecule": factor}
var creation_inhibitors: Dictionary = {}  ## {"molecule": factor}
var degradation_activators: Dictionary = {}
var degradation_inhibitors: Dictionary = {}

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = 0.01
	initial_concentration = 0.01

func add_reaction(reaction: Reaction) -> void:
	reactions.append(reaction)

func remove_reaction(reaction: Reaction) -> void:
	reactions.erase(reaction)
