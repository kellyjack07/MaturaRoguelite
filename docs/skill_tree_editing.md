# Skill-tree UI editing guide

The skill tree is a presentation layer over `SkillTreeService`. The UI reads
node views from the service and sends purchases through `Main.purchase_skill_node()`.
Costs, prerequisites, effects, ownership and save behavior stay in
`data/skill_tree/skill_tree.tres` and must not be copied into UI scripts.

## Main editing points

| What to edit | File | Properties |
| --- | --- | --- |
| Shared font and base text | `ui/themes/dungeon_theme.tres` | `default_font`, `default_font_size`, `Label/*`, `Button/*` |
| Skill-tree text sizes | `ui/themes/dungeon_theme.tres` | `SkillTreeTitle/font_sizes/font_size`, `SkillTreeEssence`, `SkillTreeSectionTitle`, `SkillTreeDetailTitle`, `SkillTreeDetailBody`, `SkillPurchaseButton`, and `SkillNode*` |
| Node and graph geometry | `data/ui/skill_tree_layout.tres` | `node_size`, `vertical_node_gap`, `branch_gap`, `canvas_padding` |
| Screen margins and spacing | `data/ui/skill_tree_layout.tres` | `outer_margin`, `header_spacing`, `footer_spacing` |
| Details/responsive layout | `data/ui/skill_tree_layout.tres` | `details_width`, `details_min_height`, `responsive_breakpoint` |
| Background/connectors | `data/ui/skill_tree_layout.tres` | `background_color`, `connector_purchased_color`, `connector_available_color`, `connector_locked_color` |
| Screen structure | `ui/skill_tree_screen.tscn` | Containers, labels, scroll container and separate purchase/footer controls |
| Graph behavior | `scripts/ui/skill_tree_graph.gd` | API-driven placement, predecessor links and focus neighbors |
| Node presentation | `scripts/ui/skill_tree_node.gd` and `ui/components/skill_tree_node.tscn` | Compact display-ID button and independent selection overlay |

The `Vector4` padding and margin values use `left, top, right, bottom` order.
The graph derives its content bounds, node positions and connector endpoints
from `node_size`, gaps, the returned branch ordering and each node's
`predecessor_id`. Changing a node size or gap therefore moves the nodes and
redraws the links together.

## Theme and text

`ui/themes/dungeon_theme.tres` is the single font source. It references
`res://assets/UI/enter-the-gungeon-big.ttf`; do not add another font reference
to individual nodes. The skill-specific variations inherit their base types:

- `SkillTreeTitle`, `SkillTreeEssence`, `SkillTreeSectionTitle`,
  `SkillTreeDetailTitle` and `SkillTreeDetailBody` inherit from `Label`.
- `SkillPurchaseButton`, `SkillNode`, `SkillNodeAvailable`,
  `SkillNodePurchased` and `SkillNodeLocked` inherit from `Button`.
- `SkillTreePanel` inherits from `PanelContainer`.

Changing `Label`/`Button` base styling affects the main menu as well. Change a
`SkillTree*` variation when only the skill tree should change. The node state
variations provide purchased, available and locked visual differences without
maintaining a UI-side state list.

## Artwork

The layout resource references each supplied presentation texture once:

- `path_tileset` →
  `assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_tree_path_tileset.png`
- `selection_texture` →
  `assets/UI/Tiny Dungeons - UI Pack/skill_tree/skill_selected.png`

The path atlas is 128×64 and is arranged as 16×16 cells: columns 0–3 are the
dark set, columns 4–7 are the corresponding light set, with rows 0–3 holding
the connector/end/junction pieces. The current graph uses aligned 2-pixel
connector lines colored by authoritative node state; the atlas remains the
central mapping reference for replacing those lines with sliced tiles later.
This avoids stretching the whole atlas and keeps a future slice change in one
resource. The selection artwork is a 26×26 overlay and is independent of node
state/focus.

`scripts/ui/skill_tree_node.gd` maps the definition's `effect_type` to the
supplied health, strength, stat-boost and inventory icon pairs. Max-health uses
health; character/basic/special damage uses strength; target-limit uses
inventory; movement, reach, width, area and cooldown use stat boost. Branch
entries, special unlocks and unknown future effect types use the plus icon as a
generic fallback. Locked nodes use the matching `_locked` texture, available
nodes use the unlocked texture with a 72% tint, and purchased nodes use the
unmodified unlocked texture. The compact display ID remains visible beside the
icon.

## Data boundary

`data/skill_tree/skill_tree.tres` remains the source of truth for every node's
ID, display ID, title, description, effect, cost, order and predecessor. The
UI does not derive branch relationships from display-number strings, subtract
essence, unlock weapons, or save progress. The sword/root automatic relationship
continues to be owned by the service.

## Verification

The Godot editor parse/import check completed successfully for the classes and
scene resources. `tests/skill_tree_smoke_test.gd` passes. The focused
`tests/skill_tree_ui_smoke_test.gd` also passes at the project's 640×360 logical
viewport and verifies that the graph exposes a vertical range, mouse-wheel
input changes its scroll position, details wrap within their scroll viewport,
and both the Back button and Escape return to the main menu. Godot emits only
the host's root-certificate-store warning, which does not affect these tests.

The graph and detail text use separate vertical scroll containers. The footer
is outside both, so Other Gear and Back remain fixed on screen.

## Manual verification checklist

Runtime visual and interaction checks remain manual in the Godot editor/project:

1. Open Gear Store from the main menu; confirm root, three weapon entries and
   all ten upgrades per branch appear exactly once.
2. Select with mouse and keyboard; verify offscreen focus scrolls into view and
   the details panel shows full text and the exact `blocking_reason`.
3. Purchase an available node from the separate Purchase button; confirm the
   service refreshes essence/state while selection and scroll position remain.
4. Confirm purchased and locked nodes remain inspectable, legacy gear buttons
   and Back still work, and Escape closes the store.
5. Resize to a width below the configured breakpoint; confirm the details panel
   switches below the tree and both independent scroll areas remain usable.

No save data is modified by these checks.
