# Shop and potion HUD editing

- Shop and Rest Room now share `scripts/ui/rest_shop.gd` and its existing scene. Room type selects the visible offers; shops stay open for multiple purchases.
- Change shared panel width, gaps and preview scale in `data/ui/rest_shop_layout.tres`. The default panel width is 480 logical pixels for three cards.
- Shop prices, descriptions and artwork definitions are in `data/player/potion_catalogue.tres`. Rest purchases also read catalogue prices.
- Change the equipped HUD slot size and icon inset through `data/ui/hud_layout.tres`: `potion_slot_size` and `potion_icon_padding`. Shared font remains in the dungeon Theme.
- Shop stock is initialized for new floors, saved per offer, and never reset on reopening. A partial purchase keeps the chest open; sold-out completion is saved with the final purchase.
- The shared UI calls `get_shop_potion_offer(room_id, potion_id)` and `select_shop_potion(room_id, potion_id)`. Purchase validation requires the matching open shop. Save failure rolls back inventory, gold, stock and completion.
- Regression tests: `tests/shop_ui_smoke_test.gd`, `tests/rest_shop_smoke_test.gd`, `tests/hud_smoke_test.gd`. They use isolated in-memory saves. Shop test accepts `-- --capture` for rendered previews under `.godot`.
