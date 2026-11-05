local addonName, SS = ...
_G.SimpleSequence = SS

SS.name = addonName
SS.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
SS.BUTTON_PREFIX = "SimpleSequenceBtn_"
SS.MACRO_PREFIX = "SS "
SS.MAX_STEPS = 64
SS.MAX_EXTRAS = 8
SS.MAX_EVERY = 4
SS.MAX_COMPILED = 240
SS.MAX_STEP_TEXT = 1023

-- Saved variables are restored before the first addon file runs; Forever beta handed
-- them back empty, so record what the client gave before Database:Init touches it.
SS.loadProbe = {
    hadTable = type(_G.SimpleSequenceDB) == "table",
    hadData = type(_G.SimpleSequenceDB) == "table" and next(_G.SimpleSequenceDB) ~= nil,
}

local listeners = {}

function SS:On(event, fn)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
    end
    list[#list + 1] = fn
end

function SS:Off(event, fn)
    local list = listeners[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then
            table.remove(list, i)
        end
    end
end

function SS:Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            geterrorhandler()(err)
        end
    end
end

local eventFrame = CreateFrame("Frame")
local gameHandlers = {}

function SS:RegisterGameEvent(event, fn)
    local list = gameHandlers[event]
    if not list then
        list = {}
        gameHandlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

function SS:RegisterUnitGameEvent(event, unit, fn)
    local list = gameHandlers[event]
    if not list then
        list = {}
        gameHandlers[event] = list
        eventFrame:RegisterUnitEvent(event, unit)
    end
    list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = gameHandlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            geterrorhandler()(err)
        end
    end
end)

function SS:Print(...)
    print("|cffe8c27dSimpleSequence|r:", ...)
end

local debounced = {}

function SS:Debounce(key, seconds, fn)
    local timer = debounced[key]
    if timer then
        timer:Cancel()
    end
    debounced[key] = C_Timer.NewTimer(seconds, function()
        debounced[key] = nil
        fn()
    end)
end

function SS:InCombat()
    return InCombatLockdown()
end

-- 0 is the bucket for characters without a specialization yet (low level).
function SS:GetSpecID()
    local index = C_SpecializationInfo.GetSpecialization()
    if not index or index == 0 then
        return 0
    end
    local specID = C_SpecializationInfo.GetSpecializationInfo(index)
    return specID or 0
end

function SS:GetSpecLabel()
    local index = C_SpecializationInfo.GetSpecialization()
    if index and index > 0 then
        local _, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(index)
        local className = UnitClass("player")
        if name then
            if not className or className == name then
                return name, icon
            end
            return name .. " " .. className, icon
        end
    end
    return UnitClass("player") or "", nil
end

SS.currentSpec = 0

local function updateSpec()
    local specID = SS:GetSpecID()
    if specID ~= SS.currentSpec or not SS.specKnown then
        local old = SS.currentSpec
        SS.currentSpec = specID
        SS.specKnown = true
        SS:Fire("SPEC_CHANGED", specID, old)
    end
end

SS:RegisterGameEvent("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    SS.Database:Init()
    SS:Fire("DB_READY")
end)

SS:RegisterGameEvent("PLAYER_LOGIN", function()
    SS.currentSpec = SS:GetSpecID()
    SS.specKnown = true
    SS:Fire("LOGIN", SS.currentSpec)
end)

SS:RegisterUnitGameEvent("PLAYER_SPECIALIZATION_CHANGED", "player", updateSpec)
SS:RegisterGameEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", updateSpec)

SS:RegisterGameEvent("PLAYER_REGEN_ENABLED", function()
    SS:Fire("COMBAT_ENDED")
end)

SS:RegisterGameEvent("PLAYER_REGEN_DISABLED", function()
    SS:Fire("COMBAT_STARTED")
end)

function SimpleSequence_OnCompartmentClick()
    if SS.Window then
        SS.Window:Toggle()
    end
end
