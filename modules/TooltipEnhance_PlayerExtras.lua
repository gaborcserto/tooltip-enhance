-- TooltipEnhance_PlayerExtras.lua
-- Player tooltip extras (mount/score/rank/pvp/ilvl/target).

TE = TE or {}
TE.PlayerExtras = TE.PlayerExtras or {}
TE.Safe = TE.Safe or {}

local Safe = TE.Safe

-- --------------------------------------------------------------------
-- Safe helpers fallbackok
-- --------------------------------------------------------------------

if type(Safe.ToString) ~= "function" then
    function Safe.ToString(v)
        if v == nil then return nil end
        local ok, s = pcall(tostring, v)
        if ok and type(s) == "string" then return s end
        return nil
    end
end

if type(Safe.GetText) ~= "function" then
    function Safe.GetText(fs)
        if not fs then return nil end
        local ok, text = pcall(fs.GetText, fs)
        if ok then return text end
        return nil
    end
end

if type(Safe.SetText) ~= "function" then
    function Safe.SetText(fs, text)
        if not (fs and fs.SetText) then return false end
        local s = Safe.ToString(text)
        if not s then return false end
        return pcall(fs.SetText, fs, s)
    end
end

if type(Safe.IsForbidden) ~= "function" then
    function Safe.IsForbidden(frame)
        if not frame then return true end
        if frame.IsForbidden then
            local ok, v = pcall(frame.IsForbidden, frame)
            if ok and v == true then
                return true
            end
        end
        return false
    end
end

if type(Safe.StringLen) ~= "function" then
    function Safe.StringLen(s)
        if type(s) ~= "string" then return false, 0 end
        local ok, n = pcall(string.len, s)
        if ok and type(n) == "number" then
            return true, n
        end
        return false, 0
    end
end

if type(Safe.StripColorCodes) ~= "function" then
    function Safe.StripColorCodes(s)
        if type(s) ~= "string" then return nil end
        local ok, out = pcall(function(str)
            str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
            str = string.gsub(str, "|r", "")
            return str
        end, s)
        if ok and type(out) == "string" then
            return out
        end
        return nil
    end
end

local function SafeBooleanCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    if not ok then return false end

    local okEq, isTrue = pcall(function(x) return x == true end, v)
    if okEq and isTrue then
        return true
    end

    return false
end

local function SafeValueCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

local function SafeValueCall2(fn, ...)
    if type(fn) ~= "function" then return nil, nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil, nil
end

local function SafeValueCall3(fn, ...)
    if type(fn) ~= "function" then return nil, nil, nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil, nil, nil
end

local function SafeUnitExists(unit)
    return type(unit) == "string" and SafeBooleanCall(UnitExists, unit)
end

local function SafeUnitIsUnit(a, b)
    return type(a) == "string" and type(b) == "string" and SafeBooleanCall(UnitIsUnit, a, b)
end

local function SafeUnitIsPlayer(unit)
    return type(unit) == "string" and SafeBooleanCall(UnitIsPlayer, unit)
end

local function SafeUnitIsPVP(unit)
    return type(unit) == "string" and SafeBooleanCall(UnitIsPVP, unit)
end

local function SafeGetFullUnitName(unit)
    if type(unit) ~= "string" then return nil end

    local rawName, rawRealm = SafeValueCall2(UnitName, unit)
    local nameS = Safe.ToString(rawName)
    if not nameS or nameS == "" then return nil end

    local realmS = Safe.ToString(rawRealm)
    if realmS and realmS ~= "" then
        return nameS .. "-" .. realmS
    end

    return nameS
end

local function SafeStringFind(haystack, needle, plain)
    if type(haystack) ~= "string" or type(needle) ~= "string" then return false end
    local ok, found = pcall(string.find, haystack, needle, 1, plain == true)
    return ok and found ~= nil
end

local function SafeStringMatch(haystack, pattern)
    if type(haystack) ~= "string" or type(pattern) ~= "string" then return false end
    local ok, found = pcall(string.match, haystack, pattern)
    return ok and found ~= nil
end

local function SafeConcat(a, b)
    local sa = Safe.ToString(a)
    local sb = Safe.ToString(b)
    if not sa or not sb then return nil end
    return sa .. sb
end

local function SafeColoredName(unit, fullName)
    if type(fullName) ~= "string" or fullName == "" then return nil end

    if SafeUnitIsPlayer(unit) then
        local _, class = SafeValueCall3(UnitClass, unit)
        class = Safe.ToString(class)
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            if c then
                if c.colorStr and type(c.colorStr) == "string" then
                    return "|c" .. c.colorStr .. fullName .. "|r"
                elseif type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
                    local ok, colored = pcall(string.format, "|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, fullName)
                    if ok and type(colored) == "string" then
                        return colored
                    end
                end
            end
        end
    end

    return "|cffffffff" .. fullName .. "|r"
end

-- tiny cache for mount aura scan
local lastMountScan = { guid = nil, t = 0, name = nil }

local function Now()
    return (GetTime and GetTime()) or 0
end

local function IsAuraMount(aura)
    if aura and aura.spellId and C_MountJournal and C_MountJournal.GetMountFromSpell then
        local ok, mountID = pcall(C_MountJournal.GetMountFromSpell, aura.spellId)
        return ok and mountID ~= nil
    end
    return false
end

local function AllowUnitExtrasNow()
    if SafeBooleanCall(UnitAffectingCombat, "player") then return false end
    if SafeBooleanCall(InCombatLockdown) then return false end

    if IsInInstance then
        local ok, inInstance = pcall(IsInInstance)
        if ok and inInstance == true and not TESettings.enableInInstances then
            return false
        end
    end

    return true
end

local function AddPrefixed(tooltip, prefix, text)
    if not tooltip or Safe.IsForbidden(tooltip) then return end
    if type(prefix) ~= "string" then return end

    local okP, pLen = Safe.StringLen(prefix)
    if not okP or pLen <= 0 then return end

    local s = Safe.ToString(text)
    if not s then return end

    local tooltipName = Safe.GetName and Safe.GetName(tooltip)
    local lineCount = tooltip.NumLines and tooltip:NumLines() or 0
    local label = prefix .. ":"

    if tooltipName then
        for i = 1, lineCount do
            local left = _G[tooltipName .. "TextLeft" .. i]
            local leftText = left and Safe.GetText(left)
            local plainText = leftText and Safe.StripColorCodes(leftText)
            if plainText == label then
                local right = _G[tooltipName .. "TextRight" .. i]
                if right and right.SetText then
                    pcall(right.SetText, right, "|cffffffff" .. s)
                    pcall(tooltip.Show, tooltip)
                    return
                end
            end
        end
    end

    pcall(tooltip.AddDoubleLine, tooltip, "|cffffd100" .. label, "|cffffffff" .. s)
    pcall(tooltip.Show, tooltip)
end

local function GetPlayerMythicPlusInfo(unit)
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then return nil end
    return SafeValueCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
end

local function AddMythicPlusInfo(tooltip, info)
    if not info then return end

    if TESettings.activePlayerInfo.score
            and type(info.currentSeasonScore) == "number"
            and info.currentSeasonScore > 0 then
        AddPrefixed(tooltip, "Mythic+ Score", info.currentSeasonScore)
    end

    if not (TESettings.activePlayerInfo.mplusdetails and type(info.runs) == "table") then return end

    local bestLevel, bestMap = 0, nil
    for _, run in next, info.runs do
        if run then
            local finished = (run.finishedSuccess == true)
            local level = run.bestRunLevel
            if finished and type(level) == "number" and level > bestLevel then
                bestLevel = level
                bestMap = run.challengeModeID
            end
        end
    end

    if bestLevel <= 0 then return end

    local dungeon = nil
    if bestMap and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        dungeon = SafeValueCall(C_ChallengeMode.GetMapUIInfo, bestMap)
    end

    if dungeon and type(dungeon) == "string" then
        local ok, txt = pcall(string.format, "%d (%s)", bestLevel, dungeon)
        AddPrefixed(tooltip, "Best M+ Run", (ok and txt) or tostring(bestLevel))
    else
        AddPrefixed(tooltip, "Best M+ Run", bestLevel)
    end
end

local function AddGuildInfo(tooltip, unit)
    if not TESettings.activePlayerInfo.rank then return false end

    local guildName, guildRank = SafeValueCall2(GetGuildInfo, unit)
    local guildNameS = Safe.ToString(guildName)
    local guildRankS = Safe.ToString(guildRank)
    if not guildNameS then return false end

    local tooltipName = Safe.GetName and Safe.GetName(tooltip)
    local lineCount = tooltip.NumLines and tooltip:NumLines() or 0
    if tooltipName then
        for i = 1, lineCount do
            local left = _G[tooltipName .. "TextLeft" .. i]
            local leftText = left and Safe.GetText(left)
            local plainText = leftText and Safe.StripColorCodes(leftText)
            if plainText and SafeStringFind(plainText, guildNameS, true) then
                if guildRankS and not SafeStringFind(plainText, guildRankS, true) then
                    Safe.SetText(left, leftText .. " - " .. guildRankS)
                end
                return true
            end
        end
    end

    local value = guildNameS .. (guildRankS and (" - " .. guildRankS) or "")
    AddPrefixed(tooltip, GUILD or "Guild", value)
    return true
end

local pendingRefresh = {}

local function SchedulePlayerInfoRefresh(tooltip, unit, needMythicPlus, needGuild)
    if not (C_Timer and C_Timer.After) then return end

    local guid = Safe.ToString(SafeValueCall(UnitGUID, unit))
    if not guid or pendingRefresh[guid] then return end
    pendingRefresh[guid] = true

    C_Timer.After(0.1, function()
        pendingRefresh[guid] = nil
        if not (tooltip and tooltip.IsShown and tooltip:IsShown()) then return end

        local currentUnit = TE.Core and TE.Core.GetTooltipUnit
                and TE.Core.GetTooltipUnit(tooltip)
        if type(currentUnit) ~= "string" then return end

        local currentGUID = Safe.ToString(SafeValueCall(UnitGUID, currentUnit))
        if currentGUID ~= guid then return end

        if needGuild then
            AddGuildInfo(tooltip, currentUnit)
        end
        if needMythicPlus then
            AddMythicPlusInfo(tooltip, GetPlayerMythicPlusInfo(currentUnit))
        end

        if TESettings.activePlayerInfo.target then
            TE.PlayerExtras.AddTargetAtBottom(tooltip, currentUnit)
        end
    end)
end

-- -------- Target (single line, always bottom, hide other target lines) --------
local function RemoveAnyTargetLines(tt)
    if not (tt and tt.GetName) then return end
    local name = tt:GetName()
    if not name then return end

    local label = TARGET or "Target"
    local n = (tt.NumLines and tt:NumLines()) or 0

    for i = 1, n do
        local left = _G[name .. "TextLeft" .. i]
        if left then
            local okText, t = pcall(Safe.GetText, left)
            if okText and type(t) == "string" then
                local s = Safe.StripColorCodes(t)
                if type(s) == "string" then
                    local exactPattern = "^%s*" .. label .. "%s*:?%s*$"
                    local startsPattern = "^%s*" .. label .. "%s*:"
                    local match1 = SafeStringMatch(s, exactPattern)
                    local match2 = SafeStringMatch(s, startsPattern)

                    if match1 or match2 then
                        pcall(left.SetText, left, "")
                        local right = _G[name .. "TextRight" .. i]
                        if right and right.SetText then
                            pcall(right.SetText, right, "")
                        end
                    end
                end
            end
        end
    end
end

function TE.PlayerExtras.AddTargetAtBottom(tt, unit)
    if not tt then return end
    RemoveAnyTargetLines(tt)

    if not (TESettings.activePlayerInfo and TESettings.activePlayerInfo.target) then return end
    if type(unit) ~= "string" then return end

    local isMe = SafeUnitIsUnit("player", unit)
    local tu = isMe and "target" or (unit .. "target")

    if not SafeUnitExists(tu) then return end

    local full = SafeGetFullUnitName(tu)
    if not full then return end

    local colored
    local isSelfTarget = SafeUnitIsUnit(tu, "player")
    if isSelfTarget then
        colored = "|cffff0000" .. (YOU or "YOU") .. "|r"
    else
        colored = SafeColoredName(tu, full)
    end

    if not colored then return end

    local label = TARGET or "Target"
    pcall(tt.AddDoubleLine, tt, "|cffffd200" .. label .. ":|r", colored)
    pcall(tt.Show, tt)
end

-- -------- Main extras --------
function TE.PlayerExtras.Apply(tooltip, unit, isRestrictedTooltip)
    if isRestrictedTooltip then return end
    if not AllowUnitExtrasNow() then return end
    if not TESettings.activePlayerInfo then return end
    if type(unit) ~= "string" then return end

    if TESettings.activePlayerInfo.mount then
        local mGuid = SafeValueCall(UnitGUID, unit)
        local now = Now()

        local canUseCache =
        type(mGuid) == "string" and
                lastMountScan.guid == mGuid and
                (now - (lastMountScan.t or 0)) < 0.35

        if canUseCache then
            if lastMountScan.name then
                AddPrefixed(tooltip, "Mount", lastMountScan.name)
            end
        else
            lastMountScan.guid = type(mGuid) == "string" and mGuid or nil
            lastMountScan.t = now
            lastMountScan.name = nil

            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                for i = 1, 40 do
                    local aura = SafeValueCall(C_UnitAuras.GetAuraDataByIndex, unit, i)
                    if aura and aura.name and IsAuraMount(aura) then
                        local auraName = Safe.ToString(aura.name)
                        if auraName then
                            lastMountScan.name = auraName
                            AddPrefixed(tooltip, "Mount", auraName)
                        end
                        break
                    end
                end
            end
        end
    end

    local needM = (TESettings.activePlayerInfo.score == true) or (TESettings.activePlayerInfo.mplusdetails == true)
    local info = needM and GetPlayerMythicPlusInfo(unit) or nil
    AddMythicPlusInfo(tooltip, info)

    if TESettings.activePlayerInfo.honor then
        local hl = SafeValueCall(UnitHonorLevel, unit)
        if type(hl) == "number" and hl > 0 then
            AddPrefixed(tooltip, "Honor Level", hl)
        end
    end

    if TESettings.activePlayerInfo.pvp and SafeUnitIsPVP(unit) then
        local line = _G["GameTooltipTextLeft1"]
        if line then
            local t = Safe.GetText(line)
            if type(t) == "string" then
                local okT, len = Safe.StringLen(t)
                if okT and len > 0 then
                    local hasPvp = SafeStringFind(t, "%(PVP%)", false)
                    if not hasPvp then
                        local newText = SafeConcat(t, " (" .. (PVP or "PVP") .. ")")
                        if newText then
                            Safe.SetText(line, newText)
                        end
                    end
                end
            end
        end
    end

    local hasGuildInfo = AddGuildInfo(tooltip, unit)

    if (needM and not info) or (TESettings.activePlayerInfo.rank and not hasGuildInfo) then
        SchedulePlayerInfoRefresh(
                tooltip,
                unit,
                needM and not info,
                TESettings.activePlayerInfo.rank and not hasGuildInfo
        )
    end

    -- iLvl/Max iLvl (Inspect module)
    if TESettings.activePlayerInfo.ilvl or TESettings.activePlayerInfo.maxilvl then
        if TE.Inspect and TE.Inspect.Ensure then
            TE.Inspect.Ensure(unit, isRestrictedTooltip)
        end

        local guid = SafeValueCall(UnitGUID, unit)
        if type(guid) == "string" and TE.Inspect and TE.Inspect.GetCache then
            local c = TE.Inspect.GetCache(guid)
            if c then
                if TESettings.activePlayerInfo.ilvl and type(c.ilvl) == "number" and c.ilvl > 0 then
                    local label = STAT_AVERAGE_ITEM_LEVEL or ITEM_LEVEL or "Item Level"
                    pcall(tooltip.AddDoubleLine, tooltip, "|cffffd200" .. (label .. ":") .. "|r", tostring(c.ilvl))
                end

                if TESettings.activePlayerInfo.maxilvl and type(c.maxilvl) == "number" and c.maxilvl > 0 then
                    pcall(tooltip.AddDoubleLine, tooltip, "|cffffd200Max Item Level|r", tostring(c.maxilvl))
                end

                pcall(tooltip.Show, tooltip)
            end
        end
    end

    -- Target ALWAYS last line
    if TESettings.activePlayerInfo.target then
        TE.PlayerExtras.AddTargetAtBottom(tooltip, unit)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if tooltip ~= GameTooltip then return end

        if TE.Core and TE.Core.IsRestrictedTooltip
                and TE.Core.IsRestrictedTooltip(tooltip) then
            return
        end

        local unit = TE.Core and TE.Core.GetTooltipUnit
                and TE.Core.GetTooltipUnit(tooltip, data)
        if not unit or not SafeUnitIsPlayer(unit) then return end

        if TE.Ids and TE.Ids.AddUnitId then
            TE.Ids.AddUnitId(tooltip, unit)
        end
        TE.PlayerExtras.Apply(tooltip, unit, false)
        if TE.Style and TE.Style.Apply then
            TE.Style.Apply(tooltip, unit)
        end
    end)
end
