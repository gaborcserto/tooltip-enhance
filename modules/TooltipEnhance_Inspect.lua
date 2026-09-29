-- TooltipEnhance_Inspect.lua
-- Inspect cache + iLvl avg/max.

TE = TE or {}
TE.Inspect = TE.Inspect or {}

local CACHE_TTL = 30
local INSPECT_REQUEST_COOLDOWN = 1.25
local INSPECT_PENDING_TIMEOUT = 2.0

local InspectCache = {}
local pendingGUID, pendingUnit, pendingRequestedAt

local function Now()
    return (GetTime and GetTime()) or 0
end

local function IsInspectUIBusy()
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return true end
    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then return true end
    return false
end

local function ClearTooltipInspectState()
    pendingGUID, pendingUnit, pendingRequestedAt = nil, nil, nil
end

local function FinishTooltipInspectRequest()
    ClearTooltipInspectState()
    if C_Timer and C_Timer.After and ClearInspectPlayer and not IsInspectUIBusy() then
        C_Timer.After(0, function()
            if ClearInspectPlayer and not IsInspectUIBusy() then
                pcall(ClearInspectPlayer)
            end
        end)
    end
end

local function ComputeMaxEquippedIlvl(unit)
    local maxIlvl = 0
    if not (unit and GetInventoryItemLink and GetDetailedItemLevelInfo) then return 0 end

    local slots = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17 }
    for i = 1, #slots do
        local slot = slots[i]
        local okL, link = pcall(GetInventoryItemLink, unit, slot)
        if okL and link then
            local okI, ilvl = pcall(GetDetailedItemLevelInfo, link)
            if okI and type(ilvl) == "number" and ilvl > maxIlvl then
                maxIlvl = ilvl
            end
        end
    end
    return maxIlvl
end

-- SAFE TEXT ACCESS
TE.Safe = TE.Safe or {}
function TE.Safe.GetText(fs)
    if not fs then return nil end
    local ok, text = pcall(fs.GetText, fs)
    if ok then return text end
    return nil
end

function TE.Inspect.GetCache(guid)
    return InspectCache[guid]
end

function TE.Inspect.Ensure(unit, isRestrictedTooltip)
    if type(unit) ~= "string" then return end
    if isRestrictedTooltip then return end
    if UnitAffectingCombat("player") or InCombatLockdown() then return end

    local wantAvg = TESettings.activePlayerInfo and TESettings.activePlayerInfo.ilvl
    local wantMax = TESettings.activePlayerInfo and TESettings.activePlayerInfo.maxilvl
    if not (wantAvg or wantMax) then return end

    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP or not isPlayer then return end

    local okG, guid = pcall(UnitGUID, unit)
    if not okG or type(guid) ~= "string" then return end

    local tNow = Now()
    local c = InspectCache[guid]

    if c and (tNow - (c.last or 0)) < CACHE_TTL then return end
    if c and (tNow - (c.requestAt or 0)) < INSPECT_REQUEST_COOLDOWN then return end

    local okU, isMe = pcall(UnitIsUnit, unit, "player")
    if okU and isMe then
        local ilvl
        if GetAverageItemLevel then
            local _, eq = GetAverageItemLevel()
            if type(eq) == "number" and eq > 0 then
                ilvl = tonumber(string.format("%.1f", eq))
            end
        end
        local maxIlvl = ComputeMaxEquippedIlvl("player")
        InspectCache[guid] = {
            ilvl = ilvl,
            maxilvl = maxIlvl,
            last = tNow,
        }
        return
    end

    if IsInspectUIBusy() then
        ClearTooltipInspectState()
        return
    end

    if pendingGUID and pendingRequestedAt and (tNow - pendingRequestedAt) >= INSPECT_PENDING_TIMEOUT then
        FinishTooltipInspectRequest()
    end

    if CanInspect and NotifyInspect and not InCombatLockdown() then
        local okC, can = pcall(CanInspect, unit)
        if not okC or not can then return end

        local cacheEntry = c or {}
        cacheEntry.requestAt = tNow
        InspectCache[guid] = cacheEntry

        pendingGUID = guid
        pendingUnit = unit
        pendingRequestedAt = tNow
        pcall(NotifyInspect, unit)
    end
end

-- Find a tooltip line by label.
local function FindLineIndexByLabel(tt, label)
    if not (tt and label) then return nil end

    local name = tt.GetName and tt:GetName()
    if not name then return nil end

    local n = (tt.NumLines and tt:NumLines()) or 0
    for i = 1, n do
        local left = _G[name .. "TextLeft" .. i]
        if left then
            local text = TE.Safe.GetText(left)
            if type(text) == "string" then
                local ok, found = pcall(string.find, text, label, 1, true)
                if ok and found then
                    return i
                end
            end
        end
    end
    return nil
end

local function UpdateOrAddRightLine(tt, label, value)
    if not (tt and label and value ~= nil) then return end

    local idx = FindLineIndexByLabel(tt, label)

    if idx then
        local right = _G[tt:GetName() .. "TextRight" .. idx]
        if right and right.SetText then
            pcall(right.SetText, right, tostring(value))
        end
    else
        tt:AddDoubleLine("|cffffd200" .. label .. "|r", tostring(value))
    end

    pcall(tt.Show, tt)
end

local function RefreshTooltipForGUID(guid)
    if not (GameTooltip and GameTooltip:IsShown()) then return end

    local unit = TE.Core and TE.Core.GetTooltipUnit and TE.Core.GetTooltipUnit(GameTooltip)
    if not unit then return end

    local okG, uGuid = pcall(UnitGUID, unit)
    if not okG or uGuid ~= guid then return end

    local c = InspectCache[guid]
    if not c then return end

    if TESettings.activePlayerInfo and TESettings.activePlayerInfo.ilvl and c.ilvl then
        local label = STAT_AVERAGE_ITEM_LEVEL or ITEM_LEVEL or "Item Level"
        UpdateOrAddRightLine(GameTooltip, label .. ":", c.ilvl)
    end

    if TESettings.activePlayerInfo and TESettings.activePlayerInfo.maxilvl and c.maxilvl then
        UpdateOrAddRightLine(GameTooltip, "Max Item Level", c.maxilvl)
    end

    if TE.PlayerExtras and TE.PlayerExtras.AddTargetAtBottom then
        TE.PlayerExtras.AddTargetAtBottom(GameTooltip, unit)
    end
end

-- INSPECT_READY
local fInspect = CreateFrame("Frame")
fInspect:RegisterEvent("INSPECT_READY")

fInspect:SetScript("OnEvent", function(_, _, guid)
    if type(guid) ~= "string" then return end
    if pendingGUID ~= guid then return end

    local unit = pendingUnit
    FinishTooltipInspectRequest()

    if not unit or not UnitExists(unit) then return end

    local okCurrentGUID, currentGUID = pcall(UnitGUID, unit)
    if not okCurrentGUID or currentGUID ~= guid then return end

    local function ReadAvgIlvl(u)
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            local ok, v = pcall(C_PaperDollInfo.GetInspectItemLevel, u)
            if ok and type(v) == "number" and v > 0 then
                return tonumber(string.format("%.1f", v))
            end
        end
    end

    local function ReadMaxIlvl(u)
        local v = ComputeMaxEquippedIlvl(u)
        if v > 0 then return v end
    end

    local c = InspectCache[guid] or {}
    c.ilvl = ReadAvgIlvl(unit)
    c.maxilvl = ReadMaxIlvl(unit)
    c.last = Now()
    InspectCache[guid] = c

    RefreshTooltipForGUID(guid)
end)
