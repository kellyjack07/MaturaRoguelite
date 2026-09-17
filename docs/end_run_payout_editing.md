# End-of-run Essence payout editing guide

The payout settings live in
`data/progression/end_run_payout_settings.tres`, using
`scripts/end_run_payout_settings.gd`. Edit the exported Resource values there;
the calculation is read-only and the player-facing summary displays only
category totals.

Accounting is stored in the active run snapshot in `scripts/main.gd`:

- `run_id` identifies one run for exactly-once crediting.
- `completed_levels` stores portal-confirmed level IDs and their first-clear
  classification.
- `regular_kills` and `boss_kills` are updated by the deduplicated enemy death
  path. Designated boss metadata controls classification; MonsterSlasher and
  summons remain regular kills.
- `payout_status` and `payout_result` make the death summary read-only after a
  successful save.

Permanent transaction state is in the meta progression save under
`credited_run_ids` and `last_run_result`. The fresh-profile default essence is
zero; existing balances are preserved by migration. The separate tutorial
grant remains owned by `SkillTreeService`.

The death summary is laid out in `scenes/main.tscn` under `UI/DeathScreen`.
Its summary and status labels are populated by `scripts/main.gd`. If the
transaction save fails, `RetryPayoutButton` remains available and no balance,
credited-run marker or retired-run state is committed.

The future debuff-room contribution is represented as a zero-valued
`debuff_essence` result field only; debuff choices and accrual are not
implemented here.
