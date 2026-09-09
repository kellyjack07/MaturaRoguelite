# Player weapons: implementation and testing

## Controls and developer access

- Move: WASD or arrow keys.
- Basic attack: Space.
- Special attack: Q.
- In normal progression, each weapon's special requires its skill-tree node 07. The F6 screen is the explicit testing bypass and does not purchase that node.
- Dash: Shift.
- Developer weapon screen: F6, only in debug builds unless `enable_dev_weapon_screen_in_release` is explicitly enabled on `Main`.
- Escape or F6 closes the developer screen. Opening it cancels the active attack/dash and pauses the scene tree; its controls continue processing while paused.

The screen is available only during a live, unpaused run and not during death, transitions, room events, settings, the normal pause screen or the main menu. Locked weapons are labelled and may be equipped for testing without changing permanent unlocks. The chosen test weapon becomes the run's existing `weapon` field and is saved/continued, but no unlock, currency, health, floor or reward state is changed.

## Editable definitions

- Registry: `scripts/weapons/weapon_registry.gd`
- Resource schemas: `scripts/weapons/weapon_definition.gd`, `scripts/weapons/attack_definition.gd`
- Weapon tuning: `data/weapons/sword.tres`, `data/weapons/spear.tres`, `data/weapons/hammer.tres`
- Controller/action execution: `scripts/player.gd`
- Total attack hit budget and pulse deduplication: `scripts/hitbox_component.gd`
- Developer UI: `ui/dev_weapon_screen.tscn`, `scripts/ui/dev_weapon_screen.gd`

Initial playtest values (not final balance):

| Weapon | Basic | Basic timing | Shape / cap | Special | Special timing | Shape / cap | Cooldown |
|---|---:|---|---|---:|---|---|---:|
| Sword | 5 | 0.10 startup, 0.20 active, 0.20 recovery | 34×20 sweep / 3 | 8 | 0.10, 0.20, 0.10 | radius 32 spin / 6 | 1.5 s |
| Spear | 4 | 0.10, 0.10, 0.10 | 52×12 thrust / 2 | 7 | 0.10, 0.50, 0.10; 3 pulses | 68×16 thrust / 6 total hits | 2.0 s |
| Hammer | 7 | 0.20, 0.10, 0.10 | 42×30 strike / 3 | 12 | 0.30, 0.20, 0.30 | radius 42 slam / 8 | 3.0 s |

Upgrade levels add to their matching resource base damage. The existing attack debuff is subtracted once from both basic and special damage. Movement speed debuffs remain independent. Per-weapon special cooldowns survive A-B-A switching and are included in the run snapshot, so switching cannot reset a cooldown. Legacy `heavy` IDs/meta entries migrate to `hammer`; unknown weapon IDs fall back to `sword`.

## Automated verification performed

Godot executable: 4.6 stable Mono. Tests used isolated writable AppData directories because the execution sandbox cannot write the normal Godot profile folders.

1. Headless editor import/parse: project resources and scripts loaded with no project parse errors.
2. Headless main-scene launch: main menu loaded and ran for 120 frames with no project runtime error.
3. `tests/player_weapons_smoke_test.gd`:
   - checks every mapped animation's atlas row, left-to-right frame order, frame count, 100 ms source timing and loop flag;
   - checks every weapon/action/direction resolves to a non-empty animation, including documented fallbacks;
   - checks right-facing side convention and the stable foot-anchor offset indirectly through the saved contract;
   - checks invalid and legacy weapon ID fallback;
   - checks sword basic's total target cap and that idle overlap does no damage;
   - checks spear multi-pulses respect hurtbox invulnerability;
   - checks weapon switching cancels windup and cannot produce a stale hit;
   - checks A-B-A switching preserves cooldowns and produces identical effective stats;
   - checks basic/special upgrade and debuff math is applied once;
   - checks the developer panel pauses/resumes, updates player/run state, saves the weapon and does not unlock it;
   - checks death disables damage reception, completes the animation, and reset restores visibility/action/hurtbox state.

The commands emit a Windows certificate-store warning in this restricted host; the engine falls back to built-in certificates. This is outside the project and does not affect gameplay.

## Manual graphical checks still recommended

A native interactive playthrough was not performed from the headless test environment. In the editor, verify the feel of diagonal attacks, visual overlap of each hit shape with contact artwork, mouse/keyboard focus in the F6 panel, and the perceived foot anchor against room tiles. The principal asset limitation is the missing sword side strike; it currently uses the documented down-strike fallback. Shared movement/reaction art also does not show a held weapon except in the three down-idle sequences.
