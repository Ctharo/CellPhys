## Represents a chemical molecule with concentration
class_name Molecule
extends RefCounted

var name: String
var concentration: float
var initial_concentration: float

func _init(p_name: String, p_conc: float) -> void:
	name = p_name
	concentration = p_conc
	initial_concentration = p_conc
