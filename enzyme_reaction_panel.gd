## Combined panel showing enzymes and their linked reactions
## Enzymes and reactions are intrinsically linked - this view shows them together
class_name EnzymeReactionPanel
extends VBoxContainer

signal concentration_changed(enzyme_id: String, value: float)
signal lock_changed(enzyme_id: String, locked: bool)
signal global_unit_changed(unit: int)

#region Unit Conversion Constants

enum Unit { MILLIMOLAR, MICROMOLAR, NANOMOLAR, PICOMOLAR }

const UNIT_NAMES: Array[String] = ["mM", "µM", "nM", "pM"]
const UNIT_MULTIPLIERS: Array[float] = [1.0, 1000.0, 1000000.0, 1000000000.0]

#endregion

#region State

var entries: Dictionary = {}  ## {enzyme_id: EnzymeReactionEntry}
var category_locked: bool = false
var current_global_unit: int = Unit.MILLIMOLAR

class EnzymeReactionEntry:
	var enzyme_id: String
	var enzyme_name: String
	var base_concentration_mm: float = 0.0
	var current_unit: int = 0
	var is_updating: bool = false
	
	## UI Elements
	var card: PanelContainer
	var header_row: HBoxContainer
	var lock_button: CheckBox
	var name_label: Label
	var slider: HSlider
	var spinbox: SpinBox
	var info_label: Label
	var reaction_container: VBoxContainer
	var reaction_labels: Array[RichTextLabel] = []

#endregion

#region Label Settings Cache

var _label_settings_title: LabelSettings
var _label_settings_normal: LabelSettings
var _label_settings_small: LabelSettings
var _label_settings_info: LabelSettings
var _label_settings_reaction_header: LabelSettings

func _create_label_settings() -> void:
	_label_settings_title = LabelSettings.new()
	_label_settings_title.font_size = 13
	
	_label_settings_normal = LabelSettings.new()
	_label_settings_normal.font_size = 13
	
	_label_settings_small = LabelSettings.new()
	_label_settings_small.font_size = 11
	
	_label_settings_info = LabelSettings.new()
	_label_settings_info.font_size = 10
	_label_settings_info.font_color = Color(0.5, 0.5, 0.55)
	
	_label_settings_reaction_header = LabelSettings.new()
	_label_settings_reaction_header.font_size = 10
	_label_settings_reaction_header.font_color = Color(0.45, 0.55, 0.65)

#endregion

#region Header UI

var header_container: HBoxContainer
var global_unit_option: OptionButton
var category_lock_button: CheckBox
var title_label: Label

#endregion

#region Setup

func _init() -> void:
	add_theme_constant_override("separation", 8)
	_create_label_settings()

func _ready() -> void:
	_create_header()
	_load_settings()

func _create_header() -> void:
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	## Title
	title_label = Label.new()
	title_label.text = "Enzymes & Reactions"
	title_label.label_settings = _label_settings_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	## Global unit selector
	var unit_label = Label.new()
	unit_label.text = "Unit:"
	unit_label.label_settings = _label_settings_small
	header_container.add_child(unit_label)
	
	global_unit_option = OptionButton.new()
	global_unit_option.custom_minimum_size = Vector2(60, 0)
	for i in range(UNIT_NAMES.size()):
		global_unit_option.add_item(UNIT_NAMES[i], i)
	global_unit_option.item_selected.connect(_on_global_unit_changed)
	header_container.add_child(global_unit_option)
	
	## Separator
	var sep = VSeparator.new()
	header_container.add_child(sep)
	
	## Category lock
	category_lock_button = CheckBox.new()
	category_lock_button.text = "Lock All"
	category_lock_button.tooltip_text = "Lock all enzymes from simulation changes"
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	add_child(header_container)
	
	## Separator line
	var line = HSeparator.new()
	add_child(line)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	current_global_unit = settings.enzyme_unit
	global_unit_option.selected = current_global_unit
	category_locked = settings.lock_enzymes
	category_lock_button.button_pressed = category_locked

#endregion

#region Public API

func clear() -> void:
	for child in get_children():
		if child != header_container and child is not HSeparator:
			child.queue_free()
	entries.clear()

func setup_enzymes_and_reactions(enzymes: Array, _reactions: Array) -> void:
	## Clear existing entries but keep header
	var children_to_remove: Array[Node] = []
	for child in get_children():
		if child != header_container and child is not HSeparator:
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()
	entries.clear()
	
	if enzymes.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No enzymes in simulation"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	## Create entries for each enzyme with its reactions
	for enzyme in enzymes:
		var enz_reactions = _get_enzyme_reactions(enzyme)
		_create_enzyme_entry(enzyme, enz_reactions)

func add_enzyme(enzyme, reactions_for_enzyme: Array = []) -> void:
	var enz_id = _get_enzyme_id(enzyme)
	if entries.has(enz_id):
		return
	var enz_reactions = reactions_for_enzyme if not reactions_for_enzyme.is_empty() else _get_enzyme_reactions(enzyme)
	_create_enzyme_entry(enzyme, enz_reactions)

func update_values(enzymes: Array, _reactions: Array) -> void:
	for enzyme in enzymes:
		var enz_id = _get_enzyme_id(enzyme)
		if not entries.has(enz_id):
			continue
		
		var entry = entries[enz_id] as EnzymeReactionEntry
		var new_conc = _get_enzyme_concentration(enzyme)
		
		if absf(entry.base_concentration_mm - new_conc) > 0.00001:
			entry.base_concentration_mm = new_conc
			_update_entry_display(entry)
		
		## Update reaction displays from enzyme.reactions
		var enz_reactions = _get_enzyme_reactions(enzyme)
		for i in range(mini(entry.reaction_labels.size(), enz_reactions.size())):
			entry.reaction_labels[i].text = _format_reaction(enz_reactions[i])

func set_category_locked(locked: bool) -> void:
	category_locked = locked
	category_lock_button.button_pressed = locked
	
	for entry in entries.values():
		entry.lock_button.disabled = locked
		_update_lock_visual(entry)

func apply_element_sizing() -> void:
	## Called when layout settings change - can be expanded if needed
	pass

#endregion

#region Entry Creation

func _create_enzyme_entry(enzyme, reactions_for_enzyme: Array) -> void:
	var entry = EnzymeReactionEntry.new()
	entry.enzyme_id = _get_enzyme_id(enzyme)
	entry.enzyme_name = _get_enzyme_name(enzyme)
	entry.base_concentration_mm = _get_enzyme_concentration(enzyme)
	entry.current_unit = current_global_unit
	
	## Card container
	entry.card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.17)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.24, 0.28)
	entry.card.add_theme_stylebox_override("panel", style)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	
	## Header row with enzyme info
	entry.header_row = HBoxContainer.new()
	entry.header_row.add_theme_constant_override("separation", 8)
	
	## Lock checkbox
	entry.lock_button = CheckBox.new()
	entry.lock_button.button_pressed = _get_enzyme_locked(enzyme)
	entry.lock_button.tooltip_text = "Lock concentration from simulation changes"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(entry.enzyme_id))
	entry.lock_button.disabled = category_locked
	entry.header_row.add_child(entry.lock_button)
	
	## Enzyme name
	entry.name_label = Label.new()
	entry.name_label.text = entry.enzyme_name
	entry.name_label.custom_minimum_size = Vector2(90, 0)
	entry.name_label.label_settings = _label_settings_normal
	entry.name_label.clip_text = true
	entry.header_row.add_child(entry.name_label)
	
	## Concentration slider
	entry.slider = HSlider.new()
	entry.slider.custom_minimum_size = Vector2(80, 0)
	entry.slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.slider.min_value = 0.0
	entry.slider.max_value = _get_slider_max_for_unit(entry.current_unit)
	entry.slider.step = 0.00001
	entry.slider.value = entry.base_concentration_mm * UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value_changed.connect(_on_slider_changed.bind(entry.enzyme_id))
	entry.header_row.add_child(entry.slider)
	
	## SpinBox for concentration
	entry.spinbox = SpinBox.new()
	entry.spinbox.min_value = 0.0
	entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.current_unit)
	entry.spinbox.step = 0.00001
	entry.spinbox.value = entry.base_concentration_mm * UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.allow_greater = true
	entry.spinbox.allow_lesser = false
	entry.spinbox.select_all_on_focus = true
	entry.spinbox.suffix = " " + UNIT_NAMES[entry.current_unit]
	entry.spinbox.value_changed.connect(_on_spinbox_changed.bind(entry.enzyme_id))
	entry.header_row.add_child(entry.spinbox)
	
	## Info label
	var degrade_str = "t½=%.0fs" % _get_enzyme_half_life(enzyme) if _get_enzyme_degradable(enzyme) else "stable"
	entry.info_label = Label.new()
	entry.info_label.text = "(%s)" % degrade_str
	entry.info_label.label_settings = _label_settings_info
	entry.header_row.add_child(entry.info_label)
	
	card_vbox.add_child(entry.header_row)
	
	## Reactions section
	if not reactions_for_enzyme.is_empty():
		entry.reaction_container = VBoxContainer.new()
		entry.reaction_container.add_theme_constant_override("separation", 3)
		
		var rxn_header = Label.new()
		rxn_header.text = "Catalyzes:"
		rxn_header.label_settings = _label_settings_reaction_header
		entry.reaction_container.add_child(rxn_header)
		
		for rxn in reactions_for_enzyme:
			var rxn_label = RichTextLabel.new()
			rxn_label.bbcode_enabled = true
			rxn_label.fit_content = true
			rxn_label.scroll_active = false
			rxn_label.custom_minimum_size = Vector2(0, 20)
			rxn_label.text = _format_reaction(rxn)
			entry.reaction_container.add_child(rxn_label)
			entry.reaction_labels.append(rxn_label)
		
		card_vbox.add_child(entry.reaction_container)
	
	entry.card.add_child(card_vbox)
	add_child(entry.card)
	entries[entry.enzyme_id] = entry
	
	_update_lock_visual(entry)

#endregion

#region Display Updates

func _update_entry_display(entry: EnzymeReactionEntry) -> void:
	if entry.is_updating:
		return
	entry.is_updating = true
	
	var display_value = entry.base_concentration_mm * UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value = display_value
	entry.spinbox.set_value_no_signal(display_value)
	
	entry.is_updating = false

func _update_all_units() -> void:
	for entry in entries.values():
		entry.current_unit = current_global_unit
		
		## Update slider range
		entry.slider.max_value = _get_slider_max_for_unit(entry.current_unit)
		
		## Update spinbox range and suffix
		entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.current_unit)
		entry.spinbox.suffix = " " + UNIT_NAMES[entry.current_unit]
		
		## Update displayed values
		_update_entry_display(entry)

func _update_lock_visual(entry: EnzymeReactionEntry) -> void:
	var is_locked = entry.lock_button.button_pressed or category_locked
	var alpha = 0.6 if is_locked else 1.0
	entry.name_label.modulate.a = alpha
	entry.slider.editable = not category_locked
	entry.spinbox.editable = not category_locked

func _format_reaction(rxn) -> String:
	var summary = _get_reaction_summary(rxn)
	var net_rate = _get_reaction_net_rate(rxn)
	var efficiency = _get_reaction_efficiency(rxn)
	var delta_g = _get_reaction_delta_g(rxn)
	
	var rate_color = "lime" if net_rate > 0.001 else ("orange" if net_rate < -0.001 else "gray")
	
	return "  [color=#888]%s[/color]\n  [color=%s]%.4f mM/s[/color] η=%.0f%% ΔG=%.1f kJ" % [
		summary, rate_color, net_rate, efficiency * 100.0, delta_g
	]

#endregion

#region Callbacks

func _on_global_unit_changed(index: int) -> void:
	current_global_unit = index
	_update_all_units()
	
	## Save setting
	SettingsManager.get_instance().set_enzyme_unit(index)
	
	global_unit_changed.emit(index)

func _on_category_lock_toggled(pressed: bool) -> void:
	category_locked = pressed
	
	## Save setting
	SettingsManager.get_instance().set_lock_enzymes(pressed)
	
	for entry in entries.values():
		entry.lock_button.disabled = pressed
		_update_lock_visual(entry)

func _on_lock_toggled(pressed: bool, enzyme_id: String) -> void:
	if entries.has(enzyme_id):
		_update_lock_visual(entries[enzyme_id])
	lock_changed.emit(enzyme_id, pressed)

func _on_slider_changed(value: float, enzyme_id: String) -> void:
	if not entries.has(enzyme_id):
		return
	
	var entry = entries[enzyme_id] as EnzymeReactionEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	
	## Convert from display unit to mM
	entry.base_concentration_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.value = value
	
	entry.is_updating = false
	
	concentration_changed.emit(enzyme_id, entry.base_concentration_mm)

func _on_spinbox_changed(value: float, enzyme_id: String) -> void:
	if not entries.has(enzyme_id):
		return
	
	var entry = entries[enzyme_id] as EnzymeReactionEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	
	## Convert from display unit to mM
	entry.base_concentration_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value = value
	
	entry.is_updating = false
	
	concentration_changed.emit(enzyme_id, entry.base_concentration_mm)

#endregion

#region Helpers

func _get_slider_max_for_unit(unit: int) -> float:
	return 0.1 * UNIT_MULTIPLIERS[unit]

func _get_spinbox_max_for_unit(unit: int) -> float:
	return 1.0 * UNIT_MULTIPLIERS[unit]

## Enzyme property accessors (handle both old and new data classes)
func _get_enzyme_id(enzyme) -> String:
	if enzyme is EnzymeData:
		return enzyme.enzyme_id
	return enzyme.id if "id" in enzyme else enzyme.enzyme_id

func _get_enzyme_name(enzyme) -> String:
	if enzyme is EnzymeData:
		return enzyme.enzyme_name
	return enzyme.name if "name" in enzyme else enzyme.enzyme_name

func _get_enzyme_concentration(enzyme) -> float:
	return enzyme.concentration

func _get_enzyme_locked(enzyme) -> bool:
	return enzyme.is_locked

func _get_enzyme_half_life(enzyme) -> float:
	return enzyme.half_life

func _get_enzyme_degradable(enzyme) -> bool:
	return enzyme.is_degradable

func _get_enzyme_reactions(enzyme) -> Array:
	if "reactions" in enzyme:
		return enzyme.reactions
	return []

## Reaction property accessors
func _get_reaction_enzyme_id(rxn) -> String:
	if "enzyme_id" in rxn:
		return rxn.enzyme_id
	elif "enzyme" in rxn and rxn.enzyme:
		return _get_enzyme_id(rxn.enzyme)
	return ""

func _get_reaction_summary(rxn) -> String:
	if rxn.has_method("get_summary"):
		return rxn.get_summary()
	return str(rxn)

func _get_reaction_net_rate(rxn) -> float:
	if rxn.has_method("get_net_rate"):
		return rxn.get_net_rate()
	return 0.0

func _get_reaction_efficiency(rxn) -> float:
	if "reaction_efficiency" in rxn:
		return rxn.reaction_efficiency
	return 0.0

func _get_reaction_delta_g(rxn) -> float:
	if "current_delta_g_actual" in rxn:
		return rxn.current_delta_g_actual
	return 0.0

#endregion
