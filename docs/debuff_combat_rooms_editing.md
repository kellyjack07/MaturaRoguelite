# Debuff combat rooms

The debuff-room system is integrated in `scripts/main.gd` and uses the typed
resources in `data/progression/debuff_catalogue.tres`. A modified room is still
a normal combat room: the room is generated on the regular combat graph, the
player chooses one modifier when entering it, and the modifier is removed when
the room is cleared.

## Central editing points

Edit the definitions in `data/progression/debuff_catalogue.tres`. Each entry is
a `DebuffDefinition` resource from `scripts/debuff_definition.gd` and exposes:

- `id`: stable save/API identifier; do not rename after shipping.
- `title` and `description`: choice-modal text.
- `tier`: 1, 2, or 3. The catalogue maps those tiers to +1, +2, or +3 Essence.
- `min_stage` and `max_stage`: stage-floor eligibility.
- `enabled` and `selection_weight`: catalogue availability controls.
- capability flags and effect fields: only use a flag when the corresponding
  gameplay hook exists.

The catalogue and selection filtering live in `scripts/debuff_catalogue.gd`.
The central list named `supported` is an intentional safety gate: a definition
may exist in the resource for future work but must not be offered until its
effect is implemented and tested.

## Current behaviour

Modified rooms are generated only after the current world's final level has
been cleared before. The requested number is randomly either floor(N/2) or
ceil(N/2), where N is the regular combat-room count. The first combat room,
rest/shop rooms, terminals, and boss rooms are not modified.

The offered IDs and selected ID are persisted in the room save data. Selection
is mandatory and pauses the player through the existing room-event modal.
Clearing the room banks the tier Essence in the run payout accounting; it does
not credit Essence immediately. Existing end-of-run payout and exactly-once
crediting remain responsible for the final account change.

Currently offered and wired effects are `enemy_health`, `more_enemies`,
`slowness`, `damage_reduction`, and `enemy_haste`. The resource also contains
placeholders for projectile speed, melee reach, regeneration, restricted
vision, slow recovery, elite defender, and reinforcements. Those are filtered
out until their authoritative gameplay hooks are added. `damage_tick` and
`weapon_restriction` remain disabled in the resource.

## Save and integration notes

Room state is migrated by `ensure_stage_room_shape()` in `scripts/main.gd`.
Do not keep a second purchased/selected list outside the room data. New room
effects should be applied from the saved selected ID and cleared from
`on_combat_room_cleared()` so reloads cannot duplicate waves or rewards.

The existing payout editor remains at `data/progression/end_run_payout_settings.tres`.
The debuff contribution is controlled by the run's `debuff_bonus_essence` and
is included in the normal death summary.
