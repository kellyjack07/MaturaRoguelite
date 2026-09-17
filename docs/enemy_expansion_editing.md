# Stage 1 enemy editing guide

The implemented Stage 1-2 and Stage 1-3 enemies are configured in
`data/encounters/encounter_catalogue.tres`. The catalogue IDs are stable save
identities: `green_goblin`, `green_orc_archer`, `orc_barbare`,
`blue_orc_barbare`, `red_orc_barbare`, `blue_orc_archer`, and `red_orc_archer`.

## Enemy tuning

- `scripts/new_melee_enemy.gd` contains local exported values for goblin and
  barbare movement, range, prepare, dash, attack, hit delay and recovery.
- `scripts/orc_archer.gd` contains local exported values for detection,
  firing range, timing, projectile speed and lifetime.
- Each scene keeps its own exported values. There is no shared balance resource.
- All new enemies start at 20 HP and deal 5 damage; knockback reception is
  disabled in their scripts.
- Orc colour presets are scene-editable: green is 20 HP/5 damage/40 movement,
  blue is 25/6/42, and red is 30/7/44. Archer projectile speeds are 180/190/200;
  melee recovery is 0.8/0.72/0.64 seconds and archer recovery is 1.0/0.9/0.8.
- Stage 1-3 chooses the Orc family first with equal family weight, then chooses
  green/blue/red at 60%/30%/10%, with at most one red enemy per regular room.
  `difficulty_weight` remains explicit metadata on each family scene (1.0,
  1.4, 1.8 by colour); it is not used to bias the family roll.

Prepare and attack durations are calculated once on spawn from the assigned
SpriteFrames frame durations and animation FPS. Empty or missing clips use the
exported fallback duration, so a bad resource cannot stall an attack. The
editable `attack_hit_point` / `attack_release_point` values are normalized
positions within the authored attack clip; they replace hidden timer offsets
while preserving the existing single-hit/single-projectile behavior.

## Animation slots

All future enemies use editor-authored `AnimatedSprite2D.sprite_frames`.
Runtime scripts select an existing animation by name but never construct or
replace `SpriteFrames` during spawn. Edit the base resources directly in
`enemies/green_goblin.tscn`, `enemies/orc_archer.tscn`, and
`enemies/orc_barbare.tscn`.

The independently editable colour resources are:

- `data/enemy_frames_orc_archer_blue.tres`, used by `enemies/orc_archer_blue.tscn`.
- `data/enemy_frames_orc_archer_red.tres`, used by `enemies/orc_archer_red.tscn`.
- `data/enemy_frames_orc_barbare_blue.tres`, used by `enemies/orc_barbare_blue.tscn`.
- `data/enemy_frames_orc_barbare_red.tres`, used by `enemies/orc_barbare_red.tscn`.

Open the matching `.tres` file in Godot's Inspector/SpriteFrames editor to
change that colour only. The PNG sheets are shared read-only inputs; frame
regions and animation settings are serialized independently per resource.
Barbare remains stationary during its swing: its authored `dash` animation is
kept available but gameplay continues to set `uses_dash = false`.

## Projectile settings

`scripts/enemy_projectile.gd` owns the arrow's damage, speed and lifetime.
The current default is 5 damage, 180 px/s and 2 seconds. The projectile uses
a swept ray between frames for wall blocking and checks the player's Hurtbox
once before freeing itself.

Edit the archetype scripts or variant scene instance properties when tuning;
do not add values to a shared enemy parameter resource.

## Fixed floor finales

`data/encounters/encounter_catalogue.tres` owns the editable `final_waves`
rosters for the 1-1 and 1-2 final challenge rooms, plus the replay-specific
1-1 roster. `scripts/main.gd` saves every generated wave record and only
activates the current wave. After a wave is cleared, the room displays a
two-second incoming-wave warning before spawning the next wave. The existing
1-3 Sorcerer/MonsterSlasher major boss remains a separate encounter and is not
given these waves.

The final-wave records are regular enemy kills, not designated boss kills.
Older saves with a generated final challenge but no `fixed_final_waves` format
are left as their existing encounter; new templates apply only to newly
generated encounters, so a continue cannot replace an active legacy fight.
