## Custom SpinBox with scientific notation support
## Uses stable fixed width to prevent jarring resize during updates
class_name ScientificSpinBox
extends HBoxContainer

signal value_changed(new_value: float)

#region Configuration

## Threshold for switching to scientific notation (number of digits before/after decimal)
@export var scientific_threshold: int = 5
## Fixed width for the input field (stable, no dynamic resizing)
@export var fixed_width: float = 85.0
## Number of significant figures in scientific notation
@export var scientific_precision: int = 3
## Number of decimal places in standard notation
@export var standard_precision: int = 4

#endregion

#region SpinBox Properties

var value: float = 0.0:
	set(v):
		if is_equal_approx(value, v):
			return
		value = v
		if _line_edit and not _is_user_editing:
			_update_display()
	get:
		return value

var min_value: float = 0.0:
	set(v):
		min_value = v
		if value < min_value:
			value = min_value

var max_value: float = 100.0:
	set(v):
		max_value = v
		if value > max_value:
			value = max_value

var step: float = 0.0001

var suffix: String = "":
	set(v):
		suffix = v
		if _suffix_label:
			_suffix_label.text = suffix

var editable: bool = true:
	set(v):
		editable = v
		if _line_edit:
			_line_edit.editable = v
		if _increment_btn:
			_increment_btn.disabled = not v
		if _decrement_btn:
			_decrement_btn.disabled = not v

var allow_greater: bool = true
var allow_lesser: bool = false
var select_all_on_focus: bool = true

#endregion

#region Internal State

var _line_edit: LineEdit
var _suffix_label: Label
var _increment_btn: Button
var _decrement_btn: Button
var _is_updating: bool = false
var _is_user_editing: bool = false
var _pending_font_size: int = -1

#endregion

#region Setup

func _init() -> void:
	add_theme_constant_override("separation", 0)

func _ready() -> void:
	_create_ui()
	_suffix_label.text = suffix
	_line_edit.editable = editable
	_increment_btn.disabled = not editable
	_decrement_btn.disabled = not editable
	if _pending_font_size > 0:
		_line_edit.add_theme_font_size_override("font_size", _pending_font_size)
		_suffix_label.add_theme_font_size_override("font_size", _pending_font_size)
	_update_display()

func _create_ui() -> void:
	## Decrement button
	_decrement_btn = Button.new()
	_decrement_btn.text = "−"
	_decrement_btn.custom_minimum_size = Vector2(20, 0)
	_decrement_btn.pressed.connect(_on_decrement)
	_decrement_btn.focus_mode = Control.FOCUS_NONE
	add_child(_decrement_btn)
	
	## Line edit - FIXED WIDTH for stability
	_line_edit = LineEdit.new()
	_line_edit.custom_minimum_size = Vector2(fixed_width, 0)
	_line_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_entered.connect(_on_focus_entered)
	_line_edit.focus_exited.connect(_on_focus_exited)
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	add_child(_line_edit)
	
	## Suffix label
	_suffix_label = Label.new()
	_suffix_label.text = suffix
	_suffix_label.add_theme_font_size_override("font_size", 11)
	_suffix_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	add_child(_suffix_label)
	
	## Increment button
	_increment_btn = Button.new()
	_increment_btn.text = "+"
	_increment_btn.custom_minimum_size = Vector2(20, 0)
	_increment_btn.pressed.connect(_on_increment)
	_increment_btn.focus_mode = Control.FOCUS_NONE
	add_child(_increment_btn)

## Apply font size override (handles calls before _ready)
func add_theme_font_size_override(name: String, size: int) -> void:
	if name == "font_size":
		_pending_font_size = size
		if _line_edit:
			_line_edit.add_theme_font_size_override("font_size", size)
		if _suffix_label:
			_suffix_label.add_theme_font_size_override("font_size", size)

#endregion

#region Display Formatting

func _update_display() -> void:
	if _is_updating or not is_inside_tree() or _is_user_editing:
		return
	_is_updating = true
	
	var display_text = _format_value(value)
	_line_edit.text = display_text
	
	_is_updating = false

func _format_value(val: float) -> String:
	if is_zero_approx(val):
		return "0"
	
	var abs_val = absf(val)
	var use_scientific = _should_use_scientific(abs_val)
	
	if use_scientific:
		return _format_scientific(val)
	else:
		return _format_standard(val)

func _should_use_scientific(abs_val: float) -> bool:
	if abs_val == 0.0:
		return false
	
	var upper_threshold = pow(10, scientific_threshold)
	if abs_val >= upper_threshold:
		return true
	
	var lower_threshold = pow(10, -scientific_threshold + 1)
	if abs_val < lower_threshold:
		return true
	
	return false

func _format_scientific(val: float) -> String:
	if val == 0.0:
		return "0"
	
	var exponent = floori(log(absf(val)) / log(10.0))
	var mantissa = val / pow(10.0, exponent)
	
	if absf(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	elif absf(mantissa) < 1.0 and mantissa != 0.0:
		mantissa *= 10.0
		exponent -= 1
	
	var format_str = "%." + str(scientific_precision - 1) + "f"
	var mantissa_str = _strip_trailing_zeros(format_str % mantissa)
	
	return "%se%d" % [mantissa_str, exponent]

func _format_standard(val: float) -> String:
	var decimals = standard_precision
	var abs_val = absf(val)
	
	if abs_val >= 100.0:
		decimals = 1
	elif abs_val >= 10.0:
		decimals = 2
	elif abs_val >= 1.0:
		decimals = 3
	
	var format_str = "%." + str(decimals) + "f"
	var result = format_str % val
	return _strip_trailing_zeros(result)

func _strip_trailing_zeros(s: String) -> String:
	if not s.contains("."):
		return s
	
	while s.ends_with("0") and not s.ends_with(".0"):
		s = s.substr(0, s.length() - 1)
	
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	
	return s

#endregion

#region Input Parsing

func _parse_input(text: String) -> float:
	text = text.strip_edges().to_lower()
	
	if text.is_empty():
		return value
	
	var scientific_patterns = ["e", "×10^", "x10^", "*10^"]
	
	for pattern in scientific_patterns:
		if text.contains(pattern):
			var parts = text.split(pattern)
			if parts.size() == 2:
				var mantissa = _safe_float(parts[0])
				var exponent = _safe_float(parts[1])
				return mantissa * pow(10.0, exponent)
	
	var superscript_map = {
		"⁰": 0, "¹": 1, "²": 2, "³": 3, "⁴": 4,
		"⁵": 5, "⁶": 6, "⁷": 7, "⁸": 8, "⁹": 9,
		"⁻": -1
	}
	
	for marker in ["×10", "x10", "*10"]:
		var idx = text.find(marker)
		if idx != -1:
			var mantissa_str = text.substr(0, idx)
			var exp_str = text.substr(idx + marker.length())
			
			var mantissa = _safe_float(mantissa_str)
			var exponent = _parse_superscript_exponent(exp_str, superscript_map)
			return mantissa * pow(10.0, exponent)
	
	return _safe_float(text)

func _parse_superscript_exponent(exp_str: String, superscript_map: Dictionary) -> float:
	var is_negative = false
	var exponent = 0.0
	
	for c in exp_str:
		if c == "⁻" or c == "-":
			is_negative = true
		elif superscript_map.has(c):
			exponent = exponent * 10 + superscript_map[c]
		elif c.is_valid_int():
			exponent = exponent * 10 + c.to_int()
	
	return -exponent if is_negative else exponent

func _safe_float(s: String) -> float:
	s = s.strip_edges()
	if s.is_empty():
		return 0.0
	if s.is_valid_float():
		return s.to_float()
	return 0.0

#endregion

#region Callbacks

func _on_text_submitted(new_text: String) -> void:
	_is_user_editing = false
	var parsed = _parse_input(new_text)
	_apply_value(parsed)

func _on_focus_entered() -> void:
	_is_user_editing = true
	if select_all_on_focus:
		_line_edit.call_deferred("select_all")

func _on_focus_exited() -> void:
	_is_user_editing = false
	var parsed = _parse_input(_line_edit.text)
	_apply_value(parsed)

func _on_increment() -> void:
	var new_val = value + _get_dynamic_step()
	_apply_value(new_val)

func _on_decrement() -> void:
	var new_val = value - _get_dynamic_step()
	_apply_value(new_val)

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_on_increment()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_on_decrement()
				get_viewport().set_input_as_handled()

func _apply_value(new_val: float) -> void:
	if not allow_lesser and new_val < min_value:
		new_val = min_value
	elif new_val < min_value:
		new_val = min_value
	
	if not allow_greater and new_val > max_value:
		new_val = max_value
	
	new_val = maxf(0.0, new_val)
	
	if not is_equal_approx(value, new_val):
		value = new_val
		_update_display()
		value_changed.emit(value)
	else:
		_update_display()

func _get_dynamic_step() -> float:
	if value <= 0.0:
		return step
	
	var magnitude = floori(log(absf(value)) / log(10.0))
	return pow(10.0, magnitude - 1)

#endregion

#region Public API

## Set value without emitting signal (for external updates)
func set_value_no_signal(new_val: float) -> void:
	if is_equal_approx(value, new_val):
		return
	value = new_val
	if _line_edit and not _is_user_editing:
		_update_display()

#endregion
