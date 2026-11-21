# Lattice: Party & Raid Frames

Party and raid frames for WoW Forever (interface 16001): Grid-style indicators, an easy options window, click-casting, aura and dispel highlights, and profiles.

Written from scratch. It contains no code from Cell, Grid2 or any other addon and uses no third-party libraries.

## Use
- `/lattice` opens the settings. `/lattice unlock` lets you move the frames. `/lattice preview 20` shows fake frames.
- `/lattice probe` lists which unit values the game is hiding from addons right now.
- `/lattice status` shows why frames or auras are or aren't showing.
- `/lattice tank <name>`, `/lattice notank <name>`, `/lattice autotank <name>` fix the tank guess for a player; `/lattice tanks` lists who counts as tank.
- `/lattice feedback` (or the Feedback button in the settings) shows a link for reporting bugs and ideas.
- `/lattice ai` (or the AI help button in the settings) shows a description of every setting to paste into Claude or another AI with what you want; paste its answer into `/lattice apply`, which shows each change before applying it. Changes made in combat apply when combat ends.
- `/lattice <setting> <value>` changes one setting from chat (`/lattice get` lists them), e.g. `/lattice layouts.raid.width 90`.
- `/lattice show <spell>`, `/lattice hide <spell>`, `/lattice unlist <spell>` edit the aura filters (name or spell ID).
- `/lattice search <words>` opens the settings with the search box filled; `/lattice version`; `/lattice help` (or `?`) lists every command, and a mistyped one suggests the nearest. `/lat` works as well as `/lattice`; the commands follow the same pattern as every EverlookDB addon.
- Ctrl+Alt+Right-click a frame: tank choice for that player and a picker for their auras.

## Features
- Party, raid and large-raid layouts that switch automatically. Pet frames in their own movable block (Layout page).
- Click-casting on frames: mouse buttons 1-5 with Shift, Ctrl and Alt.
- Hover-casting: bind a key to a spell and it casts on whoever the mouse is over, optionally falling back to your friendly target, then to you (friendly spells only; on for new keys, a switch per key, and "New keys cast on me" sets where it starts).
- Your HoTs and buffs, debuffs, boss debuff and big defensives, with optional seconds-left numbers. Grid-style spell indicators, plus one-click presets for your class.
- Dispel highlight: a big icon of a debuff you can remove in the middle of the frame, edged in its type's colour, plus an optional coloured border or tint.
- Raid buffs in a row beside each frame, and a mark on players missing your class's buff.
- Incoming heals, shields, low health warning, range fade (by your heal's range), role, leader, raid marker, ready check, resurrect and summon icons. Dead players tint red, offline players grey.
- Tank frames with each tank's target, in raids.
- Profiles per spec (on clients with specs), and one string to share your whole setup.
- Tank guessing when the group has no roles, power bars by power type and role, and aura filters (always show / never show).

## Changes

What's new in each version: [CHANGELOG.md](CHANGELOG.md).

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

## Install
WowUp: pick **World of Warcraft: Forever**, then Get Addons → Install from URL, and paste `https://github.com/quikmn/LatticePartyRaidFrames`.

By hand: download the latest zip from Releases and unzip it into `World of Warcraft\_forever_\Interface\AddOns`.

## License

GPL-3.0-or-later (see LICENSE). Not affiliated with Blizzard Entertainment.
