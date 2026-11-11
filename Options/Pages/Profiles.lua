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

O:RegisterPage("profiles", "Profiles", nil, function(s)
	local msg

	local function say(text, ok)
		msg.text:SetText((ok and "|cff62cf88" or "|cffef5d5d") .. text .. "|r")
	end

	W.Header(s, "Profiles", "A profile holds all settings except click-casting. Characters can share one.")
	W.Dropdown(s, {
		label = "Active profile",
		items = ProfileItems,
		get = function() return ns.Database:ActiveName() end,
		set = function(v) P:Switch(v) end,
	})

	InputRow(s, "New profile", "Create", function(name, box)
		if P:Create(name, nil) then
			box:SetText("")
			P:Switch(name)
			say("Created and switched to " .. name .. ".", true)
		else
			say("Pick a name that isn't used yet.")
		end
	end)
	InputRow(s, "Copy the active profile as", "Copy", function(name, box)
		if P:Create(name, ns.Database:ActiveName()) then
			box:SetText("")
			say("Copied to " .. name .. ".", true)
			O:RebuildPage("profiles")
		else
			say("Pick a name that isn't used yet.")
		end
	end)
	InputRow(s, "Rename the active profile to", "Rename", function(name, box)
		if P:Rename(ns.Database:ActiveName(), name) then
			box:SetText("")
			O:RebuildPage("profiles")
		else
			say("Pick a name that isn't used yet.")
		end
	end)

	local row = CreateFrame("Frame")
	local reset = W.Button(row, "Reset active profile to defaults", function() P:Reset(); say("Profile reset.", true) end, 230)
	reset:SetPoint("LEFT")
	s:Add(row, 26)
	W.Dropdown(s, {
		label = "Delete profile (can't delete the active one)",
		items = function()
			local items = {}
			for _, name in ipairs(P:List()) do
				if name ~= ns.Database:ActiveName() then items[#items + 1] = { value = name, text = name } end
			end
			if #items == 0 then items[1] = { value = false, text = "(no other profiles)" } end
			return items
		end,
		get = function() return false end,
		set = function(v)
			if v and P:Delete(v) then say("Deleted " .. v .. ".", true) end
		end,
	})

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
	W.Header(s, "Share", "Export a profile as text to share it, or paste someone's string to import it.")
	local area = W.TextArea(nil, 520, 90)
	s:Add(area, 90)
	local ioRow = CreateFrame("Frame")
	local exp = W.Button(ioRow, "Export active profile", function()
		local str, err = P:Export()
		if str then
			area.box:SetText(str)
			area.box:HighlightText()
			area.box:SetFocus()
			say("Copied into the box above. Press Ctrl+C to copy.", true)
		else
			say(err)
		end
	end, 170)
	exp:SetPoint("LEFT")
	s:Add(ioRow, 26)
	InputRow(s, "Import the string above as a new profile named", "Import", function(name, box)
		local ok, err = P:Import(area.box:GetText(), name)
		if ok then
			box:SetText("")
			say("Imported as " .. name .. ". Pick it under Active profile to use it.", true)
		else
			say(err)
		end
	end, "accent")

	msg = W.Note(s, " ")
end)
