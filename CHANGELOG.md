# Lattice Party & Raid Frames

## Unreleased
- Settings window: switches, buttons and sliders use a softer shade of the accent colour, an on switch has a dark knob so it stands out, and boxes have cleaner rounded edges.

## v0.7.1 (2026-11-18)

- Settings: an AI help button copies a description of every setting for an AI assistant, and `/lattice apply` runs the commands it gives back.

## v0.7.0 (2026-11-18)

- Chat commands now follow one pattern across all EverlookDB addons: `/lattice help` (or `?`) lists them in the same format as the others; `/lattice search <words>` opens the settings with the search box filled; `/lattice status` starts with the version; `/lattice version`; an unknown command suggests the nearest one instead of printing the whole list. Every old command (and `/lat`) still works.
- The settings window has a search box at the top: type to find any setting.

## v0.6.0 (2026-11-17)

- Hover-casting: each key now lets you choose who the spell is for (a friend, an enemy, or either), whether it falls back to your target, and whether it then falls back to you. Enemy keys list your damage spells. Existing keys keep working as before (friend, then target, never you).
- Hover-casting: the enemy spell list shows your harmful spells only (not mounts, tracking or professions); changing who a key is for clears a spell that can't be cast on that side; the "cast on me" switch greys out for enemy keys.

- Hide long buffs now hides only buffs over 10 minutes, so Thorns and Inner Fire show again (hour-long buffs like Fortitude still hide).
- Hide Blizzard's frames keeps the raid manager (ready check, role check, world markers).

- Fear Ward is on Always show by default, so a priest sees it on the tank. It lasts 10 minutes, and "Hide long buffs" (over 5 minutes) kept it out of the buff row.
- Fix: a preview left on hid your real frames, even in combat. The preview now stops when combat starts and says so in chat.
- `/lattice unlock` and `/lattice lock` do what they say (before, both just switched), and say so in chat. Frames lock when combat starts, also while you are holding a box; the settings window's Unlock and Preview buttons always show the current state.
- Taking click-casting from a shared string keeps only bindings Lattice can use, and hover-cast keys from it work at once, without a /reload.
- Clearer messages: "No spell found" gives an example name and ID, a blank profile name says so, and typing a spell that isn't found under Click-casting or Hover-casting now says so. Replacing the aura filters from text asks for a second click, and importing them says in chat how many were added.

- Settings: text boxes (macro, import/export) get the same draggable scroll bar, and the mouse wheel over them scrolls the page unless you are typing in them. Scrolling stops on whole pixels so text stays sharp, and an open dropdown list closes when the page scrolls.
- The player tooltip now shows in combat too, like Blizzard's frames. To keep it out of fights, turn off Tooltip in combat too (General page).
- Fix: buffs like Renew could vanish when moved to the top-left corner. They grew out of the frame and sat under the raid buff row. Buff and debuff icons now grow into the frame from whichever corner they are in ("Into the frame", the new default under Grow towards).
- `/lattice feedback` and a Feedback button in the settings window show a link for reporting bugs and ideas.
- Fix: closing the character window (for example at a vendor) could show an error about a "secret number" blamed on Lattice. Lattice no longer touches Blizzard's pop-up dialogs, its Escape-to-close list or its Edit Mode frames. Escape still closes Lattice's settings window.

## v0.5.1 (2026-11-16)

- Debuffs you can dispel are easy to spot: a big icon of the debuff in the middle of the frame, edged in its type's colour (blue Magic, purple Curse, green Poison, brown Disease), with a soft pulse around it. Works in combat. Size, pulse and on/off under Dispel highlight (Auras page).
- Raid buffs show only the ones you can cast by default: a priest sees Fortitude, Divine Spirit and Shadow Protection, a mage Arcane Intellect. Classes without a raid buff see all of them. Change it under Which buffs (Auras page): only mine, all, or pick them one by one. Want another buff in the row, like Thorns? Add it by name. To keep one out, put it on Never show (Aura filters page).
- Sharing a setup: Export my setup gives one string with everything (layout, positions, sizes, colours, auras, indicators, filters). Paste a friend's string and click Import and use: it becomes a new profile and is used straight away; your old profile stays in the list. Tick Include my click-casting to share that too; only players of the same class can take it.
- Low health warning: the empty part of a player's health bar turns red when they drop below 30% health, so players in danger stand out. Off by default; turn it on under Appearance.
- Seconds left on buff and debuff icons: turn on "Seconds left on buff and debuff icons" on the Auras page to see the time count down as numbers. Off by default.
- Settings window: settings that depend on another one grey out as soon as you turn that one off, and come back when you turn it on. Many labels and help texts are clearer. The large raid layout settings moved from General to Layout. Missing buff mark has its own heading on the Auras page.
- Resetting a profile, deleting a profile, removing an indicator, resetting the aura filters and resetting positions ask for a second click first. To delete a profile, pick it, then click Delete it.
- Turning on "Hide Blizzard's party and raid frames" works straight away, without a /reload.
- The preview shows the big dispel icon and the low health warning.
- Fix: clicking "Add my class's HoTs and shields" again put the new markers on top of the old ones. They now go in a free spot.
- Fix: the Profiles page didn't show its message after creating, copying, renaming, resetting or importing a profile.
- Click-casting and hover-casting: a spell typed by name or ID shows its name, not a number.

## v0.5.0 (2026-11-16)

- Settings window: a proper scroll bar you can grab and drag, or click above or below it to jump a page. The mouse wheel no longer changes sliders, so scrolling down the page never changes a setting by accident. Type a number in the box beside a slider for exact values.
- Tank frames: in raids, each tank gets a frame in a small block of its own, with what that tank is targeting beside it (red hostile, yellow neutral). Uses assigned roles and Lattice's tank guess, so it works with no roles set. Unlock frames to move it. General page: on/off, targets on/off, also in a party.
- Missing buff mark: priests see a small Fortitude icon with a red edge on everyone who doesn't have it; mages the same for Arcane Intellect (mana users only), druids for Mark of the Wild. Works in parties and raids. Other players' auras can only be read out of combat, so it is worked out then and kept during a fight. Auras page.
- Range by your heal: priests, druids, shamans and paladins fade players by the range of a heal they know (40 yards), instead of the game's rougher check. General page.
- Class presets are Classic spells only. Priests get a Weakened Soul marker (who can't take a shield yet) next to Renew, Power Word: Shield and Fear Ward; paladins get Forbearance. Already added your presets? Click "Add my class's HoTs and shields" again to add the new ones.
- Raid with one column per group: order the players inside each group by class (or by role). Layout page.
- Raid buffs get their own row beside each frame: Fortitude, Mark of the Wild, Arcane Intellect, the Blessings and the like, from anyone, so you can see at a glance who is missing yours. It sits left of the frame and grows to the left; you can move it to the right side. The buffs are in the same order on every frame. A clock sweep on each icon shows the time left, and hovering it shows the buff's tooltip. It shows in a party and solo; in a raid only if you turn on "Also in raids" (Auras page). The buff icons on the frame keep your HoTs and shields.

## v0.4.6 (2026-11-15)

- The big defensive icon only shows real defensives (Shield Wall, Last Stand, Evasion, Divine Shield and Protection, Blessing of Protection, Ice Block, Deterrence, Barkskin, Frenzied Regeneration). Before, ordinary buffs like Arcane Intellect or Find Herbs could show there.
- Out-of-range players fade a little more (35% instead of 45%; General page).

## v0.4.5 (2026-11-15)

- Long debuffs nobody can dispel (over 10 minutes, like Boosted Rest from a camp tent) are hidden by default. The game doesn't let addons hide other players' debuffs by spell, so this goes by type and length: magic, curses, poisons and diseases always show. Turn it off under Auras: "Hide long debuffs".

## v0.4.4 (2026-11-15)

- Never shown by default: tracking (Find Herbs, Find Minerals, Find Treasure, Find Fish, Track Beasts and Humanoids, Sense Demons and Undead), Might of Stormwind and Boosted Rest. Change it on the Aura filters page.

## v0.4.3 (2026-11-15)

- Fix: an error at login ("Button.lua:272: attempt to index local 'v'") that stopped the frames from loading, when the game had made a party frame Lattice hadn't set up yet.

## v0.4.2 (2026-11-15)

- Buff icons skip long buffs (over 5 minutes, like Fortitude or Mark of the Wild) by default, so your HoTs and shields stand out. Turn it off under Auras: "Hide long buffs". Spells on your always-show list still show.

## v0.4.1 (2026-11-14)

- The party frames can be dragged like raid and pets: grab the box anywhere, even over the frames, and it covers a whole party when you're alone.

## v0.4.0 (2026-11-14)
- **Tank guessing.** With no roles set, Lattice picks the tank from the raid's main tank mark, Defensive Stance, Bear Form and Righteous Fury. In a group of five it picks one player, or the only Warrior. The guessed tank gets the tank icon. Fix a wrong guess with Ctrl+Alt+Right-click or `/lattice tank`, `notank`, `autotank`. Can be turned off on the General page.
- **Power bars by type and role.** Energy is hidden (rogues, druids in Cat Form), rage shows only for tanks (warriors, druids in Bear Form), mana shows for everyone. Druids switch as they shift. Change it per power type on the Appearance page.
- **Aura filters.** A new Aura filters page: always show or never show buffs and debuffs by name or spell ID, with Classic defaults (Power Infusion, Innervate, Blessing of Protection and Soulstone always shown; Clearcasting, Flurry, Enrage and other short procs hidden). Import and export as plain text. Ctrl+Alt+Right-click a frame to pick from that player's auras. The game only lets addons pick out a few debuffs on friendly players by ID, so for most debuffs these filters have no effect; buffs always work.
- **Polish.** Bars no longer sweep when a frame switches to another player. Heal and shield bars are smoothed too. New dispel style "Border and a light tint". Optional: no aggro border on tanks. Dropdowns and sliders grey out when they don't apply.
- **Fixes.** A ready check started within 6 seconds of the last one is no longer wiped. Dead and offline looks are refreshed only when that state changes, not on every health tick.
