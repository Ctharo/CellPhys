## Panel for adjusting molecule and enzyme concentrations at runtime
class_name ConcentrationPanel
extends VBoxContainer

signal concentration_changed(item_name: String, new_value: float, is_enzyme: bool)
signal lock_changed(item_name: String, is_locked: bool, is_enzyme: bool)

#region Configuration

const MIN_CONCENTRATION: float = 0.0
const MAX_MOLECULE_CONCENTRATION: float = 50.0
const MAX_ENZYME_CONCENTRATION: float = 0.1
const SLIDER_STEP: float = 0.001

#endregion

#region Internal References

var _controls: Dictionary = {}  ## {name: {slider, label, checkbox, is_enzyme, container}}

#endregion

func _ready() -> void:
	pass

#region Public API

## Clear all controls
func clear_controls() -> void:
	for child in get_children():
		child.queue_free()
	_controls.clear()

## Add a molecule concentration control
func add_molecule_control(mol_name: String, current_conc: float, is_locked: bool = false) -> void:
	_add_control(mol_name, current_conc, MAX_MOLECULE_CONCENTRATION, false, is_locked)

## Add an enzyme concentration control
func add_enzyme_control(enz_name: String, current_conc: float, is_locked: bool = false) -> void:
	_add_control(enz_name, current_conc, MAX_ENZYME_CONCENTRATION, true, is_locked)

## Update a specific control's value without emitting signal
func update_value(item_name: String, new_value: float) -> void:
	if _controls.has(item_name):
		var ctrl = _controls[item_name]
		ctrl.slider.set_value_no_signal(new_value)
		_update_label(ctrl.label, item_name, new_value, ctrl.is_enzyme, ctrl.checkbox.button_pressed)

## Batch update all molecule concentrations
func update_molecules(molecules: Dictionary) -> void:
	for mol_name in molecules:
		if _controls.has(mol_name):
			var mol = molecules[mol_name]
			update_value(mol_name, mol.concentration)

## Batch update all enzyme concentrations  
func update_enzymes(enzymes: Array) -> void:
	for enzyme in enzymes:
		if _controls.has(enzyme.name):
			update_value(enzyme.name, enzyme.concentration)

#endregion

#region Internal Methods

func _add_control(item_name: String, current_value: float, max_value: float, is_enzyme: bool, is_locked: bool) -> void:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	## Header row with label and lock checkbox
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(header)
	
	## Label showing name and current value
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_label(label, item_name, current_value, is_enzyme, is_locked)
	header.add_child(label)
	
	## Lock checkbox
	var checkbox = CheckBox.new()
	checkbox.text = "🔒"
	checkbox.button_pressed = is_locked
	checkbox.tooltip_text = "Lock concentration (won't change during simulation)"
	checkbox.toggled.connect(_on_lock_toggled.bind(item_name, is_enzyme))
	header.add_child(checkbox)
	
	## Slider for adjustment
	var slider = HSlider.new()
	slider.min_value = MIN_CONCENTRATION
	slider.max_value = max_value
	slider.step = SLIDER_STEP
	slider.value = current_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 20
	container.add_child(slider)
	
	## Connect signal
	slider.value_changed.connect(_on_slider_changed.bind(item_name, label, checkbox, is_enzyme))
	
	## Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	container.add_child(sep)
	
	add_child(container)
	
	## Store reference
	_controls[item_name] = {
		"slider": slider,
		"label": label,
		"checkbox": checkbox,
		"is_enzyme": is_enzyme,
		"container": container
	}

func _update_label(label: Label, item_name: String, value: float, is_enzyme: bool, is_locked: bool) -> void:
	var lock_indicator = " 🔒" if is_locked else ""
	if is_enzyme:
		label.text = "🔷 %s: %.4f mM%s" % [item_name, value, lock_indicator]
	else:
		label.text = "🔹 %s: %.3f mM%s" % [item_name, value, lock_indicator]

func _on_slider_changed(new_value: float, item_name: String, label: Label, checkbox: CheckBox, is_enzyme: bool) -> void:
	_update_label(label, item_name, new_value, is_enzyme, checkbox.button_pressed)
	concentration_changed.emit(item_name, new_value, is_enzyme)

func _on_lock_toggled(is_pressed: bool, item_name: String, is_enzyme: bool) -> void:
	if _controls.has(item_name):
		var ctrl = _controls[item_name]
		_update_label(ctrl.label, item_name, ctrl.slider.value, is_enzyme, is_pressed)
	lock_changed.emit(item_name, is_pressed, is_enzyme)

#endregion
