# Lattice

Party and raid frames for WoW Forever (interface 16001): Grid-style indicators, an easy options window, click-casting, aura and dispel highlights, and profiles.

Written from scratch. It contains no code from Cell, Grid2 or any other addon and uses no third-party libraries.

## Use
- `/lattice` opens the settings. `/lattice unlock` lets you move the frames. `/lattice preview 20` shows fake frames.
- `/lattice probe` lists which unit values the game is hiding from addons right now.

## How it copes with Forever's secret values
- Health, heals, absorbs and range are passed straight to status bars, alpha and colour curves, so the addon never does math on them.
- Auras are drawn by Blizzard's `CustomAuraContainer`, which keeps working in combat.
- No restricted snippets are used. Buttons are created ahead of time, out of combat.

## First in-game checks
1. Log in and check the chat window for Lua errors. `/console scriptErrors 1` turns them on.
2. Run `/lattice probe` solo, then in a group, in combat, and inside a dungeon.
3. Check that auras show on frames: your own HoT, a debuff, and a dispellable debuff.
4. Click-cast a heal. Change a binding while out of combat.

## Tests
`python -P tests/run.py` loads the addon in Lua 5.1 against a fake WoW API whose secret values throw on misuse. It needs `pip install lupa`.
