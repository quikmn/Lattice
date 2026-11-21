local _, ns = ...
local W, O, T = ns.Widgets, ns.Options, ns.Theme
local P = ns.Profiles

local function ProfileItems()
	local items = {}
	for _, name in ipairs(P:List()) do items[#items + 1] = { value = name, text = name } end
	return items
end

-- Text input + button on one row.
local function InputRow(s, label, buttonText, onSubmit, style)
	local row = CreateFrame("Frame")
	local l = W.Text(row, T.font, T.text)
	l:SetPoint("TOPLEFT")
	l:SetText(label)
	local box = W.EditBox(row, 220, 24)
	box:SetPoint("TOPLEFT", 0, -18)
	local b = W.Button(row, buttonText, function()
		onSubmit(box:GetText(), box)
	end, 120, style)
	b:SetPoint("LEFT", box, "RIGHT", 8, 0)
	box:SetScript("OnEnterPressed", function() b:Click() end)
	s:Add(row, 44)
	return box
end

-- Switching profiles rebuilds every page, this one too: a message said just before it is shown on the new page.
local lastMsg

O:RegisterPage("profiles", "Profiles", nil, function(s)
	local msg

	-- carry: the page is about to be rebuilt, so show the message on the new one too
	local function say(text, ok, carry)
		local t = (ok and "|cff62cf88" or "|cffef5d5d") .. text .. "|r"
		msg.text:SetText(t)
		lastMsg = carry and t or nil
	end

	W.Header(s, "Profiles", "A profile holds all settings except click-casting and hover-casting (those are per character). Characters can share one.",
		{ "export", "import", "share", "string", "copy", "rename", "delete", "reset", "spec" })
	W.Dropdown(s, {
		label = "Active profile",
		items = ProfileItems,
		get = function() return ns.Database:ActiveName() end,
		set = function(v) P:Switch(v) end,
	})

	-- why a name was refused
	local function badName(name)
		if not name or not name:find("%S") then return "Type a name first, like Healer." end
		return "There is already a profile called " .. name .. ". Pick another name."
	end

	InputRow(s, "New profile with default settings", "Create", function(name, box)
		if P:Create(name, nil) then
			box:SetText("")
			say("Created and switched to " .. name .. ".", true, true)
			P:Switch(name)
		else
			say(badName(name))
		end
	end)
	InputRow(s, "Copy the active profile as", "Copy", function(name, box)
		if P:Create(name, ns.Database:ActiveName()) then
			box:SetText("")
			say("Copied to " .. name .. ". You're still using " .. ns.Database:ActiveName() .. ".", true, true)
			O:RebuildPage("profiles")
		else
			say(badName(name))
		end
	end)
	InputRow(s, "Rename the active profile to", "Rename", function(name, box)
		if P:Rename(ns.Database:ActiveName(), name) then
			box:SetText("")
			say("Renamed to " .. name .. ".", true, true)
			O:RebuildPage("profiles")
		else
			say(badName(name))
		end
	end)

	local row = CreateFrame("Frame")
	local reset = W.ConfirmButton(row, "Reset active profile to defaults", function()
		say("Profile reset.", true, true)
		P:Reset()
	end, 240)
	reset:SetPoint("LEFT")
	s:Add(row, 26)

	-- Delete: pick a profile, then confirm with the button.
	local toDelete
	W.Dropdown(s, {
		label = "Delete a profile (not the active one)",
		items = function()
			local items = {}
			for _, name in ipairs(P:List()) do
				if name ~= ns.Database:ActiveName() then items[#items + 1] = { value = name, text = name } end
			end
			if #items == 0 then items[1] = { value = false, text = "(no other profiles)" } end
			return items
		end,
		placeholder = "Choose a profile...",
		get = function() return toDelete end,
		set = function(v) toDelete = v or nil end,
	})
	local delRow = CreateFrame("Frame")
	local del = W.ConfirmButton(delRow, "Delete it", function()
		if toDelete and P:Delete(toDelete) then
			say("Deleted " .. toDelete .. ".", true, true)
			O:RebuildPage("profiles")
		else
			say("Choose a profile to delete first.")
		end
	end, 140)
	del:SetPoint("LEFT")
	s:Add(delRow, 26)

	-- Spec switching
	if P:HasSpecs() then
		W.Header(s, "Switch by specialization")
		for i = 1, GetNumSpecializations() do
			W.Dropdown(s, {
				label = P:SpecName(i),
				items = function()
					local items = { { value = false, text = "Don't switch" } }
					for _, it in ipairs(ProfileItems()) do items[#items + 1] = it end
					return items
				end,
				get = function() return ns.char.specProfiles[i] or false end,
				set = function(v)
					ns.char.specProfiles[i] = v or nil
					P:ApplySpecProfile()
				end,
			})
		end
	end

	-- Import / export
	W.Header(s, "Share", "Your whole setup as one string: layout, positions, sizes, colors, auras, indicators and filters. Send it to a friend, or paste someone's string to use their setup.")
	local area = W.TextArea(nil, 520, 90)
	s:Add(area, 90)
	local withCasting, takeCasting = false, false

	W.Note(s, "|cffffffffExport|r: the string appears in the box above.")
	W.Toggle(s, {
		label = "Include my click-casting and hover-casting",
		desc = "Only players of your class can take it.",
		get = function() return withCasting end,
		set = function(v) withCasting = v end,
	})
	local ioRow = CreateFrame("Frame")
	local exp = W.Button(ioRow, "Export my setup", function()
		local str, err = P:Export(nil, withCasting)
		if str then
			area.box:SetText(str)
			area.box:HighlightText()
			area.box:SetFocus()
			say("The string is selected in the box above. Press Ctrl+C to copy it.", true)
		else
			say(err)
		end
	end, 170)
	exp:SetPoint("LEFT")
	s:Add(ioRow, 26)

	W.Note(s, "|cffffffffImport|r: paste a string into the box above. It becomes a new profile and is used straight away; your current profile stays in the list.")
	W.Toggle(s, {
		label = "Also take their click-casting and hover-casting",
		desc = "Replaces yours with theirs, if the string has some for your class.",
		get = function() return takeCasting end,
		set = function(v) takeCasting = v end,
	})
	InputRow(s, "Name for the new profile (optional)", "Import and use", function(name, box)
		local before = ns.Database:ActiveName()
		local ok, result, note = P:Import(area.box:GetText(), name, takeCasting)
		if ok then
			box:SetText("")
			area.box:SetText("")
			say("Now using " .. result .. ". Your old profile, " .. before .. ", is still under Active profile." .. (note and (" " .. note) or ""), true, true)
			O:RebuildPage("profiles")
		else
			say(result)
		end
	end, "accent")

	msg = W.Note(s, " ")
	if lastMsg then msg.text:SetText(lastMsg) end
	lastMsg = nil
end)
