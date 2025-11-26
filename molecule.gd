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

func _init(p_name: String, p_conc: float, p_genetic_code: Array[int] = []) -> void:
	name = p_name
	concentration = p_conc
	initial_concentration = p_conc
	
	## Generate random potential energy (20-80 kJ/mol)
	potential_energy = randf_range(20.0, 80.0)
	
	## Use provided genetic code or generate from name
	if p_genetic_code.is_empty():
		genetic_code = generate_random_code(randi_range(4, 10))
	else:
		genetic_code = p_genetic_code.duplicate()

## Generate a random molecule name
static func generate_random_name() -> String:
	const PREFIXES = ["Hex", "Pent", "Oct", "Tri", "Di", "Poly", "Meta", "Para", "Ortho", "Iso", "Neo"]
	const MIDDLES = ["ox", "yl", "an", "en", "in", "id", "ose", "ase", "ac", "ur", "pyr"]
	const SUFFIXES = ["ate", "ite", "ose", "ide", "ine", "one", "ol", "al", "ane", "ene"]
	
	var p_name = PREFIXES[randi() % PREFIXES.size()]
	p_name += MIDDLES[randi() % MIDDLES.size()]
	
	if randf() > 0.3:  ## 70% chance of suffix
		p_name += SUFFIXES[randi() % SUFFIXES.size()]
	
	return p_name

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

## Create a product molecule from this substrate based on reaction efficiency
## High efficiency = more similar product, low efficiency = more different product
static func create_product_from_substrate(substrate: Molecule, efficiency: float) -> Molecule:
	## Mutation rate inversely proportional to efficiency
	## High efficiency (0.9) = low mutation (0.1)
	## Low efficiency (0.3) = high mutation (0.7)
	var mutation_rate = 1.0 - efficiency
	
	var new_code = create_mutated_code(substrate.genetic_code, mutation_rate)
	var product_name = generate_random_name()
	var product = Molecule.new(product_name, 0.0, new_code)
	
	## Potential energy based on reaction energetics (set by caller)
	## This will be adjusted in Reaction based on ΔG
	
	return product

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
	if randf() < mutation_rate * 0.3:  ## Scale with mutation rate
		if randf() < 0.5 and new_code.size() > 2:
			## Deletion
			new_code.remove_at(randi() % new_code.size())
		else:
			## Insertion
			new_code.insert(randi() % (new_code.size() + 1), randi() % 10)
	
	return new_code

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
	var summary = "%s: %.3f mM, E=%.1f kJ/mol, DNA=%s" % [
		name,
		concentration,
		potential_energy,
		get_genetic_code_display()
	]
	
	if not modifications.is_empty():
		summary += " | Mods: " + ", ".join(modifications)
	
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
