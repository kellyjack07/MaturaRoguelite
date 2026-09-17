# Sorcerer summon effect

The Sorcerer's summon VFX is wired through
`effects/sorcerer_summon_effect.tscn` and is spawned once at every enemy spawn
location whenever the Sorcerer creates a summon wave. It does not affect
summon timing, enemy spawning, or combat.

## Edit the frames

Open:

`data/vfx/sorcerer_summon_effect_frames.tres`

Add the effect frames to the existing `summon` animation. The animation is
non-looping and uses 12 FPS by default. Each effect is placed at the matching
summoned enemy's spawn position and then frees itself after the animation
finishes.

The frame list is intentionally empty until the summon artwork is selected.
While it is empty, each reusable effect node stays alive briefly and then
removes itself, so the gameplay summon flow still works.

The one central runtime setting is `fallback_duration` on
`scripts/sorcerer_summon_effect.gd`; it only controls the empty-frame fallback
duration and does not change the Sorcerer's summon timing.
