local _, SS = ...

local Theme = SS.Theme
local Widgets = SS.Widgets
local Editor = {}
SS.Editor = Editor

local TILE, GAP = 40, 6
local PAD = 12
local SECTION_GAP = 22
local TOP_HEIGHT = 92
local ICON_CROP = 0.08
local DOT = " \194\183 "
local BADGE_H = 12
local MENU_COLUMNS, MENU_ICON, MENU_GAP = 6, 32, 4

local TILE_HINT_STEP = "Click for options" .. DOT .. "Right-click to remove" .. DOT .. "Drag to move"
local TILE_HINT_EXTRA = "Right-click to remove" .. DOT .. "Drag to move"

local SECTIONS = {
    { key = "opener", title = "Opener", help = "Cast once at the start of each fight. Optional.",
        empty = "Optional: drop spells here" },
    { key = "loop", title = "Loop", help = "Repeats while you keep pressing.",
        empty = "Drop a spell here" },
    { key = "extras", title = "Every press",
        help = "Also fires on every press: trinkets, racials, off-GCD spells.",
        empty = "Drop a spell here", extras = true },
}

local TARGET_BADGE = { player = "Me", mouseover = "MO", focus = "F" }
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true,
}

local tilePool, tileUsed = {}, 0
local problemLines = {}
local sectionByKey = {}
local capture

local function toast(text, actionLabel, actionFn)
    if SS.Window and SS.Window.Toast then
        SS.Window:Toast(text, actionLabel, actionFn)
    end
end

local function database()
    return SS.Database
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

local function listFor(seq, key)
    return seq[key] or {}
end

local function maxFor(key)
    return key == "extras" and SS.MAX_EXTRAS or SS.MAX_STEPS
end

function Editor:GetActiveSection()
    return self.active or "loop"
end

function Editor:SetActive(key)
    self.active = key
    for sectionKey, sec in pairs(sectionByKey) do
        sec.activeBar:SetShown(sectionKey == key)
    end
end

function Editor:RemoveStep(id, section, index)
    local seq = database():GetSequence(id)
    local step = seq and seq[section] and seq[section][index]
    local name = step and entryName(step.entry) or "step"
    if database():RemoveStep(id, section, index) then
        toast("Removed " .. name, "Undo", function() database():Undo() end)
    end
end

function Editor:RemoveExtra(id, index)
    local seq = database():GetSequence(id)
    local entry = seq and seq.extras and seq.extras[index]
    local name = entry and entryName(entry) or "spell"
    if database():RemoveExtra(id, index) then
        toast("Removed " .. name, "Undo", function() database():Undo() end)
    end
end

function Editor:AddEntry(entry)
    if SS.StepPopover and SS.StepPopover:ConsumeArmed(entry) then return end
    local id = self.id
    local seq = id and database():GetSequence(id)
    if not seq then
        toast("Pick or create a sequence first")
        return
    end
    local key = self:GetActiveSection()
    if #listFor(seq, key) >= maxFor(key) then
        toast("That part is full")
        return
    end
    self.flash = { key = key, index = #listFor(seq, key) + 1 }
    local ok
    if key == "extras" then
        ok = database():InsertExtra(id, nil, entry)
    else
        ok = database():InsertStep(id, key, nil, entry)
    end
    if not ok then self.flash = nil end
end

local CAPTURE_TIMEOUT = 10

local function stopListening()
    if capture.timer then
        capture.timer:Cancel()
        capture.timer = nil
    end
    capture:UnregisterEvent("GLOBAL_MOUSE_DOWN")
end

local function cancelCapture()
    if capture and capture.active then
        capture.active = false
        capture:EnableKeyboard(false)
        stopListening()
        Editor:RefreshTopBar()
    end
end

local function applyKey(id, key)
    local ok, err = SS.Bindings:SetKey(id, key)
    if ok == false then
        toast(err or "Could not use that key")
    end
end

StaticPopupDialogs["SIMPLESEQUENCE_CONFIRM_KEY"] = {
    text = "%s is used for %s. Use it for this sequence instead? (Your normal binding comes back if you clear it.)",
    button1 = "Use it",
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data then applyKey(data.id, data.key) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function buildKeyName(key)
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

local function chooseKey(id, key)
    local seq = database():GetSequence(id)
    if seq and seq.key == key then return end
    local label = key and SS.Bindings:GetConflict(key)
    if label and StaticPopup_Show then
        StaticPopup_Show("SIMPLESEQUENCE_CONFIRM_KEY", key, label, { id = id, key = key })
        return
    end
    applyKey(id, key)
end

local function onCaptureKey(self, key)
    if not self.active then
        self:EnableKeyboard(false)
        return
    end
    if MODIFIER_KEYS[key] then return end
    local id = Editor.id
    self.active = false
    self:EnableKeyboard(false)
    stopListening()
    Editor:RefreshTopBar()
    if key == "ESCAPE" or not id then return end
    if key == "BACKSPACE" or key == "DELETE" then
        applyKey(id, nil)
        return
    end
    chooseKey(id, buildKeyName(key))
end

local function startCapture()
    if not Editor.id then return end
    capture.active = true
    capture:EnableKeyboard(true)
    capture:RegisterEvent("GLOBAL_MOUSE_DOWN")
    capture.timer = C_Timer.NewTimer(CAPTURE_TIMEOUT, cancelCapture)
    Editor:RefreshTopBar()
end

local function autoIcon(seq)
    for _, section in ipairs({ "loop", "opener" }) do
        local step = seq[section] and seq[section][1]
        if step and step.entry then
            return entryIcon(step.entry)
        end
    end
    return Theme.assets.unknownItem.file
end

local iconMenu

local function closeIconMenu()
    if iconMenu then
        iconMenu.frame:Hide()
        iconMenu.catcher:Hide()
    end
end

local function distinctIcons(seq)
    local seen, icons = {}, {}
    local function add(entry)
        local icon = entry and SS.Compiler and SS.Compiler.EntryIcon(entry)
        if icon and not seen[icon] then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end
    for _, section in ipairs({ "opener", "loop" }) do
        for _, step in ipairs(seq[section] or {}) do add(step.entry) end
    end
    for _, entry in ipairs(seq.extras or {}) do add(entry) end
    return icons
end

local function buildIconMenu()
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:SetFrameLevel(1)
    catcher:Hide()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetFrameLevel(20)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Theme:Fill(frame, "SURFACE")
    Theme:FlatBorder(frame)
    frame:Hide()
    catcher:SetScript("OnClick", closeIconMenu)
    frame:SetScript("OnHide", function() catcher:Hide() end)
    local width = MENU_COLUMNS * MENU_ICON + (MENU_COLUMNS - 1) * MENU_GAP + 16
    frame.auto = Theme:ListButton(frame, width - 16, 24, "Automatic", function()
        closeIconMenu()
        if Editor.id then database():SetIcon(Editor.id, nil) end
    end)
    frame.auto:SetPoint("TOPLEFT", 8, -8)
    frame.note = Theme:Text(frame, "Add spells to pick one of their icons.", "small", "TEXT_MUTED")
    frame.note:SetPoint("TOPLEFT", 12, -40)
    frame.buttons = {}
    iconMenu = { frame = frame, catcher = catcher, width = width }
end

local function acquireMenuButton(index)
    local frame = iconMenu.frame
    local button = frame.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, frame)
    button:SetSize(MENU_ICON, MENU_ICON)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    Theme:FlatBorder(button)
    button.hoverTex = Theme:Texture(button, "listHover", "OVERLAY")
    button.hoverTex:SetAllPoints()
    button.hover = Theme:Fader(button.hoverTex, 0.08, 0.13)
    button:SetScript("OnEnter", function(widget) widget.hover:To(1) end)
    button:SetScript("OnLeave", function(widget) widget.hover:To(0) end)
    button:SetScript("OnClick", function(widget)
        closeIconMenu()
        if Editor.id then database():SetIcon(Editor.id, widget.fileID) end
    end)
    frame.buttons[index] = button
    return button
end

local function openIconMenu(anchor)
    local seq = Editor.id and database():GetSequence(Editor.id)
    if not seq then return end
    if not iconMenu then buildIconMenu() end
    if iconMenu.frame:IsShown() then
        closeIconMenu()
        return
    end
    local icons = distinctIcons(seq)
    for _, button in ipairs(iconMenu.frame.buttons) do button:Hide() end
    for index, icon in ipairs(icons) do
        local button = acquireMenuButton(index)
        local col, row = (index - 1) % MENU_COLUMNS, math.floor((index - 1) / MENU_COLUMNS)
        button.fileID = icon
        button.icon:SetTexture(icon)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 8 + col * (MENU_ICON + MENU_GAP), -(40 + row * (MENU_ICON + MENU_GAP)))
        button:Show()
    end
    local rows = math.ceil(#icons / MENU_COLUMNS)
    iconMenu.frame.note:SetShown(#icons == 0)
    iconMenu.frame:SetSize(iconMenu.width, 48 + math.max(1, rows) * (MENU_ICON + MENU_GAP) + (#icons == 0 and 4 or 0))
    iconMenu.frame:ClearAllPoints()
    iconMenu.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    iconMenu.catcher:Show()
    iconMenu.frame:Show()
end

function Editor:RefreshTopBar()
    if not self.nameBox then return end
    local seq = self.id and database():GetSequence(self.id)
    if not seq then return end
    if not self.nameBox:HasFocus() then
        self.nameBox:SetText(seq.name or "")
        self.nameBox:SetCursorPosition(0)
    end
    self.iconTex:SetTexture(seq.icon or autoIcon(seq))
    if capture and capture.active then
        self.keyButton.label:SetText("Press a key\226\128\166 (Esc to cancel)")
    elseif seq.key and seq.key ~= "" then
        self.keyButton.label:SetText("Key: " .. seq.key)
    else
        self.keyButton.label:SetText("Set key")
    end
end

local function buildTopBar(content)
    local iconButton = CreateFrame("Button", nil, content)
    iconButton:SetSize(32, 32)
    iconButton:SetPoint("TOPLEFT", PAD, -PAD)
    Theme:Fill(iconButton, "SURFACE")
    Theme:FlatBorder(iconButton)
    Editor.iconTex = iconButton:CreateTexture(nil, "ARTWORK")
    Editor.iconTex:SetPoint("TOPLEFT", 1, -1)
    Editor.iconTex:SetPoint("BOTTOMRIGHT", -1, 1)
    Editor.iconTex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    iconButton.hoverTex = Theme:Texture(iconButton, "listHover", "OVERLAY")
    iconButton.hoverTex:SetAllPoints()
    iconButton.hover = Theme:Fader(iconButton.hoverTex, 0.08, 0.13)
    iconButton:SetScript("OnEnter", function(widget)
        widget.hover:To(1)
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Change icon", 1, 1, 1)
        local r, g, b = unpack(Theme.colors.TEXT_MUTED)
        GameTooltip:AddLine("Automatic uses the first spell of your loop.", r, g, b, true)
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function(widget)
        widget.hover:To(0)
        GameTooltip:Hide()
    end)
    iconButton:SetScript("OnClick", function(widget) openIconMenu(widget) end)
    Editor.iconButton = iconButton

    local nameBox = Widgets:Input(content, 100, 32)
    nameBox:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 10, 0)
    nameBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -PAD)
    nameBox:SetMaxLetters(40)
    local function commitName(widget)
        if widget.cancelled then
            widget.cancelled = false
            return
        end
        local id = Editor.id
        local seq = id and database():GetSequence(id)
        if not seq then return end
        local text = strtrim(widget:GetText() or "")
        if text == "" then
            widget:SetText(seq.name or "")
        elseif text ~= seq.name then
            database():Rename(id, text)
        end
    end
    nameBox:HookScript("OnEnterPressed", commitName)
    nameBox:HookScript("OnEditFocusLost", commitName)
    nameBox:SetScript("OnEscapePressed", function(widget)
        local seq = Editor.id and database():GetSequence(Editor.id)
        widget.cancelled = true
        widget:SetText(seq and seq.name or "")
        widget:ClearFocus()
    end)
    Editor.nameBox = nameBox

    local keyButton = Theme:Button(content, 214, "Set key", function()
        if capture and capture.active then
            cancelCapture()
        else
            startCapture()
        end
    end, 24)
    keyButton:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -(PAD + 32 + 10))
    keyButton:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Pick the key that runs this sequence", 1, 1, 1)
        local r, g, b = unpack(Theme.colors.TEXT_MUTED)
        GameTooltip:AddLine("Backspace clears the key.", r, g, b, true)
        GameTooltip:Show()
    end)
    keyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Editor.keyButton = keyButton

    local barButton = Theme:Button(content, 150, "Put on action bar", function()
        if not Editor.id then return end
        local ok, err = SS.Bindings:PutOnActionBar(Editor.id)
        if ok then
            toast("Now click an action bar slot to place it")
        else
            toast(err or "Could not put that on an action bar")
        end
    end, 24)
    barButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -(PAD + 32 + 10))
    Editor.barButton = barButton
end

local function receiveCursorOn(tile)
    local sec = tile.section
    if sec then SS.DragDrop:ReceiveCursor(sec.frame) end
end

local function showTileTooltip(tile)
    if SS.DragDrop:IsDragging() or not tile.entry then return end
    local hint = tile.section and tile.section.def.extras and TILE_HINT_EXTRA or TILE_HINT_STEP
    SS.SpellSidebar:ShowTooltip(tile, tile.entry, hint, "ANCHOR_RIGHT")
end

local function tilePayload(tile)
    GameTooltip:Hide()
    local id, key, index = Editor.id, tile.section.key, tile.index
    local function dropOutside()
        if Editor.content and Editor.content:IsMouseOver() then return end
        if key == "extras" then
            Editor:RemoveExtra(id, index)
        else
            Editor:RemoveStep(id, key, index)
        end
    end
    if key == "extras" then
        return { type = "extra", id = id, index = index, onDropOutside = dropOutside }, tile.iconID
    end
    return { type = "step", id = id, section = key, index = index, onDropOutside = dropOutside }, tile.iconID
end

local function createTile()
    local tile = CreateFrame("Button", nil, UIParent)
    tile:SetSize(TILE, TILE)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Theme:Fill(tile, "SURFACE", "BACKGROUND")
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", 1, -1)
    tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    tile.numBg = Theme:Fill(tile, "DIALOG_BG", "ARTWORK")
    tile.numBg:SetDrawLayer("ARTWORK", 2)
    tile.numBg:ClearAllPoints()
    tile.numBg:SetPoint("TOPLEFT", 1, -1)
    tile.numBg:SetHeight(BADGE_H)
    tile.num = Theme:Text(tile, "", "small", "TEXT_HIGHLIGHT")
    tile.num:SetPoint("TOPLEFT", 3, -2)

    tile.strip = Theme:Fill(tile, "DIALOG_BG", "ARTWORK")
    tile.strip:SetDrawLayer("ARTWORK", 2)
    tile.strip:ClearAllPoints()
    tile.strip:SetPoint("BOTTOMLEFT", 1, 1)
    tile.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.strip:SetHeight(BADGE_H)
    tile.target = Theme:Text(tile, "", "small", "TEXT_ACTIVE")
    tile.target:SetPoint("BOTTOMLEFT", 3, 2)
    tile.mods = Theme:Text(tile, "", "small", "TEXT_TITLE")
    tile.mods:SetPoint("BOTTOMRIGHT", -3, 2)
    tile.everyBg = Theme:Fill(tile, "DIALOG_BG", "ARTWORK")
    tile.everyBg:SetDrawLayer("ARTWORK", 2)
    tile.everyBg:ClearAllPoints()
    tile.everyBg:SetPoint("TOPRIGHT", -1, -1)
    tile.everyBg:SetHeight(BADGE_H)
    tile.every = Theme:Text(tile, "", "small", "TEXT_WARNING")
    tile.every:SetPoint("TOPRIGHT", -3, -2)

    tile.hoverTex = Theme:Texture(tile, "listHover", "OVERLAY")
    tile.hoverTex:SetAllPoints()
    tile.hover = Theme:Fader(tile.hoverTex, 0.08, 0.13)

    tile.flashTex = Theme:Fill(tile, "ACCENT_COPPER", "OVERLAY")
    tile.flashTex:SetAlpha(0)
    tile.flashGroup = tile.flashTex:CreateAnimationGroup()
    local rise = tile.flashGroup:CreateAnimation("Alpha")
    rise:SetFromAlpha(0)
    rise:SetToAlpha(0.7)
    rise:SetDuration(0.12)
    rise:SetOrder(1)
    local fall = tile.flashGroup:CreateAnimation("Alpha")
    fall:SetFromAlpha(0.7)
    fall:SetToAlpha(0)
    fall:SetDuration(0.5)
    fall:SetOrder(2)
    tile.flashGroup:SetToFinalAlpha(true)

    tile:SetScript("OnEnter", function(widget)
        widget.hover:To(1)
        showTileTooltip(widget)
    end)
    tile:SetScript("OnLeave", function(widget)
        widget.hover:To(0)
        GameTooltip:Hide()
    end)
    tile:SetScript("OnClick", function(widget, button)
        local sec, id = widget.section, Editor.id
        if not sec or not id then return end
        GameTooltip:Hide()
        if button == "RightButton" then
            if sec.key == "extras" then
                Editor:RemoveExtra(id, widget.index)
            else
                Editor:RemoveStep(id, sec.key, widget.index)
            end
            return
        end
        Editor:SetActive(sec.key)
        if sec.key ~= "extras" and SS.StepPopover then
            SS.StepPopover:Open(widget, id, sec.key, widget.index)
        end
    end)
    tile:SetScript("OnReceiveDrag", receiveCursorOn)
    SS.DragDrop:RegisterSource(tile, tilePayload)
    tilePool[#tilePool + 1] = tile
    return tile
end

local function acquireTile(parent)
    tileUsed = tileUsed + 1
    local tile = tilePool[tileUsed] or createTile()
    tile:SetParent(parent)
    tile:SetFrameStrata(parent:GetFrameStrata())
    tile:SetFrameLevel(parent:GetFrameLevel() + 3)
    tile:ClearAllPoints()
    tile:Show()
    return tile
end

local function releaseTiles()
    for index = 1, #tilePool do
        local tile = tilePool[index]
        tile.flashGroup:Stop()
        tile:Hide()
        tile.section = nil
        tile.entry = nil
    end
    tileUsed = 0
end

local function gridPoint(sec, slotIndex)
    local zero = slotIndex - 1
    local col = zero % sec.perRow
    local row = math.floor(zero / sec.perRow)
    return col * (TILE + GAP), -row * (TILE + GAP), col, row
end

local function dropIndex(sec)
    local seq = Editor.id and database():GetSequence(Editor.id)
    local count = seq and #listFor(seq, sec.key) or 0
    local grid = sec.grid
    local left, top = grid:GetLeft(), grid:GetTop()
    if not left or not top then return count + 1 end
    local scale = grid:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local perRow = sec.perRow or 1
    local col = clamp(math.floor((cursorX - left) / (TILE + GAP) + 0.5), 0, perRow - 1)
    local row = clamp(math.floor((top - cursorY) / (TILE + GAP)), 0, math.floor(count / perRow))
    return clamp(row * perRow + col + 1, 1, count + 1)
end

local function updateBar(sec)
    local index = dropIndex(sec)
    sec.dropIndex = index
    local x, y = gridPoint(sec, index)
    sec.bar:ClearAllPoints()
    sec.bar:SetPoint("TOPLEFT", sec.grid, "TOPLEFT", math.max(0, x - GAP / 2 - 1.5), y)
    sec.bar:SetSize(3, TILE)
    sec.bar:Show()
end

local function hideBar(sec)
    sec.bar:Hide()
    sec.dropIndex = nil
end

local function insertAt(sec, entry, index)
    local id = Editor.id
    local seq = id and database():GetSequence(id)
    if not seq then return false end
    if #listFor(seq, sec.key) >= maxFor(sec.key) then
        toast("That part is full")
        return false
    end
    Editor:SetActive(sec.key)
    Editor.flash = { key = sec.key, index = index }
    local ok
    if sec.key == "extras" then
        ok = database():InsertExtra(id, index, entry)
    else
        ok = database():InsertStep(id, sec.key, index, entry)
    end
    if not ok then Editor.flash = nil end
    return ok
end

local function dropOnSection(sec, payload)
    local index = sec.dropIndex or dropIndex(sec)
    hideBar(sec)
    local id = Editor.id
    if not id then return false end
    if payload.type == "entry" then
        return insertAt(sec, payload.entry, index)
    end
    Editor:SetActive(sec.key)
    if (payload.type == "step") == (sec.key == "extras") then
        local seq = database():GetSequence(id)
        local fromList = seq and listFor(seq, payload.section or "extras")
        local item = fromList and fromList[payload.index]
        local ok, reason = database():MoveAcross(id, payload.section or "extras", payload.index, sec.key, index)
        if ok then
            Editor.flash = { key = sec.key, index = index }
            if payload.type == "step" and item and ((item.target and item.target ~= "target") or next(item.mods or {})) then
                toast("Every press spells use your target, so Cast on and Hold-key options were removed")
            end
        elseif reason == "emote" then
            toast("Emotes can't go in Every press")
        elseif reason == "full" then
            toast("That part is full")
        end
        return ok
    end
    if payload.type == "step" then
        local final = index
        if payload.section == sec.key and index > payload.index then final = index - 1 end
        if payload.section == sec.key and final == payload.index then return true end
        Editor.flash = { key = sec.key, index = final }
        database():MoveStep(id, payload.section, payload.index, sec.key, final)
        return true
    end
    if payload.type == "extra" then
        local final = index
        if index > payload.index then final = index - 1 end
        if final == payload.index then return true end
        Editor.flash = { key = "extras", index = final }
        database():MoveExtra(id, payload.index, final)
        return true
    end
    return false
end

local function acceptsPayload(sec, payload)
    if payload.id and payload.id ~= Editor.id then return false end
    if Editor.scroll and not Editor.scroll:IsMouseOver() then return false end
    return payload.type == "entry" or payload.type == "step" or payload.type == "extra"
end

local function buildSection(child, def)
    local sec = Widgets:Section(child, def.title, def.help)
    sec.def, sec.key, sec.frame = def, def.key, sec
    sec.perRow = 1
    sec:EnableMouse(true)
    sec:SetScript("OnMouseDown", function() Editor:SetActive(def.key) end)

    sec.activeBar = Theme:Fill(sec, "ACCENT_COPPER", "ARTWORK")
    sec.activeBar:ClearAllPoints()
    sec.activeBar:SetPoint("TOPLEFT", sec, "TOPLEFT", -8, 0)
    sec.activeBar:SetPoint("BOTTOMLEFT", sec, "BOTTOMLEFT", -8, 0)
    sec.activeBar:SetWidth(2)
    sec.activeBar:Hide()

    sec.grid = CreateFrame("Frame", nil, sec)
    sec.grid:SetPoint("TOPLEFT", sec, "TOPLEFT", 0, sec.top)

    sec.slot = CreateFrame("Button", nil, sec.grid)
    sec.slot:SetSize(TILE, TILE)
    Theme:Fill(sec.slot, "SURFACE")
    Theme:FlatBorder(sec.slot)
    sec.slot.plus = Theme:Text(sec.slot, "+", "title", "TEXT_MUTED")
    sec.slot.plus:SetPoint("CENTER", 0, 1)
    sec.slot.hoverTex = Theme:Texture(sec.slot, "listHover", "OVERLAY")
    sec.slot.hoverTex:SetAllPoints()
    sec.slot.hover = Theme:Fader(sec.slot.hoverTex, 0.08, 0.13)
    sec.slot:SetScript("OnEnter", function(widget) widget.hover:To(1) end)
    sec.slot:SetScript("OnLeave", function(widget) widget.hover:To(0) end)
    sec.slot:SetScript("OnClick", function() Editor:SetActive(def.key) end)
    sec.slot:SetScript("OnReceiveDrag", function() SS.DragDrop:ReceiveCursor(sec) end)
    sec.slotLabel = Theme:Text(sec.grid, def.empty, "small", "TEXT_MUTED")
    sec.slotLabel:SetPoint("LEFT", sec.slot, "RIGHT", 10, 0)

    sec.bar = Theme:Fill(sec.grid, "ACCENT_COPPER", "OVERLAY")
    sec.bar:ClearAllPoints()
    sec.bar:SetSize(3, TILE)
    sec.bar:Hide()

    if def.extras then
        sec.startAttack = Theme:Checkbox(sec, 300, "Start auto-attack", function(box)
            if Editor.id then
                database():SetFlag(Editor.id, "startAttack", box:GetChecked() == true)
            end
        end)
        sec.autoTarget = Theme:Checkbox(sec, 300, "Target the nearest enemy if you have none", function(box)
            if Editor.id then
                database():SetFlag(Editor.id, "autoTarget", box:GetChecked() == true)
            end
        end)
    end

    SS.DragDrop:RegisterTarget(sec, {
        accept = function(payload) return acceptsPayload(sec, payload) end,
        onEnter = function() updateBar(sec) end,
        onMove = function() updateBar(sec) end,
        onLeave = function() hideBar(sec) end,
        onDrop = function(payload) return dropOnSection(sec, payload) end,
        onCursorDrop = function(entry)
            return insertAt(sec, entry, dropIndex(sec))
        end,
    })
    sectionByKey[def.key] = sec
    return sec
end

local function stepBadges(tile, step)
    local target = TARGET_BADGE[step.target or "target"] or ""
    local letters = ""
    local mods = step.mods or {}
    if mods.shift then letters = letters .. "S" end
    if mods.ctrl then letters = letters .. "C" end
    if mods.alt then letters = letters .. "A" end
    tile.target:SetText(target)
    tile.mods:SetText(letters ~= "" and ("+" .. letters) or "")
    tile.strip:SetShown(target ~= "" or letters ~= "")
    local every = tile.section and tile.section.key == "loop" and step.every or nil
    tile.every:SetText(every and ("1/" .. every) or "")
    tile.everyBg:SetWidth(tile.every:GetStringWidth() + 6)
    tile.every:SetShown(every ~= nil)
    tile.everyBg:SetShown(every ~= nil)
end

local function setupTile(sec, index, item, number)
    local tile = acquireTile(sec.grid)
    local entry = sec.def.extras and item or item.entry
    tile.section, tile.index, tile.entry = sec, index, entry
    tile.iconID = entryIcon(entry)
    tile.icon:SetTexture(tile.iconID)
    local x, y = gridPoint(sec, index)
    tile:SetPoint("TOPLEFT", sec.grid, "TOPLEFT", x, y)
    if number then
        tile.num:SetText(tostring(number))
        tile.numBg:SetWidth(tile.num:GetStringWidth() + 6)
        tile.num:Show()
        tile.numBg:Show()
    else
        tile.num:SetText("")
        tile.num:Hide()
        tile.numBg:Hide()
    end
    if sec.def.extras then
        tile.target:SetText("")
        tile.mods:SetText("")
        tile.strip:Hide()
        tile.every:Hide()
        tile.everyBg:Hide()
    else
        stepBadges(tile, item)
    end
    local flash = Editor.flash
    if flash and flash.key == sec.key and flash.index == index then
        Editor.flash = nil
        tile.flashGroup:Stop()
        tile.flashGroup:Play()
    end
end

local function layoutSection(sec, seq, width, base)
    local items = listFor(seq, sec.key)
    local count = #items
    sec.perRow = math.max(1, math.floor((width + GAP) / (TILE + GAP)))
    for index, item in ipairs(items) do
        setupTile(sec, index, item, not sec.def.extras and (base + index) or nil)
    end
    local hasSlot = count < maxFor(sec.key)
    sec.slot:SetShown(hasSlot)
    sec.slotLabel:SetShown(hasSlot and count == 0)
    local slotPosition = count + (hasSlot and 1 or 0)
    if hasSlot then
        local x, y = gridPoint(sec, count + 1)
        sec.slot:ClearAllPoints()
        sec.slot:SetPoint("TOPLEFT", sec.grid, "TOPLEFT", x, y)
    end
    sec.slotLabel:SetWidth(math.max(40, width - TILE - 14))
    local rows = math.max(1, math.ceil(slotPosition / sec.perRow))
    local gridHeight = rows * TILE + (rows - 1) * GAP
    sec:SetWidth(width)
    sec.grid:SetSize(width, gridHeight)
    local body = gridHeight
    if sec.startAttack then
        sec.startAttack:ClearAllPoints()
        sec.startAttack:SetPoint("TOPLEFT", sec, "TOPLEFT", 0, sec.top - gridHeight - 12)
        sec.startAttack.label:SetWidth(math.max(60, width - 34))
        sec.startAttack:SetChecked(seq.startAttack == true)
        body = body + 12 + Theme.checkboxSize
        sec.autoTarget:ClearAllPoints()
        sec.autoTarget:SetPoint("TOPLEFT", sec.startAttack, "BOTTOMLEFT", 0, -6)
        sec.autoTarget.label:SetWidth(math.max(60, width - 34))
        sec.autoTarget:SetChecked(seq.autoTarget ~= false)
        body = body + 6 + Theme.checkboxSize
    end
    sec:SetBodyHeight(body)
    return count
end

local function paragraph(parent, token)
    local label = Theme:Text(parent, "", "small", token or "TEXT_MUTED")
    label:SetWordWrap(true)
    label:SetJustifyV("TOP")
    return label
end

local function buildBody(content)
    local scroll = Widgets:Scroll(content)
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 4, -TOP_HEIGHT)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -(PAD + 16), 8)
    Editor.scroll = scroll
    local child = scroll.child

    Editor.sections = {}
    for _, def in ipairs(SECTIONS) do
        Editor.sections[#Editor.sections + 1] = buildSection(child, def)
    end

    local restart = Widgets:Section(child, "Restart", "Start over from the beginning when:")
    restart.combat = Theme:Checkbox(restart, 300, "When combat ends", function(box)
        if Editor.id then database():SetFlag(Editor.id, "reset.combat", box:GetChecked() == true) end
    end)
    restart.combat:SetPoint("TOPLEFT", restart, "TOPLEFT", 0, restart.top)
    restart.target = Theme:Checkbox(restart, 300, "When your target dies or is cleared", function(box)
        if Editor.id then database():SetFlag(Editor.id, "reset.target", box:GetChecked() == true) end
    end)
    restart.target:SetPoint("TOPLEFT", restart.combat, "BOTTOMLEFT", 0, -6)
    restart:SetBodyHeight(Theme.checkboxSize * 2 + 6)
    Editor.restart = restart

    Editor.preview = paragraph(child, "TEXT_MUTED")
    scroll:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth()
        if width and math.abs(width - (Editor.lastWidth or 0)) > 1 then
            Editor:Refresh(true)
        end
    end)
end

local function layoutProblems(child, problems, width, y)
    for _, line in ipairs(problemLines) do line:Hide() end
    for index, problem in ipairs(problems) do
        local line = problemLines[index]
        if not line then
            line = paragraph(child, "TEXT_WARNING")
            problemLines[index] = line
        end
        Theme:Color(line, problem.level == "error" and "TEXT_ERROR" or "TEXT_WARNING", true)
        line:SetWidth(width)
        line:SetText(problem.text or "")
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
        line:Show()
        y = y + math.ceil(line:GetStringHeight()) + 6
    end
    return y
end

function Editor:Layout(seq)
    local scroll = self.scroll
    local scrollWidth = scroll:GetWidth()
    if not scrollWidth or scrollWidth < 50 then scrollWidth = 360 end
    self.lastWidth = scrollWidth
    local width = math.max(TILE, scrollWidth - PAD * 2)
    releaseTiles()

    local y = PAD
    local openerCount = 0
    for _, sec in ipairs(self.sections) do
        local base = sec.key == "loop" and openerCount or 0
        local count = layoutSection(sec, seq, width, base)
        if sec.key == "opener" then openerCount = count end
        sec:ClearAllPoints()
        sec:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", PAD, -y)
        y = y + sec.height + SECTION_GAP
    end

    local restart = self.restart
    restart:SetWidth(width)
    restart:ClearAllPoints()
    restart:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", PAD, -y)
    restart.combat.label:SetWidth(math.max(60, width - 34))
    restart.target.label:SetWidth(math.max(60, width - 34))
    restart.combat:SetChecked(seq.reset and seq.reset.combat == true)
    restart.target:SetChecked(seq.reset and seq.reset.target == true)
    y = y + restart.height + SECTION_GAP

    local describeOk, description = pcall(SS.Compiler.Describe, SS.Compiler, seq)
    local compileOk, compiled = pcall(SS.Compiler.Compile, SS.Compiler, seq)
    local text = describeOk and description or ""
    if text == "" then
        text = "Add spells to the Loop to see what each press does."
    end
    self.preview:SetWidth(width)
    self.preview:SetText(text)
    self.preview:ClearAllPoints()
    self.preview:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", PAD, -y)
    y = y + math.ceil(self.preview:GetStringHeight()) + 12

    y = layoutProblems(scroll.child, compileOk and compiled and compiled.problems or {}, width, y)
    scroll:UpdateExtent(y + PAD)
end

function Editor:Refresh(force)
    if not self.root then return end
    if not force and not self.root:IsVisible() then
        self.dirty = true
        return
    end
    self.dirty = false
    local id = database():GetSelected(SS.currentSpec)
    if id ~= self.id then
        cancelCapture()
        closeIconMenu()
        self.id = id
    end
    local seq = id and database():GetSequence(id)
    self.empty:SetShown(seq == nil)
    self.content:SetShown(seq ~= nil)
    if not seq then
        self.id = nil
        self:UpdateKeyboard()
        return
    end
    self:RefreshTopBar()
    self:Layout(seq)
    self:UpdateKeyboard()
end

function Editor:UpdateKeyboard(combatStarting)
    local undo = self.undoFrame
    if not undo then return end
    local want = not combatStarting and self.root:IsVisible() and self.id ~= nil and not InCombatLockdown()
    undo:EnableKeyboard(want)
    if want then
        undo:SetPropagateKeyboardInput(true)
    end
end

local function buildKeyboard(root)
    local undo = CreateFrame("Frame", nil, root)
    undo:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        local typing = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if key == "Z" and IsControlKeyDown() and not typing and not (capture and capture.active)
            and database():CanUndo() then
            self:SetPropagateKeyboardInput(false)
            database():Undo()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    undo:EnableKeyboard(false)
    Editor.undoFrame = undo

    capture = CreateFrame("Frame", nil, root)
    capture:SetScript("OnKeyDown", onCaptureKey)
    capture:EnableKeyboard(false)
    capture:SetScript("OnHide", cancelCapture)
    capture:SetScript("OnEvent", function()
        local keyButton = Editor.keyButton
        if not (keyButton and keyButton:IsMouseOver()) then cancelCapture() end
    end)
end

function Editor:Build(parent)
    if self.root then return end
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    self.root, self.frame = root, root
    self.active = "loop"
    self.dirty = true

    self.empty = Theme:Text(root, "Pick a sequence on the left, or create one.", "body", "TEXT_MUTED")
    self.empty:SetPoint("CENTER", root, "CENTER", 0, 0)
    self.empty:SetJustifyH("CENTER")
    self.empty:SetWidth(280)

    self.content = CreateFrame("Frame", nil, root)
    self.content:SetAllPoints(root)
    buildTopBar(self.content)
    buildBody(self.content)
    buildKeyboard(root)
    self:SetActive("loop")

    root:SetScript("OnShow", function()
        if Editor.dirty then
            Editor:Refresh()
        else
            Editor:UpdateKeyboard()
        end
    end)
    root:SetScript("OnHide", function()
        closeIconMenu()
        cancelCapture()
        if SS.StepPopover then SS.StepPopover:Close() end
        Editor:UpdateKeyboard()
    end)

    SS:On("SELECTION_CHANGED", function() Editor:Refresh() end)
    SS:On("SPEC_CHANGED", function() Editor:Refresh() end)
    SS:On("UNDO_CHANGED", function() Editor:Refresh() end)
    SS:On("SEQUENCE_UPDATED", function(id)
        if id == Editor.id or Editor.id == nil then
            Editor:Refresh()
        end
    end)
    SS:On("COMBAT_STARTED", function()
        cancelCapture()
        Editor:UpdateKeyboard(true)
    end)
    SS:On("COMBAT_ENDED", function() Editor:UpdateKeyboard() end)

    self:Refresh()
end
