local _, ns = ...
local W, O, U, T = ns.Widgets, ns.Options, ns.Util, ns.Theme
local A, CC = ns.Auras, ns.ClickCast

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local function Rebuild() O:RebuildPage("aurafilters") end

-- One list entry: icon, name, ID, and buttons to move or remove it.
local function EntryRow(s, e)
	local row = CreateFrame("Frame")
	local bg = U.Solid(row, "BACKGROUND", rgba(T.surface))
	bg:SetAllPoints()
	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", 8, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetTexture(CC.SpellIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
	local name = W.Text(row, T.font, T.text)
	name:SetPoint("LEFT", 32, 0)
	name:SetPoint("RIGHT", -200, 0)
	name:SetWordWrap(false)
	name:SetText(e.name .. "  |cff8d94a3" .. e.id .. "|r")
	local other = e.mode == "show" and "hide" or "show"
	local move = W.Button(row, other == "hide" and "Never show" or "Always show", function()
		A:SetListMode(e.id, other)
		Rebuild()
	end, 100)
	move:SetHeight(20)
	move:SetPoint("RIGHT", -82, 0)
	local del = W.Button(row, "Remove", function()
		A:SetListMode(e.id, nil)
		Rebuild()
	end, 70, "danger")
	del:SetHeight(20)
	del:SetPoint("RIGHT", -6, 0)
	s:Add(row, 26, 4)
end

local function ListSection(s, mode, title, sub)
	local entries = A:ListEntries(mode)
	W.Header(s, title .. " (" .. #entries .. ")", sub)
	if #entries == 0 then W.Note(s, "Nothing here yet.") end
	for _, e in ipairs(entries) do EntryRow(s, e) end
end

O:RegisterPage("aurafilters", "Aura filters", nil, function(s)
	W.Header(s, "Aura filters", "Pick buffs and debuffs that always show, or never show, on your frames.",
		{ "filter", "whitelist", "blacklist", "always show", "never show", "hide" })
	W.Note(s, "|cffffffffAlways show|r puts the aura first in the buff or debuff row, even when someone else cast it. |cffffffffNever show|r hides it everywhere: icons, the boss slot and the dispel highlight.")
	W.Note(s, "Quick way: |cffffffffCtrl+Alt+Right-click|r a frame (out of combat) and pick one of that player's auras.")
	W.Note(s, "Buffs always work. For debuffs on friendly players the game only lets addons pick out a few spells by ID (such as Recently Bandaged); other debuffs keep showing as usual.", T.muted)

	-- Add by name or ID
	local row = CreateFrame("Frame")
	local box = W.EditBox(row, 220, 24)
	box:SetPoint("LEFT")
	local status = W.Text(row, T.fontSmall + 1, T.muted)
	local function add(mode)
		local text = box:GetText()
		local ids = A:ResolveSpells(text)
		if #ids == 0 then
			status:SetText("|cffef5d5dNo spell found. Type a spell you know, like Flurry, or its ID, like 12966.|r")
			return
		end
		for _, id in ipairs(ids) do A:SetListMode(id, mode, true) end
		A:Refresh()
		box:SetText("")
		Rebuild()
	end
	local show = W.Button(row, "Always show", function() add("show") end, 110, "accent")
	show:SetPoint("LEFT", box, "RIGHT", 8, 0)
	local hide = W.Button(row, "Never show", function() add("hide") end, 110)
	hide:SetPoint("LEFT", show, "RIGHT", 6, 0)
	status:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
	box:SetScript("OnEnterPressed", function() add("hide") end)
	W.Tooltip(box, "Spell name or ID", "A name you know picks up every rank. Several IDs can be separated by commas. Enter adds it to Never show.")
	s:Add(row, 40)

	-- Pick from a player
	local pickRow = CreateFrame("Frame")
	local pickStatus = W.Text(pickRow, T.fontSmall + 1, T.muted)
	local pick = W.Button(pickRow, "Pick from my target", function()
		local unit = UnitExists("target") and UnitCanAssist("player", "target") and "target" or "player"
		local list, err = A:CurrentAuras(unit)
		if not list then pickStatus:SetText("|cffef5d5d" .. err .. "|r") return end
		if #list == 0 then pickStatus:SetText("No auras on " .. (unit == "player" and "you" or "your target") .. " right now.") return end
		ns.UnitMenu:OpenAuras(unit)
	end, 170)
	pick:SetPoint("LEFT")
	pickStatus:SetPoint("LEFT", pick, "RIGHT", 10, 0)
	pickStatus:SetText("Lists your target's auras, or your own when you have no friendly target.")
	s:Add(pickRow, 26)

	ListSection(s, "show", "Always show", nil)
	ListSection(s, "hide", "Never show", nil)

	-- Share
	W.Header(s, "Share", "Plain text, one per line: |cffffffffshow 10060|r or |cffffffffhide Flurry|r. Lines starting with # are ignored.",
		{ "export", "import", "copy", "paste", "reset" })
	local area = W.TextArea(nil, 520, 110)
	s:Add(area, 110)
	local msg
	local ioRow = CreateFrame("Frame")
	local exp = W.Button(ioRow, "Export", function()
		area.box:SetText(A:ExportLists())
		area.box:HighlightText()
		area.box:SetFocus()
		msg.text:SetText("|cff62cf88The list is selected in the box. Press Ctrl+C to copy it.|r")
	end, 80)
	exp:SetPoint("LEFT")
	local function import(replace)
		local n, bad = A:ImportLists(area.box:GetText(), replace)
		if n == 0 then
			msg.text:SetText("|cffef5d5dNothing to import. Paste lines like \"hide 12966\" into the box.|r")
			return
		end
		local skipped = ""
		if #bad > 0 then
			skipped = string.format(" %d line(s) skipped (unknown spell or missing show/hide): %s", #bad, ns.Escape(table.concat(bad, " / ")))
		end
		ns:Printf("Aura filters: %d spell(s) %s.%s", n, replace and "now make up the lists" or "added", skipped)
		Rebuild()
	end
	local addBtn = W.Button(ioRow, "Add from text", function() import(false) end, 120)
	addBtn:SetPoint("LEFT", exp, "RIGHT", 6, 0)
	local repl = W.ConfirmButton(ioRow, "Replace with text", function() import(true) end, 156)
	repl:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
	local reset = W.ConfirmButton(ioRow, "Reset to defaults", function() A:ResetLists(); Rebuild() end, 170)
	reset:SetPoint("LEFT", repl, "RIGHT", 6, 0)
	s:Add(ioRow, 26)
	msg = W.Note(s, " ")
end)
