-- Lattice: Ctrl+Alt+Right-click on a frame opens a small menu for that player:
-- tank choice (always / never / guess) and the aura filter picker.
--
-- The secure button gets a do-nothing "latticemenu" type for that click (set in
-- ClickCast), so neither Blizzard's unit menu nor a click-cast fires with it.
-- If the user binds Ctrl+Alt+Right-click to something, the menu steps aside.
local _, ns = ...
local S = ns.Secret
local M = {}
ns.UnitMenu = M

M.BUTTON, M.MODS = 2, "alt-ctrl"
M.TYPE = "latticemenu"

function M:Enabled()
	return not ns.ClickCast:FindConflict(M.BUTTON, M.MODS)
end

-- PostClick hook on every secure unit button.
function M:OnPostClick(btn, mouse)
	if mouse ~= "RightButton" or not btn.unit then return end
	if not (IsAltKeyDown() and IsControlKeyDown()) or IsShiftKeyDown() then return end
	if not self:Enabled() then return end
	self:Open(btn.unit)
end

local function Name(unit)
	return S.Plain(UnitName(unit), nil) or unit
end

local function InGroup(unit)
	for _, u in ipairs(ns.Roles:Roster()) do
		if UnitIsUnit(u, unit) then return u end
	end
end

function M:Open(unit)
	local R, W = ns.Roles, ns.Widgets
	local items = { { title = true, text = Name(unit) } }
	local member = InGroup(unit)
	if member then
		local why = R:IsTank(member) and (R:Reason(member) or "assigned role")
		items[#items + 1] = { title = true, text = why and ("Tank now (" .. why .. ")") or "Not a tank now" }
		items[#items + 1] = { value = "tank", text = "Always tank" }
		items[#items + 1] = { value = "notank", text = "Never tank" }
		items[#items + 1] = { value = "auto", text = "Guess automatically" }
	end
	items[#items + 1] = { value = "auras", text = "Hide or pin one of their auras..." }
	items[#items + 1] = { value = "options", text = "Aura filter settings" }
	local current = member and (R:Override(R.Key(member)) or "auto") or nil
	W.OpenPopup(nil, items, current, function(v)
		if v == "tank" or v == "notank" then
			R:SetOverride(member, v)
		elseif v == "auto" then
			R:SetOverride(member, nil)
		elseif v == "auras" then
			self:OpenAuras(unit)
		elseif v == "options" then
			ns.Options:Open("aurafilters")
		end
	end, { width = 240, atCursor = true })
end

local MODE_TAG = { show = "  |cff62cf88always|r", hide = "  |cffef5d5dhidden|r" }

function M:OpenAuras(unit)
	local A = ns.Auras
	local list, err = A:CurrentAuras(unit)
	if not list then ns:Print(err) return end
	if #list == 0 then ns:Print(Name(unit) .. " has no auras right now.") return end
	local items = { { title = true, text = "Pick an aura on " .. Name(unit) } }
	for i, a in ipairs(list) do
		if i > 24 then break end
		local tag = MODE_TAG[A:ListMode(a.id) or ""] or ""
		items[#items + 1] = { value = i, icon = a.icon, text = a.name .. (a.harmful and "  |cffaaaaaa(debuff)|r" or "") .. tag }
	end
	ns.Widgets.OpenPopup(nil, items, nil, function(i) self:OpenMode(list[i]) end, { width = 280, atCursor = true })
end

function M:OpenMode(aura)
	local A = ns.Auras
	local mode = A:ListMode(aura.id)
	local items = {
		{ title = true, text = aura.name .. "  |cff888888" .. aura.id .. "|r" },
		{ value = "show", text = A.LIST_MODES.show },
		{ value = "hide", text = A.LIST_MODES.hide },
	}
	if mode then items[#items + 1] = { value = "remove", text = "Remove from the filters" } end
	ns.Widgets.OpenPopup(nil, items, mode, function(v)
		A:SetListMode(aura.id, v ~= "remove" and v or nil)
		local label = v == "remove" and "removed from the filters" or (A.LIST_MODES[v]:lower())
		ns:Print(aura.name .. ": " .. label .. ".")
		if aura.harmful and v ~= "remove" and A:CanFilterDebuff(aura.id) == false then
			ns:Print("The game doesn't let addons pick out this debuff on friendly players, so it keeps showing as usual.")
		end
		if ns.Options:IsShown() then ns.Options:RebuildPage("aurafilters") end
	end, { width = 240, atCursor = true })
end
