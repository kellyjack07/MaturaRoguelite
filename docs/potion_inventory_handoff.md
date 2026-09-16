# Potion inventory and room-shop handoff

## Editing

- Potion IDs, names, descriptions, prices, and icons are centralized in
  `data/player/potion_catalogue.tres`.
- `STAMINA_BOTTLE_COST` remains the legacy constant for compatibility; the
  catalogue price is used by the unified Shop Room offers.
- The three fixed inventory IDs are `small_healing`, `big_healing`, and
  `stamina`. Capacity is one of each in `scripts/potion_inventory.gd`.
- `use_stamina_bottle` in `project.godot` is the named potion-use binding
  (currently F). `I` opens the paused inventory panel.
- Slot artwork and icon sizing are in `scripts/ui/potion_inventory.gd`; the
  equipped HUD slot is built in `scripts/ui/hud.gd`.

## Rules and integration

Rest Room offers are one-choice-only: free instant 20% healing, small healing
potion for 3 gold, or big healing potion for 5 gold. Rest bonuses and
penalties affect only the free instant heal. Shop Room offers have independent
stock for small, big, and stamina potions; different offers can all be bought,
and stock is stored in the room record.

`Main` is the authority for funds, room stock, healing, potion use, equipment,
and save rollback. The inventory component stores only quantities and the
equipped ID; `StaminaComponent` stores stamina and boost state. A legacy
`stamina.bottle_count` is migrated once into the stamina inventory slot.
