# Luna Implementation Prompt: Editable Main Menu

Implement the main-menu presentation described below in the existing Godot project. Read current files before editing, preserve user changes, and complete implementation and proportional verification. This handoff was prepared from the current menu and supplied assets; gameplay has not been changed by the planning pass.

## Outcome and scope

Create a simple pixel-art main menu with a placeholder title and a compact vertical button stack in the upper-left portion of the viewport. The supplied INMOST screenshot is a composition reference: title above the buttons, ample free space to the right. Do not reproduce its logo, forest artwork, letterboxing or bottom line. Use the user's supplied button textures, black text and font. A plain light muted background is sufficient until background artwork is provided.

Only restyle the main menu. Preserve navigation into the existing gear store/skill tree and settings. Do not restyle those screens, the pause screen or HUD in this task. Do not change combat, progression, save behaviour or input bindings unrelated to menu focus.

The most important requirement is editability: font, text sizes, colours and button styling must each have one source of truth. Button dimensions, gaps and position must also have one source of truth. No repeated per-button font/size/style overrides or manually positioned buttons.

## Verified inputs

- Font: `res://assets/UI/enter-the-gungeon-big.ttf`
- Component directory: `res://assets/UI/Tiny Dungeons - UI Pack/components/`
- Normal button: `component_3slices_button.png`
- Pressed button: `component_3slices_button_pressed.png`
- Green/red variants exist but are not needed for the default main buttons.
- The normal and pressed assets were visually inspected: they are small pixel-art button tiles, intended to be stretched with preserved edges.
- Current main menu: `UI/MainMenuScreen` inside `scenes/main.tscn`.
- Current coordinator: `scripts/main.gd`.
- Current game viewport is 640x360, normally displayed at 1280x720. Recheck project.godot before choosing dimensions.

Inspect actual PNG dimensions and border pixels before selecting stretch margins. Use existing assets without repainting or overwriting them. No external asset purchases or plugins are needed.

## Two editing locations

### 1. Shared appearance: `ui/themes/dungeon_theme.tres`

Create a reusable Godot Theme resource. Apply it only to the main menu for now so other screens retain their current appearance. Future screens should be able to opt in to the same resource.

Store the font and default font size here. Configure black text for labels and button states, including hover, pressed, focus and disabled states. Define reusable title and status Label theme variations for their font sizes, without repeating font files on individual controls. The title should inherit the same font.

Use StyleBoxTexture resources for normal/hover/pressed/disabled button backgrounds, with slice margins derived from the actual asset. Preserve borders and stretch only appropriate interior regions. Since the asset is named three-slice, inspect how to handle vertical resizing without distorting its pixel borders; verify both width and height changes visually. Do not set a texture on each button separately.

Normal and pressed states must use the supplied textures. Hover can reuse normal with a subtle centrally configured modulation. Focus needs a clearly visible outline or equivalent indicator that does not rely on text changing from black. Disabled buttons must also look distinct through the background. Keep text readable on every state. Configure padding/content margins centrally in these styles.

Use nearest texture filtering for the menu artwork. Inspect font rendering at actual game scale; do not apply broad project import/render changes just to style this screen. Avoid fractional Control.scale hacks.

### 2. Menu layout: `data/ui/main_menu_layout.tres`

Define a small custom Resource in `scripts/ui/main_menu_layout.gd`. Suggested fields:

- `placeholder_title`: default `Matura Roguelite`.
- `outer_margin`: initial left/top inset around 48/28 logical pixels, with adequate right/bottom clearance.
- `button_width`: initial 180 logical pixels.
- `button_min_height`: initial 28 logical pixels; grow if font/content requires more.
- `button_gap`: initial 6 logical pixels.
- `title_gap`: initial 12 logical pixels.
- `status_gap`: initial 8 logical pixels.
- `background_color`: a light muted neutral/blue-grey that supports black title/status text.

These are starting values; adjust after visual verification. Keep all font and text-colour settings in the Theme, not duplicated here. Document whether spacing uses a Vector4, individual margins or another inspector-friendly type.

The menu controller applies these layout values consistently. Editor preview should work when editing the resource, ideally with a small @tool controller that listens to the Resource's changed signal. Implement Resource setters/emit_changed if necessary. Tool-mode code must only update presentation: never load saves, purchase upgrades or invoke game actions in the editor. Keep the controller simple and guard node access during initialization.

## Scene and integration

Prefer a reusable `ui/main_menu_screen.tscn` with controller `scripts/ui/main_menu_screen.gd`, instanced at the existing `UI/MainMenuScreen` location. Use a full-rect background, margins, optional vertical scrolling for overflow, a vertical content layout, title, button column and wrapped status label. Keep the column on the left, not centred over the whole viewport. Centre text inside the buttons.

Button order:

1. Continue Run (shown only when a resumable run exists).
2. Start Run.
3. Gear Store (existing skill-tree entry).
4. Settings.
5. Quit Game.

Keep Reset Save accessible as a separated, smaller developer control beneath the main group. Preserve its existing visibility and reset behaviour; do not execute it during testing against the user's real save. Its separation can use a theme variation/layout grouping, not repeated ad hoc overrides.

Continue's visibility must collapse layout space automatically. Preserve the status text supplied by gameplay, wrapping it within the column and using a smaller theme-defined size. Replacing the obsolete 'Placeholder main menu' status sentence with concise wording is allowed, without changing save logic.

Current main.gd refers directly to MainMenuScreen/MenuStatusLabel, ContinueRunButton and ResetSaveButton, and directly connects StartRunButton, ContinueRunButton, GearStoreButton, SettingsButton, ResetSaveButton and QuitButton. Reparenting requires updating all these references and connections together. Search for all uses rather than assuming the initial list is exhaustive.

Prefer a small explicit menu API/signals for navigation plus setters for saved-run availability and status text. Keep gameplay callbacks in main.gd. Alternatively use stable scene-unique references/accessors if simpler for the existing code. Do not have both old and new signal connections fire the same action twice.

Preserve existing actions:

- start_new_run
- continue_saved_run
- open_gear_store
- open_settings_from_main_menu
- reset_all_save_data
- save_and_quit_game

Do not create duplicate gameplay implementations in the menu script. Preserve save-and-quit semantics and skill-tree eligibility commits. Do not modify any saved data simply by opening the menu.

## Input and resizing

Set decorative background/labels to ignore mouse input where appropriate; they must not obscure clickable controls. Buttons must accept mouse and keyboard focus. Initial focus goes to Continue if available, otherwise Start Run. Refresh focus when returning from settings/store or when visibility changes; do not steal focus every frame.

Keyboard navigation must follow visible button order, skip hidden/disabled controls and keep a focused control visible if scrolling is necessary. Existing keyboard activation must work. Menu clicks/keys must not trigger gameplay behind the screen.

Use containers and anchors. If enlarged font, taller buttons or a smaller viewport cause overflow, grow the content and scroll rather than clip controls or overlap them. Do not force a fixed button height below the font's minimum. Larger widths must remain within viewport margins. Preserve project viewport, camera and stretch configuration.

## Workflow

1. Read main.gd menu methods, main.tscn, project.godot and applicable instructions; inspect textures/font.
2. Create the shared Theme and layout Resource.
3. Build the reusable menu scene and minimal presentation controller.
4. Connect the existing main.gd actions/state, removing obsolete menu nodes/connections only where replaced.
5. Validate behaviour, sizing, input and editor editability.
6. Create `docs/main_menu_editing.md` with exact inspector paths/properties for changing font, text size/colour, button styling, button size, spacing, title and background.

## Acceptance checks

- Every main-menu button uses the supplied font and common textured styling, with black text.
- A single Theme font change updates the whole menu; title/status inherit the font too.
- A single layout width/height/gap change affects every primary button.
- Font size can be increased without clipped labels, overlapping controls or an inaccessible Quit button.
- The layout resembles the reference's upper-left arrangement with a placeholder title and open right-hand area.
- Normal, hover, pressed, focused and disabled states remain recognisable and readable.
- Continue is hidden with no save and works with a save; Start, Gear Store, Settings, Back-to-menu and Quit retain existing behaviour.
- Verify destructive actions using isolated test data or signal checks, never deleting/overwriting the user's real save.
- Editor preview and runtime agree. Check logical 640x360 layout and the normal 1280x720 window, plus a larger window and increased text size.
- Existing skill-tree, gameplay and pause screens are not unintentionally restyled.
- Godot imports/parses the changes without errors. Run available focused smoke checks and visually inspect the menu if tools allow. Report actual checks and any manual testing still needed.

Deliver only this main-menu implementation and editing guide. Summarize the two central editing resources, preserved actions and verification results. Do not claim visual testing if it was unavailable.
