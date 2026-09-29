-- TooltipEnhance_Settings.lua
-- Settings, locale, bitmask helpers, Blizzard Settings UI.
-- Layout: Safety / General / Style (Font under Style)
-- Border mode is always active: BLACK (default) / CLASS / UNIT

TE = TE or {}
TE.Name = TE.Name or "TooltipEnhance"
TESettings = TESettings or {}

local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)

TE.DEFAULTS = {
    enableInInstances = false,

    hideTooltip = false,
    hideHealthBar = false,
    toggleTooltipColor = false,

    toggleAnchor = false,
    anchorPosition = "ANCHOR_CURSOR_RIGHT",

    toggleScaling = false,
    tooltipScale = 100,

    backgroundAlpha = 0.65,
    borderColorMode = "BLACK",

    displayIds = 0,
    displayPlayerInfo = 0,

    tooltipFont = "__DEFAULT__",
    tooltipFontSize = 0,

    activeIds = {},
    activePlayerInfo = {},
}

TE.ID_BITS = {
    unit = 1,
    spell = 2,
    mount = 4,
    item = 8,
    toy = 16,
    currency = 32,
    quest = 64,
    macro = 128,
}

-- Player tooltip extras bitmask
TE.PLAYER_BITS = {
    mount = 1,
    target = 2,
    score = 4,
    rank = 8,
    mplusdetails = 16,
    honor = 32,
    pvp = 64,

    ilvl = 128,      -- Item Level (avg)
    maxilvl = 256,   -- Item Level (max)
}

TE.LOCALE = {
    enUS = {
        header = { safety = "Safety / Scope", general = "General", style = "Style" },

        enableInInstances = {
            label = "Enable in Instances",
            tooltip = "Allow Unit tooltip extras inside dungeons/raids/scenarios (still disabled during combat).",
        },

        hideTooltip = {
            label = "Hide Tooltip in Combat",
            tooltip = "Hide (non-restricted) tooltips while you are in combat.",
        },
        hideHealthBar = {
            label = "Hide Tooltip Health Bar",
            tooltip = "Hide the unit tooltip health bar.",
        },

        toggleAnchor = {
            label = "Cursor Anchor",
            tooltip = "Anchor tooltips to the cursor and choose a position.",
        },
        anchorPosition = { label = "Anchor Position", tooltip = "" },

        toggleScaling = {
            label = "Tooltip Scaling",
            tooltip = "Enable custom scaling for tooltips (non-restricted tooltips).",
        },
        tooltipScale = { label = "Tooltip Scale", tooltip = "Min: 5%  Max: 250%" },

        toggleTooltipColor = {
            label = "Tooltip Coloring",
            tooltip = "Apply class color to player names.",
        },

        displayIds = { label = "Show IDs for", tooltip = "Add selected IDs to tooltips." },
        displayPlayerInfo = { label = "Show Player Info", tooltip = "Show extra information for hovered players." },

        backgroundAlpha = { label = "Background Opacity", tooltip = "Adjust tooltip background opacity." },
        borderColorMode = { label = "Border Color", tooltip = "Choose tooltip border color mode." },
        borderBlack = { label = "Black (Default)" },
        borderClass = { label = "Class Color" },
        borderUnit = { label = "Unit Reaction" },

        tooltipFont = { label = "Tooltip Font", tooltip = "Choose a registered font (LibSharedMedia-3.0)." },
        tooltipFontSize = { label = "Font Size", tooltip = "0 = default size." },

        unit = { label = "Unit" },
        spell = { label = "Spell" },
        mount = { label = "Mount" },
        item = { label = "Item" },
        toy = { label = "Toy" },
        currency = { label = "Currency" },
        quest = { label = "Quest" },
        macro = { label = "Macro" },

        pimount = { label = "Mount (buff)" },
        pitarget = { label = "Target" },
        piscore = { label = "Mythic+ Score" },
        pirank = { label = "Guild Rank" },
        pimplusdetails = { label = "Best M+ Run" },
        pihonor = { label = "Honor Level" },
        pipvp = { label = "PvP Flag" },

        -- Item level options
        piilvl = { label = "Item Level (avg)" },
        pimaxilvl = { label = "Item Level (max)" },
    }
}

local function L()
    return TE.LOCALE[GetLocale()] or TE.LOCALE.enUS
end

local function InitDefaults()
    for k, v in pairs(TE.DEFAULTS) do
        if TESettings[k] == nil then TESettings[k] = v end
    end
end

local function DecodeMask(mask, bits)
    local active = {}
    for key, val in pairs(bits) do
        active[key] = (mask % (val * 2)) >= val
    end
    return active
end

function TE.RebuildCaches()
    TESettings.activeIds = DecodeMask(TESettings.displayIds or 0, TE.ID_BITS)
    TESettings.activePlayerInfo = DecodeMask(TESettings.displayPlayerInfo or 0, TE.PLAYER_BITS)
end

function TE.BuildSettingsUI()
    if TE._uiBuilt then return end
    TE._uiBuilt = true

    InitDefaults()
    TE.RebuildCaches()

    local lang = L()
    local category, layout = Settings.RegisterVerticalLayoutCategory(TE.Name)

    local function AddHeader(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function CreateSetting(key, varType, label, defaultValue)
        local set = Settings.RegisterAddOnSetting(category, key, key, TESettings, varType, label, defaultValue)
        set:SetValueChangedCallback(function(s, v) TESettings[s:GetVariable()] = v end)
        return set
    end

    local function AddCheckbox(key, label, tooltip)
        local set = CreateSetting(key, "boolean", label, TE.DEFAULTS[key])
        Settings.CreateCheckbox(category, set, tooltip)
        return set
    end

    local function BuildAnchorOptions()
        local c = Settings.CreateControlTextContainer()
        c:Add("ANCHOR_CURSOR_LEFT", "Left")
        c:Add("ANCHOR_CURSOR", "Center")
        c:Add("ANCHOR_CURSOR_RIGHT", "Right")
        return c:GetData()
    end

    local function BuildBorderModeOptions()
        local c = Settings.CreateControlTextContainer()
        c:Add("BLACK", lang.borderBlack.label)
        c:Add("CLASS", lang.borderClass.label)
        c:Add("UNIT", lang.borderUnit.label)
        return c:GetData()
    end

    local function BuildIdOptions()
        local c = Settings.CreateControlTextContainer()
        c:AddCheckbox(1, lang.unit.label)
        c:AddCheckbox(2, lang.spell.label)
        c:AddCheckbox(3, lang.mount.label)
        c:AddCheckbox(4, lang.item.label)
        c:AddCheckbox(5, lang.toy.label)
        c:AddCheckbox(6, lang.currency.label)
        c:AddCheckbox(7, lang.quest.label)
        c:AddCheckbox(8, lang.macro.label)
        return c:GetData()
    end

    local function BuildPlayerInfoOptions()
        local c = Settings.CreateControlTextContainer()
        c:AddCheckbox(1, lang.pimount.label)
        c:AddCheckbox(2, lang.pitarget.label)
        c:AddCheckbox(3, lang.piscore.label)
        c:AddCheckbox(4, lang.pirank.label)
        c:AddCheckbox(5, lang.pimplusdetails.label)
        c:AddCheckbox(6, lang.pihonor.label)
        c:AddCheckbox(7, lang.pipvp.label)

        -- Item level options
        c:AddCheckbox(8, lang.piilvl.label)
        c:AddCheckbox(9, lang.pimaxilvl.label)
        return c:GetData()
    end

    local function AddCheckboxDropdown(varKey, label, tooltip, getter, setter, optionBuilder)
        local proxy = Settings.RegisterProxySetting(category, varKey, Settings.VarType.Number, label, 0, getter, setter)
        local init = Settings.CreateDropdown(category, proxy, optionBuilder)
        init.getSelectionTextFunc = function(selections)
            if #selections == 0 then return "None" end
            return nil
        end
        return init
    end

    AddHeader(lang.header.safety)
    AddCheckbox("enableInInstances", lang.enableInInstances.label, lang.enableInInstances.tooltip)

    AddHeader(lang.header.general)
    AddCheckbox("hideTooltip", lang.hideTooltip.label, lang.hideTooltip.tooltip)
    AddCheckbox("hideHealthBar", lang.hideHealthBar.label, lang.hideHealthBar.tooltip)

    do
        local cSet = CreateSetting("toggleAnchor", "boolean", lang.toggleAnchor.label, TE.DEFAULTS.toggleAnchor)
        local dSet = CreateSetting("anchorPosition", "string", lang.anchorPosition.label, TE.DEFAULTS.anchorPosition)
        layout:AddInitializer(CreateSettingsCheckboxDropdownInitializer(
                cSet, lang.toggleAnchor.label, lang.toggleAnchor.tooltip,
                dSet, BuildAnchorOptions
        ))
    end

    do
        local cSet = CreateSetting("toggleScaling", "boolean", lang.toggleScaling.label, TE.DEFAULTS.toggleScaling)
        local sSet = CreateSetting("tooltipScale", "number", lang.tooltipScale.label, TE.DEFAULTS.tooltipScale)

        local opts = Settings.CreateSliderOptions(5, 250, 5)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return v .. "%" end)

        layout:AddInitializer(CreateSettingsCheckboxSliderInitializer(
                cSet, lang.toggleScaling.label, lang.toggleScaling.tooltip,
                sSet, opts,
                lang.tooltipScale.label, lang.tooltipScale.tooltip
        ))
    end

    AddCheckbox("toggleTooltipColor", lang.toggleTooltipColor.label, lang.toggleTooltipColor.tooltip)

    AddCheckboxDropdown(
            "displayIds",
            lang.displayIds.label,
            lang.displayIds.tooltip,
            function() return TESettings.displayIds or 0 end,
            function(v) TESettings.displayIds = v; TE.RebuildCaches() end,
            BuildIdOptions
    )

    AddCheckboxDropdown(
            "displayPlayerInfo",
            lang.displayPlayerInfo.label,
            lang.displayPlayerInfo.tooltip,
            function() return TESettings.displayPlayerInfo or 0 end,
            function(v) TESettings.displayPlayerInfo = v; TE.RebuildCaches() end,
            BuildPlayerInfoOptions
    )

    AddHeader(lang.header.style)

    do
        local sSet = CreateSetting("backgroundAlpha", "number", lang.backgroundAlpha.label, TE.DEFAULTS.backgroundAlpha)
        local opts = Settings.CreateSliderOptions(0.05, 1.00, 0.05)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
            return string.format("%.2f", v)
        end)
        Settings.CreateSlider(category, sSet, opts, lang.backgroundAlpha.tooltip)
    end

    do
        local sSet = CreateSetting("borderColorMode", "string", lang.borderColorMode.label, TE.DEFAULTS.borderColorMode)
        Settings.CreateDropdown(category, sSet, BuildBorderModeOptions, lang.borderColorMode.tooltip)
    end

    if LSM then
        local function BuildFontOptions()
            local c = Settings.CreateControlTextContainer()
            c:Add("__DEFAULT__", "Default")
            local fonts = LSM:List("font")
            table.sort(fonts)
            for _, name in ipairs(fonts) do
                c:Add(name, name)
            end
            return c:GetData()
        end

        do
            local s = CreateSetting("tooltipFont", "string", lang.tooltipFont.label, TE.DEFAULTS.tooltipFont)
            Settings.CreateDropdown(category, s, BuildFontOptions, lang.tooltipFont.tooltip)
            s:SetValueChangedCallback(function(_, v)
                TESettings.tooltipFont = v
                if TE.ApplyTooltipFont then TE.ApplyTooltipFont() end
            end)
        end

        do
            local s = CreateSetting("tooltipFontSize", "number", lang.tooltipFontSize.label, TE.DEFAULTS.tooltipFontSize)
            local opts = Settings.CreateSliderOptions(0, 24, 1)
            opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
                return (v == 0) and "Default" or tostring(v)
            end)
            Settings.CreateSlider(category, s, opts, lang.tooltipFontSize.tooltip)
            s:SetValueChangedCallback(function(_, v)
                TESettings.tooltipFontSize = v
                if TE.ApplyTooltipFont then TE.ApplyTooltipFont() end
            end)
        end
    end

    Settings.RegisterAddOnCategory(category)
end

local settingsLoader = CreateFrame("Frame")
settingsLoader:RegisterEvent("ADDON_LOADED")
settingsLoader:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= TE.Name then return end
    self:UnregisterEvent("ADDON_LOADED")
    TE.BuildSettingsUI()
    if TE.ApplyTooltipFont then TE.ApplyTooltipFont() end
end)
