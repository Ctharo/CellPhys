## Represents a chemical molecule with concentration and structural code
class_name Molecule
extends RefCounted

var name: String
var concentration: float
var initial_concentration: float
var potential_energy: float  ## Energy stored in chemical bonds (kJ/mol)
var structural_code: Array[int] = []  ## Variable-length code representing molecular structure (0-9)

#region Initialization

func _init(p_name: String, p_conc: float, p_code: Array[int] = []) -> void:
	name = p_name
	concentration = p_conc
	initial_concentration = p_conc
	potential_energy = randf_range(20.0, 80.0)
	
	if p_code.is_empty():
		structural_code = generate_random_code(randi_range(4, 8))
	else:
		structural_code = p_code.duplicate()

static func generate_random_name() -> String:
	const PREFIXES = ["Hex", "Pent", "Oct", "Tri", "Di", "Poly", "Meta"]
	const MIDDLES = ["ox", "yl", "an", "en", "ose", "ase", "pyr"]
	const SUFFIXES = ["ate", "ite", "ose", "ide", "ine", "one", "ol"]
	
	var p_name = PREFIXES[randi() % PREFIXES.size()]
	p_name += MIDDLES[randi() % MIDDLES.size()]
	if randf() > 0.3:
		p_name += SUFFIXES[randi() % SUFFIXES.size()]
	return p_name

static func generate_random_code(length: int = 6) -> Array[int]:
	var code: Array[int] = []
	for i in range(length):
		code.append(randi() % 10)
	return code

#endregion

#region Structural Comparison

## Calculate structural distance between two codes using alignment
static func structural_distance(code1: Array[int], code2: Array[int]) -> float:
	if code1.is_empty() or code2.is_empty():
		return 10.0
	
	var len1 = code1.size()
	var len2 = code2.size()
	
	## Very different lengths = high distance
	var length_ratio = float(max(len1, len2)) / float(min(len1, len2))
	if length_ratio > 3.0:
		return 8.0 + min(abs(len1 - len2) * 0.1, 2.0)
	
	## Dynamic programming alignment (Needleman-Wunsch style)
	var matrix: Array = []
	for i in range(len1 + 1):
		var row: Array[float] = []
		row.resize(len2 + 1)
		row.fill(0.0)
		matrix.append(row)
	
	const GAP_PENALTY = 1.0
	for i in range(len1 + 1):
		matrix[i][0] = i * GAP_PENALTY
	for j in range(len2 + 1):
		matrix[0][j] = j * GAP_PENALTY
	
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var match_score = abs(code1[i-1] - code2[j-1])
			var diagonal = matrix[i-1][j-1] + match_score
			var up = matrix[i-1][j] + GAP_PENALTY
			var left = matrix[i][j-1] + GAP_PENALTY
			matrix[i][j] = min(diagonal, min(up, left))
	
	var alignment_distance = matrix[len1][len2]
	var avg_length = (len1 + len2) / 2.0
	return alignment_distance / max(avg_length, 1.0)

## Calculate similarity to another molecule (0 to 1)
func similarity_to(other: Molecule) -> float:
	var distance = structural_distance(structural_code, other.structural_code)
	const MAX_DISTANCE = 10.0
	return max(0.0, 1.0 - min(distance / MAX_DISTANCE, 1.0))

#endregion

#region Display

func get_code_string() -> String:
	var s = ""
	for digit in structural_code:
		s += str(digit)
	return s

func get_summary() -> String:
	return "%s: %.3f mM, E=%.1f kJ/mol, Code=%s" % [
		name, concentration, potential_energy, get_code_string()
	]

#endregion
