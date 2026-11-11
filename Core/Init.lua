-- Lattice: core namespace, event dispatch, callbacks and combat-safe queue.
local ADDON, ns = ...

ns.name = ADDON
ns.title = "Lattice"
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

_G.Lattice = ns -- handy for /dump and snippets; nothing secure hangs off this

------------------------------------------------------------------------
-- Printing
------------------------------------------------------------------------
local PREFIX = "|cff5aa9ffLattice|r: "

function ns:Print(...)
	local out = {}
	for i = 1, select("#", ...) do
		out[#out + 1] = tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(out, " "))
end

function ns:Printf(fmt, ...)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. string.format(fmt, ...))
end

------------------------------------------------------------------------
-- Events: ns:RegisterEvent(event, handler) with multiple handlers per event
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		list[i](event, ...)
	end
end)

function ns:RegisterEvent(event, handler)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		eventFrame:RegisterEvent(event)
	end
	list[#list + 1] = handler
end

function ns:UnregisterEvent(event, handler)
	local list = handlers[event]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i] == handler then table.remove(list, i) end
	end
	if #list == 0 then
		handlers[event] = nil
		eventFrame:UnregisterEvent(event)
	end
end

------------------------------------------------------------------------
-- Internal callbacks (settings changed, profile switched, ...)
------------------------------------------------------------------------
local callbacks = {}

function ns:Listen(message, fn)
	callbacks[message] = callbacks[message] or {}
	table.insert(callbacks[message], fn)
end

function ns:Fire(message, ...)
	local list = callbacks[message]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end

------------------------------------------------------------------------
-- Combat lockdown queue. Secure frames can't be touched in combat, so
-- anything that changes attributes, size or position goes through here.
-- Keyed so repeated requests collapse into one run.
------------------------------------------------------------------------
local pending, pendingOrder = {}, {}

function ns:InCombat()
	return InCombatLockdown()
end

function ns:RunOutOfCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return true
	end
	if not pending[key] then
		pendingOrder[#pendingOrder + 1] = key
	end
	pending[key] = fn
	return false
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local order = pendingOrder
	pendingOrder = {}
	for i = 1, #order do
		local key = order[i]
		local fn = pending[key]
		pending[key] = nil
		if fn then fn() end
	end
end)

------------------------------------------------------------------------
-- Module registry: modules register an OnInitialize (after DB is ready)
-- and an OnEnable (after PLAYER_LOGIN).
------------------------------------------------------------------------
ns.modules = {}

function ns:NewModule(name)
	local mod = { name = name }
	ns.modules[#ns.modules + 1] = mod
	ns[name] = mod
	return mod
end
