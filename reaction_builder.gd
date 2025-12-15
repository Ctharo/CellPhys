## ReactionBuilder - Fluent builder pattern for constructing ReactionData
## Makes it easy to create complex multi-substrate/multi-product reactions
class_name ReactionBuilder
extends RefCounted

var _reaction: ReactionData

#region Construction

func _init(reaction_id: String = "", reaction_name: String = "") -> void:
	_reaction = ReactionData.new(reaction_id, reaction_name)


## Create a new builder
static func create(reaction_id: String = "", reaction_name: String = "") -> ReactionBuilder:
	return ReactionBuilder.new(reaction_id, reaction_name)

#endregion

#region Substrates

## Add a single substrate (stoichiometry defaults to 1.0)
func substrate(mol_name: String, stoich: float = 1.0) -> ReactionBuilder:
	_reaction.substrates[mol_name] = stoich
	return self


## Add multiple substrates: {"A": 1.0, "B": 2.0}
func substrates(substrate_dict: Dictionary) -> ReactionBuilder:
	for mol_name in substrate_dict:
		_reaction.substrates[mol_name] = substrate_dict[mol_name]
	return self


## Convenience: A + B (both stoich 1.0)
func substrates_simple(mol_names: Array[String]) -> ReactionBuilder:
	for mol_name in mol_names:
		_reaction.substrates[mol_name] = 1.0
	return self

#endregion

#region Products

## Add a single product (stoichiometry defaults to 1.0)
func product(mol_name: String, stoich: float = 1.0) -> ReactionBuilder:
	_reaction.products[mol_name] = stoich
	return self


## Add multiple products: {"C": 1.0, "D": 1.0}
func products(product_dict: Dictionary) -> ReactionBuilder:
	for mol_name in product_dict:
		_reaction.products[mol_name] = product_dict[mol_name]
	return self


## Convenience: C + D (both stoich 1.0)
func products_simple(mol_names: Array[String]) -> ReactionBuilder:
	for mol_name in mol_names:
		_reaction.products[mol_name] = 1.0
	return self

#endregion

#region Kinetic Parameters

## Set maximum velocity (mM/s)
func vmax(value: float) -> ReactionBuilder:
	_reaction.vmax = value
	return self


## Set Michaelis constant (mM)
func km(value: float) -> ReactionBuilder:
	_reaction.km = value
	return self


## Set reaction efficiency (0-1)
func efficiency(value: float) -> ReactionBuilder:
	_reaction.reaction_efficiency = clampf(value, 0.01, 0.99)
	return self


## Mark reaction as irreversible
func irreversible(value: bool = true) -> ReactionBuilder:
	_reaction.is_irreversible = value
	return self

#endregion

#region Thermodynamic Parameters

## Set standard free energy change (kJ/mol)
## Negative = exergonic (favored forward)
## Positive = endergonic (requires energy)
func delta_g(value: float) -> ReactionBuilder:
	_reaction.delta_g = value
	return self


## Set temperature (Kelvin)
func temperature(value: float) -> ReactionBuilder:
	_reaction.temperature = value
	return self

#endregion

#region Build

## Finalize and return the reaction
func build() -> ReactionData:
	## Auto-generate name if not set
	if _reaction.reaction_name == "" or _reaction.reaction_name == _reaction.reaction_id:
		_reaction.reaction_name = _reaction.get_summary()
	return _reaction


## Build and validate
func build_validated() -> Dictionary:
	var rxn = build()
	var valid = rxn.is_valid()
	return {
		"reaction": rxn,
		"valid": valid,
		"reason": "" if valid else "Reaction has no substrates and no products"
	}

#endregion

#region Presets

## Create a simple A → B reaction
static func simple(substrate_name: String, product_name: String, delta_g_val: float = -5.0) -> ReactionData:
	return ReactionBuilder.create() \
		.substrate(substrate_name) \
		.product(product_name) \
		.delta_g(delta_g_val) \
		.build()


## Create source reaction (∅ → A)
static func source(product_name: String, stoich: float = 1.0) -> ReactionData:
	return ReactionBuilder.create() \
		.product(product_name, stoich) \
		.irreversible() \
		.build()


## Create sink reaction (A → ∅)
static func sink(substrate_name: String, stoich: float = 1.0) -> ReactionData:
	return ReactionBuilder.create() \
		.substrate(substrate_name, stoich) \
		.irreversible() \
		.build()


## Create bimolecular reaction: A + B → C
static func bimolecular_substrate(sub_a: String, sub_b: String, product_name: String) -> ReactionData:
	return ReactionBuilder.create() \
		.substrates_simple([sub_a, sub_b] as Array[String]) \
		.product(product_name) \
		.build()


## Create splitting reaction: A → B + C
static func bimolecular_product(substrate_name: String, prod_a: String, prod_b: String) -> ReactionData:
	return ReactionBuilder.create() \
		.substrate(substrate_name) \
		.products_simple([prod_a, prod_b] as Array[String]) \
		.build()


## Create exchange reaction: A + B → C + D
static func exchange(sub_a: String, sub_b: String, prod_a: String, prod_b: String) -> ReactionData:
	return ReactionBuilder.create() \
		.substrates_simple([sub_a, sub_b] as Array[String]) \
		.products_simple([prod_a, prod_b] as Array[String]) \
		.build()


## Create ATP-coupled reaction: A + ATP → B + ADP + Pi
static func atp_coupled(substrate_name: String, product_name: String, delta_g_val: float = -30.0) -> ReactionData:
	return ReactionBuilder.create() \
		.substrates({"ATP": 1.0, substrate_name: 1.0}) \
		.products({"ADP": 1.0, "Pi": 1.0, product_name: 1.0}) \
		.delta_g(delta_g_val) \
		.irreversible() \
		.build()


## Create NAD-coupled oxidation: A + NAD+ → B + NADH
static func nad_oxidation(substrate_name: String, product_name: String) -> ReactionData:
	return ReactionBuilder.create() \
		.substrates({substrate_name: 1.0, "NAD+": 1.0}) \
		.products({product_name: 1.0, "NADH": 1.0}) \
		.delta_g(-5.0) \
		.build()

#endregion
