# Player Animations, Weapons and Developer Screen

Implementation handoff for GPT-5.6 Sol. Prepared 2026-09-08.

## Task and scope

Implement this plan end to end in the existing Godot project. First inspect and connect the supplied player animations to gameplay. Then implement the weapons represented by those assets and a developer screen for switching between them during a run. Deliver working basic and special attacks, weapon-specific animation and damage configuration, and compatibility with existing run state and saves.

This document is the plan; the planning pass has not changed gameplay code. Re-read the current files before implementing because the user may have edited them since this handoff. Preserve user changes, animation artwork, meaningful function comments and existing gameplay unless a change is necessary for this task. Do not implement the wider roadmap (cyclic maps, enemies, rewards, debuff choices or progression redesign).

## Evidence from the planning pass

- `assets/Character/Character Animations.aseprite` and `assets/Character/Character Animations-Sheet.png` exist. The PNG is 1728 by 5824 pixels. There is no companion JSON file in that folder at this time.
- Visual inspection suggests sword, spear and hammer attacks, including special attacks, plus locomotion and reaction sequences. These are provisional interpretations; inspect the source tags, frame timings and actual artwork before deciding exact mappings.
- `scenes/player.tscn` still references placeholder Swordsman textures. Its SpriteFrames contain `idle_*`, `walk_*` and `attack_*` for up, down and side. The new sheet has not yet been wired into this saved scene.
- `scenes/main.tscn` instances `scenes/player.tscn`. Check instance overrides before editing or moving resources.
- `scripts/player.gd` uses one generic attack shape, a delayed single damage query and an animation-name prefix to finish attacks. Its animation selection has no distinct dash, special, hurt or death playback. Death currently hides the player immediately.
- Attack and dash inputs are handled before reading the current movement input. This can select the previous frame's direction. Correct that ordering while wiring the new controller.
- The player scene overrides basic damage to 5 while the script default is 50. Use effective scene values as the existing baseline; do not accidentally make attacks ten times stronger.
- `scripts/main.gd` stores `current_run["weapon"]`, initializes sword/spear/hammer meta entries, displays the weapon and saves it. `apply_run_modifiers()` currently calculates damage from one cached player base value rather than an equipped weapon definition. Special upgrade entries exist but the player has no special attack implementation.
- `scripts/hitbox_component.gd` supports target limits and excludes the player's own hurtbox, but disables itself after one query. Its target counter resets per query. Extending it to active attack windows requires maintaining a total hit budget across the attack.
- Existing unrelated/user changes were present in `docs/balancing.xlsx`, `scenes/main.tscn` and `assets/Character/`. Preserve them.

## 1. Inspect and document the animation contract

Read `scripts/player.gd`, `scripts/hitbox_component.gd`, `scripts/hurtbox_component.gd`, `scripts/health_component.gd`, `scenes/player.tscn`, relevant run/menu/save/death methods in `scripts/main.gd`, `scenes/main.tscn`, and `project.godot`. Read any applicable repository instructions.

Inspect the Aseprite source using Aseprite or a read-only metadata parser. Inspect the exported PNG visually as well. Identify tags, frame durations, directions, held-weapon poses, attack contact frames, special sequences, dash, hurt and death. Determine whether a side-facing animation points left or right; do not inherit the old flip convention without checking it. Establish cell sizes, padding, frame counts and foot anchors from evidence. Do not assume every row has the same number of frames or that transparent cells are valid frames.

If source metadata does not describe the existing sheet layout, make a reproducible new PNG/JSON export under a new generated-output path without overwriting the user's source or sheet. If export tooling is unavailable, inspect the sheet and write an explicit atlas mapping. Do not invent tag names or silently guess an ambiguous animation. Complete independent work and ask one focused question only if a material ambiguity cannot be resolved from the files.

Create `docs/player_animation_map.md` recording the source sequence, weapon/action/direction, rectangles or frame range, per-frame timing, loop flag, facing/flip convention, and planned damage-active frames. Mark provisional gameplay choices distinctly from asset facts. Preserve artist timing unless a documented gameplay adjustment is necessary. Establish explicit shared-animation fallbacks when a weapon lacks its own locomotion or reaction animation.

Acceptance: every supplied player sequence is mapped to gameplay or explicitly documented as an unused/alternative sequence with a reason. No empty animation frames or guessed sheet slices.

## 2. Add a small data-driven weapon foundation

Prefer custom Godot Resource definitions, with explicit script-path references where needed to avoid the project's previous global-class resolution errors. Suggested structure, adjustable after inspection:

```text
scripts/weapons/weapon_definition.gd
scripts/weapons/attack_definition.gd
data/weapons/sword.tres
data/weapons/spear.tres
data/weapons/hammer.tres
data/player/                       # generated SpriteFrames/animation resources
scripts/ui/dev_weapon_screen.gd
ui/dev_weapon_screen.tscn
docs/player_animation_map.md
docs/weapon_testing.md
```

Use stable weapon IDs `sword`, `spear`, `hammer` if the assets confirm these weapons. Do not add unrelated weapons simply because enemy art exists. Keep one player controller rather than duplicating it per weapon. The developer screen must list weapons from the same registry gameplay uses.

Weapon definitions should hold display name, animation mappings and basic/special attack definitions. Attack definitions should expose base damage, timing/active frames, cooldown, shape and reach/offset, target cap, and any necessary attack movement. Use small dedicated behaviour helpers only for attacks that actually need them. Duplicate mutable shapes/resources per player instance to avoid modifying shared defaults.

Use `equip_weapon(id)` or an equivalent single API for applying visuals, attack configuration and state reset. Validate IDs and provide a safe sword fallback for missing/old saved IDs. Keep gameplay state ownership clear: the run owns the selected weapon ID; the player owns execution. Have the run coordinator apply equipment and modifiers together so UI, damage and saves cannot disagree.

## 3. Connect animation and action state

Read current movement input before accepting attacks/dashes. Preserve full-vector movement and attack direction; choose the nearest available visual direction separately. Lock attack direction when the attack starts. Use explicit action state rather than `animation.begins_with("attack")` to decide when an attack finishes.

Introduce a clear state priority and interruption policy covering death, reactions, attacks/specials, dash and locomotion. Preserve the ability to deal movement/dash-scaled damage. Recommended default: sample the movement multiplier once when an attack begins, expose it in debug output, and document this choice. Do not make attack animation restrictions remove the existing dash-attack mechanic. During an attack, attack visuals can take priority while dash movement continues where permitted.

Use confirmed active animation frames or timings derived from the animation map. Define startup, active window and recovery for every attack. Repeating specials must finish according to their configured action duration rather than relying on an animation-finished signal from a looping clip. Restart action animations intentionally, but do not restart idle/walk every physics tick.

Replace vulnerable delayed callbacks with action-state timers or an action-generation token. Finishing or cancelling an attack, switching equipment, dying, restarting a run, or leaving gameplay must invalidate old damage callbacks and disable the attack area. Pausing must freeze gameplay timing consistently. No delayed hit from a previous weapon may damage an enemy after switching.

Wire dash visuals to actual dash duration. Preserve hurt feedback and invulnerability blinking without leaving the sprite hidden or overwriting attack/death state. Lethal damage must not start a hurt animation after death begins; inspect the health/hurtbox signal order. Play the supplied death animation before hiding the character. Coordinate with `main.gd`, whose death callback currently pauses the game, so death playback completes, run invalidation happens exactly once and enemies cannot keep attacking the dead player. Reset all transient action, visibility and reaction state when reusing the player for a new run.

## 4. Implement playable weapon attacks

Implement basic and special attacks for each confirmed weapon. Match the supplied art before adding mechanics. Reasonable provisional identities are sword as a medium-reach sweep, spear as a longer/narrower thrust, and hammer as a slower heavy strike. A visible spin or multi-thrust sequence should have corresponding attack behaviour, but do not infer projectiles, status effects or combos without supporting animation/design evidence.

Choose initial values from the current effective sword baseline and expose tuning in Resources. Document the values as initial playtest settings rather than final balance. Every special needs a functioning input action and cooldown with visible readiness; use an unused key such as Q after checking existing input bindings. Retain existing movement, basic attack, dash and interaction controls.

Use oriented hit shapes appropriate to the weapon, rotating to the full attack vector. Do not rotate the top-down character sprite to arbitrary angles. Basic attacks hit each target at most once per swing, up to the configured total cap. If a special intentionally hits repeatedly, define separate pulse windows/intervals and respect enemy invulnerability. Do not blindly query damage every frame without deduplication. Exclude self and unintended target types, and use the appropriate collision mask. If a shape query has a finite result limit, account for that when supporting broad/multiple-target attacks.

Confirm attack areas stay inactive during ordinary movement, idle, cancellation and recovery. Use safe deferred physics changes where required. Avoid introducing the previously encountered monitoring/physics-query flush errors. Ensure changing an equipped shape during an active physics step is safe.

Acceptance: each weapon has visibly distinct, functional basic and special attacks whose damage coincides with the artwork. Walking into enemies does not deal weapon damage, and no attack damages the player itself.

## 5. Integrate run modifiers and saving

Update new-run initialization, continue-run loading, `apply_run_modifiers()`, weapon HUD and snapshot handling to use the equipped definition. Compute effective stats from base weapon values plus the existing upgrade/debuff rules every time; repeated switching must not accumulate bonuses or reset debuffs. Apply special-damage upgrades to special attacks. Keep the wider progression design unchanged.

Retain the existing save format where possible and supply defaults for new fields. Load the weapon definition before applying saved modifiers. Distinguish debug access from ownership: developer selection may temporarily equip locked weapons, but it must not unlock weapons, spend currency or rewrite upgrade levels.

Recommended persistence policy: keep the selected test weapon as the existing run weapon so save/continue restores the run accurately, while never changing permanent unlocks. State this explicitly on the developer screen or in testing instructions. Keep normal unlock restrictions outside the developer tool. Weapon selection must not refill health, reset the floor or discard run rewards. Prevent switching from being a special-cooldown reset exploit by preserving per-weapon cooldowns or applying an explicitly documented shared cooldown.

## 6. Add the developer weapon screen

Build a small reusable Control scene under the existing UI. Add a `dev_weapon_menu` action, default F6 if available. Show it only when developer tools are enabled; default enablement should follow debug builds, with an explicit editor override if useful. Release builds must not accidentally expose the menu.

Open only during a live run, outside death, transitions and other modal screens. Pause player, enemies and gameplay timers while the panel is open, while keeping the panel responsive. Integrate with existing pause/input handling: Escape closes this panel first, closing restores the prior pause state, and neither key presses nor mouse clicks may also attack or interact in the world. Ignore held-key echo toggles.

Provide labelled weapon buttons, current selection, permanent locked/unlocked status, and a clear indication that locked weapons are available for developer testing. Show effective basic/special damage, special cooldown and the relevant controls. Include Close/Resume and optional hitbox visibility if it can be implemented locally. Make mouse and keyboard focus navigation work; the previous reward UI had click issues, so check input interception and Control mouse filters.

Selecting a weapon uses the same equip API as gameplay and immediately updates visuals, attack configuration, run state and HUD. Cancel the current attack/dash safely before equipping; no damage should occur behind the panel. This is a tool for equipping and testing through normal controls, not merely an animation preview. Do not add unrelated cheats or a new developer game mode.

## 7. Verification and delivery

Use an available Godot 4.6 executable to run a headless editor import/parse check, then playtest the main scene. Locate the executable safely if it is not on PATH. If runtime testing is unavailable, document that limitation precisely rather than claiming the game was tested. Keep tests proportional: focused checks for action cancellation, targeting and stat application are more useful than broad unrelated test scaffolding.

Verify the following matrix:

- All confirmed weapons: idle, movement, dash, basic and special attacks in up/down/left/right and diagonal movement; correct sprite flip, stable foot anchor and no missing animations.
- Idle overlap causes no damage; basic attacks respect their full-swing target cap; intentional repeated specials obey pulse timing and invulnerability; enemies still damage the player normally.
- Startup, active and recovery timing match artwork; specials have working cooldowns; movement-based damage still distinguishes stationary, moving and dashing attacks.
- Switching during windup/active/recovery/dash does not leave a stale hit, locked attack state, wrong shape, hidden sprite or reset cooldown.
- Opening the developer panel in combat freezes enemies and attacks; closing restores the correct state; Escape and mouse clicks do not trigger gameplay or competing menus.
- Repeated A-B-A weapon switching produces identical effective stats. Existing debuffs/upgrades remain applied exactly once; locked debug weapons do not become permanently owned.
- Save/quit/continue restores the selected run weapon and correct stats. Old sword saves still load. Invalid weapon IDs fall back safely. New run and restart reset death/action state.
- Hurt and death animations finish correctly. Death processing occurs once, damage cannot fire after death, and restart restores a visible, controllable player.
- No missing resources, parse errors, physics flush errors or unintended editor/runtime warnings from the changed code. Developer panel unavailable by default in release configuration.

Document the final animation mappings, editable weapon Resource paths, developer-menu shortcut, special-attack input, provisional balance values, test results and unresolved asset limitations in `docs/weapon_testing.md`. End with a concise user-facing summary of actual changes and anything still requiring manual playtesting. Do not claim verification that was not performed.

## Suggested implementation order

1. Inspect assets and scene overrides; write the verified animation map.
2. Add definitions and wire the sword plus shared movement/reaction/death animations.
3. Verify action timing/cancellation and hit detection with one weapon.
4. Implement the remaining confirmed weapons and specials through the same foundation.
5. Integrate run modifiers, weapon state and save restoration.
6. Add the developer switcher and validate pause/input behaviour.
7. Run the full targeted checks, fix regressions and deliver testing notes.

The task is complete when the new artwork is used by the actual playable character, every confirmed weapon can be equipped and tested with functional attacks, and the developer panel, run state and saves all agree about the equipped weapon.
