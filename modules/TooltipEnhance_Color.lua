-- TooltipEnhance_Color.lua
-- Player name class coloring for unit tooltips.

TE = TE or {}
TE.Core = TE.Core or {}
TE.Color = TE.Color or {}

local Safe = TE.Safe
local IsSecretValue = issecretvalue

local function IsUsableString(value)
    if type(value) ~= "string" then return false end
    if type(IsSecretValue) ~= "function" then return true end

    local ok, isSecret = pcall(IsSecretValue, value)
    return ok and not isSecret
end

local function SafeBooleanCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    if not ok then return false end

    local okCompare, isTrue = pcall(function(v) return v == true end, value)
    return okCompare and isTrue
end

local function UnitMatchesGuid(unit, guid)
    if not IsUsableString(unit) then return false end
    if not SafeBooleanCall(UnitExists, unit) then return false end
    if not guid then return true end

    local okGuid, unitGuid = pcall(UnitGUID, unit)
    if not okGuid or not IsUsableString(unitGuid) then return false end

    local okMatch, matches = pcall(function(a, b) return a == b end, unitGuid, guid)
    return okMatch and matches
end

function TE.Core.GetTooltipUnit(tooltip, data)
    if not tooltip or Safe.IsForbidden(tooltip) then return nil end

    local guid = data and data.guid
    if not IsUsableString(guid) then guid = nil end

    if tooltip.GetUnit then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if ok and UnitMatchesGuid(unit, guid) then return unit end
    end

    if guid and type(UnitTokenFromGUID) == "function" then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and UnitMatchesGuid(unit, guid) then return unit end
    end

    if tooltip == GameTooltip and WorldFrame and WorldFrame.IsMouseMotionFocus then
        if SafeBooleanCall(WorldFrame.IsMouseMotionFocus, WorldFrame)
                and UnitMatchesGuid("mouseover", guid) then
            return "mouseover"
        end
    end

    return nil
end

local function GetPlayerClass(unit, data)
    local guid = data and data.guid
    if IsUsableString(guid) and type(GetPlayerInfoByGUID) == "function" then
        local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
        if ok and IsUsableString(class) then return class end

        -- The tooltip GUID is authoritative. Do not fall back to a potentially
        -- stale unit token when Blizzard supplied a usable GUID.
        return nil
    end

    if type(unit) ~= "string" then return nil end
    if not SafeBooleanCall(UnitIsPlayer, unit) then return nil end

    local ok, _, class = pcall(UnitClass, unit)
    if ok and IsUsableString(class) then return class end
    return nil
end

function TE.Color.Apply(tooltip, unit, data)
    if not TESettings.toggleTooltipColor then return end
    local class = GetPlayerClass(unit, data)
    if not class then return end

    local okColor, color = pcall(function()
        return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    end)
    if not okColor or not color then return end

    local tooltipName = Safe.GetName(tooltip)
    local nameLine = tooltipName and _G[tooltipName .. "TextLeft1"]
    if nameLine and nameLine.SetTextColor then
        pcall(nameLine.SetTextColor, nameLine, color.r, color.g, color.b)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if tooltip ~= GameTooltip then return end
        if TE.Core.IsRestrictedTooltip and TE.Core.IsRestrictedTooltip(tooltip) then return end
        if not TESettings.toggleTooltipColor then return end
        local unit = TE.Core.GetTooltipUnit(tooltip, data)
        TE.Color.Apply(tooltip, unit, data)
    end)
end
