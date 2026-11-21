# FlareUI: Buff & Debuff Timers

An extension for the FlareUI interface that puts your buff and debuff timers directly on your action buttons, so you can see how long an effect has left without looking away from your bars.

## What it does

In the base game, an action button only tells you when a spell is ready to cast again. It does not tell you how long the effect you just cast will last. To know when Flame Shock is about to fall off your target, or how many Lightning Shield charges you have left, you have to look at the small buff and debuff icons somewhere else on the screen.

With this addon, the button itself shows it:

- **Time left, in gold.** While the spell's effect is active, the button shows the remaining time in gold in the middle of the button, in place of the usual cooldown number.
- **A gold sweep.** A gold clock-style sweep drains over the button as the effect runs out, so you can read it at a glance.
- **Stacks and charges.** If the effect has stacks or charges, the count shows in the corner of the button.
- **Back to normal afterwards.** The moment the effect ends, the button shows its normal cooldown again.

It works the same way as Blizzard's Cooldown Manager, but on the action bars you already use.

## Examples

- **Shaman:** cast Flame Shock and its button counts down the debuff on your target, so you know exactly when to reapply it. Lightning Shield shows its time left and its remaining charges.
- **Warrior:** press Bloodrage and the button shows how long the rage generation lasts before showing the cooldown.
- **Any class:** any spell on your bars that leaves a buff on you, or a debuff of yours on your target, gets a timer.

## How it changes your play

- You keep your eyes on your action bars and your target instead of hunting through rows of small icons.
- You reapply damage-over-time effects at the right moment instead of too early or too late.
- You notice a self-buff is about to run out because the button you would press to renew it is the one counting down.

## Details

- **Your effects only.** It shows buffs on you and debuffs that you put on your current target. Other players' effects are ignored.
- **Works in combat.** The timers keep running and updating during fights.
- **Light on performance.** Only buttons that can show a timer are watched: attack spells, and buff spells already seen to leave a buff on you.
- **Buffs are learned once.** A buff's timer starts showing after the first time you have that buff out of combat. Debuffs on your target work straight away.
- **One limit.** While a timer is showing it covers the button, so the red "out of range" and blue "out of mana" tints are hidden on that button until the effect ends.

## Options

The options appear inside FlareUI's own settings window, under Action Bars > Button Appearance. You can also type `/flaretimers`, or open the game's Options > AddOns.

- **Buff & Debuff Timers:** on or off.
- **Timer Colour:** pick your own colour for the sweep and the time. Gold by default.
- **Timer Number Same as Cooldowns:** draw the time in the colour your cooldown numbers have, instead of the Timer Colour.
- **Timer Sweep Same as Cooldowns:** use the dark sweep every cooldown has, instead of the Timer Colour.
- **Timer Sweep:** show or hide the sweep.
- **Timer Time Left:** show or hide the time in the middle of the button.
- **Timer Stack Count:** show or hide the stacks or charges in the corner.

## Install

1. Download the latest zip from this project's [Releases](https://github.com/ronborens/FlareUI_AuraTimers/releases).
2. Extract it into your game's `Interface/AddOns` folder, so that `FlareUI_AuraTimers` sits beside `FlareUI`.
3. Restart the game.

To run it straight from the source, clone this repository into `Interface/AddOns` as `FlareUI_AuraTimers`.

## Turning the timer off for one spell

Some spells leave an effect that is not worth a timer, and the timer would cover the cooldown you do want to see. You can switch the timer off spell by spell:

- `/flaretimers ignore Stormstrike` turns the timer off for that spell. Its button shows the cooldown as usual.
- `/flaretimers unignore Stormstrike` brings the timer back.
- `/flaretimers ignored` lists the spells with no timer.
- `/flaretimers tracked` lists the spells on your bars that can show a timer, with their exact names.

Stormstrike starts out ignored. The list is saved for your whole account.

## Problems and ideas

Please open an [issue](https://github.com/ronborens/FlareUI_AuraTimers/issues) and say which FlareUI version you have.

## Requirements

- [FlareUI](https://www.curseforge.com/wow/addons/flareui) must be installed and enabled.

This is an unofficial extension. It is not made or endorsed by the FlareUI authors, so please report problems here and not to them. MIT licensed.
