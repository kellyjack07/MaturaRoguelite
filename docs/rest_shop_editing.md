# Rest Room

Rest rooms no longer heal on entry. Interact with their chest using E, then choose one potion: small is free and heals 20% of maximum health; big costs 5 gold and heals 50%. Percentage healing rounds up before the existing flat rest bonus/penalty, then clamps to missing health. Either choice consumes the chest. Closing leaves it available; full health or zero healing cannot consume it.

## Editing

- `data/ui/rest_shop_settings.tres`: Small Heal Fraction, Big Heal Fraction and Big Cost. These are the authoritative gameplay values.
- `data/ui/rest_shop_layout.tres`: Panel Width, Margin, Gap, Potion Scale, Animation FPS and Chest Offset. Reopen/restart the scene after editing. Content scrolls when fonts or spacing exceed the viewport.
- `ui/themes/dungeon_theme.tres`: shared font and buttons; `RestShopText` controls the shop label size without changing other screens.
- `data/ui/rest_chest_frames.tres`: editable shared SpriteFrames for closed/opening/open. The first chest row uses five 32x32 regions at y=128 in the supplied doors/lever/chest sheet. Opening is non-looping, 8 FPS; the final pose stays open after consumption. Each rest-room instance exposes an AnimatedSprite2D at RewardInteractable/RestChest in the Remote scene tree.
- `scripts/ui/rest_shop.gd`: supplied image references and atlas dimensions. Small vial frames are 14x24 (9 frames); round potion frames are 19x38 (15 frames). The source sheets are rectangular, so square slicing would mix neighbouring frames. Title uses 32-pixel horizontal caps; panel uses 12-pixel border slices.

The reusable screen is `ui/rest_shop.tscn`. Main owns `get_rest_shop_offer(room_id, potion)` and `select_rest_shop_offer(room_id, potion)`. UI cannot independently spend gold or grant healing. A failed save rolls back health, gold and completion; successful selection saves immediately. Existing completed rest rooms stay consumed, including older saves. Incomplete rooms can use the shop even if an old initialized flag is set.

Gameplay pauses while the shop is open; potion previews and chest opening continue. Escape/Close restore the prior pause state. The modal does not appear in the pause menu, and no shields or inventory were added.

## Verification

`tests/rest_shop_smoke_test.gd` uses in-memory save isolation. It checks percentage rounding, modifiers, unaffordable/zero-healing purchases, closing/Escape, both choices, repeated selection, failed-save rollback and consumed state after continue. Run with Godot `--headless --path . --script tests/rest_shop_smoke_test.gd`. A non-headless run with `-- --capture` writes `.godot/rest-shop-preview.png` for visual inspection without accessing the real save.

The supplied sprites and panel were visually checked in Godot's Forward+ renderer at the existing 640x360 viewport. No normal user save is modified by the tests.
