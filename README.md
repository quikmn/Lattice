# Lattice: Party & Raid Frames

Party and raid frames for WoW Forever (interface 16001): Grid-style indicators, an easy options window, click-casting, aura and dispel highlights, and profiles.

Written from scratch. It contains no code from Cell, Grid2 or any other addon and uses no third-party libraries.

## Use
- `/lattice` opens the settings. `/lattice unlock` lets you move the frames. `/lattice preview 20` shows fake frames.
- `/lattice probe` lists which unit values the game is hiding from addons right now.
- `/lattice status` shows why frames or auras are or aren't showing.
- `/lattice tank <name>`, `/lattice notank <name>`, `/lattice autotank <name>` fix the tank guess for a player; `/lattice tanks` lists who counts as tank.
- `/lattice show <spell>`, `/lattice hide <spell>`, `/lattice unlist <spell>` edit the aura filters (name or spell ID).
- Ctrl+Alt+Right-click a frame: tank choice for that player and a picker for their auras.

## Features
- Party, raid and large-raid layouts that switch automatically. Pet frames in their own movable block (Layout page).
- Click-casting on frames: mouse buttons 1-5 with Shift, Ctrl and Alt.
- Hover-casting: bind a key to a spell and it casts on whoever the mouse is over, optionally falling back to your friendly target. It never falls back to you.
- Your HoTs and buffs, debuffs, dispel highlight, boss debuff and big defensives. Grid-style spell indicators, plus one-click presets for your class.
- Incoming heals, shields, range fade, role, leader, raid marker, ready check, resurrect and summon icons. Dead players tint red, offline players grey.
- Profiles per spec, import and export.
- Tank guessing when the group has no roles, power bars by power type and role, and aura filters (always show / never show).

## 0.4.5 (2026-11-15)

- Long debuffs nobody can dispel (over 10 minutes, like Boosted Rest from a camp tent) are hidden by default. The game doesn't let addons hide other players' debuffs by spell, so this goes by type and length: magic, curses, poisons and diseases always show. Turn it off under Auras: "Hide long debuffs".

## 0.4.4 (2026-11-15)

- Never shown by default: tracking (Find Herbs, Find Minerals, Find Treasure, Find Fish, Track Beasts and Humanoids, Sense Demons and Undead), Might of Stormwind and Boosted Rest. Change it on the Aura filters page.

## 0.4.3 (2026-11-15)

- Fix: an error at login ("Button.lua:272: attempt to index local 'v'") that stopped the frames from loading, when the game had made a party frame Lattice hadn't set up yet.

## 0.4.2 (2026-11-15)

- Buff icons skip long buffs (over 5 minutes, like Fortitude or Mark of the Wild) by default, so your HoTs and shields stand out. Turn it off under Auras: "Hide long buffs". Spells on your always-show list still show.

## 0.4.1 (2026-11-14)

- The party frames can be dragged like raid and pets: grab the box anywhere, even over the frames, and it covers a whole party when you're alone.

## 0.4.0 (2026-11-14)
- **Tank guessing.** With no roles set, Lattice picks the tank from the raid's main tank mark, Defensive Stance, Bear Form and Righteous Fury. In a group of five it picks one player, or the only Warrior. The guessed tank gets the tank icon. Fix a wrong guess with Ctrl+Alt+Right-click or `/lattice tank`, `notank`, `autotank`. Can be turned off on the General page.
- **Power bars by type and role.** Energy is hidden (rogues, druids in Cat Form), rage shows only for tanks (warriors, druids in Bear Form), mana shows for everyone. Druids switch as they shift. Change it per power type on the Appearance page.
- **Aura filters.** A new Aura filters page: always show or never show buffs and debuffs by name or spell ID, with Classic defaults (Power Infusion, Innervate, Blessing of Protection and Soulstone always shown; Clearcasting, Flurry, Enrage and other short procs hidden). Import and export as plain text. Ctrl+Alt+Right-click a frame to pick from that player's auras. The game only lets addons pick out a few debuffs on friendly players by ID, so for most debuffs these filters have no effect; buffs always work.
- **Polish.** Bars no longer sweep when a frame switches to another player. Heal and shield bars are smoothed too. New dispel style "Border and a light tint". Optional: no aggro border on tanks. Dropdowns and sliders grey out when they don't apply.
- **Fixes.** A ready check started within 6 seconds of the last one is no longer wiped. Dead and offline looks are refreshed only when that state changes, not on every health tick.

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
