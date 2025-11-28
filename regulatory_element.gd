## Regulatory element that modulates gene expression based on molecule concentration
## Uses Hill kinetics to model cooperative binding
class_name RegulatoryElement
extends RefCounted

enum Type { ACTIVATOR, REPRESSOR }

var type: Type = Type.ACTIVATOR
var molecule_name: String = ""  ## Name of the molecule this element responds to
var kd: float = 1.0  ## Dissociation constant (mM) - concentration for half-maximal effect
var max_fold_change: float = 10.0  ## Maximum fold change in expression
var hill_coefficient: float = 1.0  ## Cooperativity (n > 1 = positive cooperativity)

#region Initialization

func _init(p_type: Type, p_molecule: String, p_kd: float = 1.0, p_max_fold: float = 10.0, p_hill: float = 1.0) -> void:
	type = p_type
	molecule_name = p_molecule
	kd = max(p_kd, 1e-6)
	max_fold_change = max(p_max_fold, 1.0)
	hill_coefficient = clampf(p_hill, 0.1, 4.0)

static func create_activator(molecule: String, kd_val: float = 1.0, fold_change: float = 10.0, hill: float = 1.0) -> RegulatoryElement:
	return RegulatoryElement.new(Type.ACTIVATOR, molecule, kd_val, fold_change, hill)

static func create_repressor(molecule: String, kd_val: float = 1.0, fold_change: float = 10.0, hill: float = 1.0) -> RegulatoryElement:
	return RegulatoryElement.new(Type.REPRESSOR, molecule, kd_val, fold_change, hill)

#endregion

#region Effect Calculation

## Calculate the fold-effect on expression rate based on molecule concentration
## Returns multiplier (1.0 = no effect)
func calculate_effect(molecules: Dictionary) -> float:
	if molecule_name.is_empty() or not molecules.has(molecule_name):
		return 1.0
	
	var conc = molecules[molecule_name].concentration
	if conc <= 0.0:
		## No molecule present
		if type == Type.ACTIVATOR:
			return 1.0  ## No activation without activator
		else:
			return 1.0  ## No repression without repressor
	
	## Hill equation: occupancy = [S]^n / (Kd^n + [S]^n)
	var conc_n = pow(conc, hill_coefficient)
	var kd_n = pow(kd, hill_coefficient)
	var occupancy = conc_n / (kd_n + conc_n)
	
	if type == Type.ACTIVATOR:
		## Expression increases with molecule: 1 → max_fold_change
		## At [S]=0: effect = 1.0 (basal)
		## At [S]>>Kd: effect → max_fold_change
		return 1.0 + (max_fold_change - 1.0) * occupancy
	else:
		## Expression decreases with molecule: 1 → 1/max_fold_change
		## At [S]=0: effect = 1.0 (full expression)
		## At [S]>>Kd: effect → 1/max_fold_change
		return 1.0 / (1.0 + (max_fold_change - 1.0) * occupancy)

## Get the current occupancy (0-1) of this regulatory element
func get_occupancy(molecules: Dictionary) -> float:
	if molecule_name.is_empty() or not molecules.has(molecule_name):
		return 0.0
	
	var conc = molecules[molecule_name].concentration
	if conc <= 0.0:
		return 0.0
	
	var conc_n = pow(conc, hill_coefficient)
	var kd_n = pow(kd, hill_coefficient)
	return conc_n / (kd_n + conc_n)

#endregion

#region Display

func get_type_string() -> String:
	return "activator" if type == Type.ACTIVATOR else "repressor"

func get_summary() -> String:
	var direction = "↑" if type == Type.ACTIVATOR else "↓"
	return "%s %s (Kd=%.2f mM, %.1fx, n=%.1f)" % [
		molecule_name, direction, kd, max_fold_change, hill_coefficient
	]

func get_detailed_summary() -> String:
	var type_str = "Activator" if type == Type.ACTIVATOR else "Repressor"
	return "%s: %s\n  Kd=%.3f mM, Max fold=%.1f, Hill=%.1f" % [
		type_str, molecule_name, kd, max_fold_change, hill_coefficient
	]

#endregion
