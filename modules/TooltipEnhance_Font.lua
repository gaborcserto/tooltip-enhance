-- TooltipEnhance_Font.lua
-- Tooltip font support (LibSharedMedia-3.0 optional)

TE = TE or {}
local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)

function TE.ApplyTooltipFont()
    if not LSM then return end
    if not TESettings.tooltipFont or TESettings.tooltipFont == "__DEFAULT__" then return end

    local path = LSM:Fetch("font", TESettings.tooltipFont, true)
    if not path then return end

    local sizeOverride = tonumber(TESettings.tooltipFontSize or 0) or 0

    for i = 1, 30 do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]

        if left then
            local ok, _, sz, flags = pcall(left.GetFont, left)
            if ok then
                pcall(left.SetFont, left, path, (sizeOverride > 0) and sizeOverride or sz, flags)
            end
        end

        if right then
            local ok, _, sz, flags = pcall(right.GetFont, right)
            if ok then
                pcall(right.SetFont, right, path, (sizeOverride > 0) and sizeOverride or sz, flags)
            end
        end
    end
end