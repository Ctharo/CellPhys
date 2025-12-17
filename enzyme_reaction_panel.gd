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
	
	## Category lock checkbox
	category_lock_button = CheckBox.new()
	category_lock_button.button_pressed = category_locked
	category_lock_button.tooltip_text = "Lock all enzymes from simulation changes"
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	## Title
	title_label = Label.new()
	title_label.text = "Enzymes & Reactions"
	title_label.label_settings = _label_settings_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	## Global unit selector
	global_unit_option = OptionButton.new()
	global_unit_option.custom_minimum_size = Vector2(70, 0)
	for unit_name in UNIT_NAMES:
		global_unit_option.add_item(unit_name)
	global_unit_option.selected = current_global_unit
	global_unit_option.item_selected.connect(_on_global_unit_changed)
	header_container.add_child(global_unit_option)
	
	add_child(header_container)
	
	## Separator
	var sep = HSeparator.new()
	add_child(sep)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	current_global_unit = settings.enzyme_unit
	category_locked = settings.lock_enzymes
	
	if global_unit_option:
		global_unit_option.selected = current_global_unit
	if category_lock_button:
		category_lock_button.button_pressed = category_locked

#endregion

#region Public API

func setup_enzymes_and_reactions(enzymes: Array, reactions: Array) -> void:
	clear_entries()
	
	## Build reaction lookup by enzyme
	var rxn_by_enzyme: Dictionary = {}
	for rxn in reactions:
		var enz_id = _get_reaction_enzyme_id(rxn)
		if not rxn_by_enzyme.has(enz_id):
			rxn_by_enzyme[enz_id] = []
		rxn_by_enzyme[enz_id].append(rxn)
	
	## Create entries for each enzyme
	for enzyme in enzymes:
		var enz_id = _get_enzyme_id(enzyme)
		var enz_rxns = rxn_by_enzyme.get(enz_id, []) as Array
		_create_enzyme_entry(enzyme, enz_rxns)

func clear_entries() -> void:
	for entry in entries.values():
		if entry.card and is_instance_valid(entry.card):
			entry.card.queue_free()
	entries.clear()

func update_values(enzymes: Array, reactions: Array) -> void:
	## Update enzyme concentrations
	for enzyme in enzymes:
		var enz_id = _get_enzyme_id(enzyme)
		if entries.has(enz_id):
			var entry = entries[enz_id] as EnzymeReactionEntry
			if entry.is_updating:
				continue
			
			var is_locked = entry.lock_button.button_pressed or category_locked
			if is_locked:
				continue
			
			entry.is_updating = true
			entry.base_concentration_mm = _get_enzyme_concentration(enzyme)
			var display_val = entry.base_concentration_mm * UNIT_MULTIPLIERS[entry.current_unit]
			entry.spinbox.set_value_no_signal(display_val)
			entry.info_label.text = "(%.4f mM)" % entry.base_concentration_mm
			entry.is_updating = false
	
	## Update reaction displays
	_update_reaction_displays(reactions)

func is_enzyme_locked(enzyme_id: String) -> bool:
	if category_locked:
		return true
	if entries.has(enzyme_id):
		return entries[enzyme_id].lock_button.button_pressed
	return false

#endregion

#region Entry Creation

func _create_enzyme_entry(enzyme, reactions: Array) -> void:
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
	entry.name_label.custom_minimum_size = Vector2(100, 0)
	entry.name_label.label_settings = _label_settings_normal
	entry.name_label.clip_text = true
	entry.header_row.add_child(entry.name_label)
	
	## SpinBox for concentration (wider, no slider)
	entry.spinbox = SpinBox.new()
	entry.spinbox.custom_minimum_size = Vector2(140, 0)
	entry.spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	
	## Info label showing base mM value
	entry.info_label = Label.new()
	entry.info_label.text = "(%.4f mM)" % entry.base_concentration_mm
	entry.info_label.custom_minimum_size = Vector2(80, 0)
	entry.info_label.label_settings = _label_settings_info
	entry.info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.header_row.add_child(entry.info_label)
	
	card_vbox.add_child(entry.header_row)
	
	## Reaction container
	if reactions.size() > 0:
		entry.reaction_container = VBoxContainer.new()
		entry.reaction_container.add_theme_constant_override("separation", 2)
		
		## Reactions header
		var rxn_header = Label.new()
		rxn_header.text = "Reactions:"
		rxn_header.label_settings = _label_settings_reaction_header
		entry.reaction_container.add_child(rxn_header)
		
		for rxn in reactions:
			var rxn_label = RichTextLabel.new()
			rxn_label.bbcode_enabled = true
			rxn_label.fit_content = true
			rxn_label.scroll_active = false
			rxn_label.custom_minimum_size = Vector2(0, 36)
			rxn_label.text = _format_reaction(rxn)
			entry.reaction_labels.append(rxn_label)
			entry.reaction_container.add_child(rxn_label)
		
		card_vbox.add_child(entry.reaction_container)
	
	entry.card.add_child(card_vbox)
	entries[entry.enzyme_id] = entry
	add_child(entry.card)
	
	_update_lock_visual(entry)

#endregion

#region Updates

func _update_all_units() -> void:
	for entry in entries.values():
		entry.current_unit = current_global_unit
		
		## Update spinbox range and suffix
		entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.current_unit)
		entry.spinbox.suffix = " " + UNIT_NAMES[entry.current_unit]
		
		## Update displayed values
		_update_entry_display(entry)

func _update_entry_display(entry: EnzymeReactionEntry) -> void:
	entry.is_updating = true
	entry.spinbox.value = entry.base_concentration_mm * UNIT_MULTIPLIERS[entry.current_unit]
	entry.is_updating = false

func _update_reaction_displays(reactions: Array) -> void:
	## Build lookup
	var rxn_by_enzyme: Dictionary = {}
	for rxn in reactions:
		var enz_id = _get_reaction_enzyme_id(rxn)
		if not rxn_by_enzyme.has(enz_id):
			rxn_by_enzyme[enz_id] = []
		rxn_by_enzyme[enz_id].append(rxn)
	
	## Update each entry's reaction labels
	for enz_id in entries:
		var entry = entries[enz_id] as EnzymeReactionEntry
		var enz_rxns = rxn_by_enzyme.get(enz_id, []) as Array
		
		for i in range(mini(entry.reaction_labels.size(), enz_rxns.size())):
			entry.reaction_labels[i].text = _format_reaction(enz_rxns[i])

func _update_lock_visual(entry: EnzymeReactionEntry) -> void:
	var is_locked = entry.lock_button.button_pressed or category_locked
	var alpha = 0.6 if is_locked else 1.0
	entry.name_label.modulate.a = alpha
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

func _on_spinbox_changed(value: float, enzyme_id: String) -> void:
	if not entries.has(enzyme_id):
		return
	
	var entry = entries[enzyme_id] as EnzymeReactionEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	
	## Convert from display unit to mM
	entry.base_concentration_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.info_label.text = "(%.4f mM)" % entry.base_concentration_mm
	
	entry.is_updating = false
	
	concentration_changed.emit(enzyme_id, entry.base_concentration_mm)

#endregion

#region Helpers

func _get_spinbox_max_for_unit(unit: int) -> float:
	return 1.0 * UNIT_MULTIPLIERS[unit]  ## 1 mM max for enzymes

func _get_enzyme_id(enzyme) -> String:
	if "enzyme_id" in enzyme:
		return enzyme.enzyme_id
	if "id" in enzyme:
		return enzyme.id
	return str(enzyme.get_instance_id())

func _get_enzyme_name(enzyme) -> String:
	if "enzyme_name" in enzyme:
		return enzyme.enzyme_name
	if "name" in enzyme:
		return enzyme.name
	return "Unknown"

func _get_enzyme_concentration(enzyme) -> float:
	if "concentration" in enzyme:
		return enzyme.concentration
	return 0.0

func _get_enzyme_locked(enzyme) -> bool:
	if "is_locked" in enzyme:
		return enzyme.is_locked
	return false

func _get_reaction_enzyme_id(rxn) -> String:
	if "enzyme_id" in rxn:
		return rxn.enzyme_id
	if "enzyme" in rxn and rxn.enzyme:
		return _get_enzyme_id(rxn.enzyme)
	return ""

func _get_reaction_summary(rxn) -> String:
	if rxn.has_method("get_summary"):
		return rxn.get_summary()
	if "summary" in rxn:
		return rxn.summary
	return "Unknown reaction"

func _get_reaction_net_rate(rxn) -> float:
	if "net_rate" in rxn:
		return rxn.net_rate
	return 0.0

func _get_reaction_efficiency(rxn) -> float:
	if "reaction_efficiency" in rxn:
		return rxn.reaction_efficiency
	return 0.0

func _get_reaction_delta_g(rxn) -> float:
	if "current_delta_g_actual" in rxn:
		return rxn.current_delta_g_actual
	if "delta_g" in rxn:
		return rxn.delta_g
	return 0.0

#endregion
