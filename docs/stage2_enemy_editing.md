# Stage 2 enemy editing

Stage 2 enemy scenes are:

- `enemies/frog_monster.tscn`
- `enemies/ent_lvl1.tscn`, `enemies/ent_lvl2.tscn`, `enemies/ent_lvl3.tscn`
- `enemies/mushroom.tscn`
- `enemies/cyclop_archer.tscn`
- `enemies/frog_boss.tscn`

They use `scripts/stage2_enemy.gd`. Every scene contains named, empty
`AnimatedSprite2D` slots so sheets can be populated manually without runtime
frame generation. The slots are:

- FrogMonster: `idle`, `prepare`, `jump`, `recover`
- Ent1: `idle`, `move`, `ignite`, `burning`, `recover`
- Ent2/3: `idle`, `move`, `prepare`, `attack`, `recover`
- Mushroom/Cyclop: `idle`, `move`, `prepare`, `attack`, `recover`
- FrogBoss: `idle`, `prepare`, `jump`, `recover`, `summon`

Open the scene's `AnimatedSprite2D` and assign/edit its SpriteFrames. The
scripts derive prepare and attack durations from non-empty clips and use the
scene fallback values when a slot is empty. Normalized `action_point` values
control landing or projectile release without changing SpriteFrames.

Encounter rosters and fixed finales are editable in
`data/encounters/encounter_catalogue.tres`. Stage 2 is stages 4, 5 and 6
(2-1, 2-2 and 2-3). Stage 2 final waves use the existing room-owned wave
system and two-second warning break.
