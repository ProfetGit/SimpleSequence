local _, SS = ...

local Theme = SS.Theme
local StepPopover = {}
SS.StepPopover = StepPopover

local FRAME_NAME = "SimpleSequenceStepPopover"
local WIDTH, PAD = 288, 14
local SLOT = 28
local ICON_CROP = 0.08
local MODS = {
    { key = "shift", label = "Hold Shift for:" },
    { key = "ctrl", label = "Hold Ctrl for:" },
    { key = "alt", label = "Hold Alt for:" },
}
local TARGETS = {
    { value = "target", text = "Target" },
    { value = "player", text = "Me" },
    { value = "mouseover", text = "Mouseover (else target)" },
    { value = "focus", text = "Focus (else target)" },
}
local TARGET_TEXT = {}
for _, option in ipairs(TARGETS) do TARGET_TEXT[option.value] = option.text end
local OFTEN = {
    { value = 1, text = "Every time" },
    { value = 2, text = "Every 2nd time" },
    { value = 3, text = "Every 3rd time" },
    { value = 4, text = "Every 4th time" },
}
local OFTEN_TEXT = {}
for _, option in ipairs(OFTEN) do OFTEN_TEXT[option.value] = option.text end
local OFTEN_HEIGHT = 40

local HELP = "Modifiers let one button do two jobs: hold Shift to cast the other spell instead."

local frame, state

local function currentStep()
    if not state then return nil end
    local seq = SS.Database and SS.Database:GetSequence(state.id)
    local list = seq and seq[state.section]
    return list and list[state.index], seq
end

local function entryName(entry)
    return entry and SS.Compiler and SS.Compiler.EntryName(entry) or "Unknown"
end

local function entryIcon(entry)
    return entry and SS.Compiler and SS.Compiler.EntryIcon(entry) or Theme.assets.unknownItem.file
end

local function setMod(mod, entry)
    if not state then return end
    SS.Database:SetStepMod(state.id, state.section, state.index, mod, entry)
end

local function buildSlot(parent, mod)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetSize(SLOT, SLOT)
    Theme:Fill(slot, "SURFACE")
    Theme:FlatBorder(slot)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 1, -1)
    slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    slot.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    slot.plus = Theme:Text(slot, "+", "title", "TEXT_MUTED")
    slot.plus:SetPoint("CENTER", 0, 1)
    slot.armedFill = Theme:Fill(slot, "HIGHLIGHT", "OVERLAY")
    slot.armedFill:Hide()
    slot.hoverTex = Theme:Texture(slot, "listHover", "OVERLAY")
    slot.hoverTex:SetAllPoints()
    slot.hover = Theme:Fader(slot.hoverTex, 0.08, 0.13)
    slot.mod = mod
    return slot
end

local function isArmed(mod)
    local armed = StepPopover.armed
    return armed and state and armed.id == state.id and armed.section == state.section
        and armed.index == state.index and armed.mod == mod
end

local function arm(mod)
    if not state then return end
    if isArmed(mod) then
        StepPopover.armed = nil
    else
        StepPopover.armed = { id = state.id, section = state.section, index = state.index, mod = mod }
    end
    StepPopover:Update()
end

local function dropEntry(mod, entry)
    if entry and entry.kind then
        StepPopover.armed = nil
        setMod(mod, entry)
        return true
    end
    return false
end

local function wireSlot(row)
    local slot, mod = row.slot, row.mod
    slot:SetScript("OnClick", function() arm(mod) end)
    slot:SetScript("OnEnter", function(widget)
        widget.hover:To(1)
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        GameTooltip:AddLine(widget.entryName or "Empty slot", 1, 1, 1)
        local r, g, b = unpack(Theme.colors.TEXT_MUTED)
        GameTooltip:AddLine("Drop a spell here, or click and then click a spell on the right", r, g, b, true)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function(widget)
        widget.hover:To(0)
        GameTooltip:Hide()
    end)
    SS.DragDrop:RegisterTarget(slot, {
        accept = function(payload) return payload.type == "entry" end,
        onEnter = function() slot.hover:To(1) end,
        onLeave = function() slot.hover:To(0) end,
        onDrop = function(payload) return dropEntry(mod, payload.entry) end,
        onCursorDrop = function(entry) return dropEntry(mod, entry) end,
    })
end

local function close()
    if not frame then return end
    frame:Hide()
end

local function build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetSize(WIDTH, 300)
    Theme:Fill(frame, "SURFACE")
    Theme:FlatBorder(frame)
    frame:Hide()
    table.insert(UISpecialFrames, 1, FRAME_NAME)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(28, 28)
    frame.icon:SetPoint("TOPLEFT", PAD, -PAD)
    frame.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    frame.name = Theme:Text(frame, "", "title", "TEXT_TITLE")
    frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 10, 0)
    frame.name:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.name:SetWordWrap(false)

    local line = Theme:Divider(frame)
    line:SetPoint("TOPLEFT", PAD, -(PAD + 28 + 10))
    line:SetPoint("TOPRIGHT", -PAD, -(PAD + 28 + 10))

    local top = PAD + 28 + 20
    frame.cast = Theme:Dropdown(frame, WIDTH - PAD * 2, TARGETS,
        function(value)
            local step = currentStep()
            return step ~= nil and (step.target or "target") == value
        end,
        function(value)
            if state then
                SS.Database:SetStepTarget(state.id, state.section, state.index, value)
            end
        end)
    frame.cast:SetPoint("TOPLEFT", PAD, -top)
    frame.cast:SetLabel("Cast on")

    frame.often = Theme:Dropdown(frame, WIDTH - PAD * 2, OFTEN,
        function(value)
            local step = currentStep()
            return step ~= nil and (step.every or 1) == value
        end,
        function(value)
            if state then
                SS.Database:SetStepEvery(state.id, state.section, state.index, value)
            end
        end)
    frame.often:SetPoint("TOPLEFT", PAD, -(top + 40))
    frame.often:SetLabel("How often")

    frame.rows = {}
    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", 0, -(top + 40))
    frame.body:SetPoint("TOPRIGHT", 0, -(top + 40))
    frame.body:SetHeight(1)
    frame.baseHeight = top + 40
    local rowTop = 0
    for i, def in ipairs(MODS) do
        local row = { mod = def.key }
        row.label = Theme:Text(frame, def.label, "body", "TEXT_BODY")
        row.slot = buildSlot(frame, def.key)
        row.name = Theme:Text(frame, "", "small", "TEXT_MUTED")
        row.name:SetWordWrap(false)
        row.clear = CreateFrame("Button", nil, frame)
        row.clear:SetSize(20, 20)
        row.clear.text = Theme:Text(row.clear, "x", "body", "TEXT_MUTED")
        row.clear.text:SetPoint("CENTER")
        row.clear:SetScript("OnEnter", function(widget) Theme:Color(widget.text, "TEXT_HIGHLIGHT", true) end)
        row.clear:SetScript("OnLeave", function(widget) Theme:Color(widget.text, "TEXT_MUTED", true) end)
        row.clear:SetScript("OnClick", function()
            StepPopover.armed = nil
            setMod(def.key, nil)
        end)
        local y = -(rowTop + (i - 1) * 36)
        row.label:SetPoint("TOPLEFT", frame.body, "TOPLEFT", PAD, y - 6)
        row.slot:SetPoint("TOPLEFT", frame.body, "TOPLEFT", PAD + 108, y)
        row.clear:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, y - 4)
        row.name:SetPoint("LEFT", row.slot, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row.clear, "LEFT", -4, 0)
        wireSlot(row)
        frame.rows[i] = row
    end

    local helpTop = rowTop + 3 * 36 + 4
    frame.help = Theme:Text(frame, HELP, "small", "TEXT_MUTED")
    frame.help:SetPoint("TOPLEFT", frame.body, "TOPLEFT", PAD, -helpTop)
    frame.help:SetWidth(WIDTH - PAD * 2)
    frame.help:SetWordWrap(true)
    frame.help:SetJustifyV("TOP")

    local line2 = Theme:Divider(frame)
    line2:SetPoint("TOPLEFT", frame.body, "TOPLEFT", PAD, -(helpTop + 44))
    line2:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", -PAD, -(helpTop + 44))

    frame.remove = Theme:ListButton(frame, WIDTH - PAD * 2, 26, "Remove step", function()
        if not state then return end
        local id, section, index = state.id, state.section, state.index
        close()
        if SS.Editor and SS.Editor.RemoveStep then
            SS.Editor:RemoveStep(id, section, index)
        else
            SS.Database:RemoveStep(id, section, index)
        end
    end)
    frame.remove:SetPoint("TOPLEFT", frame.body, "TOPLEFT", PAD, -(helpTop + 52))
    frame.bodyHeight = helpTop + 52 + 26 + PAD
    frame:SetHeight(frame.baseHeight + frame.bodyHeight)

    frame:SetScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    frame:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        StepPopover.armed = nil
        state = nil
        GameTooltip:Hide()
    end)
    frame:SetScript("OnEvent", function(self, _, button)
        if not state or button == nil then return end
        if self:IsMouseOver() or (state.anchor and state.anchor:IsMouseOver()) then return end
        for _, dropdown in ipairs({ self.cast, self.often }) do
            local menuButton = dropdown and dropdown.button
            if menuButton and type(menuButton.IsMenuOpen) == "function" and menuButton:IsMenuOpen() then return end
        end
        local sidebar = SS.SpellSidebar and SS.SpellSidebar.frame
        if StepPopover.armed and sidebar and sidebar:IsMouseOver() then return end
        close()
    end)
end

function StepPopover:Update()
    if not frame or not frame:IsShown() or not state then return end
    local step, seq = currentStep()
    if not step or not seq then
        close()
        return
    end
    frame.icon:SetTexture(entryIcon(step.entry))
    frame.name:SetText(entryName(step.entry))
    local target = step.target or "target"
    frame.cast:SetValueText(TARGET_TEXT[target] or TARGET_TEXT.target)
    local inLoop = state.section == "loop"
    frame.often:SetShown(inLoop)
    if inLoop then
        frame.often:SetValueText(OFTEN_TEXT[step.every or 1] or OFTEN_TEXT[1])
    end
    local offset = inLoop and OFTEN_HEIGHT or 0
    frame.body:ClearAllPoints()
    frame.body:SetPoint("TOPLEFT", 0, -(frame.baseHeight + offset))
    frame.body:SetPoint("TOPRIGHT", 0, -(frame.baseHeight + offset))
    frame:SetHeight(frame.baseHeight + offset + frame.bodyHeight)
    local mods = step.mods or {}
    for _, row in ipairs(frame.rows) do
        local entry = mods[row.mod]
        local armed = isArmed(row.mod)
        row.slot.entryName = entry and entryName(entry) or nil
        if entry then
            row.slot.icon:SetTexture(entryIcon(entry))
            row.slot.icon:Show()
            row.slot.plus:Hide()
            row.name:SetText(entryName(entry))
        else
            row.slot.icon:Hide()
            row.slot.plus:Show()
            row.name:SetText(armed and "Now click a spell on the right" or "")
        end
        row.slot.armedFill:SetShown(armed and true or false)
        row.clear:SetShown(entry ~= nil)
        Theme:Color(row.name, armed and "TEXT_TITLE" or "TEXT_MUTED", true)
    end
end

function StepPopover:Open(anchor, id, section, index)
    if not frame then build() end
    if frame:IsShown() and state and state.id == id and state.section == section and state.index == index then
        close()
        return
    end
    if frame:IsShown() then
        StepPopover.armed = nil
    end
    state = { id = id, section = section, index = index, anchor = anchor }
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    frame:Show()
    self:Update()
end

function StepPopover:Close()
    close()
end

function StepPopover:IsOpen()
    return frame ~= nil and frame:IsShown()
end

function StepPopover:ConsumeArmed(entry)
    local armed = self.armed
    if not armed or not state then return false end
    self.armed = nil
    if armed.id ~= state.id or armed.section ~= state.section or armed.index ~= state.index then
        self:Update()
        return false
    end
    SS.Database:SetStepMod(armed.id, armed.section, armed.index, armed.mod, entry)
    return true
end

SS:On("SEQUENCE_UPDATED", function(id)
    if state and state.id == id then
        StepPopover:Update()
    end
end)

local function closeOnChange()
    close()
end

SS:On("SELECTION_CHANGED", closeOnChange)
SS:On("SPEC_CHANGED", closeOnChange)
