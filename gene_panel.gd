## Panel for displaying gene expression and regulation status
## Shows each gene with its regulators and current expression state
class_name GenePanel
extends VBoxContainer

signal gene_toggled(gene_id: String, is_active: bool)
signal regulator_selected(gene_id: String, element_index: int, is_activator: bool)

const UPREGULATED_COLOR = Color(0.2, 0.8, 0.3)
const DOWNREGULATED_COLOR = Color(0.8, 0.3, 0.2)
const BASAL_COLOR = Color(0.7, 0.7, 0.7)

var gene_entries: Dictionary = {}  ## {gene_id: GeneEntry}
var category_locked: bool = false  ## Whether the entire category is locked

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
		var gene: Gene = genes[gene_id]
		var enzyme: Enzyme = enzymes.get(gene.enzyme_id)
		_create_gene_entry(gene, enzyme)

## Add a single gene dynamically (for reactive updates)
func add_gene(gene: Gene, enzyme: Enzyme) -> void:
	## Remove "no genes" label if present
	if gene_entries.is_empty() and get_child_count() > 0:
		var first_child = get_child(0)
		if first_child is Label:
			first_child.queue_free()
	
	_create_gene_entry(gene, enzyme)

func _create_gene_entry(gene: Gene, enzyme: Enzyme) -> void:
	var entry = GeneEntry.new()
	
	## Main container
	entry.container = VBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 4)
	
	## Gene card panel
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
	
	## Header row: toggle + name + status
	entry.header = HBoxContainer.new()
	entry.header.add_theme_constant_override("separation", 8)
	
	entry.toggle = CheckButton.new()
	entry.toggle.button_pressed = gene.is_active
	entry.toggle.tooltip_text = "Toggle gene expression"
	entry.toggle.toggled.connect(_on_gene_toggled.bind(gene.enzyme_id))
	entry.toggle.disabled = category_locked
	entry.header.add_child(entry.toggle)
	
	entry.name_label = Label.new()
	entry.name_label.text = gene.name
	entry.name_label.add_theme_font_size_override("font_size", 14)
	entry.header.add_child(entry.name_label)
	
	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entry.header.add_child(arrow_label)
	
	entry.enzyme_label = Label.new()
	entry.enzyme_label.text = enzyme.name if enzyme else "???"
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
	entry.rate_bar.max_value = 10.0  ## Will show fold change from basal
	entry.rate_bar.value = 1.0
	entry.rate_bar.show_percentage = false
	rate_row.add_child(entry.rate_bar)
	
	card_content.add_child(rate_row)
	
	## Regulation section
	entry.regulation_container = VBoxContainer.new()
	entry.regulation_container.add_theme_constant_override("separation", 2)
	
	## Activators
	if not gene.activators.is_empty():
		var act_header = Label.new()
		act_header.text = "Activators:"
		act_header.add_theme_font_size_override("font_size", 11)
		act_header.add_theme_color_override("font_color", UPREGULATED_COLOR)
		entry.regulation_container.add_child(act_header)
		
		for i in range(gene.activators.size()):
			var act: RegulatoryElement = gene.activators[i]
			var act_entry = _create_regulator_entry(act, true, gene.enzyme_id, i)
			entry.activator_entries.append(act_entry)
			entry.regulation_container.add_child(act_entry.container)
	
	## Repressors
	if not gene.repressors.is_empty():
		var rep_header = Label.new()
		rep_header.text = "Repressors:"
		rep_header.add_theme_font_size_override("font_size", 11)
		rep_header.add_theme_color_override("font_color", DOWNREGULATED_COLOR)
		entry.regulation_container.add_child(rep_header)
		
		for i in range(gene.repressors.size()):
			var rep: RegulatoryElement = gene.repressors[i]
			var rep_entry = _create_regulator_entry(rep, false, gene.enzyme_id, i)
			entry.repressor_entries.append(rep_entry)
			entry.regulation_container.add_child(rep_entry.container)
	
	## Constitutive label if no regulation
	if gene.activators.is_empty() and gene.repressors.is_empty():
		var const_label = Label.new()
		const_label.text = "Constitutive (no regulation)"
		const_label.add_theme_font_size_override("font_size", 11)
		const_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		entry.regulation_container.add_child(const_label)
	
	card_content.add_child(entry.regulation_container)
	card.add_child(card_content)
	entry.container.add_child(card)
	
	## Add separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	entry.container.add_child(sep)
	
	add_child(entry.container)
	gene_entries[gene.enzyme_id] = entry

func _create_regulator_entry(element: RegulatoryElement, is_activator: bool, gene_id: String, index: int) -> RegulatorEntry:
	var entry = RegulatorEntry.new()
	
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 6)
	
	## Indent
	var indent = Control.new()
	indent.custom_minimum_size = Vector2(16, 0)
	entry.container.add_child(indent)
	
	## Icon
	var icon = Label.new()
	icon.text = "+" if is_activator else "−"
	icon.add_theme_color_override("font_color", UPREGULATED_COLOR if is_activator else DOWNREGULATED_COLOR)
	entry.container.add_child(icon)
	
	## Molecule name
	entry.molecule_label = Label.new()
	entry.molecule_label.text = element.molecule_name
	entry.molecule_label.add_theme_font_size_override("font_size", 11)
	entry.molecule_label.custom_minimum_size = Vector2(80, 0)
	entry.container.add_child(entry.molecule_label)
	
	## Occupancy bar
	entry.occupancy_bar = ProgressBar.new()
	entry.occupancy_bar.custom_minimum_size = Vector2(60, 10)
	entry.occupancy_bar.max_value = 1.0
	entry.occupancy_bar.value = 0.0
	entry.occupancy_bar.show_percentage = false
	entry.container.add_child(entry.occupancy_bar)
	
	## Effect label
	entry.effect_label = Label.new()
	entry.effect_label.text = "1.0x"
	entry.effect_label.add_theme_font_size_override("font_size", 11)
	entry.effect_label.custom_minimum_size = Vector2(45, 0)
	entry.effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.container.add_child(entry.effect_label)
	
	## Kd info
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
		
		var gene: Gene = genes[gene_id]
		var entry: GeneEntry = gene_entries[gene_id]
		var enzyme: Enzyme = enzymes.get(gene.enzyme_id)
		
		## Update status
		var fold = gene.get_fold_change()
		entry.status_label.text = "%.2fx" % fold
		
		if fold > 1.1:
			entry.status_label.add_theme_color_override("font_color", UPREGULATED_COLOR)
		elif fold < 0.9:
			entry.status_label.add_theme_color_override("font_color", DOWNREGULATED_COLOR)
		else:
			entry.status_label.add_theme_color_override("font_color", BASAL_COLOR)
		
		## Update rate bar (log scale, centered at 1.0)
		## Show 0.1x to 10x range
		var bar_value = clampf(fold, 0.1, 10.0)
		entry.rate_bar.value = bar_value
		
		## Update enzyme concentration in label
		if enzyme:
			entry.enzyme_label.text = "%s [%.4f mM]" % [enzyme.name, enzyme.concentration]
		
		## Update activator entries
		for i in range(gene.activators.size()):
			if i >= entry.activator_entries.size():
				break
			var act: RegulatoryElement = gene.activators[i]
			var act_entry = entry.activator_entries[i]
			var occupancy = act.get_occupancy(molecules)
			var effect = act.calculate_effect(molecules)
			act_entry.occupancy_bar.value = occupancy
			act_entry.effect_label.text = "%.1fx" % effect
		
		## Update repressor entries
		for i in range(gene.repressors.size()):
			if i >= entry.repressor_entries.size():
				break
			var rep: RegulatoryElement = gene.repressors[i]
			var rep_entry = entry.repressor_entries[i]
			var occupancy = rep.get_occupancy(molecules)
			var effect = rep.calculate_effect(molecules)
			rep_entry.occupancy_bar.value = occupancy
			rep_entry.effect_label.text = "%.2fx" % effect

## Set category-level lock state
func set_category_locked(locked: bool) -> void:
	category_locked = locked
	for gene_id in gene_entries:
		var entry: GeneEntry = gene_entries[gene_id]
		entry.toggle.disabled = locked
		
		## Visual feedback for category lock
		if locked:
			entry.name_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		else:
			entry.name_label.remove_theme_color_override("font_color")

#endregion

#region Signals

func _on_gene_toggled(is_active: bool, gene_id: String) -> void:
	gene_toggled.emit(gene_id, is_active)

#endregion
