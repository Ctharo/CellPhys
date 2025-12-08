## Panel for displaying gene expression and regulation status
## Works with GeneData Resources - shows each gene with regulators and expression state
class_name GenePanel
extends VBoxContainer

signal gene_toggled(gene_id: String, is_active: bool)
signal regulator_selected(gene_id: String, element_index: int, is_activator: bool)

const UPREGULATED_COLOR = Color(0.2, 0.8, 0.3)
const DOWNREGULATED_COLOR = Color(0.8, 0.3, 0.2)
const BASAL_COLOR = Color(0.7, 0.7, 0.7)

var gene_entries: Dictionary = {}
var category_locked: bool = false

class GeneEntry:
	var container: VBoxContainer
	var header: HBoxContainer
	var toggle: CheckButton
	var name_label: Label
	var status_label: Label
	var enzyme_label: Label
	var rate_bar: ProgressBar
	var regulation_container: VBoxContainer
	var activator_entries: Array = []
	var repressor_entries: Array = []

class RegulatorEntry:
	var container: HBoxContainer
	var molecule_label: Label
	var occupancy_bar: ProgressBar
	var effect_label: Label

#region Setup

func _ready() -> void:
	pass

func clear() -> void:
	for child in get_children():
		child.queue_free()
	gene_entries.clear()

func setup_genes(genes: Dictionary, enzymes: Dictionary) -> void:
	clear()
	
	if genes.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No genes in simulation"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	for gene_id in genes:
		var gene = genes[gene_id]
		var enzyme = enzymes.get(_get_enzyme_id(gene))
		_create_gene_entry(gene, enzyme)

func add_gene(gene, enzyme) -> void:
	if gene_entries.is_empty() and get_child_count() > 0:
		var first_child = get_child(0)
		if first_child is Label:
			first_child.queue_free()
	
	_create_gene_entry(gene, enzyme)

## Helper to get enzyme_id regardless of class type
func _get_enzyme_id(gene) -> String:
	if gene is GeneData:
		return gene.enzyme_id
	return gene.enzyme_id  ## Legacy Gene class

func _get_gene_name(gene) -> String:
	if gene is GeneData:
		return gene.gene_name
	return gene.name

func _get_activators(gene) -> Array:
	return gene.activators

func _get_repressors(gene) -> Array:
	return gene.repressors

func _get_enzyme_name(enzyme) -> String:
	if enzyme is EnzymeData:
		return enzyme.enzyme_name
	return enzyme.name if enzyme else "???"

func _get_enzyme_concentration(enzyme) -> float:
	return enzyme.concentration if enzyme else 0.0

func _create_gene_entry(gene, enzyme) -> void:
	var entry = GeneEntry.new()
	var gene_enzyme_id = _get_enzyme_id(gene)
	
	entry.container = VBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 4)
	
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	
	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 4)
	
	## Header row
	entry.header = HBoxContainer.new()
	entry.header.add_theme_constant_override("separation", 8)
	
	entry.toggle = CheckButton.new()
	entry.toggle.button_pressed = gene.is_active
	entry.toggle.tooltip_text = "Toggle gene expression"
	entry.toggle.toggled.connect(_on_gene_toggled.bind(gene_enzyme_id))
	entry.toggle.disabled = category_locked
	entry.header.add_child(entry.toggle)
	
	entry.name_label = Label.new()
	entry.name_label.text = _get_gene_name(gene)
	entry.name_label.add_theme_font_size_override("font_size", 14)
	entry.header.add_child(entry.name_label)
	
	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entry.header.add_child(arrow_label)
	
	entry.enzyme_label = Label.new()
	entry.enzyme_label.text = _get_enzyme_name(enzyme)
	entry.enzyme_label.add_theme_font_size_override("font_size", 14)
	entry.header.add_child(entry.enzyme_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.header.add_child(spacer)
	
	entry.status_label = Label.new()
	entry.status_label.text = "1.0x"
	entry.status_label.add_theme_font_size_override("font_size", 13)
	entry.header.add_child(entry.status_label)
	
	card_content.add_child(entry.header)
	
	## Rate bar
	var rate_row = HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 8)
	
	var rate_label = Label.new()
	rate_label.text = "Expression:"
	rate_label.add_theme_font_size_override("font_size", 11)
	rate_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	rate_row.add_child(rate_label)
	
	entry.rate_bar = ProgressBar.new()
	entry.rate_bar.custom_minimum_size = Vector2(120, 12)
	entry.rate_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.rate_bar.max_value = 10.0
	entry.rate_bar.value = 1.0
	entry.rate_bar.show_percentage = false
	rate_row.add_child(entry.rate_bar)
	
	card_content.add_child(rate_row)
	
	## Regulation section
	entry.regulation_container = VBoxContainer.new()
	entry.regulation_container.add_theme_constant_override("separation", 2)
	
	var activators = _get_activators(gene)
	var repressors = _get_repressors(gene)
	
	if not activators.is_empty():
		var act_header = Label.new()
		act_header.text = "Activators:"
		act_header.add_theme_font_size_override("font_size", 11)
		act_header.add_theme_color_override("font_color", UPREGULATED_COLOR)
		entry.regulation_container.add_child(act_header)
		
		for i in range(activators.size()):
			var act = activators[i]
			var act_entry = _create_regulator_entry(act, true, gene_enzyme_id, i)
			entry.activator_entries.append(act_entry)
			entry.regulation_container.add_child(act_entry.container)
	
	if not repressors.is_empty():
		var rep_header = Label.new()
		rep_header.text = "Repressors:"
		rep_header.add_theme_font_size_override("font_size", 11)
		rep_header.add_theme_color_override("font_color", DOWNREGULATED_COLOR)
		entry.regulation_container.add_child(rep_header)
		
		for i in range(repressors.size()):
			var rep = repressors[i]
			var rep_entry = _create_regulator_entry(rep, false, gene_enzyme_id, i)
			entry.repressor_entries.append(rep_entry)
			entry.regulation_container.add_child(rep_entry.container)
	
	if activators.is_empty() and repressors.is_empty():
		var const_label = Label.new()
		const_label.text = "Constitutive (no regulation)"
		const_label.add_theme_font_size_override("font_size", 11)
		const_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		entry.regulation_container.add_child(const_label)
	
	card_content.add_child(entry.regulation_container)
	card.add_child(card_content)
	entry.container.add_child(card)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	entry.container.add_child(sep)
	
	add_child(entry.container)
	gene_entries[gene_enzyme_id] = entry

func _create_regulator_entry(element, is_activator: bool, gene_id: String, index: int) -> RegulatorEntry:
	var entry = RegulatorEntry.new()
	
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 6)
	
	var indent = Control.new()
	indent.custom_minimum_size = Vector2(16, 0)
	entry.container.add_child(indent)
	
	var icon = Label.new()
	icon.text = "+" if is_activator else "−"
	icon.add_theme_color_override("font_color", UPREGULATED_COLOR if is_activator else DOWNREGULATED_COLOR)
	entry.container.add_child(icon)
	
	entry.molecule_label = Label.new()
	entry.molecule_label.text = element.molecule_name
	entry.molecule_label.add_theme_font_size_override("font_size", 11)
	entry.molecule_label.custom_minimum_size = Vector2(80, 0)
	entry.container.add_child(entry.molecule_label)
	
	entry.occupancy_bar = ProgressBar.new()
	entry.occupancy_bar.custom_minimum_size = Vector2(60, 10)
	entry.occupancy_bar.max_value = 1.0
	entry.occupancy_bar.value = 0.0
	entry.occupancy_bar.show_percentage = false
	entry.container.add_child(entry.occupancy_bar)
	
	entry.effect_label = Label.new()
	entry.effect_label.text = "1.0x"
	entry.effect_label.add_theme_font_size_override("font_size", 11)
	entry.effect_label.custom_minimum_size = Vector2(45, 0)
	entry.effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.container.add_child(entry.effect_label)
	
	var kd_label = Label.new()
	kd_label.text = "(Kd=%.2f)" % element.kd
	kd_label.add_theme_font_size_override("font_size", 10)
	kd_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	entry.container.add_child(kd_label)
	
	return entry

#endregion

#region Updates

func update_genes(genes: Dictionary, molecules: Dictionary, enzymes: Dictionary) -> void:
	for gene_id in genes:
		if not gene_entries.has(gene_id):
			continue
		
		var gene = genes[gene_id]
		var entry: GeneEntry = gene_entries[gene_id]
		var enzyme = enzymes.get(_get_enzyme_id(gene))
		
		var fold = gene.get_fold_change()
		entry.status_label.text = "%.2fx" % fold
		
		if fold > 1.1:
			entry.status_label.add_theme_color_override("font_color", UPREGULATED_COLOR)
		elif fold < 0.9:
			entry.status_label.add_theme_color_override("font_color", DOWNREGULATED_COLOR)
		else:
			entry.status_label.add_theme_color_override("font_color", BASAL_COLOR)
		
		var bar_value = clampf(fold, 0.1, 10.0)
		entry.rate_bar.value = bar_value
		
		if enzyme:
			entry.enzyme_label.text = "%s [%.4f mM]" % [_get_enzyme_name(enzyme), _get_enzyme_concentration(enzyme)]
		
		var activators = _get_activators(gene)
		for i in range(activators.size()):
			if i >= entry.activator_entries.size():
				break
			var act = activators[i]
			var act_entry = entry.activator_entries[i]
			var occupancy = act.get_occupancy(molecules)
			var effect = act.calculate_effect(molecules)
			act_entry.occupancy_bar.value = occupancy
			act_entry.effect_label.text = "%.1fx" % effect
		
		var repressors = _get_repressors(gene)
		for i in range(repressors.size()):
			if i >= entry.repressor_entries.size():
				break
			var rep = repressors[i]
			var rep_entry = entry.repressor_entries[i]
			var occupancy = rep.get_occupancy(molecules)
			var effect = rep.calculate_effect(molecules)
			rep_entry.occupancy_bar.value = occupancy
			rep_entry.effect_label.text = "%.2fx" % effect

func set_category_locked(locked: bool) -> void:
	category_locked = locked
	for gene_id in gene_entries:
		var entry: GeneEntry = gene_entries[gene_id]
		entry.toggle.disabled = locked
		
		if locked:
			entry.name_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		else:
			entry.name_label.remove_theme_color_override("font_color")

#endregion

#region Signals

func _on_gene_toggled(is_active: bool, gene_id: String) -> void:
	gene_toggled.emit(gene_id, is_active)

#endregion
