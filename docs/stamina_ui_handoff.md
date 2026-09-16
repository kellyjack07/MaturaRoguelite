# Player stamina and stamina bottle handoff

## Central gameplay settings

Edit `data/player/stamina_settings.tres` to change:

- `max_stamina`: default 100
- `dash_cost`: default 40
- `regen_per_second`: default 20
- `regen_delay`: default 1 second after a dash spends stamina
- `boost_duration`: default 8 active gameplay seconds
- `boost_regen_per_second`: default 40

`scripts/stamina_component.gd` owns current stamina, delay, boost state,
clamping, signals, and save snapshots. Potion ownership is separate in
`scripts/potion_inventory.gd`. `Player` owns dash eligibility/spending and
emits a potion-use request; `Main` authoritatively validates potion use,
saves it, and restores the previous snapshots if saving fails.

## Bottle and input editing

`STAMINA_BOTTLE_COST` in `scripts/main.gd` controls the Shop Room price. The
named `use_stamina_bottle` action is bound to F in `project.godot`. The single
slot is intentionally capped at one bottle; no general inventory is involved.

## HUD editing

The stamina readout is built in `scripts/ui/hud.gd` below the existing player
health display and uses the existing `HUDText` theme variation. Edit the HUD
theme/font for typography. The display shows current/max stamina, the actual
bottle count, the action binding, and remaining boost seconds.

The reward-event panel has a fourth button in `scenes/main.tscn`. Only the
Shop Room fills it; other room events leave it hidden. The shop button is
disabled with a tooltip/status reason when gold is insufficient or the bottle
slot is full.

## Lifecycle and integration

- Stamina ticks only from the active Player physics loop, so pause, menus,
  room events, stage transitions, and death do not advance it.
- Dash immunity is independent from normal post-hit invulnerability and is
  cleared by dash completion, cancellation, death, reset, and load.
- Save snapshots include stamina, regen delay, bottle count, boost time, and
  the existing dash cooldown. Legacy snapshots default to full stamina with
  no bottle or boost.
