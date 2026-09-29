-- TooltipEnhance_Safe.lua
-- Safe wrappers + "secret string" hardened helpers.

TE = TE or {}
TE.Safe = TE.Safe or {}

local function safe_pcall(obj, methodName, ...)
    if not obj then return false, nil end
    local fn = obj[methodName]
    if type(fn) ~= "function" then return false, nil end
    return pcall(fn, obj, ...)
end
TE.Safe.pcallMethod = safe_pcall

function TE.Safe.IsForbidden(frame)
    local ok, forbidden = safe_pcall(frame, "IsForbidden")
    if not ok then return true end
    return forbidden and true or false
end

function TE.Safe.GetOwner(tooltip)
    local ok, owner = safe_pcall(tooltip, "GetOwner")
    if not ok then return nil end
    return owner
end

function TE.Safe.GetName(frame)
    local ok, name = safe_pcall(frame, "GetName")
    if not ok then return nil end
    return (type(name) == "string") and name or nil
end

function TE.Safe.GetText(fontString)
    local ok, text = safe_pcall(fontString, "GetText")
    if not ok then return nil end
    return (type(text) == "string") and text or nil
end

function TE.Safe.SetText(fontString, text)
    pcall(fontString.SetText, fontString, text)
end

function TE.Safe.StringLen(s)
    if type(s) ~= "string" then return false, 0 end
    local ok, n = pcall(string.len, s)
    if not ok or type(n) ~= "number" then return false, 0 end
    return true, n
end

function TE.Safe.ToString(v)
    local tv = type(v)
    if tv == "string" then
        local ok, n = TE.Safe.StringLen(v)
        if not ok or n <= 0 then return nil end
        return v
    elseif tv == "number" or tv == "boolean" then
        local ok, s = pcall(tostring, v)
        if not ok or type(s) ~= "string" then return nil end
        local ok2, n = TE.Safe.StringLen(s)
        if not ok2 or n <= 0 then return nil end
        return s
    end
    return nil
end

function TE.Safe.StripColorCodes(s)
    if type(s) ~= "string" then return nil end
    local ok1, t = pcall(string.gsub, s, "|c%x%x%x%x%x%x%x%x", "")
    if not ok1 or type(t) ~= "string" then return nil end
    local ok2, t2 = pcall(string.gsub, t, "|r", "")
    if not ok2 or type(t2) ~= "string" then return nil end
    return t2
end