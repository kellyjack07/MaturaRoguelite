# HUD editing

The reusable scene is `ui/hud.tscn`, instanced as `Main/UI/HUD`. Its presentation-only controller builds the component children in the editor and at runtime. Change shared settings rather than editing generated children.

## Two editing resources

- `ui/themes/dungeon_theme.tres`: Default Font changes the font shared with the menus. `HUDText` controls HUD font size, light text colour and dark outline. `HUDPanel` controls content padding without changing menu panels. Its style geometry is shaded by the glass material instead of drawing a solid panel.
- `data/ui/hud_layout.tres`: Margin sets screen clearance; Gap sets internal spacing; Health Width and Weapon Width are minimum panel widths; Artwork Scale uses integer scaling; Minimap Size controls map space; Map Room Size caps room squares. Current/Visited/Unknown/Connector Color control minimap states. Changes update the scene preview. Text may grow panels beyond their configured minimum size.

The screen uses logical pixels in the project's existing 640x360 viewport. The normal 1280x720 window displays these at double size. Keep reasonable sizes so HUD panels leave space for gameplay. The stage drops below the upper panels if larger text would overlap; the map drops below health if they collide. This is not an unlimited-size UI: very large settings can consume the gameplay area.

## Blur and run atmosphere

- `ui/themes/hud_glass.tres`: shared Blur Radius (logical pixels) and Darkening for all HUD backings. The screen is copied once before the HUD; only the small panel regions use a nine-sample blur. Text and artwork stay sharp. Menu panels are unaffected.
- `data/ui/run_atmosphere.tres`: Deep Color, Cloud Color, Speed and Scale control the procedural blue-black moving background. No image assets or noise textures are needed. The background lives on CanvasLayer -100, below rooms, enemies and player. It is screen-fixed, visible during runs, hidden in the main menu/death screen and frozen while paused. Existing floor/wall artwork is unchanged.

Changing these materials in the Inspector adjusts the appearance centrally; no edits to each panel or room are required. Restart the run to apply changes to the atmosphere's per-instance material copy.

## Artwork and status

`scripts/ui/hud.gd` references the supplied HUD frame, health texture and ability border once. The portrait frame is cropped from the player-info asset at Rect2(0, 0, 42, 44), omitting the unused energy tracks. Its interior is intentionally a portrait placeholder. Weapon names remain text placeholders; no invented weapon icons are used.

Health shows current/max HP and a clamped fill. Gold is run currency. Special status reads the player's real cooldown, unlock/developer state and the current `special_attack` binding. It refreshes at 10 Hz while visible and freezes with gameplay when paused. The cooldown bar fills towards readiness. No HUD code changes player stats, currency or saves.

The minimap uses only discovered room bounds. Current room is outlined/highlighted, visited rooms remain visible, adjacent rooms show their types, and earlier revealed unvisited rooms become `?` outside current adjacency. Undiscovered rooms and their connections are not drawn. Type labels are omitted when cells are too small to fit them. Existing world interaction prompts are unchanged.

Enable `Show Debug Overlay` on the HUD instance to show movement state, multiplier and last damage in debug builds; it defaults off. HUD controls ignore mouse input. The HUD sits behind pause/reward panels and is hidden for main menu, death and stage transitions.

## Verification

Godot 4.6 runtime tests: HUD smoke test, existing skill-tree smoke test and player-weapons smoke test (with `-- --isolated`) passed. The HUD test uses a main-script subclass with in-memory saving and never touches the real save. Coverage includes health/gold, cooldown/locked states, pause, map discovery, larger fonts, input passthrough and menu/death visibility. A rendered 640x360 HUD screenshot was inspected using the Compatibility renderer; normal window scaling is retained.

Run `--headless --path . --script tests/hud_smoke_test.gd` for the HUD regression check. Add `-- --capture` in a non-headless run to save a preview under `.godot/hud-preview.png`. The capture uses synthetic map data and in-memory progress. Runtime tests do not replace a final hands-on readability check on your display, especially after changing layout dimensions or fonts.
