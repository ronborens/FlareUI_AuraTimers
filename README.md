# FlareUI: Buff & Debuff Timers

Shows how long your buff or debuff has left, right on the action button that cast it.

While a spell's effect is up, its button shows the time left in gold in place of the cooldown number, with a gold sweep and the stack count. When the effect ends, the normal cooldown comes back.

- Your buffs, such as Bloodrage or Lightning Shield (with its charges)
- Your debuffs on your current target, such as Flame Shock
- Only your own effects count
- Works in combat

## Options

The options appear inside FlareUI's own settings window. You can also type `/flaretimers`, or open the game's Options > AddOns.

## Good to know

- A buff's timer starts showing after the first time you have that buff out of combat. Debuffs on your target work straight away.
- To keep it light, only buttons that can show a timer are watched: attack spells, and buff spells already seen to leave a buff on you.
- While the timer shows, it covers the button, so the out-of-range and out-of-mana tints are hidden on that button until the effect ends.

## Install

1. Download the latest zip from this project's [Releases](https://github.com/ronborens/FlareUI_AuraTimers/releases).
2. Extract it into your game's `Interface/AddOns` folder, so that `FlareUI_AuraTimers` sits beside `FlareUI`.
3. Restart the game.

To run it straight from the source, clone this repository into `Interface/AddOns` as `FlareUI_AuraTimers`.

## Problems and ideas

Please open an [issue](https://github.com/ronborens/FlareUI_AuraTimers/issues) and say which FlareUI version you have.

## Requirements

- [FlareUI](https://www.curseforge.com/wow/addons/flareui) must be installed and enabled.

This is an unofficial extension. It is not made or endorsed by the FlareUI authors, so please report problems here and not to them. MIT licensed.
