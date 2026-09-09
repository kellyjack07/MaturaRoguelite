extends Control
class_name SkillTreeGraph

signal node_selected(node_id: String)
signal node_focused(node_id: String)

const NODE_SCENE := preload("res://ui/components/skill_tree_node.tscn")

var layout: SkillTreeLayout
var node_controls: Dictionary = {}
var node_views: Dictionary = {}
var node_positions: Dictionary = {}
var selected_node_id: String = ""
var content_size := Vector2.ZERO


func set_layout(value: SkillTreeLayout) -> void:
	layout = value
	queue_redraw()


func set_tree_data(branches: Array[Dictionary], requested_selection: String = "") -> void:
	var views := _flatten_views(branches)
	var ids: Array[String] = []
	for view: Dictionary in views:
		ids.append(str(view.get("node_id", "")))
	var existing_ids: Array[String] = []
	for node_id: String in node_controls.keys():
		existing_ids.append(node_id)
	ids.sort()
	existing_ids.sort()
	if ids != existing_ids:
		_rebuild(views, branches)
	else:
		node_views.clear()
		for view: Dictionary in views:
			node_views[str(view.get("node_id", ""))] = view
		_update_nodes()
		queue_redraw()

	if requested_selection != "" and node_controls.has(requested_selection):
		select_node(requested_selection)
	elif selected_node_id == "" or not node_controls.has(selected_node_id):
		select_node(_default_node_id())


func select_node(node_id: String) -> void:
	if not node_controls.has(node_id):
		return
	selected_node_id = node_id
	var selected_texture: Texture2D = layout.selection_texture if layout != null else null
	for id: String in node_controls.keys():
		var node: SkillTreeNode = node_controls[id]
		node.set_node_view(node_views[id], id == selected_node_id, selected_texture, layout.artwork_scale)
	queue_redraw()


func focus_selected_or_root() -> void:
	var target_id := selected_node_id if node_controls.has(selected_node_id) else _default_node_id()
	var target: SkillTreeNode = node_controls.get(target_id)
	if target != null:
		target.grab_focus()


func get_selected_node_id() -> String:
	return selected_node_id


func _flatten_views(branches: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for branch: Dictionary in branches:
		for view: Dictionary in branch.get("nodes", []):
			result.append(view)
	return result


func _rebuild(views: Array[Dictionary], branches: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.free()
	node_controls.clear()
	node_views.clear()
	node_positions.clear()
	for view: Dictionary in views:
		node_views[str(view.get("node_id", ""))] = view

	if layout == null:
		return
	var branch_lists: Array[Array] = []
	var root_id := ""
	for branch: Dictionary in branches:
		var branch_id := str(branch.get("branch_id", ""))
		var branch_nodes: Array = []
		for view: Dictionary in branch.get("nodes", []):
			var node_id := str(view.get("node_id", ""))
			if branch_id == "root" or str(view.get("display_id", "")) == "0" or node_id == "root":
				root_id = node_id
			else:
				branch_nodes.append(node_id)
		if not branch_nodes.is_empty():
			branch_lists.append(branch_nodes)

	var padding := layout.canvas_padding
	var node_width := maxf(48.0, layout.node_size.x)
	var node_height := maxf(34.0, layout.node_size.y)
	var max_branch_count := 1
	for branch_nodes: Array in branch_lists:
		max_branch_count = maxi(max_branch_count, branch_nodes.size())
	var graph_width := padding.x + padding.z + branch_lists.size() * node_width + maxi(0, branch_lists.size() - 1) * layout.branch_gap
	var step := node_height + layout.vertical_node_gap
	var branch_bottom := padding.y + (max_branch_count - 1) * step
	var root_y := branch_bottom + step
	content_size = Vector2(maxf(graph_width, node_width + padding.x + padding.z), root_y + node_height + padding.w)
	custom_minimum_size = content_size
	size = content_size

	for branch_index in range(branch_lists.size()):
		var branch_nodes: Array = branch_lists[branch_index]
		var x := padding.x + branch_index * (node_width + layout.branch_gap)
		for row in range(branch_nodes.size()):
			var node_id: String = branch_nodes[row]
			var node: SkillTreeNode = NODE_SCENE.instantiate()
			node.custom_minimum_size = Vector2(node_width, node_height)
			node.size = Vector2(node_width, node_height)
			node.position = Vector2(x, padding.y + (branch_nodes.size() - 1 - row) * step)
			node.set_node_view(node_views[node_id], false, layout.selection_texture, layout.artwork_scale)
			_add_node(node, node_id)
			branch_nodes[row] = node_id

	if root_id != "" and node_views.has(root_id):
		var root_node: SkillTreeNode = NODE_SCENE.instantiate()
		root_node.custom_minimum_size = Vector2(node_width, node_height)
		root_node.size = Vector2(node_width, node_height)
		root_node.position = Vector2((content_size.x - node_width) * 0.5, root_y)
		root_node.set_node_view(node_views[root_id], false, layout.selection_texture, layout.artwork_scale)
		_add_node(root_node, root_id)

	_set_focus_neighbours(branch_lists, root_id)
	_update_positions()
	queue_redraw()


func _add_node(node: SkillTreeNode, node_id: String) -> void:
	add_child(node)
	node_controls[node_id] = node
	node_positions[node_id] = node.position
	node.inspected.connect(_on_node_inspected)
	node.focus_entered.connect(_on_node_focus_entered.bind(node_id))


func _update_nodes() -> void:
	var selected_texture: Texture2D = layout.selection_texture if layout != null else null
	for node_id: String in node_controls.keys():
		var node: SkillTreeNode = node_controls[node_id]
		node.set_node_view(node_views[node_id], node_id == selected_node_id, selected_texture, layout.artwork_scale)


func _update_positions() -> void:
	for node_id: String in node_controls.keys():
		node_positions[node_id] = node_controls[node_id].position


func _set_focus_neighbours(branch_lists: Array[Array], root_id: String) -> void:
	for branch_index in range(branch_lists.size()):
		var branch_nodes: Array = branch_lists[branch_index]
		for row in range(branch_nodes.size()):
			var node: SkillTreeNode = node_controls[branch_nodes[row]]
			if row > 0:
				node.set_focus_neighbor(SIDE_BOTTOM, node_controls[branch_nodes[row - 1]].get_path())
			if row < branch_nodes.size() - 1:
				node.set_focus_neighbor(SIDE_TOP, node_controls[branch_nodes[row + 1]].get_path())
			if branch_index > 0 and row < branch_lists[branch_index - 1].size():
				node.set_focus_neighbor(SIDE_LEFT, node_controls[branch_lists[branch_index - 1][row]].get_path())
			if branch_index < branch_lists.size() - 1 and row < branch_lists[branch_index + 1].size():
				node.set_focus_neighbor(SIDE_RIGHT, node_controls[branch_lists[branch_index + 1][row]].get_path())
			if row == 0 and root_id != "":
				node.set_focus_neighbor(SIDE_BOTTOM, node_controls[root_id].get_path())
	if root_id != "" and node_controls.has(root_id):
		var root_node: SkillTreeNode = node_controls[root_id]
		if not branch_lists.is_empty():
			root_node.set_focus_neighbor(SIDE_TOP, node_controls[branch_lists[0][0]].get_path())
			root_node.set_focus_neighbor(SIDE_LEFT, node_controls[branch_lists[0][0]].get_path())
			root_node.set_focus_neighbor(SIDE_RIGHT, node_controls[branch_lists[branch_lists.size() - 1][0]].get_path())


func _default_node_id() -> String:
	if node_views.has("root"):
		return "root"
	for node_id: String in node_controls.keys():
		if str(node_views[node_id].get("display_id", "")) == "0":
			return node_id
	return node_controls.keys()[0] if not node_controls.is_empty() else ""


func _on_node_inspected(node_id: String) -> void:
	select_node(node_id)
	node_selected.emit(node_id)


func _on_node_focus_entered(node_id: String) -> void:
	select_node(node_id)
	node_focused.emit(node_id)


func _draw() -> void:
	if layout == null:
		return
	for node_id: String in node_views.keys():
		var predecessor := str(node_views[node_id].get("predecessor_id", ""))
		if predecessor.is_empty() or not node_positions.has(predecessor) or not node_positions.has(node_id):
			continue
		var from: Vector2 = node_positions[predecessor] + layout.node_size * 0.5
		var to: Vector2 = node_positions[node_id] + layout.node_size * 0.5
		var state := str(node_views[node_id].get("state", "locked"))
		var colour := layout.connector_locked_color
		if state == "purchased":
			colour = layout.connector_purchased_color
		elif state == "available":
			colour = layout.connector_available_color
		if layout.path_tileset != null and is_zero_approx(from.x - to.x):
			_draw_vertical_path(from, to, state)
		else:
			draw_line(from, to, colour, 2.0, false)


func _draw_vertical_path(from: Vector2, to: Vector2, state: String) -> void:
	# The atlas is a 16px grid. Row 1, column 0 is the dark vertical
	# straight tile; column 4 is its light counterpart. Repeat the tile
	# without stretching it so pixel artwork stays integer-aligned.
	var column := 4 if state == "purchased" or state == "available" else 0
	var region := Rect2(column * 16, 16, 16, 16)
	var top := minf(from.y, to.y)
	var bottom := maxf(from.y, to.y)
	var y := floorf(top / 16.0) * 16.0
	while y <= bottom:
		draw_texture_rect_region(layout.path_tileset, Rect2(from.x - 8.0, y, 16.0, 16.0), region)
		y += 16.0
