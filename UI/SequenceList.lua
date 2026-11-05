local _, SS = ...
local Theme = SS.Theme
local Widgets = SS.Widgets
local List = {}
SS.SequenceList = List

local ROW_HEIGHT, ROW_GAP, ICON_SIZE = 44, 2, 32
local HEADER_HEIGHT, HEADER_ICON = 30, 20
local FOOTER_HEIGHT, FOOTER_BUTTON, FOOTER_GAP = 100, 28, 6
local SCROLL_RIGHT = 20
local UNKNOWN_ICON = 134400
local BACKUP_AFTER = 7 * 24 * 60 * 60
local ICON_CROP = 0.07
local BAR_HEIGHT = 3
local EMPTY_LINES = {
    "1. Drag spells from the right into the Loop.",
    "2. Press Put on action bar.",
    "3. Press that button in combat, again and again.",
}

local rows = {}
local state = { rowWidth = 0 }
local rename

StaticPopupDialogs["SIMPLESEQUENCE_DELETE"] = {
    text = "Delete \"%s\"?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(_, data)
        if data and data.id then List:Delete(data.id) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function toast(...)
    if SS.Window then SS.Window:Toast(...) end
end

local function shortKey(key)
    key = key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-")
    return key
end

local function sequenceIcon(seq)
    if seq.icon then return seq.icon end
    local step = seq.loop and seq.loop[1] or seq.opener and seq.opener[1]
    local icon = step and SS.Compiler and SS.Compiler.EntryIcon(step.entry)
    return icon or UNKNOWN_ICON
end

local function hasError(seq)
    if not (SS.Compiler and SS.Compiler.Compile) then return false end
    local ok, result = pcall(SS.Compiler.Compile, SS.Compiler, seq)
    if not ok or type(result) ~= "table" or not result.problems then return false end
    for _, problem in ipairs(result.problems) do
        if problem.level == "error" then return true end
    end
    return false
end

function List:Delete(id)
    local seq = SS.Database:GetSequence(id)
    if not seq then return end
    local name = seq.name
    SS.Database:Delete(id)
    toast("Deleted \"" .. name .. "\"", "Undo", function() SS.Database:Undo() end)
end

function List:StartRename(row)
    local seq = SS.Database:GetSequence(row.id)
    if not seq then return end
    if not rename then
        rename = Widgets:Input(row, state.rowWidth - 8, 26)
        rename:SetScript("OnEnterPressed", function(widget)
            local text = strtrim(widget:GetText())
            local id = widget.id
            widget.id = nil
            widget:ClearFocus()
            widget:Hide()
            if text ~= "" and id then SS.Database:Rename(id, text) end
        end)
        rename:SetScript("OnEscapePressed", function(widget)
            widget.id = nil
            widget:ClearFocus()
            widget:Hide()
        end)
        rename:SetScript("OnEditFocusLost", function(widget)
            widget.id = nil
            widget:Hide()
        end)
    end
    rename:SetParent(row)
    rename:SetFrameLevel(row:GetFrameLevel() + 10)
    rename:ClearAllPoints()
    rename:SetPoint("CENTER", row, "CENTER", 0, 0)
    rename:SetWidth(state.rowWidth - 8)
    rename.id = row.id
    rename:SetText(seq.name)
    rename:Show()
    rename:SetFocus()
    rename:HighlightText()
end

function List:ShowMenu(row)
    local id = row.id
    local seq = SS.Database:GetSequence(id)
    if not seq then return end
    Widgets:ContextMenu(row, {
        { text = "Rename", fn = function() List:StartRename(row) end },
        { text = "Duplicate", fn = function()
            local copy = SS.Database:Duplicate(id)
            if copy then SS.Database:SetSelected(SS.currentSpec, copy.id) end
        end },
        { text = "Export", fn = function()
            SS.ShareDialog:ShowExport(seq.name, SS.Share:Export(id))
        end },
        { text = "Delete", fn = function()
            StaticPopup_Show("SIMPLESEQUENCE_DELETE", seq.name, nil, { id = id })
        end },
    })
end

local function putOnActionBar(id)
    local ok, err = SS.Bindings:PutOnActionBar(id)
    if ok then
        toast("Click an action bar slot to place it")
    else
        toast(err or "Could not pick up the macro")
    end
end

local function rowCount()
    local list = SS.Database:GetSequences(SS.currentSpec)
    return list and #list or 0
end

local function dropSlot()
    local count = rowCount()
    local child = List.scroll and List.scroll.child
    local top = child and child:GetTop()
    if not top then return count + 1 end
    local scale = child:GetEffectiveScale()
    local _, cursorY = GetCursorPosition()
    cursorY = cursorY / scale
    local slot = math.floor((top - cursorY) / (ROW_HEIGHT + ROW_GAP) + 0.5) + 1
    return math.max(1, math.min(count + 1, slot))
end

local function updateBar()
    local slot = dropSlot()
    List.dropSlot = slot
    local bar = List.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", List.scroll.child, "TOPLEFT", 0, -(slot - 1) * (ROW_HEIGHT + ROW_GAP) + ROW_GAP / 2 + BAR_HEIGHT / 2)
    bar:SetSize(state.rowWidth, BAR_HEIGHT)
    bar:Show()
end

local function hideBar()
    List.bar:Hide()
    List.dropSlot = nil
end

local function dropOnList(payload)
    local slot = List.dropSlot or dropSlot()
    hideBar()
    if payload.type ~= "sequence" then return false end
    local final = slot
    if slot > payload.index then final = slot - 1 end
    if final == payload.index then return true end
    SS.Database:MoveInList(SS.currentSpec, payload.index, final)
    return true
end

local function createRow(parent)
    local row = Theme:ListButton(parent, state.rowWidth, ROW_HEIGHT, "", function(widget, button)
        if button == "RightButton" then
            List:ShowMenu(widget)
        elseif widget.id then
            SS.Database:SetSelected(SS.currentSpec, widget.id)
        end
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(widget)
        if widget.id and widget.index then
            SS.DragDrop:Begin({ type = "sequence", id = widget.id, index = widget.index }, widget.iconFile)
        end
    end)
    row.iconButton = CreateFrame("Button", nil, row)
    row.iconButton:SetSize(ICON_SIZE, ICON_SIZE)
    row.iconButton:SetPoint("LEFT", 6, 0)
    row.iconButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.iconButton:RegisterForDrag("LeftButton")
    row.icon = row.iconButton:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.iconButton:SetScript("OnClick", function(_, button) row:Click(button) end)
    row.iconButton:SetScript("OnEnter", function() row:GetScript("OnEnter")(row) end)
    row.iconButton:SetScript("OnLeave", function() row:GetScript("OnLeave")(row) end)
    row.iconButton:SetScript("OnDragStart", function()
        if row.id then putOnActionBar(row.id) end
    end)
    row.warn = Theme:Text(row, "!", "body", "TEXT_WARNING")
    row.warn:SetPoint("RIGHT", -8, 0)
    row.key = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.key:SetJustifyH("RIGHT")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.iconButton, "RIGHT", 8, 0)
    row.label:SetWordWrap(false)
    return row
end

local function fillRow(row, seq, index, selected)
    row.id = seq.id
    row.index = index
    row.iconFile = sequenceIcon(seq)
    row.icon:SetTexture(row.iconFile)
    row.label:SetText(seq.name or "")
    local warn = hasError(seq)
    row.warn:SetShown(warn)
    row.key:ClearAllPoints()
    row.key:SetPoint("RIGHT", warn and -22 or -8, 0)
    local key = seq.key
    row.key:SetText(key and shortKey(key) or "")
    row.key:SetShown(key ~= nil)
    row.label:SetPoint("RIGHT", key and row.key or row, key and "LEFT" or "RIGHT", key and -6 or -8, 0)
    Theme:ListButtonState(row, selected)
end

function List:Refresh()
    if not state.built then return end
    local spec = SS.currentSpec
    local name, icon = SS:GetSpecLabel()
    self.headerName:SetText(name or "")
    if icon then
        self.headerIcon:SetTexture(icon)
        self.headerIcon:Show()
        self.headerName:SetPoint("LEFT", self.headerIcon, "RIGHT", 8, 0)
    else
        self.headerIcon:Hide()
        self.headerName:SetPoint("LEFT", self.headerIcon, "LEFT", 0, 0)
    end
    local list = SS.Database:GetSequences(spec) or {}
    local selected = SS.Database:GetSelected(spec)
    local empty = #list == 0
    self.scroll:SetShown(empty == false)
    self.footer:SetShown(not empty)
    self.empty:SetShown(empty)
    if empty then
        self.scroll.slider:Hide()
        self.scroll.up:Hide()
        self.scroll.down:Hide()
        for _, row in ipairs(rows) do row:Hide() end
        if rename then rename:Hide() end
        return
    end
    for index, seq in ipairs(list) do
        local row = rows[index]
        if not row then
            row = createRow(self.scroll.child)
            rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + ROW_GAP))
        fillRow(row, seq, index, seq.id == selected)
        row:Show()
    end
    for index = #list + 1, #rows do
        rows[index]:Hide()
        rows[index].id = nil
        rows[index].index = nil
    end
    local total = #list * (ROW_HEIGHT + ROW_GAP)
    self.scroll:UpdateExtent(total)
    self.scroll.child:SetWidth(state.rowWidth)
    local lastBackup = SS.db and SS.db.lastBackup or 0
    self.backup:SetShown(time() - lastBackup > BACKUP_AFTER)
end

function List:Build(parent)
    if state.built then return end
    state.built = true
    local width = parent:GetWidth()
    state.rowWidth = width - SCROLL_RIGHT

    self.headerIcon = parent:CreateTexture(nil, "ARTWORK")
    self.headerIcon:SetSize(HEADER_ICON, HEADER_ICON)
    self.headerIcon:SetPoint("TOPLEFT", 4, -4)
    self.headerIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    self.headerName = Theme:Text(parent, "", "body", "TEXT_TITLE")
    self.headerName:SetPoint("LEFT", self.headerIcon, "RIGHT", 8, 0)
    self.headerName:SetPoint("RIGHT", -4, 0)
    self.headerName:SetWordWrap(false)
    local rule = Theme:Divider(parent)
    rule:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    rule:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)

    self.scroll = Widgets:Scroll(parent)
    self.scroll:SetPoint("TOPLEFT", 0, -(HEADER_HEIGHT + 8))
    self.scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, FOOTER_HEIGHT + 8)

    self.bar = Theme:Fill(self.scroll.child, "ACCENT_COPPER", "OVERLAY")
    self.bar:ClearAllPoints()
    self.bar:SetSize(state.rowWidth, BAR_HEIGHT)
    self.bar:Hide()
    SS.DragDrop:RegisterTarget(self.scroll, {
        accept = function(payload) return payload.type == "sequence" end,
        onEnter = updateBar,
        onMove = updateBar,
        onLeave = hideBar,
        onDrop = dropOnList,
    })

    self.footer = CreateFrame("Frame", nil, parent)
    self.footer:SetPoint("BOTTOMLEFT")
    self.footer:SetPoint("BOTTOMRIGHT")
    self.footer:SetHeight(FOOTER_HEIGHT)
    local new = Theme:Button(self.footer, width, "New sequence", function()
        SS.Database:Create(SS.currentSpec)
    end, FOOTER_BUTTON)
    new:SetPoint("TOP", 0, -4)
    local import = Theme:ListButton(self.footer, width, 24, "Import", function()
        SS.ShareDialog:ShowImport()
    end)
    import.label:SetPoint("LEFT", 4, 0)
    import:SetPoint("TOP", new, "BOTTOM", 0, -FOOTER_GAP)
    self.backup = CreateFrame("Button", nil, self.footer)
    self.backup:SetSize(width, 20)
    self.backup:SetPoint("TOP", import, "BOTTOM", 0, -FOOTER_GAP)
    self.backup.label = Theme:Text(self.backup, "Back up your sequences", "small", "TEXT_MUTED")
    self.backup.label:SetPoint("LEFT")
    self.backup:SetScript("OnEnter", function(widget) Theme:Color(widget.label, "TEXT_HIGHLIGHT", true) end)
    self.backup:SetScript("OnLeave", function(widget) Theme:Color(widget.label, "TEXT_MUTED", true) end)
    self.backup:SetScript("OnClick", function()
        SS.ShareDialog:ShowExport("All sequences", SS.Share:ExportAll())
    end)

    self.empty = CreateFrame("Frame", nil, parent)
    self.empty:SetAllPoints()
    local create = Theme:Button(self.empty, width - 8, "Create your first sequence", function()
        SS.Database:Create(SS.currentSpec)
    end, FOOTER_BUTTON)
    create:SetPoint("TOP", 0, -120)
    local previous = create
    for _, line in ipairs(EMPTY_LINES) do
        local text = Theme:Text(self.empty, line, "small", "TEXT_BODY")
        text:SetWidth(width - 16)
        text:SetWordWrap(true)
        text:SetJustifyV("TOP")
        text:SetPoint("TOP", previous, "BOTTOM", 0, previous == create and -20 or -10)
        previous = text
    end
    self.empty:Hide()
end
