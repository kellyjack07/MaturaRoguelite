# Regular button background editing

All regular rectangular text-button backgrounds are centrally controlled by
these shared StyleBox resources:

- `ui/themes/styles/regular_button_normal.tres`
- `ui/themes/styles/regular_button_hover.tres`
- `ui/themes/styles/regular_button_pressed.tres`
- `ui/themes/styles/regular_button_disabled.tres`
- `ui/themes/styles/regular_button_focus.tres`

`ui/themes/dungeon_theme.tres` uses these styles for the main menu and skill
tree. `ui/themes/regular_button_theme.tres` references the same resources for
settings, pause, death, room events and the developer weapon screen. The
dynamic weapon-selection buttons inherit that theme from the developer screen
root. No font, colour or font-size settings are duplicated in the button-only
theme.

The normal, hover, pressed and disabled backgrounds use a 3-pixel texture
margin on each side. The source textures are the normal and pressed assets in
`assets/UI/Tiny Dungeons - UI Pack/components/`. Their interiors stretch to
the button rectangle while their borders remain fixed. In Godot's
`StyleBoxTexture.AxisStretchMode`, `0` is stretch, `1` is tile and `2` is
tile-fit; the shared styles intentionally use `0` so regular buttons do not
repeat the entire texture. The project keeps nearest texture filtering for
the pixel-art assets.

Edit the `.tres` files above when changing button backgrounds, border margins,
hover/disabled tint or focus outline. Keep labels, font settings, dimensions,
signals and actions in their existing scenes/scripts. Graphical skill-tree
nodes remain governed by their `SkillNode`, `SkillNodeAvailable`,
`SkillNodePurchased` and `SkillNodeLocked` theme variations and are excluded
from this regular-button replacement.
