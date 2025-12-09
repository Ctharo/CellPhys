## Panel for displaying and managing gene expression
## Features: category lock with persistence, integrated enzyme output display
class_name GenePanel
extends VBoxContainer

signal gene_toggled(gene_id: String, is_active: bool)
signal expression_rate_changed(gene_id: String, rate: float)
signal category_lock_changed(locked: bool)

#region State

var gene_entries: Dictionary = {}  ## {enzyme_id: GeneEntry}
var category_locked: bool = false
var panel_title: String = "Gene Expression"

class GeneEntry:
	var enzyme_id: String
	var gene_name: String
	
	## UI Elements
	var container: VBoxContainer
	var card: PanelContainer
	var header: HBoxContainer
	var toggle: CheckButton
	var name_label: Label
	var enzyme_label: Label
	var status_label: Label
	var rate_slider: HSlider
	var rate_value: Label
	var output_label: RichTextLabel

#endregion

#region Header UI

var header_container: HBoxContainer
var category_lock_button: CheckBox
var title_label: Label

#endregion

#region Setup

func _init() -> void:
	add_theme_constant_override("separation", 6)

func _ready() -> void:
	_create_header()
	_load_settings()

func _create_header() -> void:
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	## Title
	title_label = Label.new()
	title_label.text = panel_title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	## Category lock
	category_lock_button = CheckBox.new()
	category_lock_button.text = "Lock All"
	category_lock_button.add_theme_font_size_override("font_size", 11)
	category_lock_button.tooltip_text = "Lock all genes (no expression changes)"
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	add_child(header_container)
	
	## Separator line
	var line = HSeparator.new()
	add_child(line)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	category_locked = settings.lock_genes
	category_lock_button.button_pressed = category_locked

#endregion

#region Public API

func clear() -> void:
	var children_to_remove: Array[Node] = []
	for child in get_children():
		if child != header_container and child is not HSeparator:
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()
	gene_entries.clear()

func setup_genes(genes: Dictionary, molecules: Dictionary, enzymes: Dictionary) -> void:
	clear()
	
	if genes.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No genes in simulation"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	for gene in genes.values():
		var enzyme = enzymes.get(_get_enzyme_id(gene))
		_create_gene_entry(gene, enzyme)

func update_genes(genes: Dictionary, molecules: Dictionary, enzymes: Dictionary) -> void:
	for gene in genes.values():
		var enzyme_id = _get_enzyme_id(gene)
		if not gene_entries.has(enzyme_id):
			continue
		
		var entry = gene_entries[enzyme_id] as GeneEntry
		var enzyme = enzymes.get(enzyme_id)
		
		## Update status
		var fold_change = _get_fold_change(gene)
		var status_color = _get_status_color(fold_change)
		entry.status_label.text = "%.1fx" % fold_change
		entry.status_label.add_theme_color_override("font_color", status_color)
		
		## Update enzyme output
		if enzyme:
			var conc = _get_enzyme_concentration(enzyme)
			entry.output_label.text = "→ [b]%s[/b]: %.4f mM" % [
				_get_enzyme_name(enzyme), conc
			]

func add_gene(gene, enzyme) -> void:
	var enzyme_id = _get_enzyme_id(gene)
	if gene_entries.has(enzyme_id):
		return
	_create_gene_entry(gene, enzyme)

func set_category_locked(locked: bool) -> void:
	category_locked = locked
	category_lock_button.button_pressed = locked
	
	for entry in gene_entries.values():
		entry.toggle.disabled = locked
		entry.rate_slider.editable = not locked

#endregion

#region Entry Creation

func _create_gene_entry(gene, enzyme) -> void:
	var entry = GeneEntry.new()
	var gene_enzyme_id = _get_enzyme_id(gene)
	entry.enzyme_id = gene_enzyme_id
	entry.gene_name = _get_gene_name(gene)
	
	entry.container = VBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 4)
	
	entry.card = PanelContainer.new()
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
	entry.card.add_theme_stylebox_override("panel", style)
	
	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 4)
	
	## Header row
	entry.header = HBoxContainer.new()
	entry.header.add_theme_constant_override("separation", 8)
	
	entry.toggle = CheckButton.new()
	entry.toggle.button_pressed = _is_gene_active(gene)
	entry.toggle.tooltip_text = "Toggle gene expression"
	entry.toggle.toggled.connect(_on_gene_toggled.bind(gene_enzyme_id))
	entry.toggle.disabled = category_locked
	entry.header.add_child(entry.toggle)
	
	entry.name_label = Label.new()
	entry.name_label.text = entry.gene_name
	entry.name_label.add_theme_font_size_override("font_size", 14)
	entry.header.add_child(entry.name_label)
	
	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entry.header.add_child(arrow_label)
	
	entry.enzyme_label = Label.new()
	entry.enzyme_label.text = _get_enzyme_name(enzyme) if enzyme else "Unknown"
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
	
	## Rate control row
	var rate_row = HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 6)
	
	var rate_label = Label.new()
	rate_label.text = "Base rate:"
	rate_label.add_theme_font_size_override("font_size", 11)
	rate_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	rate_row.add_child(rate_label)
	
	entry.rate_slider = HSlider.new()
	entry.rate_slider.custom_minimum_size = Vector2(100, 0)
	entry.rate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.rate_slider.min_value = 0.0
	entry.rate_slider.max_value = 0.1
	entry.rate_slider.step = 0.0001
	entry.rate_slider.value = _get_base_rate(gene)
	entry.rate_slider.editable = not category_locked
	entry.rate_slider.value_changed.connect(_on_rate_changed.bind(gene_enzyme_id))
	rate_row.add_child(entry.rate_slider)
	
	entry.rate_value = Label.new()
	entry.rate_value.text = "%.4f" % _get_base_rate(gene)
	entry.rate_value.custom_minimum_size = Vector2(60, 0)
	entry.rate_value.add_theme_font_size_override("font_size", 11)
	rate_row.add_child(entry.rate_value)
	
	card_content.add_child(rate_row)
	
	## Output info
	entry.output_label = RichTextLabel.new()
	entry.output_label.bbcode_enabled = true
	entry.output_label.fit_content = true
	entry.output_label.scroll_active = false
	entry.output_label.custom_minimum_size = Vector2(0, 20)
	entry.output_label.add_theme_font_size_override("normal_font_size", 11)
	if enzyme:
		entry.output_label.text = "→ [b]%s[/b]: %.4f mM" % [
			_get_enzyme_name(enzyme), _get_enzyme_concentration(enzyme)
		]
	else:
		entry.output_label.text = "→ No enzyme linked"
	card_content.add_child(entry.output_label)
	
	entry.card.add_child(card_content)
	entry.container.add_child(entry.card)
	add_child(entry.container)
	gene_entries[gene_enzyme_id] = entry

#endregion

#region Callbacks

func _on_category_lock_toggled(pressed: bool) -> void:
	category_locked = pressed
	
	## Save setting
	SettingsManager.get_instance().set_lock_genes(pressed)
	
	for entry in gene_entries.values():
		entry.toggle.disabled = pressed
		entry.rate_slider.editable = not pressed
	
	category_lock_changed.emit(pressed)

func _on_gene_toggled(is_active: bool, enzyme_id: String) -> void:
	gene_toggled.emit(enzyme_id, is_active)

func _on_rate_changed(value: float, enzyme_id: String) -> void:
	if gene_entries.has(enzyme_id):
		gene_entries[enzyme_id].rate_value.text = "%.4f" % value
	expression_rate_changed.emit(enzyme_id, value)

#endregion

#region Helpers

func _get_enzyme_id(gene) -> String:
	return gene.enzyme_id if "enzyme_id" in gene else ""

func _get_gene_name(gene) -> String:
	if "gene_name" in gene:
		return gene.gene_name
	return "Gene_%s" % _get_enzyme_id(gene)

func _is_gene_active(gene) -> bool:
	return gene.is_active if "is_active" in gene else true

func _get_fold_change(gene) -> float:
	if "get_fold_change" in gene and gene.has_method("get_fold_change"):
		return gene.get_fold_change()
	return 1.0

func _get_base_rate(gene) -> float:
	return gene.base_expression_rate if "base_expression_rate" in gene else 0.001

func _get_enzyme_name(enzyme) -> String:
	if enzyme is EnzymeData:
		return enzyme.enzyme_name
	return enzyme.name if enzyme and "name" in enzyme else "Unknown"

func _get_enzyme_concentration(enzyme) -> float:
	return enzyme.concentration if enzyme else 0.0

func _get_status_color(fold_change: float) -> Color:
	if fold_change > 1.2:
		return Color(0.4, 0.9, 0.4)  ## Green for upregulated
	elif fold_change < 0.8:
		return Color(0.9, 0.4, 0.4)  ## Red for downregulated
	return Color(0.7, 0.7, 0.7)  ## Gray for normal

#endregion
