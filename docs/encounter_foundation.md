# Encounter foundation

The editable room encounter catalogue is `data/encounters/encounter_catalogue.tres`,
backed by `scripts/encounters/encounter_catalogue.gd`.

`scripts/main.gd` generates each combat room before spawning it. Each generated
enemy has a stable `instance_id`, catalogue `enemy_id`, `scene_path`,
`implemented` flag, and `defeated` flag. The room saves those records and the
defeated IDs, so reloads resume the same encounter and duplicate death signals
are ignored.

Stage 1 starts with two Training Dummy 2 enemies. After a recorded stage-1
clear, replay rooms use the dummy plus Goblin Barrel roster. The catalogue
contains the later stage rosters. Twenty percent of a regular floor total is
selected from the immediately previous floor's regular roster within the same
world/stage group.

Entries marked `implemented = false` remain visible in the records and set an
explicit pending status on the room. Until their scene exists, the existing
generic enemy scene is used as the documented MVP fallback; this layer adds no
enemy behavior or progression rules.

Terminal rooms preserve the existing chest and portal lifecycle. Floor 3 uses
`major_boss`; earlier terminal rooms use `final_challenge` and are labeled
separately. Legacy room saves are normalized with the new fields, and a saved
remaining count is migrated into the generated record during preparation.

MonsterSlasher's approved design is 20 HP, 5 damage, Goblin Barrel's current
range/timing/movement values, two opposite-side passes through the player, no
attack interruption, and no knockback applied yet.

The approved boss support policy is stored with stages 1-3 in the catalogue:
2 initial slashers, 3 Goblin Barrels per Sorcerer wave for 3 waves total, and 2
new slashers after waves 1 and 2 are cleared. Sorcerer only becomes eligible
for its next wave after the previous Goblin Barrel group is defeated. Sorcerer
emits the wave request; `Main` consumes the catalogue policy, registers the
summoned records, and connects them to the room clear counter. Neither boss
owns the scheduling.
