-- Lattice: helpers for Forever's secret values.
--
-- Rules (from the 1.60.1 API docs):
--  * UnitHealth / UnitHealthMissing / UnitHealthPercent / incoming heals / absorbs,
--    UnitInRange and GetRaidTargetIndex are ALWAYS secret.
--  * Secrets may only be stored, passed around, and handed to whitelisted widget
--    setters (StatusBar:SetValue, Region:SetAlpha, SetVertexColor, FontString:SetText,
--    SetFormattedText, Texture:SetSpriteSheetCell, ...). Never compare, do math,
--    test truthiness, index, or pass them to SetShown/SetWidth/SetPoint.
--  * Curves turn a secret percentage into a secret colour/alpha *inside the client*.
local _, ns = ...
local S = {}
ns.Secret = S

local issecret = issecretvalue or function() return false end
S.IsSecret = issecret

-- Run a function and swallow errors from unexpected secrets, reporting once per key.
local reported = {}
function S.Try(key, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not reported[key] then
		reported[key] = true
		if ns.db and ns.db.debug then
			ns:Print("|cffff6666" .. key .. "|r failed: " .. tostring(err))
		end
	end
	return ok
end

------------------------------------------------------------------------
-- Status bar smoothing
------------------------------------------------------------------------
function S.SmoothMode()
	if ns.db.general.smoothBars and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut then
		return Enum.StatusBarInterpolation.ExponentialEaseOut
	end
	return nil
end

function S.SetBar(bar, value, smooth)
	local mode = smooth and S.SmoothMode()
	if mode then
		bar:SetValue(value, mode)
	else
		bar:SetValue(value)
	end
end

------------------------------------------------------------------------
-- Boolean -> number without branching (works with secret booleans)
------------------------------------------------------------------------
local EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

function S.PickNumber(secretBool, ifTrue, ifFalse)
	if EvalBool then
		return EvalBool(secretBool, ifTrue, ifFalse)
	end
	-- Old clients without secrets: plain branch is fine.
	if issecret(secretBool) then return ifTrue end
	if secretBool then return ifTrue end
	return ifFalse
end

-- Alpha for range fading. UnitInRange returns (inRange, checkedRange), both secret.
-- Out of range = checked and not inRange; unchecked counts as in range.
function S.RangeAlpha(unit, outAlpha)
	if unit == "player" or UnitIsUnit(unit, "player") then return 1 end
	local inRange, checked = UnitInRange(unit)
	if not issecret(inRange) and inRange == nil then return 1 end
	if not issecret(checked) and checked == nil then checked = true end
	return S.PickNumber(checked, S.PickNumber(inRange, 1, outAlpha), 1)
end

------------------------------------------------------------------------
-- Curves (built from plain constants; evaluated by the client)
------------------------------------------------------------------------
local curves = {}

local function ColorObj(r, g, b, a)
	return CreateColor(r, g, b, a or 1)
end

-- Health colour gradient: red at 0%, yellow at 50%, green at 100%.
function S.HealthGradientCurve()
	if curves.gradient then return curves.gradient end
	if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
	local c = C_CurveUtil.CreateColorCurve()
	if Enum.LuaCurveType then c:SetType(Enum.LuaCurveType.Linear) end
	c:AddPoint(0.0, ColorObj(0.90, 0.20, 0.20))
	c:AddPoint(0.5, ColorObj(0.95, 0.80, 0.20))
	c:AddPoint(1.0, ColorObj(0.20, 0.80, 0.35))
	curves.gradient = c
	return c
end

-- 1 while health is below 100%, 0 when full. Used to hide "deficit" text at full HP.
function S.NotFullCurve()
	if curves.notFull then return curves.notFull end
	if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
	local c = C_CurveUtil.CreateCurve()
	if Enum.LuaCurveType then c:SetType(Enum.LuaCurveType.Step) end
	c:AddPoint(0, 1)
	c:AddPoint(1, 0)
	curves.notFull = c
	return c
end

function S.PercentCurve()
	return CurveConstants and CurveConstants.ScaleTo100
end

------------------------------------------------------------------------
-- Heal prediction (one calculator per button)
------------------------------------------------------------------------
function S.NewCalculator()
	if type(CreateUnitHealPredictionCalculator) ~= "function" then return nil end
	local calc = CreateUnitHealPredictionCalculator()
	if Enum.UnitDamageAbsorbClampMode then
		-- Absorbs fill missing health (after incoming heals), never past the bar.
		calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
	end
	if Enum.UnitIncomingHealClampMode then
		calc:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
	end
	if calc.SetIncomingHealOverflowPercent then
		calc:SetIncomingHealOverflowPercent(1.0)
	end
	if Enum.UnitHealAbsorbClampMode then
		calc:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.CurrentHealth)
	end
	return calc
end

-- Returns incoming heals, absorbs, heal absorbs (all possibly secret), already clamped.
function S.HealPrediction(calc, unit)
	if calc and type(UnitGetDetailedHealPrediction) == "function" then
		UnitGetDetailedHealPrediction(unit, "player", calc)
		local heals = calc:GetIncomingHeals()
		local absorbs = calc:GetDamageAbsorbs()
		local healAbsorbs = calc:GetHealAbsorbs()
		return heals, absorbs, healAbsorbs
	end
	-- Fallback for clients without the calculator (unclamped).
	return UnitGetIncomingHeals(unit) or 0, UnitGetTotalAbsorbs(unit) or 0, UnitGetTotalHealAbsorbs(unit) or 0
end

------------------------------------------------------------------------
-- Raid target icon: index is secret, so pick the sprite cell in the client.
------------------------------------------------------------------------
function S.SetRaidIcon(tex, unit)
	local idx = GetRaidTargetIndex(unit)
	if issecret(idx) then
		if tex.SetSpriteSheetCell then
			tex:SetSpriteSheetCell(idx, 4, 4)
			tex:SetAlpha(1)
			return
		end
		tex:SetAlpha(0)
		return
	end
	if idx then
		if tex.SetSpriteSheetCell then
			tex:SetSpriteSheetCell(idx, 4, 4)
		elseif SetRaidTargetIconTexture then
			SetRaidTargetIconTexture(tex, idx)
		end
		tex:SetAlpha(1)
	else
		tex:SetAlpha(0)
	end
end

------------------------------------------------------------------------
-- Readable-or-not helpers for values that are only *sometimes* secret
------------------------------------------------------------------------
-- Returns the value if it's safe to use in Lua logic, else `fallback`.
function S.Plain(v, fallback)
	if issecret(v) then return fallback end
	return v
end
