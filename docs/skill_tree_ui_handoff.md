# Skill-tree UI handoff

## Ownership and files

The core is owned by `SkillTreeService` at runtime. `Main` creates it during `_ready()` as the node `Main/SkillTreeCore`; UI may obtain it with `Main.get_skill_tree_core()` instead of searching the tree.

- `scripts/progression/skill_node_definition.gd`: editable node schema.
- `scripts/progression/skill_tree_definition.gd`: tree schema and global tuning.
- `data/skill_tree/skill_tree.tres`: all IDs, display IDs, branch order, titles, descriptions, costs, predecessor IDs, effects, tutorial reward, cross-weapon strength, and stage requirements.
- `scripts/progression/skill_tree_service.gd`: validation, purchases, state views, migration, eligibility, and stat-profile calculation.
- `scripts/main.gd`: save ownership, lifecycle hooks, and application of calculated stats to the player.
- `scripts/player.gd`: runtime attack geometry, target cap, cooldown, damage, and special lock enforcement.

Luna must not modify the five core files above or `data/skill_tree/skill_tree.tres` while building the separate UI unless a core contract change is coordinated. The intended UI scope is `scenes/main.tscn` plus a new/replacement script or reusable scene under `scripts/ui` and `ui`.

## Public API

Get the service from the current `Main` node:

```gdscript
var skill_tree: SkillTreeService = main.get_skill_tree_core()
```

`SkillTreeService` exposes:

- `signal changed`: emitted after a successful purchase, tutorial/eligibility change, or eligibility commit. Refresh the visible tree and essence label when this fires.
- `get_essence_balance() -> int`: current permanent essence.
- `get_ordered_branches() -> Array[Dictionary]`: ordered `root`, `sword`, `spear`, `hammer` branch views. Each branch has `branch_id`, `display_id`, `title`, and ordered `nodes`.
- `get_node_view(node_id: String) -> Dictionary`: one presentation-safe node view.
- `validate_purchase(node_id: String) -> Dictionary`: read-only validation, useful for previews but never a substitute for `purchase`.
- `purchase(node_id: String) -> Dictionary`: the only skill-tree purchase operation. It revalidates currency, ownership eligibility, automatic nodes, and predecessor state; deducts essence and records nodes together; saves immediately; and rolls the in-memory transaction back if saving fails.
- `is_node_purchased(node_id: String) -> bool`.
- `is_weapon_owned(weapon_id: String) -> bool`: Sword is playable even before root; Spear/Hammer require their branch-node purchase.
- `is_special_unlocked(weapon_id: String) -> bool`: true only when that weapon's `_07` node is purchased.

`Main.purchase_skill_node(node_id: String) -> Dictionary` is a convenience pass-through for UI that already owns a `Main` reference.

A node view contains `node_id`, `display_id`, `branch_id`, `order`, `title`, `description`, `cost`, `predecessor_id`, `effect_type`, `state`, and `blocking_reason`. `effect_type` is presentation metadata used for icon selection; it does not grant or calculate an effect. `state` is exactly `purchased`, `available`, or `locked`. A locked view carries the same exact reason returned by validation, such as `Purchase 1-03 first.`, `Clear 2-1 first.`, `Clear 2-1 eligibility is pending until death, run completion, or save-and-quit.`, or `Need 8 more essence.`

A purchase result contains:

```gdscript
{
    "success": bool,
    "node_id": String,
    "code": String,
    "reason": String,
    "essence": int,
}
```

Useful failure codes are `unknown_node`, `already_purchased`, `automatic_node`, `missing_prerequisite`, `stage_locked`, `eligibility_pending`, `insufficient_essence`, and `save_failed`. The UI should display `reason`, not duplicate this decision logic.

## Replacing the old store buttons

The existing screen remains at `Main/UI/GearStoreScreen`. This core task intentionally did not redesign it. The five legacy weapon controls are currently hidden, disabled, disconnected, and have no legacy handlers:

- `UnlockSpearButton`
- `SwordDamageButton`
- `SwordSpecialButton`
- `SpearDamageButton`
- `SpearSpecialButton`

Replace those controls with a tree/branch view populated only from `get_ordered_branches()`. Connect each purchase button to `purchase(node_id)` and refresh after the result and on `changed`. Never deduct essence, append node IDs, unlock weapons, or infer availability in UI code. This prevents keyboard focus, stale references, or repeated callbacks from reaching the retired `weapon_trees` counters.

Keep these existing store controls and behavior:

- `EssenceLabel` (source its value from `get_essence_balance()`).
- `StoreInfoLabel` (available for selection details/status feedback).
- `StarterGoldButton`, `RestBonusButton`, and `LuckButton` (the separate legacy gear progression is still active and outside the weapon tree).
- `BackButton` and the existing main-menu/Escape lifecycle.
- The screen background/title unless the UI design task explicitly replaces them.

The store currently opens only from the main menu through `Main.open_gear_store()` and closes through `Main.close_gear_store()`. Preserve that lifecycle. Do not add tree input to gameplay or the pause menu. Purchases save immediately, so the UI must not call `Main.save_progress()` itself.

## Progression and save behavior

Internal stage IDs are linear: 1 is `1-1`, 4 is `2-1`, and 7 is `3-1`. `Main.start_stage_transition()` records the qualifying clear immediately. Weapon eligibility remains pending until player death, `Main.complete_run()`, `Main.save_and_quit_game()`, or a window-close notification. Merely opening pause does nothing. Save-and-quit commits meta eligibility and preserves the current run snapshot.

Clearing `1-1` grants 10 essence once. The nested save value `tutorial_reward = {claimed, essence_granted}` records the flag and granted amount together. Repeated stage callbacks and reloads are idempotent.

The Hammer requirement is provisionally `3-1`, represented as editable `required_stage = 7` on node `hammer` in `data/skill_tree/skill_tree.tres`. Change that resource value if design changes; do not hard-code a different requirement in UI.

Old saves are detected by the absence of `skill_tree_version`. Migration:

- preserves old Spear/Hammer (`heavy`) ownership as grandfathered purchased branch IDs;
- transfers old per-weapon `base_damage` and `special_damage` levels into `legacy_skill_tree_bonuses` as exact flat bonuses;
- leaves the old `weapon_trees` data present for non-destructive compatibility, but runtime calculation ignores it so old and new bonuses cannot apply twice;
- converts qualifying `highest_stage_completed` values to committed eligibility;
- grants the new tutorial reward once to an old save that had already cleared `1-1`.

Legacy special-damage value is retained but the special itself still requires node 07, as required by the new tree.

## Stat calculation contract

Every recalculation starts from the immutable player/weapon Resource values. No calculated value is fed back as a future base.

1. Add a migrated legacy flat damage value to the weapon's base damage.
2. Apply summed associated weapon damage percentages.
3. Apply the summed character damage percentage. Each purchased character node is full strength on its own weapon and 30% strength on other weapons.
4. Subtract the existing run `attack_penalty` once and clamp to at least 1. Fractional damage remains until the player samples its movement multiplier; the actual hit is rounded once.
5. Movement is immutable base speed times the summed character speed multiplier, then the existing flat run `speed_penalty`, then the existing minimum-speed clamp.
6. Maximum health is immutable base max health times summed character health bonuses, rounded once. Recalculation preserves current health and only caps it when the new maximum is lower; switching never heals.

Weapon-only reach, width, area, target-limit, special-damage, and cooldown effects apply only to their associated weapon. Percentages of the same type add before the single multiplication. Hammer area scales both rectangle dimensions by `sqrt(1.15)`, producing 15% more area rather than 32.25%. All three basic attacks currently have finite caps (Sword 3, Spear 2, Hammer 3), so each `+1 target` node has an effect.

Normal load/equip falls back to Sword when a saved weapon is not owned. `Player` refuses special input and direct `start_special_attack()` calls until node 07. The F6 developer weapon screen remains the explicit bypass: it can equip an unowned weapon and test its special without changing permanent ownership or purchased nodes. That bypass is not persisted as normal ownership.

## Known limitations and provisional decisions

- The current project has no natural final-run victory event. Future endgame code must call `Main.complete_run()`; death and both quit paths are already wired.
- Hammer's `3-1` requirement is provisional and intentionally configured in the tree resource.
- Existing saved developer-selected locked weapons fall back to Sword on normal continue. Re-select them through F6 to establish an explicit developer bypass.
- The current legacy gear buttons still use their existing cost formulas and direct gear counters; they are not part of the skill-tree API.

## UI implementation update

The placeholder UI pass is complete for Sol's current API contract.

### Changed files

- `scenes/main.tscn`: replaced the five retired weapon controls in `Main/UI/GearStoreScreen` with a root section, a scrollable three-column branch container, and the existing separate gear controls repositioned below it. The store keeps its existing background, entry point, Back button, and menu lifecycle.
- `scripts/ui/skill_tree_screen.gd`: new `SkillTreeScreen` presentation script. It reads `get_ordered_branches()`, `get_essence_balance()`, and each node view, displays IDs/names/effects/costs/states/reasons, and sends purchases through `Main.purchase_skill_node()` only. The API root view populates the one static `RootButton`; the dynamic column builder excludes the root branch/node. Locked nodes stay focusable so the core's exact failure reason is shown on focus and after a failed purchase; purchased nodes are read-only. The scroll container uses `follow_focus` for keyboard navigation.
- `scripts/main.gd`: calls `GearStoreScreen.setup(self)` after creating `SkillTreeCore`, removes the retired weapon button references and signal connections, and routes the existing `SkillTreeService.changed` callback through `update_gear_store_ui()` so the new screen refreshes with the core.

### Connection points and integration notes

- `Main._ready()` creates the core, then calls `gear_store_screen.setup(self)`.
- `Main.skill_tree.changed` remains the single existing progression refresh connection and calls `Main._on_skill_tree_changed()` -> `update_gear_store_ui()` -> `SkillTreeScreen.refresh_ui()`.
- Dynamic node buttons call `Main.purchase_skill_node(node_id)` and do not subtract essence, maintain purchased state, unlock weapons, or call save directly.
- The screen is only opened by `Main.open_gear_store()` from the main menu and closes through the existing `Main.close_gear_store()` / Escape path. Its root mouse filter and button controls keep input inside the menu while it is visible.

### Verification

- `git diff --check` passes.
- Static reference checks show no remaining references to `UnlockSpearButton`, `SwordDamageButton`, `SwordSpecialButton`, `SpearDamageButton`, `SpearSpecialButton`, or their obsolete handlers.
- The project does not expose a Godot executable on PATH or in the usual installed locations in this environment, so Godot parse, visual, and runtime interaction checks could not be performed here. Sol should run the project and the existing skill-tree smoke test during the final integration pass.
