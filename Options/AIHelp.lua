-- Lattice: the settings for chat and AI help ("/lattice ai", "/lattice apply", "/lattice <setting> <value>").
--
-- Lattice draws its own settings window, so EverlookUI's app has no registered settings. This hands it every control
-- in the window that has a key (Options.Bind's path, or opt.key; the Layout page's controls once per layout), read
-- from the real controls: the same label, help, range, choices, get and set as in the window, grouped by page and
-- heading. Controls without a key (the "Layout to edit" picker, the hover-cast and click-cast draft fields, profile
-- pickers) are not settings and are left out, so a pasted answer can only change what is listed here.
--
-- The answer is pasted from an AI: every value is checked twice, by EverlookUI (on/off, range and step, one of the
-- choices, 0-1 colours) and by the validator below (the type and range the control itself could set). In combat the
-- changes wait until it ends (app:ProvideSettings(..., { combat = "queue" }) in Boot.lua): the frames are secure.
local _, ns = ...
local U = ns.Util
local AI = {}
ns.AIHelp = AI

local LAYOUT_NAMES = { party = "Party", raid = "Raid", raid40 = "Large raid" }

local function choicesOf(opt)
	local items = opt.items
	if type(items) == "function" then
		local ok, res = pcall(items)
		items = ok and res or nil
	end
	local out = {}
	for _, it in ipairs(type(items) == "table" and items or {}) do
		local v = type(it) == "table" and it.value
		if (type(v) == "string" or type(v) == "number") and not it.title then
			out[#out + 1] = { value = v, text = tostring(it.text or v) }
		end
	end
	return out
end

local function isUnit(c) return type(c) == "number" and c == c and c >= 0 and c <= 1 end

-- What the control itself could set; anything else is refused.
function AI.Validator(kind, opt, choices)
	if kind == "bool" then
		return function(v) return type(v) == "boolean", "needs on or off" end
	elseif kind == "number" then
		local lo, hi = tonumber(opt.min), tonumber(opt.max)
		return function(v)
			return type(v) == "number" and v == v and v >= lo - 1e-9 and v <= hi + 1e-9, "must be a number from " .. lo .. " to " .. hi
		end
	elseif kind == "choice" then
		return function(v)
			for _, c in ipairs(choices) do if c.value == v then return true end end
			return false, "not one of the choices"
		end
	elseif kind == "color" then
		return function(v)
			if type(v) ~= "table" or not (isUnit(v[1]) and isUnit(v[2]) and isUnit(v[3])) or (v[4] ~= nil and not isUnit(v[4])) then
				return false, "needs a colour with parts from 0 to 1"
			end
			return true
		end
	end
	return function() return false, "not settable" end
end

local function copy(v) return type(v) == "table" and U.CopyTable(v) or v end

local function newDef(kind, opt, key, label, group)
	local def = {
		key = key, type = kind, label = label, desc = opt.desc, keywords = opt.keywords, group = group,
		min = opt.min, max = opt.max, step = opt.step or (kind == "number" and 1 or nil), fmt = opt.fmt,
		hasAlpha = opt.hasAlpha,
	}
	if kind == "choice" then def.choices = choicesOf(opt) end
	def.validate = AI.Validator(kind, opt, def.choices)
	return def
end

-- The settings, from every page of the window (built hidden when needed). A flat list of defs with def.group.
function AI.Settings()
	local out = {}
	for _, e in ipairs(ns.Options:AllEntries()) do
		local s = e.frame and rawget(e.frame, "setting")
		local opt = s and s.opt
		if opt and (opt.key or opt.layoutKey) and opt.search ~= false then
			local kind = s.type
			if opt.layoutKey then
				local lk = opt.layoutKey
				for _, name in ipairs(opt.layouts or {}) do
					local def = newDef(kind, opt, "layouts." .. name .. "." .. lk, opt.label .. " (" .. (LAYOUT_NAMES[name] or name) .. ")", e.path)
					def.get = function() return ns.db.layouts[name][lk] end
					def.set = function(v)
						ns.db.layouts[name][lk] = copy(v)
						ns:ApplySettings("layout")
					end
					if opt.layoutDisabled then def.disabled = function() return opt.layoutDisabled(name) end end
					local d = ns.Defaults.layouts[name]
					def.default = d and d[lk]
					out[#out + 1] = def
				end
			else
				local def = newDef(kind, opt, opt.key, opt.label, e.path)
				def.get, def.disabled, def.after = opt.get, opt.disabled, opt.after
				local set = opt.set
				def.set = function(v) set(copy(v)) end
				local okD, d = pcall(U.Get, ns.Defaults, opt.key)
				if okD and type(d) ~= "table" or (okD and kind == "color") then def.default = d end
				out[#out + 1] = def
			end
		end
	end
	return out
end

-- More for the AI: what the apply window can't do, and how the layouts work.
function AI.Extra()
	return table.concat({
		"Party, Raid and Large raid each have their own layout: keys layouts.party.*, layouts.raid.* and layouts.raid40.*. "
			.. "The Large raid layout is used above the player count in general.largeRaidThreshold, when general.largeRaidLayout is on.",
		"All settings above are saved in the active profile.",
		"Changes to the frames made in combat wait until combat ends, then apply by themselves.",
		"Not settable from the apply window (the player does these in the settings window): click-casting bindings, "
			.. "hover-cast keys, profiles, adding or removing spell indicators, and adding spells to the raid buff row. "
			.. "Aura filters by spell have chat commands: /lattice show <spell>, /lattice hide <spell>, /lattice unlist <spell>.",
	}, "\n")
end
