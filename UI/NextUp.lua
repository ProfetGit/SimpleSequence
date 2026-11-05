local _, SS = ...
local Theme = SS.Theme
local Widgets = SS.Widgets
local NextUp = {}
SS.NextUp = NextUp

local SIZE, ICON_INSET = 36, 2
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.6, 2.0, 0.2
local UNKNOWN_ICON = 134400
local PULSE_TIME = 0.12
local CHECK_EVERY = 0.2

local VALID_POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

local frame
local editing = false
local EDIT_LABEL = "Next press"

local function settings()
    return SS.db and SS.db.nextUp
end

local function currentId()
    return SS.Engine and SS.Engine.lastPressed
end

local function applyPoint()
    local saved = settings() and settings().point
    frame:ClearAllPoints()
    if type(saved) == "table" and VALID_POINTS[saved[1]] and VALID_POINTS[saved[2]]
        and type(saved[3]) == "number" and type(saved[4]) == "number" then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
end

local function applyScale()
    local scale = settings() and settings().scale or 1
    frame:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, scale)))
end

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point and settings() then
        settings().point = { point, relativePoint, x, y }
    end
end

local function setScale(delta)
    local data = settings()
    if not data then return end
    local scale = (data.scale or 1) + delta
    data.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, math.floor(scale * 10 + 0.5) / 10))
    applyScale()
    applyPoint()
end

local function hideForGood()
    if settings() then settings().shown = false end
    frame:Hide()
    SS:Print("Show it again with /seq nextup")
end

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function itemFor(entry)
    if entry.kind == "item" then return entry.id end
    if entry.kind == "slot" then return GetInventoryItemID("player", entry.id) end
    return nil
end

local function updateCooldown()
    local cd = frame.cd
    local entry = frame.entry
    if not entry then
        cd:Clear()
        return
    end
    if entry.kind == "spell" or entry.kind == "pet" then
        if C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
            local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, entry.id)
            if ok and duration and pcall(cd.SetCooldownFromDurationObject, cd, duration) then return end
        end
        local ok, info = pcall(C_Spell.GetSpellCooldown, entry.id)
        if ok and info and pcall(cd.SetCooldown, cd, info.startTime, info.duration) then return end
    else
        local itemID = itemFor(entry)
        if itemID then
            local ok, start, duration = pcall(C_Item.GetItemCooldown, itemID)
            if ok and start and pcall(cd.SetCooldown, cd, start, duration) then return end
        end
    end
    cd:Clear()
end

local function updateTint()
    local entry = frame.entry
    local icon = frame.icon
    local usable, noPower, inRange = true, false, nil
    if entry and (entry.kind == "spell" or entry.kind == "pet") then
        local ok, isUsable, insufficient = pcall(C_Spell.IsSpellUsable, entry.id)
        if ok then
            usable = plain(isUsable) ~= false
            noPower = plain(insufficient) == true
        end
        if UnitExists("target") then
            local okRange, result = pcall(C_Spell.IsSpellInRange, entry.id, "target")
            if okRange then inRange = plain(result) end
        end
    end
    if inRange == false then
        icon:SetVertexColor(unpack(Theme.colors.TEXT_ERROR))
    elseif noPower then
        icon:SetVertexColor(unpack(Theme.colors.NO_POWER))
    else
        icon:SetVertexColor(1, 1, 1, 1)
    end
    icon:SetDesaturated(not usable and not noPower)
end

local function updateCounter(id)
    local index, count, loopStart = SS.Engine:GetProgress(id)
    if not index then
        frame.counter:SetText("")
        return
    end
    if index < loopStart then
        frame.counter:SetText(index .. "/" .. (loopStart - 1))
        Theme:Color(frame.counter, "TEXT_WARNING", true)
    else
        frame.counter:SetText((index - loopStart + 1) .. "/" .. (count - loopStart + 1))
        Theme:Color(frame.counter, "TEXT_HIGHLIGHT", true)
    end
end

local function showTooltip(widget)
    local id = currentId()
    local entry = id and SS.Engine:GetNextEntry(id)
    if not entry then return end
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
    local kind = entry.kind
    if kind == "spell" or kind == "pet" then
        GameTooltip:SetSpellByID(entry.id)
    elseif kind == "item" then
        GameTooltip:SetItemByID(entry.id)
    elseif kind == "slot" then
        local itemID = GetInventoryItemID("player", entry.id)
        if itemID then
            GameTooltip:SetItemByID(itemID)
        else
            GameTooltip:AddLine("Empty trinket slot")
        end
    else
        GameTooltip:AddLine(SS.Compiler.EntryName(entry) or tostring(entry.id))
    end
    local seq = SS.Database:GetSequence(id)
    local r, g, b = unpack(Theme.colors.TEXT_MUTED)
    GameTooltip:AddLine("Next press of " .. (seq and seq.name or "your sequence"), r, g, b)
    GameTooltip:AddLine("Move it in Edit Mode, or Shift-drag it. Right-click for options.", r, g, b, true)
    GameTooltip:Show()
end

local function build()
    frame = CreateFrame("Button", "SimpleSequenceNextUp", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForClicks("RightButtonUp")
    frame:RegisterForDrag("LeftButton")
    Theme:Fill(frame, "TILE_BG")
    Theme:FlatBorder(frame)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
    frame.icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cd:SetAllPoints(frame.icon)
    frame.cd:SetDrawEdge(false)
    frame.counter = Theme:Text(frame, "", "small", "TEXT_HIGHLIGHT")
    frame.counter:SetParent(frame.cd)
    frame.counter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(widget, elapsed)
        widget.elapsed = widget.elapsed + elapsed
        if widget.elapsed < CHECK_EVERY then return end
        widget.elapsed = 0
        updateTint()
    end)
    frame.pulse = frame.icon:CreateAnimationGroup()
    local pulse = frame.pulse:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.35)
    pulse:SetToAlpha(1)
    pulse:SetDuration(PULSE_TIME)
    pulse:SetSmoothing("OUT")
    frame:SetScript("OnDragStart", function(widget)
        if IsShiftKeyDown() then widget:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget:StopMovingOrSizing()
        savePoint()
    end)
    local function showMenu(owner)
        Widgets:ContextMenu(owner, {
            { text = "Hide", fn = hideForGood },
            { text = "Bigger", fn = function() setScale(SCALE_STEP) end },
            { text = "Smaller", fn = function() setScale(-SCALE_STEP) end },
        })
    end
    frame:SetScript("OnClick", function(widget, button)
        if button == "RightButton" then showMenu(widget) end
    end)

    local selection = Theme:EditModeSelection(frame, EDIT_LABEL)
    frame.selection = selection
    selection.label:ClearAllPoints()
    selection.label:SetPoint("BOTTOM", selection, "TOP", 0, 6)
    selection:SetScript("OnEnter", function(widget) widget:SetSelected(true) end)
    selection:SetScript("OnLeave", function(widget) widget:SetSelected(widget.dragging == true) end)
    selection:SetScript("OnDragStart", function(widget)
        widget.dragging = true
        widget:SetSelected(true)
        frame:StartMoving()
    end)
    selection:SetScript("OnDragStop", function(widget)
        widget.dragging = nil
        frame:StopMovingOrSizing()
        savePoint()
        widget:SetSelected(widget:IsMouseOver())
    end)
    selection:SetScript("OnMouseUp", function(widget, button)
        if button == "RightButton" then showMenu(widget) end
    end)
    frame:SetScript("OnEnter", showTooltip)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    applyPoint()
    applyScale()
    frame:Hide()
end

local function previewEntry()
    local id = SS.Database:GetSelected(SS.currentSpec)
    local seq = id and SS.Database:GetSequence(id)
    local step = seq and ((seq.opener and seq.opener[1]) or (seq.loop and seq.loop[1]))
    return step and step.entry
end

function NextUp:Refresh()
    if not frame then return end
    local data = settings()
    local id = currentId()
    if editing and data and data.shown ~= false and not (id and SS.Database:GetSequence(id)) then
        local entry = previewEntry()
        frame.icon:SetTexture((entry and SS.Compiler.EntryIcon(entry)) or Theme.icons.app)
        frame.entry = entry
        frame.counter:SetText("")
        updateCooldown()
        updateTint()
        frame:Show()
        return
    end
    if not data or data.shown == false or not id or not SS.Database:GetSequence(id) then
        frame:Hide()
        return
    end
    local entry = SS.Engine:GetNextEntry(id)
    local icon = entry and SS.Compiler.EntryIcon(entry)
    frame.icon:SetTexture(icon or UNKNOWN_ICON)
    frame.entry = entry
    updateCooldown()
    updateTint()
    updateCounter(id)
    if not frame:IsShown() then
        frame:Show()
    else
        frame.pulse:Stop()
        frame.pulse:Play()
    end
end

function NextUp:Init()
    if frame then return end
    build()
    self:Refresh()
end

function NextUp:Toggle()
    local data = settings()
    if not data then return end
    data.shown = not (data.shown ~= false)
    if data.shown then
        if currentId() then
            self:Refresh()
        else
            SS:Print("The next-up icon appears when you press a sequence.")
        end
    else
        if frame then frame:Hide() end
        SS:Print("Next-up icon hidden. Show it again with /seq nextup")
    end
end

function NextUp:SetEditing(on)
    editing = on == true
    if not frame then return end
    frame.selection.dragging = nil
    frame.selection:SetSelected(false)
    frame.selection:SetShown(editing)
    if not editing then frame:StopMovingOrSizing() end
    self:Refresh()
end

function NextUp:IsEditing()
    return editing
end

SS:On("LOGIN", function()
    NextUp:Init()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function() NextUp:SetEditing(true) end, NextUp)
        EventRegistry:RegisterCallback("EditMode.Exit", function() NextUp:SetEditing(false) end, NextUp)
    end
    local manager = EditModeManagerFrame
    if manager and manager.IsEditModeActive and manager:IsEditModeActive() then NextUp:SetEditing(true) end
end)
SS:On("SEQUENCE_PRESSED", function() NextUp:Refresh() end)
SS:On("SEQUENCE_ADVANCED", function(id)
    if id == currentId() and frame and frame:IsShown() then NextUp:Refresh() end
end)

local function cooldownChanged()
    if frame and frame:IsShown() then updateCooldown() end
end

SS:RegisterGameEvent("SPELL_UPDATE_COOLDOWN", cooldownChanged)
SS:RegisterGameEvent("BAG_UPDATE_COOLDOWN", cooldownChanged)
SS:On("SEQUENCES_CHANGED", function() NextUp:Refresh() end)
SS:On("SPEC_CHANGED", function() NextUp:Refresh() end)
