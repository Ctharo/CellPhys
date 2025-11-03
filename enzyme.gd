## Enzyme that catalyzes biochemical transformations
class_name Enzyme
extends RefCounted

var id: String
var name: String
var concentration: float
var initial_concentration: float
var vmax: float
var initial_vmax: float
var km: float
var initial_km: float

var substrates: Dictionary = {}     ## {"molecule_name": stoichiometry}
var products: Dictionary = {}       ## {"molecule_name": stoichiometry}
var inhibitors: Dictionary = {}     ## {"molecule_name": inhibition_factor}
var activators: Dictionary = {}     ## {"molecule_name": activation_factor}

## Enzyme dynamics
var creation_rate: float = 0.0      ## Base rate of enzyme production
var degradation_rate: float = 0.0   ## Base rate of enzyme degradation
var creation_activators: Dictionary = {}  ## {"molecule": factor}
var creation_inhibitors: Dictionary = {}  ## {"molecule": factor}
var degradation_activators: Dictionary = {}
var degradation_inhibitors: Dictionary = {}

var current_rate: float = 0.0

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	name = p_name
	concentration = 0.01
	initial_concentration = 0.01
	vmax = 10.0
	initial_vmax = 10.0
	km = 0.5
	initial_km = 0.5

func is_source() -> bool:
	return substrates.is_empty() and not products.is_empty()

func is_sink() -> bool:
	return not substrates.is_empty() and products.is_empty()
