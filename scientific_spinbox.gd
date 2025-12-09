## Custom SpinBox with scientific notation support and dynamic width
## Automatically formats large/small values in scientific notation for readability
class_name ScientificSpinBox
extends HBoxContainer

signal value_changed(new_value: float)

#region Configuration

## Threshold for switching to scientific notation (number of digits before/after decimal)
@export var scientific_threshold: int = 5
## Minimum width for the input field
@export var min_width: float = 70.0
## Maximum width for the input field
@export var max_width: float = 150.0
## Width per character (approximate)
@export var char_width: float = 8.0
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
		if _line_edit:
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
			_update_display()

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

#region Internal Nodes

var _line_edit: LineEdit
var _suffix_label: Label
var _increment_btn: Button
var _decrement_btn: Button
var _is_updating: bool = false
var _pending_font_size: int = -1

#endregion

#region Setup

func _init() -> void:
	add_theme_constant_override("separation", 0)

func _ready() -> void:
	_create_ui()
	## Apply current property values to newly created nodes
	_suffix_label.text = suffix
	_line_edit.editable = editable
	_increment_btn.disabled = not editable
	_decrement_btn.disabled = not editable
	## Apply pending font size if set before ready
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
	
	## Line edit for value input
	_line_edit = LineEdit.new()
	_line_edit.custom_minimum_size = Vector2(min_width, 0)
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

#endregion

#region Display Formatting

func _update_display() -> void:
	if _is_updating or not is_inside_tree():
		return
	_is_updating = true
	
	var display_text = _format_value(value)
	_line_edit.text = display_text
	_adjust_width(display_text)
	
	_is_updating = false

func _format_value(val: float) -> String:
	if is_zero_approx(val):
		return "0"
	
	## Determine if scientific notation is needed
	var abs_val = absf(val)
	var use_scientific = _should_use_scientific(abs_val)
	
	if use_scientific:
		return _format_scientific(val)
	else:
		return _format_standard(val)

func _should_use_scientific(abs_val: float) -> bool:
	if abs_val == 0.0:
		return false
	
	## Use scientific for very large numbers
	var upper_threshold = pow(10, scientific_threshold)
	if abs_val >= upper_threshold:
		return true
	
	## Use scientific for very small numbers
	var lower_threshold = pow(10, -scientific_threshold)
	if abs_val > 0 and abs_val < lower_threshold:
		return true
	
	## Check if standard representation would be too long
	var standard = _format_standard(abs_val)
	if standard.length() > scientific_threshold + 3:
		return true
	
	return false

func _format_scientific(val: float) -> String:
	if is_zero_approx(val):
		return "0"
	
	var sign_str = "-" if val < 0 else ""
	var abs_val = absf(val)
	
	## Calculate exponent
	var exponent = floori(log(abs_val) / log(10.0))
	var mantissa = abs_val / pow(10.0, exponent)
	
	## Round mantissa to desired precision
	var multiplier = pow(10.0, scientific_precision - 1)
	mantissa = roundf(mantissa * multiplier) / multiplier
	
	## Handle rounding that pushes mantissa to 10
	if mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	
	## Format mantissa (remove trailing zeros)
	var mantissa_str = _strip_trailing_zeros(str(snapped(mantissa, pow(10.0, -(scientific_precision - 1)))))
	
	return "%s%se%d" % [sign_str, mantissa_str, exponent]

func _format_standard(val: float) -> String:
	if is_zero_approx(val):
		return "0"
	
	## Determine appropriate decimal places based on value magnitude
	var abs_val = absf(val)
	var decimals = standard_precision
	
	if abs_val >= 1000:
		decimals = 1
	elif abs_val >= 100:
		decimals = 2
	elif abs_val >= 10:
		decimals = 3
	elif abs_val >= 1:
		decimals = 4
	elif abs_val >= 0.1:
		decimals = 5
	elif abs_val >= 0.01:
		decimals = 6
	else:
		decimals = 7
	
	var format_str = "%." + str(decimals) + "f"
	var result = format_str % val
	return _strip_trailing_zeros(result)

func _strip_trailing_zeros(s: String) -> String:
	if not s.contains("."):
		return s
	
	## Remove trailing zeros after decimal point
	while s.ends_with("0") and not s.ends_with(".0"):
		s = s.substr(0, s.length() - 1)
	
	## Remove decimal point if no decimals remain
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	
	return s

func _adjust_width(text: String) -> void:
	var total_chars = text.length() + suffix.length() + 1
	var desired_width = clampf(total_chars * char_width, min_width, max_width)
	_line_edit.custom_minimum_size.x = desired_width

#endregion

#region Input Parsing

func _parse_input(text: String) -> float:
	text = text.strip_edges().to_lower()
	
	if text.is_empty():
		return value
	
	## Handle scientific notation input (various formats)
	var scientific_patterns = ["e", "×10^", "x10^", "*10^"]
	
	for pattern in scientific_patterns:
		if text.contains(pattern):
			var parts = text.split(pattern)
			if parts.size() == 2:
				var mantissa = _safe_float(parts[0])
				var exponent = _safe_float(parts[1])
				return mantissa * pow(10.0, exponent)
	
	## Handle superscript notation (e.g., "1.5×10³")
	var superscript_map = {
		"⁰": 0, "¹": 1, "²": 2, "³": 3, "⁴": 4,
		"⁵": 5, "⁶": 6, "⁷": 7, "⁸": 8, "⁹": 9,
		"⁻": -1  ## Negative marker
	}
	
	for marker in ["×10", "x10", "*10"]:
		var idx = text.find(marker)
		if idx != -1:
			var mantissa_str = text.substr(0, idx)
			var exp_str = text.substr(idx + marker.length())
			
			var mantissa = _safe_float(mantissa_str)
			var exponent = _parse_superscript_exponent(exp_str, superscript_map)
			return mantissa * pow(10.0, exponent)
	
	## Standard numeric input
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
	var parsed = _parse_input(new_text)
	_apply_value(parsed)

func _on_focus_entered() -> void:
	if select_all_on_focus:
		## Defer to ensure text is ready
		_line_edit.call_deferred("select_all")

func _on_focus_exited() -> void:
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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_on_increment()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_on_decrement()
			get_viewport().set_input_as_handled()

func _apply_value(new_val: float) -> void:
	## Clamp to bounds
	if not allow_greater:
		new_val = minf(new_val, max_value)
	if not allow_lesser:
		new_val = maxf(new_val, min_value)
	
	new_val = clampf(new_val, min_value if not allow_lesser else -INF, max_value if not allow_greater else INF)
	
	if not is_equal_approx(value, new_val):
		value = new_val
		value_changed.emit(value)
	else:
		_update_display()

func _get_dynamic_step() -> float:
	## Adjust step based on current value magnitude for intuitive incrementing
	if is_zero_approx(value):
		return step
	
	var magnitude = floori(log(absf(value)) / log(10.0))
	return maxf(step, pow(10.0, magnitude - 2))

#endregion

#region Theme


#endregion
