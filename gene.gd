## Gene encodes protein expression with regulatory control
## Produces enzyme at a rate determined by basal expression and regulatory elements
class_name Gene
extends RefCounted

var id: String
var name: String
var enzyme_id: String  ## ID of the enzyme this gene produces

#region Expression Parameters

var basal_rate: float = 0.0001  ## Base expression rate (mM/s) without regulation
var max_expression_rate: float = 0.01  ## Upper limit on expression rate
var is_active: bool = true  ## Whether gene is being transcribed

#endregion

#region Regulation

var activators: Array[RegulatoryElement] = []
var repressors: Array[RegulatoryElement] = []

#endregion

#region Runtime State

var current_expression_rate: float = 0.0  ## Effective rate after all regulation
var current_fold_activation: float = 1.0  ## Combined effect of activators
var current_fold_repression: float = 1.0  ## Combined effect of repressors

#endregion

#region Initialization

func _init(p_id: String, p_enzyme_id: String, p_basal_rate: float = 0.0001) -> void:
	id = p_id
	name = "gene_" + p_enzyme_id
	enzyme_id = p_enzyme_id
	basal_rate = max(p_basal_rate, 1e-6)
	max_expression_rate = basal_rate * 100.0  ## Default max is 100x basal

static func generate_name_for_enzyme(enzyme_name: String) -> String:
	## Convention: gene name is lowercase enzyme name with gene_ prefix
	return "gene_" + enzyme_name.to_lower().replace(" ", "_")

#endregion

#region Regulatory Element Management

func add_activator(molecule: String, kd: float = 1.0, max_fold: float = 10.0, hill: float = 1.0) -> RegulatoryElement:
	var element = RegulatoryElement.create_activator(molecule, kd, max_fold, hill)
	activators.append(element)
	return element

func add_repressor(molecule: String, kd: float = 1.0, max_fold: float = 10.0, hill: float = 1.0) -> RegulatoryElement:
	var element = RegulatoryElement.create_repressor(molecule, kd, max_fold, hill)
	repressors.append(element)
	return element

func remove_activator(index: int) -> void:
	if index >= 0 and index < activators.size():
		activators.remove_at(index)

func remove_repressor(index: int) -> void:
	if index >= 0 and index < repressors.size():
		repressors.remove_at(index)

func clear_regulation() -> void:
	activators.clear()
	repressors.clear()

#endregion

#region Expression Calculation

## Calculate effective expression rate based on current molecule concentrations
func calculate_expression_rate(molecules: Dictionary) -> float:
	if not is_active:
		current_expression_rate = 0.0
		current_fold_activation = 1.0
		current_fold_repression = 1.0
		return 0.0
	
	## Start with basal rate
	var rate = basal_rate
	
	## Apply activators (multiplicative)
	current_fold_activation = 1.0
	for activator in activators:
		var effect = activator.calculate_effect(molecules)
		current_fold_activation *= effect
	
	## Apply repressors (multiplicative)
	current_fold_repression = 1.0
	for repressor in repressors:
		var effect = repressor.calculate_effect(molecules)
		current_fold_repression *= effect
	
	## Combined effect
	rate *= current_fold_activation * current_fold_repression
	
	## Clamp to max expression rate
	current_expression_rate = clampf(rate, 0.0, max_expression_rate)
	return current_expression_rate

## Get the amount of enzyme to synthesize this frame
func get_synthesis_amount(delta: float, molecules: Dictionary) -> float:
	calculate_expression_rate(molecules)
	return current_expression_rate * delta

#endregion

#region Analysis

## Check if expression is being activated (rate > basal)
func is_upregulated() -> bool:
	return current_expression_rate > basal_rate * 1.1

## Check if expression is being repressed (rate < basal)  
func is_downregulated() -> bool:
	return current_expression_rate < basal_rate * 0.9

## Get fold change from basal
func get_fold_change() -> float:
	if basal_rate <= 0.0:
		return 0.0
	return current_expression_rate / basal_rate

## Get list of molecules this gene responds to
func get_regulatory_molecules() -> Array[String]:
	var molecules: Array[String] = []
	for act in activators:
		if not molecules.has(act.molecule_name):
			molecules.append(act.molecule_name)
	for rep in repressors:
		if not molecules.has(rep.molecule_name):
			molecules.append(rep.molecule_name)
	return molecules

#endregion

#region Display

func get_summary() -> String:
	var status = "active" if is_active else "inactive"
	var reg_count = activators.size() + repressors.size()
	return "%s → %s (%s, %d regulators)" % [name, enzyme_id, status, reg_count]

func get_detailed_summary() -> String:
	var lines: Array[String] = []
	lines.append("Gene: %s → Enzyme: %s" % [name, enzyme_id])
	lines.append("  Basal rate: %.2e mM/s" % basal_rate)
	lines.append("  Current rate: %.2e mM/s (%.1fx basal)" % [current_expression_rate, get_fold_change()])
	
	if not activators.is_empty():
		lines.append("  Activators (%.1fx combined):" % current_fold_activation)
		for act in activators:
			lines.append("    " + act.get_summary())
	
	if not repressors.is_empty():
		lines.append("  Repressors (%.1fx combined):" % current_fold_repression)
		for rep in repressors:
			lines.append("    " + rep.get_summary())
	
	return "\n".join(lines)

func get_regulation_summary() -> String:
	if activators.is_empty() and repressors.is_empty():
		return "constitutive"
	
	var parts: Array[String] = []
	for act in activators:
		parts.append("+%s" % act.molecule_name)
	for rep in repressors:
		parts.append("-%s" % rep.molecule_name)
	return ", ".join(parts)

#endregion
