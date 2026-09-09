# Luna Implementation Plan: Skill-Tree Presentation

Implement the graphical skill-tree UI described here, using the existing working progression system and menu styling. Read the current project and applicable instructions first. This is a presentation task, not a new progression implementation. Preserve unrelated user changes.

## 1. Inputs and verified current state

- The actual asset directory is `res://assets/UI/Tiny Dungeons - UI Pack/skill_tree/` (not `skill/_tree`).
- It contains `skill_selected.png` and `skill_tree_path_tileset.png`. Both were visually inspected during planning. The former is a selection outline; the latter contains small node/connection pieces in dark and light variants. Determine their exact rectangles, transparency and intended connections before slicing. Do not render the entire atlas as one node or assume filenames describe all state semantics.
- Shared Theme: `ui/themes/dungeon_theme.tres`.
- Supplied font: `res://assets/UI/enter-the-gungeon-big.ttf`, already referenced by the Theme. Text should remain black/dark as in the menu.
- Existing controller: `scripts/ui/skill_tree_screen.gd`; existing screen: `UI/GearStoreScreen` in `scenes/main.tscn`.
- Existing API documentation: `docs/skill_tree_ui_handoff.md`. Read it and verify against the current service before implementation.
- Current UI renders large text buttons in three scrolling columns. It uses per-control font-size overrides and whole-button modulation. Replace these with shared Theme styles and compact nodes with a separate details panel.
- Current progression definitions: `data/skill_tree/skill_tree.tres`. Do not change costs, prerequisites, effects, save migration or unlock requirements.

## 2. Intended layout

Keep the gear-store entry point and existing menu lifecycle. Within it, show a skill-tree title and essence balance, a scrollable graphical tree, a details panel and the existing separate gear purchases/Back control.

Default tree orientation: root 0 at the bottom centre; sword, spear and hammer unlocks above it; each branch's ten upgrades continue vertically upwards. Root links to each weapon, and all subsequent links come from predecessor_id. Use the API's ordering and IDs rather than deriving relationships from display-number strings.

At the current 640x360 logical viewport, start with a tree viewport on the left and a details panel on the right, with a compact header/footer. All eleven nodes per branch will not fit vertically: scrolling is intentional. On narrower layouts or with larger text, stack the details below the tree using one configurable breakpoint. Avoid squeezing text or shrinking controls below readable size. Preserve project viewport/stretch settings.

When first opened, scroll to root/the branch entrances. Preserve selected node and scroll position during purchases and refreshes. On subsequent openings, restore the user's selection and scroll where possible. Selecting an offscreen node by keyboard should reveal it.

Node visuals show a compact display ID, such as 1-01, with the supplied frame/path artwork and an optional concise category marker if space permits. Full names and effects belong in the details panel. Do not require a bespoke icon for every upgrade; the supplied folder does not provide such icons. A future node-ID-to-icon mapping should be optional and have a usable text fallback.

## 3. Central editing resources

Reuse `ui/themes/dungeon_theme.tres` for the font, text colours and standard buttons. Add skill-specific Theme variations for node buttons, detail title/body, purchase button and panels as needed, declaring their base types explicitly. Do not override the shared Button defaults in a way that changes the working main menu. Do not duplicate the font file reference on nodes.

Create `data/ui/skill_tree_layout.tres` with a custom Resource `scripts/ui/skill_tree_layout.gd` for geometry and presentation choices only:

- Node minimum size and optional integer artwork scale.
- Vertical node gap, branch gap and canvas padding.
- Header/footer spacing and outer margins.
- Details width/minimum height and responsive-layout breakpoint.
- Background colour and connector-state colours, where not Theme-owned.
- References to the shared atlas slices/selection texture or a small presentation asset map.

Each property must have one source of truth. Store fonts, font sizes and Control styles in the Theme; store graph/layout geometry in the layout Resource; do not repeat them in both. Reference each atlas slice once through a reusable resource rather than repeating rectangles per node. If extra atlas resources are needed, explain that normal size/font changes do not require editing them.

Changing node size/gaps must reposition nodes, adjust content bounds and redraw paths together. Text minimum size must be respected. Support editor preview for layout changes if practical with a small @tool presentation-only script; never invoke progression, saving or purchases in editor mode. Remove the existing scattered hardcoded font sizes, 136-pixel node heights and per-node colour assignments.

## 4. Reusable components and drawing

Suggested files, adjusted to the project's existing conventions:

```text
ui/skill_tree_screen.tscn
ui/components/skill_tree_node.tscn
scripts/ui/skill_tree_screen.gd          # adapt existing controller
scripts/ui/skill_tree_node.gd
scripts/ui/skill_tree_graph.gd           # graph positioning/connector rendering
scripts/ui/skill_tree_layout.gd
data/ui/skill_tree_layout.tres
data/ui/skill_tree_art.tres              # only if helpful for shared atlas mapping
docs/skill_tree_editing.md
```

Instance the reusable screen at the existing `UI/GearStoreScreen` path. Node controls should be real focusable Buttons or equivalent accessible Controls, not only painted textures with coordinate-based click tests. Decorative textures/paths must ignore mouse input.

Draw connectors behind controls, using the provided path tiles where appropriate. Inspect atlas pixel boundaries and repeat straight segments rather than stretching all corners into distorted lines. Route root links as a clear shared junction or nonoverlapping right-angle paths. Use node centres/ports and current layout to determine endpoints; do not use static coordinates. Redraw when size, layout or visual state changes, not needlessly each frame. Nodes, connectors and selection overlays must move together in one scrollable content coordinate space.

Use nearest filtering and integer-aligned artwork. If node frames cannot stretch cleanly, keep artwork at an integer size inside a larger button hit target; allow the text label/layout to grow independently. A clickable area can be larger than the tiny source artwork.

## 5. Selection, state and purchase interaction

Selecting a node by click or keyboard focus inspects it; it does NOT immediately purchase. Use a separate labelled Purchase button in the details panel to avoid accidental purchases while exploring the graph.

All nodes, including locked and purchased ones, remain selectable/focusable. Distinguish purchased, available and locked state using the supplied variants plus a small badge/shape/status label; do not rely on colour alone. The selection overlay is independent of progression state and may use skill_selected.png after its scale/shape is verified. Focus must remain visible too.

The details panel shows display ID, title, full description, cost, purchase state and exact blocking_reason. Purchased nodes show Purchased and have no enabled purchase action. Automatically granted sword/root relationships must remain owned by the service. Do not offer a misleading purchase for an automatic node.

Use get_node_view(node_id) for the selected node and main.purchase_skill_node(node_id) for purchases. Show result.reason, including failures such as a save failure. Refresh from authoritative state; do not optimistically deduct essence or mark nodes purchased. Ensure a synchronous changed signal cannot erase the final purchase result message or selection.

Preserve the current refresh path: main.gd already subscribes to SkillTreeService.changed and calls update_gear_store_ui(), which invokes refresh_ui(). Avoid duplicate service signal subscriptions and duplicate purchase callbacks. Build controls once when the definition changes, update their state in place for ordinary purchases, and keep focus/scroll stable.

For keyboard controls, define neighbours along each branch and across equivalent rows. Root connects upward to a weapon node; branch entrances can move down to root. Tab must provide a predictable route between tree, details purchase action, separate gear controls and Back, without a focus trap. Keep ScrollContainer follow-focus behaviour or equivalent for offscreen nodes.

## 6. Integration boundaries

Retain setup(main_reference), refresh_ui() and focus_first_control(), or update every caller if an interface change is needed. main.gd currently accesses GearStoreScreen's EssenceLabel, StarterGoldButton, RestBonusButton and LuckButton, and connects BackButton directly. Search all references before restructuring. Preserve those controls' functionality and update node paths in main.gd only where required by the scene layout.

The separate starter-gold, rest-bonus and luck upgrades remain outside the tree. Keep them in a labelled compact section with sufficient space/scrolling; do not delete or merge their rules into the new node API. Reuse standard Theme buttons for them. Preserve Escape/Back and return-to-main-menu behaviour. Do not expose progression UI during gameplay/pause.

Core service, player, weapon definitions, save code and progression data are outside scope. The minimal main.gd path/accessor changes needed for presentation are allowed. If a required API capability is missing, document the exact gap instead of inventing progression state in the UI. Do not touch real user saves during testing.

## 7. Implementation order

1. Read current controller/service handoff, menu Theme and main.gd integration; inspect atlas pieces at readable scale.
2. Establish shared art slices and skill-specific Theme variations without changing existing menu defaults.
3. Build a reusable node and data-driven graph layout with root and all three chains.
4. Add details, explicit purchase action and state refresh using the existing API.
5. Integrate existing gear actions and menu navigation; add keyboard/focus and responsive scrolling.
6. Validate presentation/behaviour and write the editing guide.

## 8. Acceptance and verification

- Root, three weapon nodes and thirty upgrade nodes appear exactly once, matching the current data; if definition counts change, the UI follows them automatically.
- Links match predecessor IDs, remain aligned after resizing and do not obscure text or capture clicks.
- Locked and purchased upgrades can both be inspected; inspecting never spends essence.
- Purchase results, essence and states update immediately without resetting selection/scroll or firing twice.
- All fonts inherit from the shared Theme. Changing the font there changes menu and skill tree together; skill-specific size changes do not alter menu size.
- One node-size/gap edit updates the whole graph and connectors. Longer descriptions and larger text remain readable and accessible.
- Mouse, keyboard and scrolling work at 640x360 logical size and the normal scaled window. Header, Back and separate gear purchases remain reachable.
- No gameplay/stat/save/progression-rule changes and no main-menu appearance regression.
- Run available Godot parse/import checks and the existing skill-tree smoke test using isolated save data. Inspect the screen visually if runtime tools are available; explicitly report unavailable checks.

Write `docs/skill_tree_editing.md` with exact files/properties for fonts, text sizes, node size, branch spacing, colours, atlas mappings, selection artwork and future optional icons. Explain that effects/costs remain in data/skill_tree/skill_tree.tres, independently of the UI. Include actual verification results and remaining manual checks.

Finish with a concise summary of the new screen, central editing points and preserved behaviour. Do not claim runtime or visual verification that was not performed.
