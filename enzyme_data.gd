## Enzyme resource - catalyzes reactions with degradation kinetics
## Can be saved as .tres for enzyme libraries
class_name EnzymeData
extends Resource

const LN2: float = 0.693147  ## ln(2) for half-life calculations

#region Exported Properties (Inspector Editable)

@export var enzyme_id: String = ""
@export var enzyme_name: String = ""

@export_group("Concentration")
@export var concentration: float = 0.005:
	set(value):
		concentration = maxf(0.0, value)
		emit_changed()

@export var initial_concentration: float = 0.005
@export var is_locked: bool = false  ## If true, concentration won't change during simulation

@export_group("Degradation")
@export var half_life: float = 300.0  ## Half-life in seconds (default ~5 min)
@export var is_degradable: bool = true  ## Source/sink enzymes may be non-degradable

@export_group("Reactions")
@export var reactions: Array[ReactionData] = []

#endregion

#region Runtime State (Not Saved)

var degradation_rate: float = 0.0  ## Calculated from half_life: k = ln(2) / t_half

#endregion

#region Initialization

func _init(p_id: String = "", p_name: String = "") -> void:
	if p_id != "":
		enzyme_id = p_id
		enzyme_name = p_name
		concentration = randf_range(0.001, 0.01)
		initial_concentration = concentration
		half_life = randf_range(120.0, 600.0)  ## 2-10 minutes typical range
		_update_degradation_rate()

func _update_degradation_rate() -> void:
	## First-order degradation: d[E]/dt = -k[E], where k = ln(2)/t_half
	if half_life > 0.0:
		degradation_rate = LN2 / half_life
	else:
		degradation_rate = 0.0

## Create a runtime instance from this resource template
func create_instance() -> EnzymeData:
	var instance = duplicate(false) as EnzymeData  ## Shallow duplicate
	instance.reactions = [] as Array[ReactionData]
	for rxn in reactions:
		var rxn_instance = rxn.create_instance()
		rxn_instance.enzyme = instance
		instance.reactions.append(rxn_instance)
	instance.concentration = initial_concentration
	instance._update_degradation_rate()
	return instance

## Reset to initial state
func reset() -> void:
	concentration = initial_concentration
	_update_degradation_rate()

#endregion

#region Reaction Management

func add_reaction(reaction: ReactionData) -> void:
	reaction.enzyme = self
	reactions.append(reaction)
	emit_changed()

func remove_reaction(reaction: ReactionData) -> void:
	reactions.erase(reaction)
	emit_changed()

func clear_reactions() -> void:
	reactions.clear()
	emit_changed()

#endregion

#region Degradation Update

## Apply degradation for this timestep, returns amount degraded
func apply_degradation(delta: float) -> float:
	if is_locked or not is_degradable or concentration <= 0.0:
		return 0.0
	
	## First-order kinetics: [E](t) = [E]_0 * e^(-kt)
	## For small dt: d[E] ≈ -k * [E] * dt
	var amount_degraded = degradation_rate * concentration * delta
	concentration = max(0.0, concentration - amount_degraded)
	return amount_degraded

#endregion

#region Type Checking

func is_source() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_source():
			return false
	return true

func is_sink() -> bool:
	if reactions.is_empty():
		return false
	for rxn in reactions:
		if not rxn.is_sink():
			return false
	return true

#endregion

#region Rate Updates

## Update rates for all reactions this enzyme catalyzes
func update_reaction_rates(molecules: Dictionary) -> void:
	for reaction in reactions:
		reaction.calculate_forward_rate(molecules, concentration)
		reaction.calculate_reverse_rate(molecules, concentration)
		reaction.calculate_energy_partition(reaction.get_net_rate())

#endregion

#region Display

func get_reactions_summary() -> String:
	var summary = ""
	for i in range(reactions.size()):
		if i > 0:
			summary += "\n"
		summary += reactions[i].get_summary()
	return summary

func get_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	return "%s [%.4f mM] - %d reaction(s)%s" % [enzyme_name, concentration, reactions.size(), lock_str]

func get_detailed_summary() -> String:
	var lock_str = " 🔒" if is_locked else ""
	var degrade_str = "t½=%.0fs" % half_life if is_degradable else "stable"
	return "%s [%.4f mM] (%s) - %d reaction(s)%s" % [
		enzyme_name, concentration, degrade_str, reactions.size(), lock_str
	]

func _to_string() -> String:
	return "EnzymeData(%s: %s)" % [enzyme_id, enzyme_name]

#endregion
