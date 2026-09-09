extends Control
class_name SkillTreeScreen

## Presentation-only controller. SkillTreeService remains the authority for all
## node state, purchase validation, essence and persistence.

var main: Node
var skill_tree: SkillTreeService
var selected_node_id := ""
var feedback_message := ""

@export var layout_resource: SkillTreeLayout = preload("res://data/ui/skill_tree_layout.tres")

@onready var background: ColorRect = $Background
@onready var outer_margin: MarginContainer = $OuterMargin
@onready var main_vbox: VBoxContainer = $OuterMargin/MainVBox
@onready var body: BoxContainer = $OuterMargin/MainVBox/Body
@onready var tree_panel: PanelContainer = $OuterMargin/MainVBox/Body/TreePanel
@onready var tree_scroll: ScrollContainer = $OuterMargin/MainVBox/Body/TreePanel/TreeVBox/TreeScroll
@onready var graph: SkillTreeGraph = $OuterMargin/MainVBox/Body/TreePanel/TreeVBox/TreeScroll/GraphCanvas
@onready var info_label: Label = $OuterMargin/MainVBox/StoreInfoLabel
@onready var details_panel: PanelContainer = $OuterMargin/MainVBox/Body/DetailsPanel
@onready var details_id_label: Label = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsIdLabel
@onready var details_title_label: Label = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsTitleLabel
@onready var details_scroll: ScrollContainer = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsScroll
@onready var details_description_label: Label = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsScroll/DetailsContent/DetailsDescriptionLabel
@onready var details_cost_label: Label = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsScroll/DetailsContent/DetailsCostLabel
@onready var details_state_label: Label = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/DetailsScroll/DetailsContent/DetailsStateLabel
@onready var purchase_button: Button = $OuterMargin/MainVBox/Body/DetailsPanel/DetailsVBox/PurchaseButton


func _ready() -> void:
	set_process_input(true)
	graph.node_selected.connect(_on_graph_node_selected)
	graph.node_focused.connect(_on_graph_node_focused)
	purchase_button.pressed.connect(_on_purchase_pressed)
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_apply_layout()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE and main != null:
			main.close_gear_store()
			get_viewport().set_input_as_handled()
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_scroll := _find_scroll_ancestor(hovered)
	var pointer_position := Vector2.ZERO
	if event is InputEventMouse:
		pointer_position = event.position
	elif event is InputEventPanGesture:
		pointer_position = event.position
	var is_over_tree := hovered_scroll == tree_scroll or tree_scroll.get_global_rect().has_point(pointer_position)
	if not is_over_tree:
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
			return
		var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_scroll_tree_by(roundi(48.0 * maxf(event.factor, 1.0)) * direction)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		_scroll_tree_by(roundi(event.delta.y * 48.0))
		get_viewport().set_input_as_handled()


func _find_scroll_ancestor(control: Control) -> ScrollContainer:
	var current: Node = control
	while current != null:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


func _scroll_tree_by(delta: int) -> void:
	var scroll_bar := tree_scroll.get_v_scroll_bar()
	var maximum := maxi(roundi(scroll_bar.max_value - scroll_bar.page), 0)
	tree_scroll.scroll_vertical = clampi(tree_scroll.scroll_vertical + delta, 0, maximum)


func setup(main_reference: Node) -> void:
	main = main_reference
	skill_tree = main.get_skill_tree_core()
	feedback_message = ""
	if is_inside_tree():
		graph.set_layout(layout_resource)
	refresh_ui()


func refresh_ui() -> void:
	if skill_tree == null or not is_inside_tree():
		return
	$OuterMargin/MainVBox/Header/EssenceLabel.text = "Essence: %d" % skill_tree.get_essence_balance()
	var branches: Array[Dictionary] = skill_tree.get_ordered_branches()
	graph.set_layout(layout_resource)
	graph.set_tree_data(branches, selected_node_id)
	if selected_node_id == "":
		selected_node_id = graph.get_selected_node_id()
	_update_details()
	if feedback_message.is_empty():
		info_label.text = "Select a node to inspect it. Locked nodes show the core's exact reason."


func focus_first_control() -> void:
	if not is_inside_tree():
		return
	graph.focus_selected_or_root()


func _apply_layout() -> void:
	# Resize notifications can arrive before @onready variables are assigned.
	if layout_resource == null or not is_inside_tree() or not is_node_ready():
		return
	if outer_margin == null or main_vbox == null or body == null or background == null:
		return
	var margin := layout_resource.outer_margin
	outer_margin.add_theme_constant_override("margin_left", maxi(0, roundi(margin.x)))
	outer_margin.add_theme_constant_override("margin_top", maxi(0, roundi(margin.y)))
	outer_margin.add_theme_constant_override("margin_right", maxi(0, roundi(margin.z)))
	outer_margin.add_theme_constant_override("margin_bottom", maxi(0, roundi(margin.w)))
	main_vbox.add_theme_constant_override("separation", roundi(layout_resource.header_spacing))
	$OuterMargin/MainVBox/Footer.add_theme_constant_override("separation", roundi(layout_resource.footer_spacing))
	background.color = layout_resource.background_color
	var narrow := size.x > 0.0 and size.x < layout_resource.responsive_breakpoint
	body.vertical = narrow
	if narrow:
		details_panel.custom_minimum_size = Vector2(0.0, layout_resource.details_min_height)
		tree_panel.custom_minimum_size = Vector2(0.0, 190.0)
	else:
		details_panel.custom_minimum_size = Vector2(layout_resource.details_width, 0.0)
		tree_panel.custom_minimum_size = Vector2(0.0, 0.0)


func _on_graph_node_selected(node_id: String) -> void:
	selected_node_id = node_id
	feedback_message = ""
	_update_details()
	details_scroll.scroll_vertical = 0


func _on_graph_node_focused(node_id: String) -> void:
	selected_node_id = node_id
	feedback_message = ""
	_update_details()
	details_scroll.scroll_vertical = 0


func _update_details() -> void:
	if skill_tree == null or selected_node_id.is_empty():
		return
	var view: Dictionary = skill_tree.get_node_view(selected_node_id)
	if view.is_empty():
		return
	var state := str(view.get("state", "locked"))
	details_id_label.text = str(view.get("display_id", selected_node_id))
	details_title_label.text = str(view.get("title", "Unknown node"))
	details_description_label.text = str(view.get("description", ""))
	details_cost_label.text = "Cost: %d Essence" % int(view.get("cost", 0))
	if state == "locked":
		details_state_label.text = "LOCKED\n%s" % str(view.get("blocking_reason", "Locked."))
	else:
		details_state_label.text = state.to_upper()
	if state == "available":
		purchase_button.text = "Purchase • %d Essence" % int(view.get("cost", 0))
		purchase_button.disabled = false
	elif state == "purchased":
		purchase_button.text = "Purchased"
		purchase_button.disabled = true
	else:
		purchase_button.text = "Locked"
		purchase_button.disabled = true


func _on_purchase_pressed() -> void:
	if main == null or selected_node_id.is_empty():
		return
	var result: Dictionary = main.purchase_skill_node(selected_node_id)
	# Refresh from the service after both success and failure. The result message
	# is applied last so a synchronous changed signal cannot erase it.
	refresh_ui()
	var reason := str(result.get("reason", "Purchase failed."))
	if bool(result.get("success", false)):
		feedback_message = "Purchased %s. Essence: %d" % [selected_node_id, int(result.get("essence", 0))]
	else:
		feedback_message = "Purchase failed: %s" % reason
	info_label.text = feedback_message
