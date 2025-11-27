## Interactive chart panel with tab-based filtering and hover highlights
class_name ChartPanel
extends Panel

#region Chart Mode

enum ChartMode {
	CELL,       ## Energy and heat over time
	ENZYMES,    ## Enzyme concentrations
	MOLECULES,  ## Molecule concentrations
	REACTIONS   ## Reaction rates
}

var current_mode: ChartMode = ChartMode.MOLECULES

#endregion

#region Configuration

const MAX_HISTORY_POINTS: int = 200
const SAMPLE_INTERVAL: float = 0.1
const CHART_COLORS: Array[Color] = [
	Color(0.3, 0.8, 0.3),   ## Green
	Color(0.3, 0.6, 0.9),   ## Blue  
	Color(0.9, 0.5, 0.3),   ## Orange
	Color(0.8, 0.3, 0.8),   ## Purple
	Color(0.9, 0.9, 0.3),   ## Yellow
	Color(0.3, 0.9, 0.9),   ## Cyan
	Color(0.9, 0.3, 0.5),   ## Pink
	Color(0.6, 0.6, 0.6),   ## Gray
	Color(0.5, 0.8, 0.5),   ## Light green
	Color(0.5, 0.5, 0.9),   ## Light blue
]

const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const LINE_WIDTH: float = 2.0
const HIGHLIGHT_LINE_WIDTH: float = 4.0

#endregion

#region State

## History data per mode
var molecule_history: Dictionary = {}   ## {mol_name: Array[float]}
var enzyme_history: Dictionary = {}     ## {enz_name: Array[float]}
var reaction_history: Dictionary = {}   ## {rxn_id: Array[float]}
var cell_history: Dictionary = {        ## Fixed keys for cell data
	"energy": [],
	"heat": [],
	"generated": [],
	"consumed": []
}

var time_history: Array[float] = []
var sample_timer: float = 0.0
var max_y_value: float = 10.0

## Hover state
var hovered_item: String = ""
var legend_items: Array[Dictionary] = []  ## [{name, color, rect}]
var line_hitboxes: Dictionary = {}        ## {name: Array[Rect2]}

#endregion

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	sample_timer += delta
	if sample_timer >= SAMPLE_INTERVAL:
		sample_timer = 0.0
		_sample_data()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

func _draw() -> void:
	var rect = get_rect()
	var margin = 50.0
	var legend_width = 140.0
	var chart_rect = Rect2(
		margin, margin,
		rect.size.x - margin - legend_width - 20,
		rect.size.y - margin * 2
	)
	
	## Clear hover data
	legend_items.clear()
	line_hitboxes.clear()
	
	## Draw background
	draw_rect(chart_rect, Color(0.08, 0.08, 0.1))
	
	## Draw grid
	_draw_grid(chart_rect)
	
	## Get data for current mode
	var data = _get_current_data()
	
	## Calculate max value
	_calculate_max_value(data)
	
	## Draw lines
	_draw_data_lines(chart_rect, data)
	
	## Draw legend
	var legend_rect = Rect2(
		chart_rect.end.x + 10,
		chart_rect.position.y,
		legend_width,
		chart_rect.size.y
	)
	_draw_legend(legend_rect, data)
	
	## Draw axes labels
	_draw_axes_labels(chart_rect)
	
	## Draw title
	_draw_title(chart_rect)

#region Public API

func set_mode(mode: ChartMode) -> void:
	current_mode = mode
	hovered_item = ""
	queue_redraw()

func clear_history() -> void:
	molecule_history.clear()
	enzyme_history.clear()
	reaction_history.clear()
	cell_history = {"energy": [], "heat": [], "generated": [], "consumed": []}
	time_history.clear()
	max_y_value = 10.0

#endregion

#region Data Sampling

func _sample_data() -> void:
	var sim = _get_simulator()
	if not sim:
		return
	
	time_history.append(sim.simulation_time)
	if time_history.size() > MAX_HISTORY_POINTS:
		time_history.pop_front()
	
	## Sample molecules
	for mol_name in sim.molecules:
		if not molecule_history.has(mol_name):
			molecule_history[mol_name] = []
		molecule_history[mol_name].append(sim.molecules[mol_name].concentration)
		if molecule_history[mol_name].size() > MAX_HISTORY_POINTS:
			molecule_history[mol_name].pop_front()
	
	## Sample enzymes
	for enzyme in sim.enzymes:
		if not enzyme_history.has(enzyme.name):
			enzyme_history[enzyme.name] = []
		enzyme_history[enzyme.name].append(enzyme.concentration)
		if enzyme_history[enzyme.name].size() > MAX_HISTORY_POINTS:
			enzyme_history[enzyme.name].pop_front()
	
	## Sample reactions
	for enzyme in sim.enzymes:
		for rxn in enzyme.reactions:
			if not reaction_history.has(rxn.id):
				reaction_history[rxn.id] = []
			reaction_history[rxn.id].append(rxn.get_net_rate())
			if reaction_history[rxn.id].size() > MAX_HISTORY_POINTS:
				reaction_history[rxn.id].pop_front()
	
	## Sample cell data
	if sim.cell:
		var energy = sim.cell.get_energy_status()
		cell_history["energy"].append(energy.usable_energy)
		cell_history["heat"].append(sim.cell.heat)
		cell_history["generated"].append(energy.total_generated)
		cell_history["consumed"].append(energy.total_consumed)
		
		for key in cell_history:
			if cell_history[key].size() > MAX_HISTORY_POINTS:
				cell_history[key].pop_front()

func _get_simulator() -> Simulator:
	var owner_node = get_owner()
	if owner_node and owner_node.has_node("SimEngine"):
		return owner_node.get_node("SimEngine") as Simulator
	return null

#endregion

#region Data Access

func _get_current_data() -> Dictionary:
	match current_mode:
		ChartMode.CELL:
			return cell_history
		ChartMode.ENZYMES:
			return enzyme_history
		ChartMode.MOLECULES:
			return molecule_history
		ChartMode.REACTIONS:
			return reaction_history
	return {}

func _calculate_max_value(data: Dictionary) -> void:
	max_y_value = 1.0
	for key in data:
		var history = data[key]
		for value in history:
			max_y_value = max(max_y_value, abs(value))
	max_y_value *= 1.2  ## Add headroom

#endregion

#region Drawing

func _draw_grid(chart_rect: Rect2) -> void:
	var grid_color = Color(0.25, 0.25, 0.3, 0.5)
	
	## Horizontal lines
	for i in range(5):
		var y = chart_rect.position.y + chart_rect.size.y * (1.0 - i / 4.0)
		draw_line(
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.end.x, y),
			grid_color
		)
	
	## Vertical lines
	for i in range(5):
		var x = chart_rect.position.x + chart_rect.size.x * (i / 4.0)
		draw_line(
			Vector2(x, chart_rect.position.y),
			Vector2(x, chart_rect.end.y),
			grid_color
		)

func _draw_data_lines(chart_rect: Rect2, data: Dictionary) -> void:
	if time_history.is_empty():
		return
	
	var color_index = 0
	for item_name in data:
		var history = data[item_name]
		if history.size() < 2:
			color_index += 1
			continue
		
		var base_color = CHART_COLORS[color_index % CHART_COLORS.size()]
		var is_highlighted = (item_name == hovered_item)
		var color = HIGHLIGHT_COLOR if is_highlighted else base_color
		var width = HIGHLIGHT_LINE_WIDTH if is_highlighted else LINE_WIDTH
		
		var points: PackedVector2Array = []
		var hitbox_points: Array[Vector2] = []
		
		for i in range(history.size()):
			var x = chart_rect.position.x + (float(i) / max(history.size() - 1, 1)) * chart_rect.size.x
			var normalized_y = history[i] / max_y_value
			var y = chart_rect.end.y - normalized_y * chart_rect.size.y
			y = clamp(y, chart_rect.position.y, chart_rect.end.y)
			points.append(Vector2(x, y))
			hitbox_points.append(Vector2(x, y))
		
		## Store hitbox for hover detection
		line_hitboxes[item_name] = hitbox_points
		
		## Draw line (highlighted items drawn last/on top via z-order hack)
		if not is_highlighted:
			if points.size() >= 2:
				draw_polyline(points, color, width, true)
		
		color_index += 1
	
	## Draw highlighted line on top
	if hovered_item != "" and data.has(hovered_item):
		var history = data[hovered_item]
		if history.size() >= 2:
			var points: PackedVector2Array = []
			for i in range(history.size()):
				var x = chart_rect.position.x + (float(i) / max(history.size() - 1, 1)) * chart_rect.size.x
				var normalized_y = history[i] / max_y_value
				var y = chart_rect.end.y - normalized_y * chart_rect.size.y
				y = clamp(y, chart_rect.position.y, chart_rect.end.y)
				points.append(Vector2(x, y))
			draw_polyline(points, HIGHLIGHT_COLOR, HIGHLIGHT_LINE_WIDTH, true)

func _draw_legend(legend_rect: Rect2, data: Dictionary) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 11
	var line_height = 20
	var y_offset = 0
	var color_index = 0
	
	## Background
	draw_rect(legend_rect, Color(0.1, 0.1, 0.12, 0.8))
	
	for item_name in data:
		if y_offset > legend_rect.size.y - line_height:
			## Draw "more items" indicator
			draw_string(
				font,
				Vector2(legend_rect.position.x + 5, legend_rect.position.y + y_offset + 14),
				"... +%d more" % (data.size() - color_index),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color(0.6, 0.6, 0.6)
			)
			break
		
		var base_color = CHART_COLORS[color_index % CHART_COLORS.size()]
		var is_highlighted = (item_name == hovered_item)
		var color = HIGHLIGHT_COLOR if is_highlighted else base_color
		var text_color = Color(1.0, 1.0, 1.0) if is_highlighted else Color(0.8, 0.8, 0.8)
		
		var item_y = legend_rect.position.y + y_offset
		
		## Color swatch
		var swatch_rect = Rect2(legend_rect.position.x + 5, item_y + 4, 14, 14)
		draw_rect(swatch_rect, color)
		if is_highlighted:
			draw_rect(swatch_rect, Color.WHITE, false, 2.0)
		
		## Name (truncated)
		var display_name = _get_display_name(item_name)
		draw_string(
			font,
			Vector2(legend_rect.position.x + 24, item_y + 14),
			display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(legend_rect.size.x - 30),
			font_size,
			text_color
		)
		
		## Store legend item rect for hover detection
		var item_rect = Rect2(
			legend_rect.position.x,
			item_y,
			legend_rect.size.x,
			line_height
		)
		legend_items.append({
			"name": item_name,
			"color": base_color,
			"rect": item_rect
		})
		
		y_offset += line_height
		color_index += 1

func _get_display_name(item_name: String) -> String:
	## Shorten long names
	if item_name.length() > 14:
		return item_name.substr(0, 12) + ".."
	return item_name

func _draw_axes_labels(chart_rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 10
	var label_color = Color(0.65, 0.65, 0.7)
	
	## Y-axis labels
	for i in range(5):
		var value = max_y_value * (i / 4.0)
		var y = chart_rect.end.y - chart_rect.size.y * (i / 4.0)
		var format_str = "%.1f" if value < 10 else "%.0f"
		draw_string(
			font,
			Vector2(5, y + 4),
			format_str % value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			label_color
		)
	
	## X-axis label
	draw_string(
		font,
		Vector2(chart_rect.position.x + chart_rect.size.x / 2 - 25, chart_rect.end.y + 30),
		"Time (s)",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		label_color
	)
	
	## Y-axis unit label
	var unit = _get_y_axis_unit()
	draw_string(
		font,
		Vector2(5, chart_rect.position.y - 8),
		unit,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		label_color
	)

func _get_y_axis_unit() -> String:
	match current_mode:
		ChartMode.CELL:
			return "[kJ]"
		ChartMode.ENZYMES:
			return "[mM]"
		ChartMode.MOLECULES:
			return "[mM]"
		ChartMode.REACTIONS:
			return "[mM/s]"
	return ""

func _draw_title(chart_rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var title = _get_chart_title()
	draw_string(
		font,
		Vector2(chart_rect.position.x, 20),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(0.9, 0.9, 0.95)
	)

func _get_chart_title() -> String:
	match current_mode:
		ChartMode.CELL:
			return "📊 Cell Energy & Heat"
		ChartMode.ENZYMES:
			return "📊 Enzyme Concentrations"
		ChartMode.MOLECULES:
			return "📊 Molecule Concentrations"
		ChartMode.REACTIONS:
			return "📊 Reaction Rates"
	return "📊 Chart"

#endregion

#region Hover Detection

func _update_hover(mouse_pos: Vector2) -> void:
	var local_pos = mouse_pos - global_position
	var old_hover = hovered_item
	hovered_item = ""
	
	## Check legend items first
	for item in legend_items:
		if item.rect.has_point(local_pos):
			hovered_item = item.name
			break
	
	## If not hovering legend, check line proximity
	if hovered_item == "":
		var closest_distance = 15.0  ## Max distance to consider hovering
		for item_name in line_hitboxes:
			var points = line_hitboxes[item_name]
			var dist = _distance_to_polyline(local_pos, points)
			if dist < closest_distance:
				closest_distance = dist
				hovered_item = item_name
	
	if old_hover != hovered_item:
		queue_redraw()

func _distance_to_polyline(point: Vector2, polyline: Array) -> float:
	var min_dist = INF
	for i in range(polyline.size() - 1):
		var dist = _distance_to_segment(point, polyline[i], polyline[i + 1])
		min_dist = min(min_dist, dist)
	return min_dist

func _distance_to_segment(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var line_vec = seg_end - seg_start
	var point_vec = point - seg_start
	var line_len = line_vec.length()
	
	if line_len < 0.001:
		return point_vec.length()
	
	var line_unitvec = line_vec / line_len
	var proj_length = point_vec.dot(line_unitvec)
	proj_length = clamp(proj_length, 0, line_len)
	
	var closest_point = seg_start + line_unitvec * proj_length
	return (point - closest_point).length()

#endregion
