# Mushroom spell projectile

The Mushroom uses `prepare`, `attack_loop`, and `attack_fire` in that order.
The projectile is created when `attack_fire` starts and uses the reusable
`enemies/mushroom_spell_projectile.tscn` scene.

## Add projectile frames

Open:

`data/vfx/mushroom_spell_projectile_frames.tres`

Add the projectile frames to the existing looping `travel` animation. The
scene already uses `EnemyProjectile` for movement, lifetime, collision, and
damage; the SpriteFrames resource only controls its appearance.

The frame list is intentionally empty until the projectile artwork is added.
The projectile still follows the existing projectile logic while its visual
slot is empty.
