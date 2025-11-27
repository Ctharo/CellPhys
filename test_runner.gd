## Simple unit test framework for the biochemistry simulator
class_name TestRunner
extends Node

var tests_passed: int = 0
var tests_failed: int = 0
var current_test: String = ""

signal test_completed(test_name: String, passed: bool, message: String)
signal all_tests_completed(passed: int, failed: int)

func _ready() -> void:
	run_all_tests()

func run_all_tests() -> void:
	print("\n" + "=".repeat(60))
	print("RUNNING UNIT TESTS")
	print("=".repeat(60) + "\n")
	
	## Molecule tests
	test_molecule_creation()
	test_molecule_structural_distance()
	test_molecule_similarity()
	
	## Reaction tests
	test_reaction_creation()
	test_reaction_keq_calculation()
	test_reaction_forward_rate()
	test_reaction_reversibility()
	
	## Enzyme tests
	test_enzyme_creation()
	test_enzyme_reaction_management()
	
	## Cell tests
	test_cell_heat_tracking()
	test_cell_energy_tracking()
	
	## Integration tests
	test_simple_pathway()
	
	print_summary()

#region Assertions

func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		tests_passed += 1
		print("  ✅ PASS: %s" % message if message else "  ✅ PASS")
		return true
	else:
		tests_failed += 1
		print("  ❌ FAIL: %s" % message if message else "  ❌ FAIL")
		return false

func assert_false(condition: bool, message: String = "") -> bool:
	return assert_true(not condition, message)

func assert_equal(actual, expected, message: String = "") -> bool:
	var msg = message if message else "Expected %s, got %s" % [expected, actual]
	return assert_true(actual == expected, msg)

func assert_approx(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> bool:
	var msg = message if message else "Expected ~%.4f, got %.4f (tol=%.4f)" % [expected, actual, tolerance]
	return assert_true(abs(actual - expected) <= tolerance, msg)

func assert_greater(actual: float, threshold: float, message: String = "") -> bool:
	var msg = message if message else "Expected >%.4f, got %.4f" % [threshold, actual]
	return assert_true(actual > threshold, msg)

func assert_less(actual: float, threshold: float, message: String = "") -> bool:
	var msg = message if message else "Expected <%.4f, got %.4f" % [threshold, actual]
	return assert_true(actual < threshold, msg)

func start_test(test_name: String) -> void:
	current_test = test_name
	print("\n📋 %s" % test_name)

#endregion

#region Molecule Tests

func test_molecule_creation() -> void:
	start_test("Molecule Creation")
	
	var mol = Molecule.new("TestMol", 1.5, [1, 2, 3, 4])
	assert_equal(mol.name, "TestMol", "Name set correctly")
	assert_approx(mol.concentration, 1.5, 0.001, "Concentration set correctly")
	assert_equal(mol.structural_code.size(), 4, "Code length correct")
	assert_equal(mol.structural_code[0], 1, "Code[0] correct")

func test_molecule_structural_distance() -> void:
	start_test("Structural Distance Calculation")
	
	## Identical codes should have distance 0
	var code1: Array[int] = [1, 2, 3, 4, 5]
	var code2: Array[int] = [1, 2, 3, 4, 5]
	var dist = Molecule.structural_distance(code1, code2)
	assert_approx(dist, 0.0, 0.001, "Identical codes have 0 distance")
	
	## Completely different codes should have high distance
	var code3: Array[int] = [9, 8, 7, 6, 5]
	dist = Molecule.structural_distance(code1, code3)
	assert_greater(dist, 1.0, "Different codes have positive distance")
	
	## Different length codes
	var code4: Array[int] = [1, 2, 3]
	dist = Molecule.structural_distance(code1, code4)
	assert_greater(dist, 0.0, "Different lengths have positive distance")

func test_molecule_similarity() -> void:
	start_test("Molecule Similarity")
	
	var mol1 = Molecule.new("A", 1.0, [1, 2, 3, 4, 5])
	var mol2 = Molecule.new("B", 1.0, [1, 2, 3, 4, 5])
	var mol3 = Molecule.new("C", 1.0, [9, 8, 7, 6, 5])
	
	var sim_identical = mol1.similarity_to(mol2)
	assert_approx(sim_identical, 1.0, 0.001, "Identical codes have similarity 1.0")
	
	var sim_different = mol1.similarity_to(mol3)
	assert_less(sim_different, 0.8, "Different codes have lower similarity")
	assert_greater(sim_different, 0.0, "Similarity is positive")

#endregion

#region Reaction Tests

func test_reaction_creation() -> void:
	start_test("Reaction Creation")
	
	var rxn = Reaction.new("R1", "Test Reaction")
	assert_equal(rxn.id, "R1", "ID set correctly")
	assert_equal(rxn.name, "Test Reaction", "Name set correctly")
	assert_greater(rxn.reaction_efficiency, 0.0, "Efficiency is positive")
	assert_less(rxn.reaction_efficiency, 1.0, "Efficiency is less than 1")

func test_reaction_keq_calculation() -> void:
	start_test("Equilibrium Constant (Keq)")
	
	var rxn = Reaction.new("R1")
	rxn.delta_g = -5.0  ## Exergonic
	rxn.temperature = 310.0
	
	var keq = rxn.calculate_keq()
	assert_greater(keq, 1.0, "Exergonic reaction has Keq > 1")
	
	rxn.delta_g = 5.0  ## Endergonic
	keq = rxn.calculate_keq()
	assert_less(keq, 1.0, "Endergonic reaction has Keq < 1")

func test_reaction_forward_rate() -> void:
	start_test("Forward Rate Calculation")
	
	## Setup molecules
	var molecules: Dictionary = {}
	molecules["A"] = Molecule.new("A", 2.0)
	molecules["B"] = Molecule.new("B", 0.1)
	
	var rxn = Reaction.new("R1")
	rxn.substrates = {"A": 1.0}
	rxn.products = {"B": 1.0}
	rxn.delta_g = -5.0
	rxn.vmax = 10.0
	rxn.km = 1.0
	rxn.reaction_efficiency = 0.8
	
	var rate = rxn.calculate_forward_rate(molecules, 0.01)
	assert_greater(rate, 0.0, "Forward rate is positive with substrate")
	
	## Zero enzyme concentration
	rate = rxn.calculate_forward_rate(molecules, 0.0)
	assert_approx(rate, 0.0, 0.001, "No rate without enzyme")

func test_reaction_reversibility() -> void:
	start_test("Reaction Reversibility")
	
	var molecules: Dictionary = {}
	molecules["A"] = Molecule.new("A", 0.1)  ## Low substrate
	molecules["B"] = Molecule.new("B", 5.0)  ## High product
	
	var rxn = Reaction.new("R1")
	rxn.substrates = {"A": 1.0}
	rxn.products = {"B": 1.0}
	rxn.delta_g = -2.0  ## Mildly exergonic
	rxn.is_irreversible = false
	
	rxn.calculate_forward_rate(molecules, 0.01)
	var rev_rate = rxn.calculate_reverse_rate(molecules, 0.01)
	assert_greater(rev_rate, 0.0, "Reversible reaction has reverse rate")
	
	## Test irreversible
	rxn.is_irreversible = true
	rev_rate = rxn.calculate_reverse_rate(molecules, 0.01)
	assert_approx(rev_rate, 0.0, 0.001, "Irreversible reaction has no reverse rate")

#endregion

#region Enzyme Tests

func test_enzyme_creation() -> void:
	start_test("Enzyme Creation")
	
	var enzyme = Enzyme.new("E1", "Test Enzyme")
	assert_equal(enzyme.id, "E1", "ID set correctly")
	assert_equal(enzyme.name, "Test Enzyme", "Name set correctly")
	assert_greater(enzyme.concentration, 0.0, "Concentration is positive")

func test_enzyme_reaction_management() -> void:
	start_test("Enzyme Reaction Management")
	
	var enzyme = Enzyme.new("E1", "Test")
	var rxn1 = Reaction.new("R1")
	var rxn2 = Reaction.new("R2")
	
	enzyme.add_reaction(rxn1)
	assert_equal(enzyme.reactions.size(), 1, "One reaction added")
	assert_equal(rxn1.enzyme, enzyme, "Reaction references enzyme")
	
	enzyme.add_reaction(rxn2)
	assert_equal(enzyme.reactions.size(), 2, "Two reactions added")
	
	enzyme.remove_reaction(rxn1)
	assert_equal(enzyme.reactions.size(), 1, "One reaction removed")

#endregion

#region Cell Tests

func test_cell_heat_tracking() -> void:
	start_test("Cell Heat Tracking")
	
	var cell = Cell.new()
	var initial_heat = cell.heat
	
	## Create a reaction that generates heat
	var rxn = Reaction.new("R1")
	rxn.current_heat_generated = 10.0
	
	var reactions: Array[Reaction] = [rxn]
	cell.update_heat(0.1, reactions)
	
	## Heat should have increased (minus some dissipation)
	assert_greater(cell.heat, initial_heat * 0.5, "Heat increased from reaction")
	assert_greater(cell.total_heat_generated, 0.0, "Total heat tracked")

func test_cell_energy_tracking() -> void:
	start_test("Cell Energy Tracking")
	
	var cell = Cell.new()
	
	var rxn = Reaction.new("R1")
	rxn.current_forward_rate = 1.0
	rxn.current_reverse_rate = 0.0
	rxn.current_useful_work = 5.0
	
	var reactions: Array[Reaction] = [rxn]
	cell.update_energy(0.1, reactions)
	
	assert_greater(cell.total_energy_generated, 0.0, "Energy generation tracked")

#endregion

#region Integration Tests

func test_simple_pathway() -> void:
	start_test("Simple A→B Pathway Integration")
	
	## Setup minimal system
	var molecules: Dictionary = {}
	molecules["A"] = Molecule.new("A", 5.0)
	molecules["B"] = Molecule.new("B", 0.1)
	
	var enzyme = Enzyme.new("E1", "Kinase")
	enzyme.concentration = 0.01
	
	var rxn = Reaction.new("R1")
	rxn.substrates = {"A": 1.0}
	rxn.products = {"B": 1.0}
	rxn.delta_g = -5.0
	rxn.vmax = 10.0
	rxn.km = 1.0
	rxn.reaction_efficiency = 0.7
	
	enzyme.add_reaction(rxn)
	
	## Run one update cycle
	enzyme.update_reaction_rates(molecules)
	
	var net_rate = rxn.get_net_rate()
	assert_greater(net_rate, 0.0, "Net rate is positive (forward)")
	
	## Apply concentration change
	var dt = 0.1
	molecules["A"].concentration -= net_rate * dt
	molecules["B"].concentration += net_rate * dt
	
	assert_less(molecules["A"].concentration, 5.0, "Substrate decreased")
	assert_greater(molecules["B"].concentration, 0.1, "Product increased")
	
	## Check energy partitioning
	assert_greater(rxn.current_useful_work, 0.0, "Work is generated")
	assert_greater(rxn.current_heat_generated, 0.0, "Heat is generated")

#endregion

#region Summary

func print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("✅ Passed: %d" % tests_passed)
	print("❌ Failed: %d" % tests_failed)
	print("📊 Total:  %d" % (tests_passed + tests_failed))
	
	if tests_failed == 0:
		print("\n🎉 ALL TESTS PASSED!")
	else:
		print("\n⚠️ SOME TESTS FAILED")
	
	print("=".repeat(60) + "\n")
	
	all_tests_completed.emit(tests_passed, tests_failed)

#endregion
