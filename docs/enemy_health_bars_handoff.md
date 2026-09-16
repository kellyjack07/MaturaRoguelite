# Enemy health bars and boss HUD handoff

## What changed

- `ui/enemy_health_bar.tscn` and `scripts/ui/enemy_health_bar.gd` provide the
  reusable overhead bar. It binds directly to `HealthComponent` signals,
  reveals after damage, stays visible after healing, clamps invalid maximums,
  and hides on death.
- `scripts/base_enemy.gd` creates one overhead bar for ordinary enemies.
  `health_bar_offset` and `health_bar_width` are the per-enemy overrides.
- `ui/boss_health_bar.tscn` and `scripts/ui/boss_health_bar.gd` provide named
  boss rows using the same bar implementation without numerical HP.
- `scripts/ui/hud.gd` owns the top-centre boss panel and safely registers,
  unregisters, and clears rows.
- `scripts/ui/hud_layout.gd` exposes `boss_width` and `boss_gap` in the
  existing `data/ui/hud_layout.tres` resource.
- `scripts/main.gd` assigns presentation metadata while spawning encounter
  records. The Sorcerer is the designated boss; MonsterSlashers, Goblin
  Barrels, final-challenge regular enemies, and other enemies use overhead
  bars. No progression, health, save, or combat rules were changed.

## Central visual editing

Edit `data/ui/enemy_health_bar_style.tres` to change the shared bar width,
height, world-space offset, fill colour, backing colour, border colour, and
border thickness. The style is shared by ordinary and boss bars.

Edit `boss_width`, `boss_gap`, and `boss_top_offset` in
`data/ui/hud_layout.tres` for the boss HUD row width, spacing, and top-screen
placement. The row stays below the stage label. Existing HUD theme/font
settings continue to control the boss name label.

For a single enemy, disable `health_bar_use_style_offset` and edit
`health_bar_offset` on its `BaseEnemy` scene root. `health_bar_width = 0` uses
the shared style width.

## Connection points and behavior notes

- `Main.register_enemy_presentation()` is the single encounter-spawn
  presentation registration point. It calls `BaseEnemy.configure_health_presentation()`
  and registers only records marked with `presentation_role = "boss"`.
- Existing room death bookkeeping remains the source of encounter state.
  Boss HUD rows are removed on boss death, node exit, room replacement, and
  hidden run/menu UI; support enemies do not keep a dead Sorcerer row alive.
- The UI never subtracts essence/health or keeps a gameplay purchase list; it
  only presents the existing core state and signals.

## Verification

- Godot `--headless --editor --quit` completed its project scan and registered
  the new scripts/classes. It emits the machine-specific editor-cache and
  certificate-store warnings already present in this environment.
- `tests/hud_smoke_test.gd` could not complete because this Windows headless
  Godot build terminates with signal 11 before reporting test assertions.
  Visual runtime inspection should therefore be performed in the normal Godot
  editor/run window during Sol's final integration pass.
