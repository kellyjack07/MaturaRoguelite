# Player animation map

Verified against `assets/Character/Character Animations.aseprite` and `Character Animations-Sheet.png` on 2026-09-08. `tools/inspect_aseprite.ps1` is the reproducible read-only metadata inspector used for the source file.

## Atlas contract

- Source canvas/cell: 192×208 RGBA.
- Source frames: 160. Every frame duration in the Aseprite file is 100 ms.
- Exported sheet: 1728×5824, arranged as 9 columns × 28 tag rows.
- Rectangle formula: `Rect2(column * 192, row * 208, 192, 208)`.
- Each tag begins at column 0 of its row and proceeds left-to-right. Transparent cells after a tag are not frames.
- Side artwork is flipped for positive X in gameplay; this matches the project-facing convention requested during integration.
- The character's feet are consistently near source Y=133 (Y=132–135 while walking). The current scene transform, `AnimatedSprite2D.position = Vector2(0, -10)` with `scale = Vector2(0.7, 0.7)`, aligns the rendered feet with the player's collision footprint. The spear tip extends below this line in its held idle and is not used as the anchor.

## Source tags and gameplay mapping

All source tags use forward playback and 100 ms frames. Idle/walk clips loop in gameplay; attacks, specials, dash, hurt and death are one-shots.

| Row | Aseprite tag | Source frames | Gameplay animation | Use / active artwork |
|---:|---|---:|---|---|
| 0 | `Hammer_Idle_Front` | 0–7 | `idle_down_hammer` | Hammer down idle |
| 1 | `Sword_Idle_Front` | 8–16 | `idle_down_sword` | Sword down idle |
| 2 | `Spear_Idle_Front` | 17–25 | `idle_down_spear` | Spear down idle |
| 3 | `Idle_Side` | 26–34 | `idle_side` | Shared side idle; flip for positive X |
| 4 | `Idle_Front` | 35–43 | `idle_down` | Shared down fallback; weapon-specific down idles take priority |
| 5 | `Idle_Back` | 44–52 | `idle_up` | Shared up idle |
| 6 | `Hammer_Attack_Side` | 53–56 | `attack_side_hammer` | Contact shown in tag frames 1–2; one pulse at 0.20 s |
| 7 | `Hammer_Special_Attack` | 57–64 | `special_hammer` | Direction-independent ground slam; radial pulse at 0.35 s |
| 8 | `Hammer_Attack_Front` | 65–68 | `attack_down_hammer` | Down strike; pulse at 0.20 s |
| 9 | `Hammer_Attack_Back` | 69–72 | `attack_up_hammer` | Up strike; pulse at 0.20 s |
| 10 | `Sword_Attack_Front` | 73–77 | `attack_down_sword` | Down sweep; artwork active across tag frames 1–3, damage pulse at 0.20 s |
| 11 | `Sword_Special_Attack` | 78–81 | `special_sword` | Direction-independent spin; radial pulse at 0.15 s |
| 12 | `Sword_Attack_Back` | 82–85 | `attack_up_sword` | Up sweep; pulse at 0.20 s |
| 13 | `Spear_Attack_Front` | 86–88 | `attack_down_spear` | Down thrust; pulse at 0.10 s |
| 14 | `Spear_Back` | 89–91 | `attack_up_spear` | Up thrust; source tag omits “Attack”; pulse at 0.10 s |
| 15 | `Spear_Attack_Side` | 92–94 | `attack_side_spear` | Side thrust; flip for positive X; pulse at 0.10 s |
| 16 | `Spear_Special_Attack` | 95–101 | `special_side_spear` | Side multi-thrust; flip for positive X; pulses at 0.20/0.35/0.50 s |
| 17 | `Spear_Special_Attack_Front` | 102–108 | `special_down_spear` | Down multi-thrust; pulses at 0.20/0.35/0.50 s |
| 18 | `Spear_Special_Attack_Front` | 109–115 | `special_up_spear` | Visually the up/back multi-thrust despite the duplicate source tag name |
| 19 | `Turn_Table` | 116–119 | not imported | Artist turn-table/reference sequence; not a gameplay action |
| 20 | `Walk_Front` | 120–125 | `walk_down` | Shared down walk |
| 21 | `Walk_Back` | 126–131 | `walk_up` | Shared up walk; corrected to source left-to-right order |
| 22 | `Walk_Side` | 132–136 | `walk_side` | Shared side walk; flip for positive X |
| 23 | `Dash_side` | 137–140 | `dash_side` | Shared side dash; flip for positive X |
| 24 | `Dash_Front` | 141–144 | `dash_down` | Shared down dash |
| 25 | `Dash_Back` | 145–148 | `dash_up` | Shared up dash |
| 26 | `Hurt` | 149–152 | `hurt` | Shared reaction; one-shot |
| 27 | `Death` | 153–159 | `death` | Shared death; player death completes after the seventh frame |

## Explicit fallbacks and gameplay adjustments

- Asset fact: there is no sword side-attack tag. `basic_side` intentionally uses `attack_down_sword`; the empty editor animation was removed so no mapped action can play an empty frame list.
- Asset fact: weapon-specific held poses exist only for front/down idle. Side/up idle, all walking, dash, hurt and death use the supplied shared sequences.
- Asset fact: hammer and sword specials have no directional variants. Their circular hit shapes match the visible radial artwork.
- Gameplay adjustment: the four 100 ms dash frames play at about 2.67× speed so the artwork spans the existing 0.15 s dash duration. Source timing remains 10 fps in `SpriteFrames`; only dash playback is scaled.
- Gameplay choice: movement damage multiplier is sampled once at attack start and remains fixed for that attack, including a dash attack.
