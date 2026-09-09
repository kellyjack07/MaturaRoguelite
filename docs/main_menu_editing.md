# Main menu editing guide

The main menu has two central editing resources:

- `ui/themes/dungeon_theme.tres` controls shared appearance.
- `data/ui/main_menu_layout.tres` controls menu geometry and the placeholder title/background.

The reusable scene is `ui/main_menu_screen.tscn`, instanced at `Main/UI/MainMenuScreen` in `scenes/main.tscn`. The presentation controller is `scripts/ui/main_menu_screen.gd`; it applies the two resources and does not own gameplay actions.

## Shared appearance

Open `ui/themes/dungeon_theme.tres` in the Inspector:

- `Default Font` changes the font for labels and buttons together.
- `Default Font Size` changes the base size.
- `Button > Font Sizes > Font Size` changes ordinary button text.
- `Button > Colors > Font Color`, `Font Hover Color`, `Font Pressed Color`, `Font Focus Color`, and `Font Disabled Color` control button text. Keep these dark for contrast with the light background.
- `Button > Styles > Normal`, `Hover`, `Pressed`, `Focus`, and `Disabled` control the shared button backgrounds and focus outline. The normal and pressed styles use the supplied 16×16 sliced textures.
- `Label > Colors > Font Color` and `Label > Font Sizes > Font Size` control ordinary labels.
- The `MenuTitle` variation controls the title (`Font Sizes > Font Size` and `Colors > Font Color`).
- The `MenuStatus` variation controls the status/developer label.
- The `DeveloperButton` variation controls the smaller Reset Save text while inheriting the common button backgrounds.

Do not set a separate font, style, or text colour on individual menu buttons; the scene inherits this Theme from `MainMenuScreen`.

## Layout and text

Open `data/ui/main_menu_layout.tres` in the Inspector:

- `Placeholder Title` changes the title text.
- `Outer Margin` is a `Vector4` in logical viewport pixels, ordered `left, top, right, bottom`.
- `Button Width` changes every menu button together.
- `Button Min Height` changes every menu button together.
- `Button Gap` changes the gaps in the primary stack and the separation before Reset Save.
- `Title Gap` changes the space between title and status.
- `Status Gap` changes the space between status and the primary buttons.
- `Background Color` changes the full-screen muted background.

The menu starts at the upper-left with the default 640×360 viewport margins and scrolls vertically if the font or layout values make the content taller than the available area. Continue is hidden by gameplay when no resumable save exists; its `VBoxContainer` slot collapses automatically.

## Scene structure

In `ui/main_menu_screen.tscn`, the editable paths are:

- `MainMenuScreen/Background`
- `MainMenuScreen/ContentScroll/Content/TitleLabel`
- `MainMenuScreen/ContentScroll/Content/MenuStatusLabel`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons/ContinueRunButton`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons/StartRunButton`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons/GearStoreButton`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons/SettingsButton`
- `MainMenuScreen/ContentScroll/Content/PrimaryButtons/QuitButton`
- `MainMenuScreen/ContentScroll/Content/ResetSaveButton`

Keep the button names and order stable unless the matching paths and signal connections in `scripts/main.gd` are updated together. Main owns `start_new_run`, `continue_saved_run`, `open_gear_store`, `open_settings_from_main_menu`, `reset_all_save_data`, and `save_and_quit_game`.
