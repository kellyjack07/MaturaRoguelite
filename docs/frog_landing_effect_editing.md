# Frog landing effect

The landing effect is wired through `effects/frog_landing_effect.tscn` and is
spawned by `scripts/stage2_enemy.gd` when FrogMonster or FrogBoss completes a
jump.

To author the effect, open:

`data/vfx/frog_landing_effect_frames.tres`

Add the frames from:

`assets/ParticleEffects/Combat Effects – 2D Pixel Art VFX Pack 3/PNG/Effect (5)1.png`

Use the existing `landing` animation slot. The effect plays once and frees
itself after `animation_finished`; while the slot is empty it remains a safe,
short-lived invisible placeholder using the fallback duration in
`effects/frog_landing_effect.tscn`.
