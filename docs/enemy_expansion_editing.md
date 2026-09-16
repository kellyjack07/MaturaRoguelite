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

## Animation slots

Goblin and Barbare build `idle`, `move`, `prepare`, `attack`, and optional
`dash` slots from their selected asset folder. Archer builds `idle`, `move`,
`prepare`, and `attack` slots. Archer colour variants select their own asset
folder through `skin_variant` on the scene instance.

## Projectile settings

`scripts/enemy_projectile.gd` owns the arrow's damage, speed and lifetime.
The current default is 5 damage, 180 px/s and 2 seconds. The projectile uses
a swept ray between frames for wall blocking and checks the player's Hurtbox
once before freeing itself.

Edit the archetype scripts or variant scene instance properties when tuning;
do not add values to a shared enemy parameter resource.
