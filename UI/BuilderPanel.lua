local _, SS = ...

local Theme = SS.Theme
local Widgets = SS.Widgets
local BuilderPanel = {}
SS.BuilderPanel = BuilderPanel

local PAD = 12
local OVERLAY_LEVEL = 60
local ROW_H, ROW_GAP = 30, 2
local ROW_ICON, PREVIEW_ICON, ICON_GAP = 24, 20, 3
local RIGHT_INSET = 47
local ICON_CROP = 0.08
local CONTENT_W = 376
local LABEL_W = 70
local NOTE_MAX_W = 120
local HELP_H = 56
local LIST_TOP = PAD + 24 + HELP_H + 10
local FOOT_H, BUTTON_H, PREVIEW_H = 28, 26, 140
local BUTTONS_Y = PAD + FOOT_H + 6
local PREVIEW_Y = BUTTONS_Y + BUTTON_H + 8
local LIST_BOTTOM = PREVIEW_Y + PREVIEW_H + 8
local BAR_H = 3
local DOT = " \194\183 "

local HELP = "Put your spells in order of importance, most important first. SimpleSequence reads each spell's "
    .. "cooldown and works out how often it fits. Spells that don't use the global cooldown, and trinkets, go to Every press."
local FOOTNOTE = "Mash the key as much as you like: each spell in the loop waits until it's ready, and nothing gets skipped."
local ROW_HINT = "Drag to reorder" .. DOT .. "Right-click to remove"

local ROLE_TONE = { loop = "TEXT_ACTIVE", extras = "TEXT_ACTIVE", unused = "TEXT_WARNING", error = "TEXT_WARNING", opener = "TEXT_ACTIVE" }
local SECTION_LABEL = { opener = "Opener", loop = "Loop", extras = "Every press" }
local SECTION_ORDER = { "opener", "loop", "extras" }

local panel
local state = {}
local rows = {}
local previewRows = {}

local function database()
    return SS.Database
end

local function toast(text)
    if SS.Window and SS.Window.Toast then
        SS.Window:Toast(text)
    end
end

local function maxPriority()
    return SS.MAX_PRIORITY or 16
end

local function entryName(entry)
    return entry and SS.Compiler and SS.Compiler.EntryName(entry) or nil
end

local function entryIcon(entry)
    local icon = entry and SS.Compiler and SS.Compiler.EntryIcon(entry)
    return icon or Theme.assets.unknownItem.file
end

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function currentList()
    local seq = state.id and database():GetSequence(state.id)
    return seq and seq.priority or {}
end

local function copyList(list)
    local copy = {}
    for i, entry in ipairs(list) do
        copy[i] = { kind = entry.kind, id = entry.id }
    end
    return copy
end

local function commit(list)
    database():SetPriority(state.id, list)
    BuilderPanel:Refresh()
end

local function dropSlot()
    local count = #currentList()
    local child = panel and panel.scroll.child
    local top = child and child:GetTop()
    if not top or not panel.scroll:IsMouseOver() then return count + 1 end
    local _, cursorY = GetCursorPosition()
    cursorY = cursorY / child:GetEffectiveScale()
    local slot = math.floor((top - cursorY) / (ROW_H + ROW_GAP) + 0.5) + 1
    return clamp(slot, 1, count + 1)
end

local function updateBar()
    if not panel then return end
    if not panel.scroll:IsMouseOver() then
        panel.bar:Hide()
        state.slot = nil
        return
    end
    local slot = dropSlot()
    state.slot = slot
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", panel.scroll.child, "TOPLEFT", 0, -(slot - 1) * (ROW_H + ROW_GAP) + ROW_GAP / 2 + BAR_H / 2)
    panel.bar:SetPoint("RIGHT", panel.scroll.child, "RIGHT", 0, 0)
    panel.bar:SetHeight(BAR_H)
    panel.bar:Show()
end

local function hideBar()
    if panel then panel.bar:Hide() end
    state.slot = nil
end

local function addAt(entry, slot)
    if not state.id or not entry then return false end
    if entry.kind == "emote" then
        toast("Emotes can't be planned")
        return false
    end
    local list = copyList(currentList())
    for _, existing in ipairs(list) do
        if existing.kind == entry.kind and existing.id == entry.id then
            toast("That spell is already in the list")
            return false
        end
    end
    if #list >= maxPriority() then
        toast("That's as many spells as it can plan")
        return false
    end
    table.insert(list, clamp(slot or #list + 1, 1, #list + 1), { kind = entry.kind, id = entry.id })
    commit(list)
    return true
end

local function removeAt(index)
    local list = copyList(currentList())
    if not list[index] then return end
    table.remove(list, index)
    commit(list)
end

local function moveTo(from, slot)
    local list = copyList(currentList())
    local item = list[from]
    if not item then return false end
    local final = slot
    if slot > from then final = slot - 1 end
    if final == from then return true end
    table.remove(list, from)
    table.insert(list, clamp(final, 1, #list + 1), item)
    commit(list)
    return true
end

local function onDrop(payload)
    local slot = state.slot or dropSlot()
    hideBar()
    if payload.type == "entry" then
        return addAt(payload.entry, slot)
    elseif payload.type == "priority" then
        return moveTo(payload.index, slot)
    end
    return false
end

local function onRowClick(row, button)
    if button == "RightButton" and row.index then
        removeAt(row.index)
    end
end

local function createRow(parent)
    local row = Theme:ListButton(parent, 100, ROW_H, "", onRowClick)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(widget)
        if widget.index then
            GameTooltip:Hide()
            SS.DragDrop:Begin({ type = "priority", index = widget.index }, widget.iconID)
        end
    end)
    row:HookScript("OnEnter", function(widget)
        if SS.DragDrop:IsDragging() then return end
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        GameTooltip:AddLine(widget.nameText or "", 1, 1, 1)
        local r, g, b = unpack(Theme.colors.TEXT_BODY)
        if widget.infoText and widget.infoText ~= "" then GameTooltip:AddLine(widget.infoText, r, g, b, true) end
        if widget.noteText and widget.noteText ~= "" then
            local tr, tg, tb = unpack(Theme.colors[widget.noteTone] or Theme.colors.TEXT_ACTIVE)
            GameTooltip:AddLine(widget.noteText, tr, tg, tb, true)
        end
        if widget.detailText and widget.detailText ~= "" then GameTooltip:AddLine(widget.detailText, r, g, b, true) end
        local mr, mg, mb = unpack(Theme.colors.TEXT_MUTED)
        GameTooltip:AddLine(ROW_HINT, mr, mg, mb, true)
        GameTooltip:Show()
    end)
    row:HookScript("OnLeave", function() GameTooltip:Hide() end)

    row.rank = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.rank:SetPoint("LEFT", 6, 0)
    row.rank:SetWidth(16)
    row.rank:SetJustifyH("CENTER")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", 26, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    row.remove = Theme:CloseButton(row, function() removeAt(row.index) end)
    row.remove:SetSize(16, 16)
    row.remove:SetPoint("RIGHT", -4, 0)
    row.up = Theme:ScrollStepper(row, "scrollUp", function()
        if row.index and row.index > 1 then moveTo(row.index, row.index - 1) end
    end)
    row.up:SetPoint("BOTTOMRIGHT", row.remove, "LEFT", -4, 1)
    row.down = Theme:ScrollStepper(row, "scrollDown", function()
        if row.index then moveTo(row.index, row.index + 2) end
    end)
    row.down:SetPoint("TOPRIGHT", row.remove, "LEFT", -4, -1)

    row.note = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.note:SetJustifyH("RIGHT")
    row.note:SetWordWrap(false)
    row.note:SetPoint("TOPRIGHT", row, "TOPRIGHT", -RIGHT_INSET, -4)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 3)
    row.label:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
    row.label:SetWordWrap(false)
    row.info = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.info:SetWordWrap(false)
    row.info:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -1)
    row.info:SetPoint("RIGHT", row, "RIGHT", -RIGHT_INSET, 0)
    rows[#rows + 1] = row
    return row
end

local function fillRow(row, index, entry, planRow, count)
    local child = panel.scroll.child
    row.index = index
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(index - 1) * (ROW_H + ROW_GAP))
    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(index - 1) * (ROW_H + ROW_GAP))
    row.nameText = planRow and planRow.name or entryName(entry) or "Unknown"
    row.iconID = planRow and planRow.icon or entryIcon(entry)
    row.rank:SetText(tostring(index))
    row.icon:SetTexture(row.iconID)
    row.label:SetText(row.nameText)
    row.infoText = planRow and planRow.info or ""
    row.noteText = planRow and planRow.note or ""
    row.detailText = planRow and planRow.detail or ""
    row.noteTone = ROLE_TONE[planRow and planRow.role] or "TEXT_MUTED"
    local lineTwo = row.infoText
    if lineTwo == "" then lineTwo = row.detailText end
    row.info:SetText(lineTwo)
    row.note:SetText(row.noteText)
    local width = row.note.GetUnboundedStringWidth and row.note:GetUnboundedStringWidth() or row.note:GetStringWidth()
    row.note:SetWidth(math.min(NOTE_MAX_W, math.ceil(width or 0) + 2))
    Theme:Color(row.note, row.noteTone, true)
    row.up:SetShown(index > 1)
    row.down:SetShown(index < count)
    row:Show()
end

local function acquirePreviewIcon(group, index)
    local icon = group.icons[index]
    if icon then return icon end
    icon = CreateFrame("Button", nil, panel.preview)
    icon:SetSize(PREVIEW_ICON, PREVIEW_ICON)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    icon:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_TOP")
        GameTooltip:AddLine(widget.nameText or "", 1, 1, 1)
        local r, g, b = unpack(Theme.colors.TEXT_MUTED)
        GameTooltip:AddLine(widget.detail or "", r, g, b, true)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    group.icons[index] = icon
    return icon
end

local function acquirePreviewGroup(key)
    local group = previewRows[key]
    if group then return group end
    group = { icons = {} }
    group.label = Theme:Text(panel.preview, SECTION_LABEL[key], "small", "TEXT_MUTED")
    group.more = Theme:Text(panel.preview, "", "small", "TEXT_MUTED")
    previewRows[key] = group
    return group
end

local function hidePreviewGroup(group)
    group.label:Hide()
    group.more:Hide()
    for _, icon in ipairs(group.icons) do icon:Hide() end
end

local function layoutGroup(key, entries, y)
    local group = acquirePreviewGroup(key)
    hidePreviewGroup(group)
    if not entries or #entries == 0 then return y end
    local fit = math.floor((CONTENT_W - LABEL_W) / (PREVIEW_ICON + ICON_GAP))
    local shown = #entries
    if shown > fit then shown = fit - 1 end
    group.label:ClearAllPoints()
    group.label:SetPoint("LEFT", panel.preview, "TOPLEFT", 0, -(y + PREVIEW_ICON / 2))
    group.label:Show()
    for i = 1, shown do
        local entry = entries[i]
        local icon = acquirePreviewIcon(group, i)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", panel.preview, "TOPLEFT", LABEL_W + (i - 1) * (PREVIEW_ICON + ICON_GAP), -y)
        icon.tex:SetTexture(entryIcon(entry))
        icon.nameText = entryName(entry) or "Unknown"
        icon.detail = key == "extras" and SECTION_LABEL[key] or (SECTION_LABEL[key] .. DOT .. "press " .. i)
        icon:Show()
    end
    if shown < #entries then
        group.more:ClearAllPoints()
        group.more:SetPoint("LEFT", panel.preview, "TOPLEFT", LABEL_W + shown * (PREVIEW_ICON + ICON_GAP), -(y + PREVIEW_ICON / 2))
        group.more:SetText("+" .. (#entries - shown))
        group.more:Show()
    end
    return y + PREVIEW_ICON + 6
end

local function layoutPreview(plan, combat, empty)
    local preview = panel.preview
    local y = 0
    local warn = {}
    local summary = ""
    local sections = {}
    if combat then
        warn[1] = "You can build after the fight."
    elseif plan and plan.ok then
        summary = plan.summary or ""
        sections = plan
        for _, text in ipairs(plan.warnings or {}) do warn[#warn + 1] = text end
    elseif plan and not empty then
        warn[1] = plan.error or "Something went wrong."
    end
    panel.summary:SetText(summary)
    panel.summary:SetShown(summary ~= "")
    if summary ~= "" then
        y = math.ceil(panel.summary:GetStringHeight()) + 8
    end
    for _, key in ipairs(SECTION_ORDER) do
        y = layoutGroup(key, sections[key], y)
    end
    panel.warn:ClearAllPoints()
    panel.warn:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -y)
    panel.warn:SetWidth(CONTENT_W)
    panel.warn:SetHeight(math.max(14, PREVIEW_H - y))
    panel.warn:SetText(table.concat(warn, "\n"))
    panel.warn:SetShown(#warn > 0)
end

function BuilderPanel:IsOpen()
    return panel ~= nil and panel:IsShown() and state.id ~= nil
end

function BuilderPanel:Refresh()
    if not self:IsOpen() then return end
    local seq = database():GetSequence(state.id)
    if not seq then
        self:Close()
        return
    end
    local list = seq.priority or {}
    local combat = SS:InCombat()
    local plan
    if not combat and #list > 0 then
        plan = SS.Builder:Plan(copyList(list))
    end
    state.plan = plan

    for _, row in ipairs(rows) do row:Hide() end
    for i, entry in ipairs(list) do
        local row = rows[i] or createRow(panel.scroll.child)
        fillRow(row, i, entry, plan and plan.rows and plan.rows[i], #list)
    end
    panel.empty:SetShown(#list == 0)
    panel.scroll:UpdateExtent(#list * (ROW_H + ROW_GAP))

    layoutPreview(plan, combat, #list == 0)
    local usable = plan ~= nil and plan.ok == true and not combat
    if usable then panel.use:Enable() else panel.use:Disable() end
end

local function updateKeyboard()
    if not panel then return end
    local want = BuilderPanel:IsOpen() and not SS:InCombat()
    panel:EnableKeyboard(want)
    if want then panel:SetPropagateKeyboardInput(true) end
end

function BuilderPanel:Close()
    if not panel then return end
    state.id, state.plan, state.slot = nil, nil, nil
    panel:EnableKeyboard(false)
    GameTooltip:Hide()
    panel:Hide()
end

local function useBuild()
    local plan = state.plan
    if not state.id or SS:InCombat() or not plan or plan.ok ~= true then return end
    local id = state.id
    database():ApplyBuild(id, plan)
    BuilderPanel:Close()
    toast("Built. Ctrl+Z undoes it")
end

local function build()
    if panel then return true end
    local root = SS.Editor and SS.Editor.root
    if not root then return false end
    local f = CreateFrame("Frame", nil, root)
    panel = f
    f:SetAllPoints(root)
    f:SetFrameLevel(root:GetFrameLevel() + OVERLAY_LEVEL)
    f:EnableMouse(true)
    Theme:Fill(f, "PANEL_BG")
    f:Hide()

    local title = Theme:Text(f, "Build for me", "title", "TEXT_TITLE")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    local help = Theme:Text(f, HELP, "small", "TEXT_MUTED")
    help:SetPoint("TOPLEFT", PAD, -(PAD + 26))
    help:SetPoint("TOPRIGHT", -PAD, -(PAD + 26))
    help:SetHeight(HELP_H)
    help:SetJustifyV("TOP")
    help:SetWordWrap(true)
    local rule = Theme:Divider(f)
    rule:SetPoint("TOPLEFT", PAD, -(LIST_TOP - 6))
    rule:SetPoint("TOPRIGHT", -PAD, -(LIST_TOP - 6))

    f.scroll = Widgets:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", PAD, -LIST_TOP)
    f.scroll:SetPoint("BOTTOMRIGHT", -(PAD + 14), LIST_BOTTOM)
    f.bar = Theme:Fill(f.scroll.child, "ACCENT_COPPER", "OVERLAY")
    f.bar:ClearAllPoints()
    f.bar:SetHeight(BAR_H)
    f.bar:Hide()
    f.empty = Theme:Text(f, "Drag spells here from the right, most important first.", "body", "TEXT_MUTED")
    f.empty:SetPoint("CENTER", f.scroll, "CENTER", 0, 0)
    f.empty:SetWidth(280)
    f.empty:SetJustifyH("CENTER")
    f.empty:Hide()

    f.preview = CreateFrame("Frame", nil, f)
    f.preview:SetPoint("BOTTOMLEFT", PAD, PREVIEW_Y)
    f.preview:SetPoint("BOTTOMRIGHT", -PAD, PREVIEW_Y)
    f.preview:SetHeight(PREVIEW_H)
    f.preview:SetClipsChildren(true)
    f.summary = Theme:Text(f.preview, "", "body", "TEXT_BODY")
    f.summary:SetPoint("TOPLEFT")
    f.summary:SetWidth(CONTENT_W)
    f.summary:SetWordWrap(true)
    f.warn = Theme:Text(f.preview, "", "small", "TEXT_WARNING")
    f.warn:SetJustifyV("TOP")
    f.warn:SetWordWrap(true)

    f.use = Theme:Button(f, 160, "Use this sequence", useBuild, BUTTON_H)
    f.use:SetPoint("BOTTOMLEFT", PAD, BUTTONS_Y)
    f.cancel = Theme:ListButton(f, 80, BUTTON_H, "Cancel", function() BuilderPanel:Close() end)
    f.cancel.label:SetJustifyH("CENTER")
    f.cancel:SetPoint("LEFT", f.use, "RIGHT", 10, 0)

    local foot = Theme:Text(f, FOOTNOTE, "small", "TEXT_MUTED")
    foot:SetPoint("BOTTOMLEFT", PAD, PAD)
    foot:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    foot:SetHeight(FOOT_H)
    foot:SetJustifyV("BOTTOM")
    foot:SetWordWrap(true)

    SS.DragDrop:RegisterTarget(f, {
        accept = function(payload) return payload.type == "entry" or payload.type == "priority" end,
        onEnter = updateBar,
        onMove = updateBar,
        onLeave = hideBar,
        onDrop = onDrop,
        onCursorDrop = function(entry) return addAt(entry, dropSlot()) end,
    })

    f:SetScript("OnKeyDown", function(widget, key)
        if key == "ESCAPE" then
            widget:SetPropagateKeyboardInput(false)
            BuilderPanel:Close()
        else
            widget:SetPropagateKeyboardInput(true)
        end
    end)
    f:EnableKeyboard(false)
    f:SetScript("OnHide", function()
        state.id, state.plan, state.slot = nil, nil, nil
        f:EnableKeyboard(false)
        GameTooltip:Hide()
    end)
    return true
end

function BuilderPanel:Open(id)
    if not id or not database():GetSequence(id) then return end
    if not build() then return end
    if SS.StepPopover then SS.StepPopover:Close() end
    state.id = id
    panel:Show()
    updateKeyboard()
    self:Refresh()
end

function BuilderPanel:AddEntry(entry)
    if not self:IsOpen() then return false end
    addAt(entry, nil)
    return true
end

local function closeIfStale()
    if not BuilderPanel:IsOpen() then return end
    if database():GetSelected(SS.currentSpec) ~= state.id then
        BuilderPanel:Close()
    end
end

SS:On("SELECTION_CHANGED", closeIfStale)
SS:On("SPEC_CHANGED", function() BuilderPanel:Close() end)
SS:On("SEQUENCE_UPDATED", function(id)
    if BuilderPanel:IsOpen() and id == state.id then BuilderPanel:Refresh() end
end)
SS:On("UNDO_CHANGED", function() BuilderPanel:Refresh() end)
SS:On("BUILDER_DATA_CHANGED", function() BuilderPanel:Refresh() end)
SS:On("COMBAT_STARTED", function()
    if not panel then return end
    panel:EnableKeyboard(false)
    BuilderPanel:Refresh()
end)
SS:On("COMBAT_ENDED", function()
    updateKeyboard()
    BuilderPanel:Refresh()
end)
