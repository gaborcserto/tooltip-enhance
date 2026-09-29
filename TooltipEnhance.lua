-- TooltipEnhance.lua
-- Bootstrap only.

TE = TE or {}
TE.Name = "TooltipEnhance"

TESettings = TESettings or {}

TE._uiBuilt = TE._uiBuilt or false
TE._installed = TE._installed or false

function TE.EnsureTable(parent, key)
    if not parent[key] then parent[key] = {} end
    return parent[key]
end
