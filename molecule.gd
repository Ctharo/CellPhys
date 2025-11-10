## Represents a chemical molecule with concentration and variable-length genetic code
class_name Molecule
extends RefCounted

var name: String
var concentration: float
var initial_concentration: float

## Energy and genetic properties
var potential_energy: float  ## Energy stored in chemical bonds (kJ/mol)
var genetic_code: Array[int] = []  ## Variable-length code representing molecular structure (0-9)

## Composition tracking for code generation
var base_molecule: String = ""  ## Name of base molecule (if derivative)
var modifications: Array[String] = []  ## List of modifications applied

## Static registry for molecular fragments
static var fragment_codes: Dictionary = {
	# Base molecular structures
	"Glucose": [5, 5, 5, 5, 5, 5] as Array[int],
	"Ribose": [5, 5, 5, 5, 4] as Array[int],
	"Pyruvate": [3, 3, 3] as Array[int],
	"Acetyl": [2, 2] as Array[int],
	"Lactate": [3, 3, 3, 1] as Array[int],
	
	# Functional groups/modifications
	"Phosphate": [9, 0] as Array[int],
	"P": [9, 0] as Array[int],  ## Shorthand
	"Diphosphate": [9, 0, 9, 0] as Array[int],
	"PP": [9, 0, 9, 0] as Array[int],  ## Shorthand
	"Triphosphate": [9, 0, 9, 0, 9, 0] as Array[int],
	"PPP": [9, 0, 9, 0, 9, 0] as Array[int],  ## Shorthand
	
	# Nucleotide bases
	"Adenine": [1, 1, 1] as Array[int],
	"A": [1, 1, 1] as Array[int],
	"Guanine": [1, 1, 2] as Array[int],
	"G": [1, 1, 2] as Array[int],
	"Cytosine": [2, 2, 1] as Array[int],
	"C": [2, 2, 1] as Array[int],
	"Uracil": [2, 2, 0] as Array[int],
	"U": [2, 2, 0] as Array[int],
	
	# Other common groups
	"Amino": [7, 7] as Array[int],
	"NH2": [7, 7] as Array[int],
	"Carboxyl": [8, 8] as Array[int],
	"COOH": [8, 8] as Array[int],
	"Hydroxyl": [6, 6] as Array[int],
	"OH": [6, 6] as Array[int],
	"Methyl": [4, 4] as Array[int],
	"CH3": [4, 4] as Array[int],
	
	# Cofactors
	"NAD": [1, 1, 1, 5, 5, 9, 0] as Array[int],
	"FAD": [1, 1, 1, 5, 5, 9, 0, 9, 0] as Array[int],
	"CoA": [2, 2, 9, 0, 9, 0, 9, 0] as Array[int],
}

func _init(p_name: String, p_conc: float, p_genetic_code: Array[int] = []) -> void:
	name = p_name
	concentration = p_conc
	initial_concentration = p_conc
	
	## Generate random potential energy (20-80 kJ/mol)
	potential_energy = randf_range(20.0, 80.0)
	
	## Use provided genetic code or generate from name
	if p_genetic_code.is_empty():
		genetic_code = generate_code_from_name(p_name)
	else:
		genetic_code = p_genetic_code.duplicate()

## Generate genetic code from molecule name using fragment composition
static func generate_code_from_name(mol_name: String) -> Array[int]:
	var code: Array[int]
	
	## Try to parse the name for known fragments
	var found_fragments = false
	
	## Check for common patterns (e.g., "Glucose-6-Phosphate" or "G6P")
	for fragment_name in fragment_codes.keys():
		if mol_name.contains(fragment_name):
			code.append_array(fragment_codes[fragment_name])
			found_fragments = true
	
	## Handle special naming patterns
	## Pattern: Base + number + modification (e.g., "Glucose-6-P" or "G6P")
	if "6P" in mol_name or "6-P" in mol_name:
		if code.is_empty() and ("Glucose" in mol_name or mol_name.begins_with("G")):
			code.append_array(fragment_codes["Glucose"])
		if not has_fragment(code, fragment_codes["Phosphate"]):
			code.append_array(fragment_codes["Phosphate"])
		found_fragments = true
	
	## Pattern: ATP, ADP, AMP
	if mol_name == "ATP":
		code = fragment_codes["Adenine"].duplicate() 
		code.append_array(fragment_codes["Ribose"])
		code.append_array(fragment_codes["Triphosphate"])
		return code
	elif mol_name == "ADP":
		code = fragment_codes["Adenine"].duplicate()
		code.append_array(fragment_codes["Ribose"])
		code.append_array(fragment_codes["Diphosphate"])
		return code
	elif mol_name == "AMP":
		code = fragment_codes["Adenine"].duplicate()
		code.append_array(fragment_codes["Ribose"])
		code.append_array(fragment_codes["Phosphate"])
		return code
	
	## Pattern: Simple phosphate (Pi, PPi)
	if mol_name == "Pi":
		return fragment_codes["Phosphate"].duplicate()
	elif mol_name == "PPi":
		return fragment_codes["Diphosphate"].duplicate()
	
	## If no fragments found, generate random code
	if not found_fragments or code.is_empty():
		var length = randi_range(4, 10)
		for i in range(length):
			code.append(randi() % 10)
	
	return code

## Check if code contains a specific fragment
static func has_fragment(code: Array[int], fragment: Array[int]) -> bool:
	if fragment.size() > code.size():
		return false
	
	for i in range(code.size() - fragment.size() + 1):
		var match_found = true
		for j in range(fragment.size()):
			if code[i + j] != fragment[j]:
				match_found = false
				break
		if match_found:
			return true
	
	return false

## Generate code by combining base molecule with modifications
static func generate_derivative_code(base_code: Array[int], modification: String) -> Array[int]:
	var new_code = base_code.duplicate()
	
	if fragment_codes.has(modification):
		new_code.append_array(fragment_codes[modification])
	else:
		## Unknown modification, add random digits
		new_code.append_array([randi() % 10, randi() % 10])
	
	return new_code

## Generate a random genetic code of specified length
static func generate_random_code(length: int = 6) -> Array[int]:
	var code: Array[int] = []
	for i in range(length):
		code.append(randi() % 10)
	return code

## Calculate genetic distance between two codes using alignment-based approach
## Similar to sequence alignment in bioinformatics
static func genetic_distance(code1: Array[int], code2: Array[int]) -> float:
	if code1.is_empty() or code2.is_empty():
		return 10.0  ## Maximum distance for empty codes
	
	## Use dynamic programming for optimal alignment (like Needleman-Wunsch)
	## This handles variable-length codes properly
	var len1 = code1.size()
	var len2 = code2.size()
	
	## For efficiency, use simpler method for very different lengths
	var length_ratio = float(max(len1, len2)) / float(min(len1, len2))
	if length_ratio > 3.0:
		## Very different lengths = high distance
		return 8.0 + min(abs(len1 - len2) * 0.1, 2.0)
	
	## Create alignment matrix
	var matrix: Array = []
	for i in range(len1 + 1):
		var row: Array[float] = []
		row.resize(len2 + 1)
		row.fill(0.0)
		matrix.append(row)
	
	## Initialize first row and column (gap penalties)
	const GAP_PENALTY = 1.0
	for i in range(len1 + 1):
		matrix[i][0] = i * GAP_PENALTY
	for j in range(len2 + 1):
		matrix[0][j] = j * GAP_PENALTY
	
	## Fill matrix with alignment scores
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var match_score = abs(code1[i-1] - code2[j-1])  ## 0 if identical, up to 9 if completely different
			var diagonal = matrix[i-1][j-1] + match_score
			var up = matrix[i-1][j] + GAP_PENALTY
			var left = matrix[i][j-1] + GAP_PENALTY
			matrix[i][j] = min(diagonal, min(up, left))
	
	## The alignment distance is in the bottom-right cell
	var alignment_distance = matrix[len1][len2]
	
	## Normalize by average length for comparability
	var avg_length = (len1 + len2) / 2.0
	var normalized_distance = alignment_distance / max(avg_length, 1.0)
	
	return normalized_distance

## Calculate similarity to another molecule (0 to 1)
## 1.0 = identical codes, 0.0 = maximally different
func similarity_to(other: Molecule) -> float:
	var distance = genetic_distance(genetic_code, other.genetic_code)
	
	## Max distance is around 10.0 for very different molecules
	const MAX_DISTANCE = 10.0
	var similarity = 1.0 - min(distance / MAX_DISTANCE, 1.0)
	
	return max(0.0, similarity)

## Create a similar molecule through mutation
static func create_mutated_code(base_code: Array[int], mutation_rate: float = 0.3) -> Array[int]:
	var new_code: Array[int] = []
	
	for digit in base_code:
		if randf() < mutation_rate:
			## Mutate to a different random digit
			new_code.append(randi() % 10)
		else:
			## Keep original digit
			new_code.append(digit)
	
	## Small chance of insertion or deletion
	if randf() < 0.1:
		if randf() < 0.5 and new_code.size() > 2:
			## Deletion
			new_code.remove_at(randi() % new_code.size())
		else:
			## Insertion
			new_code.insert(randi() % (new_code.size() + 1), randi() % 10)
	
	return new_code

## Add a functional group/modification to this molecule's code
func add_modification(modification: String) -> void:
	modifications.append(modification)
	if fragment_codes.has(modification):
		genetic_code.append_array(fragment_codes[modification])
	else:
		## Unknown modification, add some random digits
		genetic_code.append_array([randi() % 10, randi() % 10])

## Remove a functional group/modification from this molecule's code
func remove_modification(modification: String) -> bool:
	if not modifications.has(modification):
		return false
	
	modifications.erase(modification)
	
	if fragment_codes.has(modification):
		var fragment = fragment_codes[modification]
		## Find and remove the fragment from the code
		for i in range(genetic_code.size() - fragment.size() + 1):
			var match_found = true
			for j in range(fragment.size()):
				if genetic_code[i + j] != fragment[j]:
					match_found = false
					break
			if match_found:
				## Remove the fragment
				for _k in range(fragment.size()):
					genetic_code.remove_at(i)
				return true
	
	return false

## Get string representation of genetic code
func get_genetic_code_string() -> String:
	if genetic_code.is_empty():
		return "[]"
	
	var code_str = ""
	for digit in genetic_code:
		code_str += str(digit)
	return code_str

## Get formatted representation with length
func get_genetic_code_display() -> String:
	return "%s (len=%d)" % [get_genetic_code_string(), genetic_code.size()]

## Get a readable summary
func get_summary() -> String:
	var summary = "%s: %.3f mM, E=%.1f kJ/mol\n  DNA=%s" % [
		name,
		concentration,
		potential_energy,
		get_genetic_code_display()
	]
	
	if not modifications.is_empty():
		summary += "\n  Mods: " + ", ".join(modifications)
	
	return summary

## Compare codes visually for debugging
static func compare_codes_visual(code1: Array[int], code2: Array[int], name1: String = "Code1", name2: String = "Code2") -> String:
	var output = "\n=== Genetic Code Comparison ===\n"
	output += "%s: %s (len=%d)\n" % [name1, array_to_string(code1), code1.size()]
	output += "%s: %s (len=%d)\n" % [name2, array_to_string(code2), code2.size()]
	
	## Show alignment
	output += "\nAlignment:\n"
	var max_len = max(code1.size(), code2.size())
	var code1_str = ""
	var code2_str = ""
	var match_str = ""
	
	for i in range(max_len):
		if i < code1.size():
			code1_str += str(code1[i]) + " "
		else:
			code1_str += "- "
		
		if i < code2.size():
			code2_str += str(code2[i]) + " "
		else:
			code2_str += "- "
		
		if i < code1.size() and i < code2.size():
			if code1[i] == code2[i]:
				match_str += "| "
			else:
				match_str += "  "
		else:
			match_str += "  "
	
	output += code1_str + "\n"
	output += match_str + "\n"
	output += code2_str + "\n"
	
	var distance = genetic_distance(code1, code2)
	var similarity = 1.0 - min(distance / 10.0, 1.0)
	output += "\nDistance: %.2f\n" % distance
	output += "Similarity: %.1f%%\n" % (similarity * 100.0)
	
	return output

static func array_to_string(arr: Array[int]) -> String:
	var s = ""
	for val in arr:
		s += str(val)
	return s
