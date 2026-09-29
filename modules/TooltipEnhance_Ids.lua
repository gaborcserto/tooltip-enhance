-- TooltipEnhance_Ids.lua
-- ID rendering helpers.

TE = TE or {}
TE.Ids = TE.Ids or {}

local Safe = TE.Safe

local function AddPrefixed(tooltip, prefix, text)
    if not tooltip or Safe.IsForbidden(tooltip) then return end

    if type(prefix) ~= "string" then return end
    local okP, pLen = Safe.StringLen(prefix)
    if not okP or pLen <= 0 then return end

    local s = Safe.ToString(text)
    if not s then return end
    local okS, sLen = Safe.StringLen(s)
    if not okS or sLen <= 0 then return end

    pcall(tooltip.AddDoubleLine, tooltip, "|cffffd100" .. prefix .. ":", "|cffffffff" .. s)
    pcall(tooltip.Show, tooltip)
end

function TE.Ids.AddTooltipId(tooltip, id, key)
    if key == "unitaura" then return end
    if not id then return end
    if not (TESettings.activeIds and TESettings.activeIds[key]) then return end
    AddPrefixed(tooltip, key:upper() .. " ID", id)
end

function TE.Ids.AddUnitId(tooltip, unit)
    if not (TESettings.activeIds and TESettings.activeIds.unit) then return end
    if type(unit) ~= "string" then return end

    local okG, guid = pcall(UnitGUID, unit)
    if not okG or type(guid) ~= "string" then return end

    local id = guid:match("^[^%-]+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-.+")
    if id then
        AddPrefixed(tooltip, "UNIT ID", id)
    end
end

local idTypes = {
    Spell = "spell",
    Mount = "mount",
    Item = "item",
    Toy = "toy",
    Currency = "currency",
    Quest = "quest",
    Macro = "macro",
}

if TooltipDataProcessor and Enum and Enum.TooltipDataType
        and TooltipDataProcessor.AddTooltipPostCall then
    for enumKey, settingKey in pairs(idTypes) do
        local tooltipType = Enum.TooltipDataType[enumKey]
        if tooltipType then
            TooltipDataProcessor.AddTooltipPostCall(tooltipType, function(tooltip, data)
                if TE.Core and TE.Core.IsRestrictedTooltip
                        and TE.Core.IsRestrictedTooltip(tooltip) then
                    return
                end

                TE.Ids.AddTooltipId(tooltip, data and data.id, settingKey)
                if TE.Style and TE.Style.Apply then
                    local unit = TE.Core and TE.Core.GetTooltipUnit
                            and TE.Core.GetTooltipUnit(tooltip, data)
                    TE.Style.Apply(tooltip, unit)
                end
            end)
        end
    end
end

if hooksecurefunc and QuestMapLogTitleButton_OnEnter and not TE.Ids._questHookInstalled then
    TE.Ids._questHookInstalled = true
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(button)
        if not button or not button.questID then return end
        if TE.Core and TE.Core.IsRestrictedTooltip
                and TE.Core.IsRestrictedTooltip(GameTooltip) then
            return
        end
        TE.Ids.AddTooltipId(GameTooltip, button.questID, "quest")
    end)
end
