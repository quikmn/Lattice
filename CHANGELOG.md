# Lattice Party & Raid Frames

## Unreleased

- Settings window: a proper scroll bar you can grab and drag, or click above or below it to jump a page. The mouse wheel no longer changes sliders, so scrolling down the page never changes a setting by accident. Type a number in the box beside a slider for exact values.
- Tank frames: in raids, each tank gets a frame in a small block of its own, with what that tank is targeting beside it (red hostile, yellow neutral). Uses assigned roles and Lattice's tank guess, so it works with no roles set. Unlock frames to move it. General page: on/off, targets on/off, also in a party.
- Missing buff mark: priests see a small Fortitude icon with a red edge on everyone who doesn't have it; mages the same for Arcane Intellect (mana users only), druids for Mark of the Wild. Works in parties and raids. Other players' auras can only be read out of combat, so it is worked out then and kept during a fight. Auras page.
- Range by your heal: priests, druids, shamans and paladins fade players by the range of a heal they know (40 yards), instead of the game's rougher check. General page.
- Class presets are Classic spells only. Priests get a Weakened Soul marker (who can't take a shield yet) next to Renew, Power Word: Shield and Fear Ward; paladins get Forbearance. Already added your presets? Click "Add my class's HoTs and shields" again to add the new ones.
- Raid with one column per group: order the players inside each group by class (or by role). Layout page.
- Raid buffs get their own row beside each frame: Fortitude, Mark of the Wild, Arcane Intellect, the Blessings and the like, from anyone, so you can see at a glance who is missing yours. It sits left of the frame and grows to the left; you can move it to the right side. It shows in a party and solo; in a raid only if you turn on "Also in raids" (Auras page). The buff icons on the frame keep your HoTs and shields.

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
