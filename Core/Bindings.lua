local addonName, SS = ...

local Bindings = {}
SS.Bindings = Bindings

local MACRO_NAME_MAX = 16
local DEFAULT_ICON = 134400
local UNDO_GRACE = 60
local liveIcons = true
local owner = CreateFrame("Frame")
local needsApply = false
local macroQueue = {}
local deleteQueue = {}

local function macroLimits()
    local consts = Constants and Constants.MacroConsts
    return (consts and consts.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120,
        (consts and consts.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 30
end

local function macroBody(id)
    return "#showtooltip\n/click " .. SS.Engine:ButtonName(id) .. " LeftButton true"
end

-- The question-mark icon lets the action button show whatever SetMacroSpell points at.
local function macroIcon(seq)
    if seq.icon then return seq.icon end
    if liveIcons then return DEFAULT_ICON end
    local first = (seq.loop and seq.loop[1]) or (seq.opener and seq.opener[1])
    return first and SS.Compiler.EntryIcon(first.entry) or DEFAULT_ICON
end

local function showNextOnMacro(id)
    if not liveIcons then return end
    local seq = SS.Database:GetSequence(id)
    if not seq or not seq.macroName or seq.specID ~= SS.currentSpec then return end
    local index = GetMacroIndexByName(seq.macroName)
    if not index or index == 0 then return end
    local entry = SS.Engine:GetNextWait(id) or SS.Engine:GetNextEntry(id)
    if not entry then return end
    local kind = entry.kind
    if kind == "spell" or kind == "pet" then
        local name = C_Spell.GetSpellName(entry.id)
        if name then pcall(SetMacroSpell, index, name) end
    elseif kind == "item" then
        pcall(SetMacroItem, index, "item:" .. entry.id)
    elseif kind == "slot" then
        local itemID = GetInventoryItemID("player", entry.id)
        if itemID then pcall(SetMacroItem, index, "item:" .. itemID) end
    end
end
Bindings.ShowNextOnMacro = showNextOnMacro

local function showNextOnAllMacros()
    for _, seq in ipairs(SS.Database:GetSequences(SS.currentSpec)) do
        showNextOnMacro(seq.id)
    end
end

-- A name is taken if any macro has it, unless it is this sequence's own macro.
local function isNameFree(name, seq)
    local index = GetMacroIndexByName(name)
    if not index or index == 0 then
        return true
    end
    return seq.macroName == name
end

local function claimedByOther(name, seq)
    for id, other in pairs(SS.db.sequences) do
        if id ~= seq.id and other.macroName == name then
            return true
        end
    end
    return false
end

local function uniqueMacroName(seq)
    local base = (SS.MACRO_PREFIX .. seq.name):sub(1, MACRO_NAME_MAX):gsub("%s+$", "")
    local name = base
    local n = 1
    while not isNameFree(name, seq) or claimedByOther(name, seq) do
        n = n + 1
        local suffix = " " .. n
        name = base:sub(1, MACRO_NAME_MAX - #suffix):gsub("%s+$", "") .. suffix
    end
    return name
end

function Bindings:ApplyAll()
    if InCombatLockdown() then
        needsApply = true
        return
    end
    needsApply = false
    ClearOverrideBindings(owner)
    for _, seq in ipairs(SS.Database:GetSequences(SS.currentSpec)) do
        if seq.key then
            SetOverrideBindingClick(owner, false, seq.key, SS.Engine:ButtonName(seq.id), "LeftButton")
        end
    end
end

function Bindings:SetKey(id, key)
    local seq = SS.Database:GetSequence(id)
    if not seq then
        return false, "That sequence no longer exists."
    end
    if key then
        for _, other in ipairs(SS.Database:GetSequences(seq.specID)) do
            if other.id ~= id and other.key == key then
                return false, "\"" .. other.name .. "\" already uses that key."
            end
        end
    end
    SS.Database:SetKeyRaw(id, key)
    self:ApplyAll()
    return true
end

function Bindings:GetConflict(key)
    if not key or key == "" then
        return nil
    end
    local action = GetBindingAction(key, true)
    if not action or action == "" then
        return nil
    end
    if action:find("CLICK " .. SS.BUTTON_PREFIX, 1, true) then
        return nil
    end
    local label = _G["BINDING_NAME_" .. action]
    if label then
        return label
    end
    local target = action:match("^CLICK (.-):")
    if target then
        return "Click on " .. target
    end
    return action
end

-- Returns the macro index, or nil and a message for the player.
function Bindings:EnsureMacro(seq)
    if InCombatLockdown() then
        return nil, "You can't change macros during combat. Try again after the fight."
    end
    local body, icon = macroBody(seq.id), macroIcon(seq)
    local index = seq.macroName and GetMacroIndexByName(seq.macroName) or 0
    if index and index > 0 then
        local name = uniqueMacroName(seq)
        local newIndex = EditMacro(index, name, icon, body)
        seq.macroName = name
        showNextOnMacro(seq.id)
        return newIndex or GetMacroIndexByName(name)
    end

    local _, numCharacter = GetNumMacros()
    local _, maxCharacter = macroLimits()
    if numCharacter >= maxCharacter then
        return nil, "Your character macro slots are full. Delete one in /macro and try again."
    end
    local name = uniqueMacroName(seq)
    local created = CreateMacro(name, icon, body, true)
    if not created then
        return nil, "Could not create the macro. Delete one in /macro and try again."
    end
    seq.macroName = name
    showNextOnMacro(seq.id)
    return created
end

function Bindings:PutOnActionBar(id)
    if InCombatLockdown() then
        return false, "You can't put macros on the bars during combat. Try again after the fight."
    end
    local seq = SS.Database:GetSequence(id)
    if not seq then
        return false, "That sequence no longer exists."
    end
    local index, err = self:EnsureMacro(seq)
    if not index then
        return false, err
    end
    PickupMacro(index)
    return true
end

local function refreshMacro(id)
    local seq = SS.Database:GetSequence(id)
    if not seq or not seq.macroName then
        return
    end
    local index = GetMacroIndexByName(seq.macroName)
    if index and index > 0 then
        Bindings:EnsureMacro(seq)
    end
end

local function deleteOwnedMacro(name, id)
    local index = GetMacroIndexByName(name)
    if not index or index == 0 then
        return
    end
    local body = GetMacroBody(index)
    if body and body:find(SS.Engine:ButtonName(id), 1, true) then
        DeleteMacro(index)
    end
end

local function flush()
    if needsApply then
        Bindings:ApplyAll()
    end
    for id in pairs(macroQueue) do
        refreshMacro(id)
    end
    macroQueue = {}
    for id, name in pairs(deleteQueue) do
        deleteOwnedMacro(name, id)
    end
    deleteQueue = {}
end

local function warnIfDataLost()
    if SS.Database:CountAll() > 0 then
        return
    end
    local _, numCharacter = GetNumMacros()
    local first = (macroLimits()) + 1
    for index = first, first + (numCharacter or 0) - 1 do
        local name = GetMacroInfo(index)
        if name and name:sub(1, #SS.MACRO_PREFIX) == SS.MACRO_PREFIX then
            SS:Print("Your saved sequences did not load, but this character still has SimpleSequence macros. "
                .. "If you made a backup, restore it with /seq import.")
            return
        end
    end
end

SS:On("LOGIN", function()
    Bindings:ApplyAll()
    warnIfDataLost()
    C_Timer.After(1, function()
        if InCombatLockdown() then
            showNextOnAllMacros()
            return
        end
        for _, seq in ipairs(SS.Database:GetSequences(SS.currentSpec)) do
            refreshMacro(seq.id)
        end
    end)
end)

SS:On("SPEC_CHANGED", function()
    Bindings:ApplyAll()
    showNextOnAllMacros()
end)

SS:On("SEQUENCE_ADVANCED", showNextOnMacro)

local function stopLiveIcons(_, culprit, fn)
    if culprit ~= addonName or type(fn) ~= "string" or not fn:find("SetMacro", 1, true) then return end
    if not liveIcons then return end
    liveIcons = false
    SS:Print("This version of the game blocks changing macro icons during combat, so action-bar icons stay fixed for this session.")
    for id, seq in pairs(SS.db.sequences) do
        if seq.macroName then macroQueue[id] = true end
    end
    if not InCombatLockdown() then flush() end
end

SS:RegisterGameEvent("ADDON_ACTION_BLOCKED", stopLiveIcons)
SS:RegisterGameEvent("ADDON_ACTION_FORBIDDEN", stopLiveIcons)

SS:On("SEQUENCES_CHANGED", function()
    Bindings:ApplyAll()
end)

SS:On("SEQUENCE_UPDATED", function(id)
    if InCombatLockdown() then
        macroQueue[id] = true
    else
        refreshMacro(id)
    end
    Bindings:ApplyAll()
end)

SS:On("SEQUENCE_DELETED", function(id, seq)
    if not seq or not seq.macroName then
        return
    end
    local name = seq.macroName
    C_Timer.After(UNDO_GRACE, function()
        if SS.Database:GetSequence(id) then
            return
        end
        if InCombatLockdown() then
            deleteQueue[id] = name
        else
            deleteOwnedMacro(name, id)
        end
    end)
end)

SS:On("COMBAT_ENDED", flush)
