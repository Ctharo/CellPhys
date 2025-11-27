## Simple line chart for displaying concentration history
extends Panel

## Colors for different molecules
const COLORS = [
	Color(0.3, 0.7, 1.0),   ## Blue - Substrate A
	Color(0.3, 0.9, 0.5),   ## Green - Intermediate B
	Color(1.0, 0.5, 0.3),   ## Orange - Product C
	Color(0.9, 0.4, 0.9),   ## Purple
	Color(1.0, 0.9, 0.3),   ## Yellow
]

var margin_left: float = 50.0
var margin_right: float = 20.0
var margin_top: float = 20.0
var margin_bottom: float = 45.0
var y_max: float = 6.0

func _draw() -> void:
	## Draw background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1))
	
	## Get data from the UI (owner of this scene)
	var ui = owner
	if not ui or not "concentration_history" in ui:
		draw_no_data()
		return
	
	var history: Dictionary = ui.concentration_history
	if history.is_empty():
		draw_no_data()
		return
	
	## Check if we have any data points
	var has_data = false
	for mol_name in history:
		if history[mol_name].size() > 1:
			has_data = true
			break
	
	if not has_data:
		draw_no_data()
		return
	
	var chart_rect = Rect2(
		margin_left, margin_top,
		size.x - margin_left - margin_right,
		size.y - margin_top - margin_bottom
	)
	
	## Calculate y_max from data
	y_max = 0.5
	for mol_name in history:
		for val in history[mol_name]:
			y_max = max(y_max, val * 1.15)
	
	draw_grid(chart_rect)
	draw_axes(chart_rect)
	draw_data(chart_rect, history)
	draw_legend(history)

func draw_no_data() -> void:
	var center = size / 2
	draw_string(ThemeDB.fallback_font, center - Vector2(60, 0), "Waiting for data...", 
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.4, 0.4, 0.5))

func draw_grid(rect: Rect2) -> void:
	var grid_color = Color(0.15, 0.15, 0.18)
	
	## Horizontal grid lines
	for i in range(1, 6):
		var y = rect.position.y + rect.size.y * (1.0 - i / 5.0)
		draw_line(
			Vector2(rect.position.x, y),
			Vector2(rect.position.x + rect.size.x, y),
			grid_color, 1.0
		)
	
	## Vertical grid lines
	for i in range(1, 10):
		var x = rect.position.x + rect.size.x * (i / 10.0)
		draw_line(
			Vector2(x, rect.position.y),
			Vector2(x, rect.position.y + rect.size.y),
			grid_color, 1.0
		)

func draw_axes(rect: Rect2) -> void:
	var axis_color = Color(0.4, 0.4, 0.45)
	var label_color = Color(0.55, 0.55, 0.6)
	var font = ThemeDB.fallback_font
	
	## X axis
	draw_line(
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		axis_color, 2.0
	)
	
	## Y axis
	draw_line(
		rect.position,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		axis_color, 2.0
	)
	
	## Y axis labels
	draw_string(font, Vector2(5, rect.position.y + 12), "%.1f" % y_max, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
	draw_string(font, Vector2(5, rect.position.y + rect.size.y * 0.5 + 5), "%.1f" % (y_max * 0.5), 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
	draw_string(font, Vector2(5, rect.position.y + rect.size.y + 3), "0", 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
	
	## Y axis title
	draw_string(font, Vector2(8, rect.position.y + rect.size.y * 0.25), "mM",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.45))

func draw_data(rect: Rect2, history: Dictionary) -> void:
	var color_idx = 0
	
	for mol_name in history:
		var data: Array = history[mol_name]
		if data.size() < 2:
			color_idx += 1
			continue
		
		var color = COLORS[color_idx % COLORS.size()]
		var points: PackedVector2Array = []
		
		for i in range(data.size()):
			var x = rect.position.x + (float(i) / max(data.size() - 1, 1)) * rect.size.x
			var y = rect.position.y + rect.size.y * (1.0 - data[i] / y_max)
			y = clamp(y, rect.position.y, rect.position.y + rect.size.y)
			points.append(Vector2(x, y))
		
		## Draw thicker line with glow effect
		for i in range(points.size() - 1):
			## Glow
			draw_line(points[i], points[i + 1], Color(color, 0.3), 6.0)
			## Main line
			draw_line(points[i], points[i + 1], color, 2.5)
		
		## Draw current value marker
		if points.size() > 0:
			var last_point = points[points.size() - 1]
			draw_circle(last_point, 5.0, color)
			draw_circle(last_point, 3.0, Color(0.1, 0.1, 0.12))
		
		color_idx += 1

func draw_legend(history: Dictionary) -> void:
	var font = ThemeDB.fallback_font
	var y_offset = size.y - 28
	var x_offset = margin_left
	var color_idx = 0
	
	for mol_name in history:
		var color = COLORS[color_idx % COLORS.size()]
		var data: Array = history[mol_name]
		var current_val = data[data.size() - 1] if data.size() > 0 else 0.0
		
		## Color indicator line
		draw_line(Vector2(x_offset, y_offset + 6), Vector2(x_offset + 20, y_offset + 6), color, 3.0)
		
		## Label with current value
		var label = "%s: %.2f" % [_shorten_name(mol_name), current_val]
		draw_string(font, Vector2(x_offset + 25, y_offset + 11), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.75))
		
		x_offset += 140
		color_idx += 1

func _shorten_name(name: String) -> String:
	## Extract key part of molecule name
	if name.begins_with("Substrate_"):
		return "Sub_" + name.substr(10)
	elif name.begins_with("Intermediate_"):
		return "Int_" + name.substr(13)
	elif name.begins_with("Product_"):
		return "Prod_" + name.substr(8)
	elif name.length() > 10:
		return name.substr(0, 8) + ".."
	return name
