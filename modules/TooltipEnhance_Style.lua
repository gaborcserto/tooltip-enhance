-- TooltipEnhance_Style.lua
-- Background alpha + border color mode.

TE = TE or {}
TE.Style = TE.Style or {}
TE.Core = TE.Core or {}

local Safe = TE.Safe
local defaultHealthBarTexture

local function Begins(name, prefix)
    return type(name) == "string" and name:sub(1, #prefix) == prefix
end

local function HasPlain(name, needle)
    return type(name) == "string" and name:find(needle, 1, true) ~= nil
end

local function IsAuraOwner(frame)
    local name = Safe.GetName(frame)
    if not name then return true end

    if Begins(name, "BuffButton") or Begins(name, "DebuffButton") then return true end
    if HasPlain(name, "TempEnchant") or HasPlain(name, "AuraButton") then return true end
    if HasPlain(name, "BuffFrame") or HasPlain(name, "DebuffFrame") then return true end
    if HasPlain(name, "TargetFrame") and (HasPlain(name, "Buff") or HasPlain(name, "Debuff")) then return true end
    if HasPlain(name, "FocusFrame") and (HasPlain(name, "Buff") or HasPlain(name, "Debuff")) then return true end
    if HasPlain(name, "Compact") and (HasPlain(name, "Buff") or HasPlain(name, "Debuff") or HasPlain(name, "Aura")) then return true end
    if HasPlain(name, "NamePlate") and (HasPlain(name, "Buff") or HasPlain(name, "Debuff") or HasPlain(name, "Aura")) then return true end
    return false
end

local restrictedCache = setmetatable({}, { __mode = "k" })

function TE.Core.IsRestrictedTooltip(tooltip)
    if not tooltip then return true end
    if restrictedCache[tooltip] ~= nil then return restrictedCache[tooltip] end

    local restricted = true
    if tooltip and not Safe.IsForbidden(tooltip) then
        local owner = Safe.GetOwner(tooltip)
        restricted = (not owner) or IsAuraOwner(owner)
    end

    restrictedCache[tooltip] = restricted
    return restricted
end

local function ClampAlpha(a)
    a = tonumber(a)
    if not a then return 0.65 end
    if a < 0.05 then return 0.05 end
    if a > 1.00 then return 1.00 end
    return a
end

local function SetTooltipBackgroundAlpha(tooltip)
    local a = ClampAlpha(TESettings.backgroundAlpha)

    if tooltip and tooltip.NineSlice then
        local center = tooltip.NineSlice.Center
        if center and center.SetAlpha then
            pcall(center.SetAlpha, center, a)
        end

        if tooltip.NineSlice.GetBackdropTexture then
            local bg = tooltip.NineSlice:GetBackdropTexture("bg")
            if bg and bg.SetAlpha then
                pcall(bg.SetAlpha, bg, a)
            end
        end
    end

    if tooltip and tooltip.GetBackdropColor and tooltip.SetBackdropColor then
        local ok, r, g, b = pcall(tooltip.GetBackdropColor, tooltip)
        if ok and r then
            pcall(tooltip.SetBackdropColor, tooltip, r, g, b, a)
        end
    end
end

local function BorderColorFromMode(unit)
    local mode = TESettings.borderColorMode or "BLACK"
    if mode == "BLACK" then
        return 0, 0, 0, 1
    end

    if type(unit) ~= "string" then
        return 0, 0, 0, 1
    end

    if mode == "UNIT" then
        local ok, r, g, b = pcall(UnitSelectionColor, unit, true)
        if ok and r and g and b then return r, g, b, 1 end
        return 0, 0, 0, 1
    end

    -- CLASS
    local okC, _, class = pcall(UnitClass, unit)
    if not okC then return 0, 0, 0, 1 end
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b, 1 end
    return 0, 0, 0, 1
end

local function SetTooltipBorderColor(tooltip, unit)
    if not (tooltip and tooltip.NineSlice and tooltip.NineSlice.SetBorderColor) then return end
    local r, g, b, a = BorderColorFromMode(unit)
    pcall(tooltip.NineSlice.SetBorderColor, tooltip.NineSlice, r, g, b, a or 1)
end

function TE.Style.Apply(tooltip, unit)
    if not tooltip or Safe.IsForbidden(tooltip) then return end
    SetTooltipBackgroundAlpha(tooltip)
    SetTooltipBorderColor(tooltip, unit)
end

local function ApplyTooltipRuntime(tooltip)
    if not tooltip or TE.Core.IsRestrictedTooltip(tooltip) then return end

    if TESettings.toggleScaling then
        pcall(tooltip.SetScale, tooltip, (TESettings.tooltipScale or 100) / 100)
    else
        pcall(tooltip.SetScale, tooltip, 1)
    end

    if TESettings.hideTooltip and UnitAffectingCombat and UnitAffectingCombat("player") then
        pcall(tooltip.Hide, tooltip)
        return
    end

    if not (tooltip.IsShown and tooltip:IsShown()) then return end

    local unit = TE.Core.GetTooltipUnit and TE.Core.GetTooltipUnit(tooltip)
    TE.Style.Apply(tooltip, unit)

    -- Keep compatibility with any pre-existing saved variable without
    -- inventing a new default or changing the current settings schema.
    if GameTooltipStatusBarTexture then
        if not defaultHealthBarTexture and GameTooltipStatusBarTexture.GetTexture then
            local ok, texture = pcall(GameTooltipStatusBarTexture.GetTexture, GameTooltipStatusBarTexture)
            if ok then defaultHealthBarTexture = texture end
        end

        if TESettings.hideHealthBar == true then
            pcall(GameTooltipStatusBarTexture.SetTexture, GameTooltipStatusBarTexture, "")
        elseif defaultHealthBarTexture then
            pcall(GameTooltipStatusBarTexture.SetTexture, GameTooltipStatusBarTexture, defaultHealthBarTexture)
        end
    end
end

if GameTooltip and hooksecurefunc and not TE.Style._runtimeInstalled then
    TE.Style._runtimeInstalled = true

    hooksecurefunc(GameTooltip, "Show", function(self)
        ApplyTooltipRuntime(self)
    end)

    hooksecurefunc(GameTooltip, "Hide", function(self)
        restrictedCache[self] = nil
    end)
end

if hooksecurefunc and GameTooltip_SetDefaultAnchor and not TE.Style._anchorInstalled then
    TE.Style._anchorInstalled = true
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if TE.Core.IsRestrictedTooltip(tooltip) then return end
        if IsAuraOwner(parent) then return end
        if InCombatLockdown and InCombatLockdown() then return end
        if not TESettings.toggleAnchor then return end
        pcall(tooltip.SetOwner, tooltip, parent or UIParent, TESettings.anchorPosition or "ANCHOR_CURSOR_RIGHT")
    end)
end
