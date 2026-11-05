local _, SS = ...

local Engine = {}
SS.Engine = Engine

local PRE = [[
if not down then return false end
local count = self:GetAttribute("ss-count") or 0
if count < 1 then return false end
local loopStart = self:GetAttribute("ss-loopstart") or 1
local i = self:GetAttribute("ss-index") or 1
if i > count then i = loopStart end
self:SetAttribute("macrotext", self:GetAttribute("ss-step" .. i))
i = i + 1
if i > count then i = loopStart end
self:SetAttribute("ss-index", i)
]]

local RESET_COMBAT = [[
if tostring(newstate) ~= "0" then return end
local n = self:GetAttribute("ss-nbuttons") or 0
for k = 1, n do
    local b = self:GetFrameRef("b" .. k)
    if b and b:GetAttribute("ss-resetcombat") then
        b:SetAttribute("ss-index", 1)
    end
end
]]

local RESET_TARGET = [[
if tostring(newstate) ~= "0" then return end
local n = self:GetAttribute("ss-nbuttons") or 0
for k = 1, n do
    local b = self:GetFrameRef("b" .. k)
    if b and b:GetAttribute("ss-resettarget") then
        b:SetAttribute("ss-index", 1)
    end
end
]]

local header
local headerReady = false
local buttons = {}
local order = {}
local queue = { setup = false, spec = false, ids = {} }
local pending = false

local function setPending(value)
    if pending ~= value then
        pending = value
        SS:Fire("ENGINE_PENDING", value)
    end
end

local function queueEmpty()
    return not queue.setup and not queue.spec and next(queue.ids) == nil
end

function Engine:ButtonName(id)
    return SS.BUTTON_PREFIX .. id
end

function Engine:IsPending()
    return pending
end

local function ensureHeader()
    if not header then
        header = CreateFrame("Frame", "SimpleSequenceHeader", UIParent, "SecureHandlerStateTemplate")
    end
    return header
end

local function setupHeader()
    ensureHeader()
    header:SetAttribute("ss-nbuttons", #order)
    header:SetAttribute("_onstate-sscombat", RESET_COMBAT)
    header:SetAttribute("_onstate-sstarget", RESET_TARGET)
    RegisterStateDriver(header, "sscombat", "[combat] 1; 0")
    RegisterStateDriver(header, "sstarget", "[@target,exists,nodead] 1; 0")
    for n, id in ipairs(order) do
        header:SetFrameRef("b" .. n, buttons[id])
    end
    headerReady = true
end

local function onPressed(btn, _, down)
    if not down then return end
    Engine.lastPressed = btn.ssId
    SS:Fire("SEQUENCE_PRESSED", btn.ssId)
end

local function onAttribute(btn, name)
    if name == "ss-index" and btn.ssId then
        SS:Fire("SEQUENCE_ADVANCED", btn.ssId)
    end
end

local function getButton(id)
    local btn = buttons[id]
    if btn then
        return btn
    end
    btn = CreateFrame("Button", Engine:ButtonName(id), UIParent, "SecureActionButtonTemplate")
    btn.ssId = id
    btn.ssCount = 0
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("useOnKeyDown", true)
    btn:SetAttribute("ss-count", 0)
    btn:SetAttribute("ss-index", 1)
    SecureHandlerWrapScript(btn, "OnClick", ensureHeader(), PRE)
    btn:HookScript("OnClick", onPressed)
    btn:HookScript("OnAttributeChanged", onAttribute)
    buttons[id] = btn
    order[#order + 1] = id
    header:SetFrameRef("b" .. #order, btn)
    header:SetAttribute("ss-nbuttons", #order)
    return btn
end

local function blank(btn)
    btn:SetAttribute("ss-count", 0)
    btn:SetAttribute("ss-index", 1)
    btn:SetAttribute("macrotext", nil)
    btn.ssEntries = nil
    btn.ssTexts = nil
end

local function applyNow(id)
    local seq = SS.Database:GetSequence(id)
    local btn = buttons[id]
    if not seq and not btn then
        return
    end
    btn = btn or getButton(id)
    if not seq or seq.specID ~= SS.currentSpec then
        blank(btn)
        return
    end

    local compiled = SS.Compiler:Compile(seq)
    if not compiled.ok or compiled.count < 1 then
        blank(btn)
        return
    end

    btn:SetAttribute("ss-count", 0)
    for i = 1, math.max(btn.ssCount or 0, compiled.count) do
        btn:SetAttribute("ss-step" .. i, compiled.steps[i])
    end
    btn.ssCount = compiled.count
    btn:SetAttribute("ss-loopstart", compiled.loopStart)
    btn:SetAttribute("ss-resetcombat", seq.reset.combat and true or false)
    btn:SetAttribute("ss-resettarget", seq.reset.target and true or false)
    btn:SetAttribute("macrotext", nil)
    btn:SetAttribute("ss-index", 1)
    btn:SetAttribute("ss-count", compiled.count)
    btn.ssEntries = compiled.entries
    btn.ssTexts = compiled.steps
end

local function applySpecNow(specID)
    for _, id in ipairs(order) do
        local seq = SS.Database:GetSequence(id)
        if not seq or seq.specID ~= specID then
            blank(buttons[id])
        end
    end
    for _, seq in ipairs(SS.Database:GetSequences(specID)) do
        applyNow(seq.id)
    end
end

local function flush()
    if queueEmpty() then
        setPending(false)
        return
    end
    local doSetup, doSpec, ids = queue.setup, queue.spec, queue.ids
    queue = { setup = false, spec = false, ids = {} }
    if doSetup or not headerReady then
        setupHeader()
    end
    if doSpec then
        applySpecNow(SS.currentSpec)
    else
        for id in pairs(ids) do
            applyNow(id)
        end
    end
    setPending(false)
end

function Engine:Apply(id)
    if not id then return end
    if InCombatLockdown() then
        queue.ids[id] = true
        setPending(true)
        return
    end
    if not headerReady then
        setupHeader()
    end
    applyNow(id)
end

function Engine:ApplySpec(specID)
    specID = specID or SS.currentSpec
    if InCombatLockdown() then
        queue.spec = true
        setPending(true)
        return
    end
    if not headerReady then
        setupHeader()
    end
    applySpecNow(specID)
end

function Engine:Reset(id)
    if InCombatLockdown() then
        SS:Print("A sequence can only be restarted outside combat. It restarts by itself when combat ends.")
        return false
    end
    if id then
        local btn = buttons[id]
        if btn then
            btn:SetAttribute("ss-index", 1)
        end
    else
        for _, btn in pairs(buttons) do
            btn:SetAttribute("ss-index", 1)
        end
    end
    if Engine.lastPressed then
        SS:Fire("SEQUENCE_PRESSED", Engine.lastPressed)
    end
    return true
end

function Engine:GetNextIndex(id)
    local btn = buttons[id]
    return btn and btn:GetAttribute("ss-index") or 1
end

function Engine:GetProgress(id)
    local btn = buttons[id]
    if not btn then return nil end
    local count = btn:GetAttribute("ss-count") or 0
    if count < 1 then return nil end
    return btn:GetAttribute("ss-index") or 1, count, btn:GetAttribute("ss-loopstart") or 1
end

function Engine:GetNextEntry(id)
    local btn = buttons[id]
    if not btn or not btn.ssEntries then
        return nil
    end
    local index = btn:GetAttribute("ss-index") or 1
    return btn.ssEntries[index] or btn.ssEntries[btn:GetAttribute("ss-loopstart") or 1]
end

function Engine:DebugLines(id)
    local lines = {}
    local seq = SS.Database:GetSequence(id)
    local btn = buttons[id]
    lines[#lines + 1] = "Sequence: " .. (seq and seq.name or "?") .. " (" .. tostring(id) .. ")"
    lines[#lines + 1] = "Button: " .. self:ButtonName(id) .. (btn and "" or " (not created yet)")
    lines[#lines + 1] = "Key: " .. tostring(seq and seq.key or "none")
    lines[#lines + 1] = "Waiting for combat to end: " .. tostring(pending)
    if btn then
        lines[#lines + 1] = "Next index: " .. tostring(btn:GetAttribute("ss-index"))
            .. "  count: " .. tostring(btn:GetAttribute("ss-count"))
            .. "  loop starts at: " .. tostring(btn:GetAttribute("ss-loopstart"))
        for i = 1, btn.ssCount or 0 do
            local text = btn:GetAttribute("ss-step" .. i) or ""
            lines[#lines + 1] = "Step " .. i .. ": " .. text:gsub("\n", " | ")
        end
    end
    return lines
end

SS:On("LOGIN", function()
    if InCombatLockdown() then
        queue.setup = true
        queue.spec = true
        setPending(true)
    else
        setupHeader()
        applySpecNow(SS.currentSpec)
    end
end)

SS:On("SPEC_CHANGED", function(specID)
    Engine:ApplySpec(specID)
end)

SS:On("SEQUENCE_UPDATED", function(id)
    Engine:Apply(id)
end)

SS:On("SEQUENCES_CHANGED", function()
    Engine:ApplySpec(SS.currentSpec)
end)

SS:On("COMBAT_ENDED", function()
    flush()
    C_Timer.After(0.2, function()
        if Engine.lastPressed then
            SS:Fire("SEQUENCE_PRESSED", Engine.lastPressed)
        end
    end)
end)
