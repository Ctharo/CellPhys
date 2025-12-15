## EnzymeBuilder - Fluent builder pattern for constructing EnzymeData
## Validates that multi-reaction enzymes don't share molecules between reactions
class_name EnzymeBuilder
extends RefCounted

var _enzyme: EnzymeData
var _strict_validation: bool = true
var _validation_errors: Array[String] = []

#region Construction

func _init(enzyme_id: String = "", enzyme_name: String = "") -> void:
	_enzyme = EnzymeData.new(enzyme_id, enzyme_name)


## Create a new builder
static func create(enzyme_id: String = "", enzyme_name: String = "") -> EnzymeBuilder:
	return EnzymeBuilder.new(enzyme_id, enzyme_name)

#endregion

#region Configuration

## Set enzyme name
func name(value: String) -> EnzymeBuilder:
	_enzyme.enzyme_name = value
	return self


## Set concentration (mM)
func concentration(value: float) -> EnzymeBuilder:
	_enzyme.concentration = value
	_enzyme.initial_concentration = value
	return self


## Set both current and initial concentration separately
func concentrations(current: float, initial: float) -> EnzymeBuilder:
	_enzyme.concentration = current
	_enzyme.initial_concentration = initial
	return self


## Lock concentration (won't change during simulation)
func locked(value: bool = true) -> EnzymeBuilder:
	_enzyme.is_locked = value
	return self


## Set degradation half-life (seconds)
func half_life(value: float) -> EnzymeBuilder:
	_enzyme.half_life = value
	_enzyme.is_degradable = true
	_enzyme._update_degradation_rate()
	return self


## Mark as non-degradable (stable enzyme)
func stable() -> EnzymeBuilder:
	_enzyme.is_degradable = false
	_enzyme.half_life = 3600.0  ## 1 hour nominal
	_enzyme._update_degradation_rate()
	return self


## Enable or disable strict validation (default: enabled)
func strict(value: bool = true) -> EnzymeBuilder:
	_strict_validation = value
	return self

#endregion

#region Reactions

## Add a reaction (validates if strict mode enabled)
func reaction(rxn: ReactionData) -> EnzymeBuilder:
	if _strict_validation and not _enzyme.reactions.is_empty():
		var validation = _enzyme.validate_new_reaction(rxn)
		if not validation.valid:
			_validation_errors.append(validation.reason)
			push_warning("EnzymeBuilder: %s" % validation.reason)
			return self  ## Skip adding invalid reaction
	
	_enzyme.add_reaction(rxn)
	return self


## Add multiple reactions (validates each if strict mode)
func reactions(rxn_array: Array[ReactionData]) -> EnzymeBuilder:
	for rxn in rxn_array:
		reaction(rxn)
	return self


## Add a simple A → B reaction inline
func simple_reaction(substrate: String, product: String, delta_g: float = -5.0) -> EnzymeBuilder:
	var rxn = ReactionBuilder.simple(substrate, product, delta_g)
	rxn.reaction_id = "%s_rxn_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)


## Add a source reaction inline (∅ → A)
func source_reaction(product: String) -> EnzymeBuilder:
	var rxn = ReactionBuilder.source(product)
	rxn.reaction_id = "%s_source_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)


## Add a sink reaction inline (A → ∅)
func sink_reaction(substrate: String) -> EnzymeBuilder:
	var rxn = ReactionBuilder.sink(substrate)
	rxn.reaction_id = "%s_sink_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)


## Add a bimolecular substrate reaction inline (A + B → C)
func combine_reaction(sub_a: String, sub_b: String, product: String) -> EnzymeBuilder:
	var rxn = ReactionBuilder.bimolecular_substrate(sub_a, sub_b, product)
	rxn.reaction_id = "%s_combine_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)


## Add a splitting reaction inline (A → B + C)
func split_reaction(substrate: String, prod_a: String, prod_b: String) -> EnzymeBuilder:
	var rxn = ReactionBuilder.bimolecular_product(substrate, prod_a, prod_b)
	rxn.reaction_id = "%s_split_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)


## Add an exchange reaction inline (A + B → C + D)
func exchange_reaction(sub_a: String, sub_b: String, prod_a: String, prod_b: String) -> EnzymeBuilder:
	var rxn = ReactionBuilder.exchange(sub_a, sub_b, prod_a, prod_b)
	rxn.reaction_id = "%s_exchange_%d" % [_enzyme.enzyme_id, _enzyme.reactions.size()]
	return reaction(rxn)

#endregion

#region Build

## Finalize and return the enzyme
func build() -> EnzymeData:
	return _enzyme


## Build with full validation report
func build_validated() -> Dictionary:
	var all_valid = _validation_errors.is_empty()
	var final_validation = _enzyme.validate_all_reactions()
	
	return {
		"enzyme": _enzyme,
		"valid": all_valid and final_validation.valid,
		"build_errors": _validation_errors.duplicate(),
		"validation": final_validation,
		"suggestion": _enzyme.suggest_split() if not final_validation.valid else {}
	}


## Check if any validation errors occurred during building
func has_errors() -> bool:
	return not _validation_errors.is_empty()


## Get validation errors
func get_errors() -> Array[String]:
	return _validation_errors.duplicate()

#endregion

#region Presets

## Create a simple single-reaction enzyme
static func single_reaction(enzyme_id: String, substrate: String, product: String) -> EnzymeData:
	return EnzymeBuilder.create(enzyme_id, enzyme_id.capitalize()) \
		.simple_reaction(substrate, product) \
		.build()


## Create a source enzyme (produces a molecule from nothing)
static func source_enzyme(enzyme_id: String, product: String) -> EnzymeData:
	return EnzymeBuilder.create(enzyme_id, "%s_Source" % product) \
		.source_reaction(product) \
		.stable() \
		.build()


## Create a sink enzyme (removes a molecule)
static func sink_enzyme(enzyme_id: String, substrate: String) -> EnzymeData:
	return EnzymeBuilder.create(enzyme_id, "%s_Sink" % substrate) \
		.sink_reaction(substrate) \
		.stable() \
		.build()


## Create a multi-functional enzyme with independent reactions
## Will validate that reactions don't share molecules
static func multi_functional(enzyme_id: String, rxn_array: Array[ReactionData]) -> Dictionary:
	var builder = EnzymeBuilder.create(enzyme_id, enzyme_id.capitalize())
	builder.reactions(rxn_array)
	return builder.build_validated()

#endregion
