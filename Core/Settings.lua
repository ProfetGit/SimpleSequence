local _, SS = ...

local Settings = {}
SS.Settings = Settings

local ERROR_SPEECH = "Sound_EnableErrorSpeech"
local AFTER_PRESS = 1
local REMEMBER = 8

-- The errors mashing a key produces. UIErrorsFrame plays an error's sound only when it
-- shows the error, so holding these back from it silences them.
local MASH_ERRORS = {
    "LE_GAME_ERR_SPELL_COOLDOWN", "LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_ITEM_COOLDOWN",
    "LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS", "LE_GAME_ERR_OUT_OF_RANGE", "LE_GAME_ERR_SPELL_OUT_OF_RANGE",
    "LE_GAME_ERR_BADATTACKFACING", "LE_GAME_ERR_BADATTACKPOS", "LE_GAME_ERR_NO_ATTACK_TARGET",
    "LE_GAME_ERR_GENERIC_NO_TARGET", "LE_GAME_ERR_INVALID_ATTACK_TARGET", "LE_GAME_ERR_SPELL_FAILED_S",
    "LE_GAME_ERR_OUT_OF_MANA", "LE_GAME_ERR_OUT_OF_RAGE", "LE_GAME_ERR_OUT_OF_ENERGY",
}

local filter
local silenced = {}
local muted = false

local function muteSounds(on)
    if muted == on then return end
    local change = on and MuteSoundFile or UnmuteSoundFile
    if type(change) ~= "function" then return end
    for _, fileID in ipairs(SS.ERROR_SOUNDS or {}) do
        pcall(change, fileID)
    end
    muted = on
end

local function store()
    if not SS.db then return nil end
    if type(SS.db.options) ~= "table" then SS.db.options = {} end
    return SS.db.options
end

local function mashTypes()
    local types = {}
    for _, name in ipairs(MASH_ERRORS) do
        local value = rawget(_G, name)
        if value ~= nil then types[value] = true end
    end
    return types
end

local function justPressed()
    local pressed = SS.Engine and SS.Engine.lastPressTime
    return pressed ~= nil and GetTime() - pressed <= AFTER_PRESS
end

local function remember(message)
    table.insert(silenced, 1, tostring(message))
    silenced[REMEMBER + 1] = nil
end

local function install()
    local errors = UIErrorsFrame
    if filter or not errors then return end
    local types = mashTypes()
    filter = CreateFrame("Frame")
    filter:SetScript("OnEvent", function(_, event, messageType, message, ...)
        if types[messageType] or justPressed() then
            remember(message)
            return
        end
        local handler = errors:GetScript("OnEvent")
        if handler then handler(errors, event, messageType, message, ...) end
    end)
    errors:UnregisterEvent("UI_ERROR_MESSAGE")
    filter:RegisterEvent("UI_ERROR_MESSAGE")
end

local function uninstall()
    if not filter then return end
    filter:UnregisterEvent("UI_ERROR_MESSAGE")
    filter:SetScript("OnEvent", nil)
    filter = nil
    if UIErrorsFrame then UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end
end

-- 0.5.0 muted error speech for this; that missed the sound, so give the setting back.
local function restoreErrorSpeech(options)
    if options.errorVoiceBefore then
        C_CVar.SetCVar(ERROR_SPEECH, options.errorVoiceBefore)
        options.errorVoiceBefore = nil
    end
end

function Settings:IsMashSilenced()
    local options = store()
    return options ~= nil and options.muteErrorVoice == true
end

function Settings:SetMashSilenced(on)
    local options = store()
    if not options then return end
    options.muteErrorVoice = on == true
    restoreErrorSpeech(options)
    if options.muteErrorVoice then install() else uninstall() end
    muteSounds(options.muteErrorVoice)
    SS:Fire("OPTIONS_CHANGED")
end

function Settings:ToggleMashSilenced()
    local on = not self:IsMashSilenced()
    self:SetMashSilenced(on)
    SS:Print(on and "\"Not ready yet\" errors are silenced: no sound or red text while you mash the key."
        or "\"Not ready yet\" errors are back.")
end

function Settings:SilencedMessages()
    return silenced
end

function Settings:MenuItems()
    local items = {
        {
            text = "Silence \"not ready yet\" errors",
            checked = function() return Settings:IsMashSilenced() end,
            fn = function() Settings:ToggleMashSilenced() end,
        },
    }
    if SS.NextUp then
        items[#items + 1] = {
            text = "Show the next-press icon",
            checked = function() return not (SS.db and SS.db.nextUp and SS.db.nextUp.shown == false) end,
            fn = function() SS.NextUp:Toggle() end,
        }
    end
    if SS.MinimapButton then
        items[#items + 1] = {
            text = "Show the minimap button",
            checked = function() return not (SS.db and SS.db.minimap and SS.db.minimap.hide) end,
            fn = function() SS.MinimapButton:Toggle() end,
        }
    end
    return items
end

SS:On("LOGIN", function()
    local options = store()
    if not options then return end
    restoreErrorSpeech(options)
    if options.muteErrorVoice then
        install()
        muteSounds(true)
    end
end)
