local _, SS = ...

local Theme = SS.Theme
local Widgets = SS.Widgets
local SpellSidebar = {}
SS.SpellSidebar = SpellSidebar

local PAD = 8
local SEARCH_HEIGHT = 26
local HEADER_HEIGHT, ENTRY_HEIGHT, ICON_SIZE = 26, 30, 24
local HINT_HEIGHT = 30
local CHEVRON = 12
local ICON_CROP = 0.08
local TOOLTIP_HINT = "Click to add \194\183 Drag to place"

local searchBox, scroll, hint, emptyText
local headerPool, entryPool = {}, {}
local collapsedByUser = {}
local built = false

local function mutedLine(text)
    local r, g, b = unpack(Theme.colors.TEXT_MUTED)
    GameTooltip:AddLine(text, r, g, b, true)
end

function SpellSidebar:ShowTooltip(owner, entry, hintText, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    local kind, id = entry.kind, entry.id
    local ok = false
    if kind == "spell" or kind == "pet" then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, id)
    elseif kind == "item" then
        ok = pcall(GameTooltip.SetItemByID, GameTooltip, id)
    elseif kind == "slot" then
        ok = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", id)
    end
    if not ok then
        local name = SS.Compiler and SS.Compiler.EntryName(entry) or tostring(id)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(name or "Unknown", 1, 1, 1)
    end
    if hintText then
        mutedLine(hintText)
    end
    GameTooltip:Show()
end

local function acquireHeader()
    for _, row in ipairs(headerPool) do
        if not row:IsShown() then return row end
    end
    local row = CreateFrame("Button", nil, scroll.child)
    row:SetHeight(HEADER_HEIGHT)
    row.hover = Theme:RowHighlight(row)
    row.chevron = Theme:Texture(row, "scrollDown", "OVERLAY")
    row.chevron:SetSize(CHEVRON, CHEVRON)
    row.chevron:SetPoint("LEFT", 8, 0)
    row.title = Theme:Text(row, "", "body", "TEXT_TITLE")
    row.title:SetPoint("LEFT", row.chevron, "RIGHT", 8, 0)
    row.count = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.count:SetPoint("LEFT", row.title, "RIGHT", 6, 0)
    row:SetScript("OnEnter", function(widget) widget.hover:To(1) end)
    row:SetScript("OnLeave", function(widget) widget.hover:To(0) end)
    row:SetScript("OnClick", function(widget)
        collapsedByUser[widget.key] = not widget.collapsed
        SpellSidebar:Refresh()
    end)
    headerPool[#headerPool + 1] = row
    return row
end

local function acquireEntry()
    for _, row in ipairs(entryPool) do
        if not row:IsShown() then return row end
    end
    local row = CreateFrame("Button", nil, scroll.child)
    row:SetHeight(ENTRY_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row.hover = Theme:RowHighlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", 14, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.name = Theme:Text(row, "", "body", "TEXT_BODY")
    row.name:SetWordWrap(false)
    row.sub = Theme:Text(row, "", "small", "TEXT_MUTED")
    row.sub:SetWordWrap(false)
    row:SetScript("OnEnter", function(widget)
        widget.hover:To(1)
        if not SS.DragDrop:IsDragging() then
            SpellSidebar:ShowTooltip(widget, widget.entry, TOOLTIP_HINT)
        end
    end)
    row:SetScript("OnLeave", function(widget)
        widget.hover:To(0)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(widget)
        if SS.Editor and widget.entry then
            SS.Editor:AddEntry(widget.entry)
        end
    end)
    SS.DragDrop:RegisterSource(row, function(widget)
        GameTooltip:Hide()
        return { type = "entry", entry = widget.entry }, widget.iconID
    end)
    entryPool[#entryPool + 1] = row
    return row
end

local function setupEntry(row, data, y)
    row.entry = data.entry
    row.iconID = data.icon or Theme.assets.unknownItem.file
    row.icon:SetTexture(row.iconID)
    row.name:SetText(data.name or "")
    row.name:ClearAllPoints()
    row.sub:ClearAllPoints()
    row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    if data.subtext and data.subtext ~= "" then
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
        row.sub:SetText(data.subtext)
        row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -1)
        row.sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.sub:Show()
    else
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.sub:SetText("")
        row.sub:Hide()
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -y)
    row:Show()
end

local function setupHeader(row, category, collapsed, y)
    row.key = category.key
    row.collapsed = collapsed
    row.title:SetText(category.title or "")
    row.count:SetText(tostring(#category.entries))
    row.chevron:SetRotation(collapsed and math.pi / 2 or 0)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -y)
    row:Show()
end

function SpellSidebar:Refresh()
    if not built then return end
    for _, row in ipairs(headerPool) do row:Hide() end
    for _, row in ipairs(entryPool) do row:Hide() end

    local text = strtrim(searchBox:GetText() or "")
    local searching = text ~= ""
    local categories = SS.SpellSource and SS.SpellSource:GetCategories(searching and text or nil) or {}

    local y, shown, headerIndex, entryIndex = 0, 0, 0, 0
    for _, category in ipairs(categories) do
        if #category.entries > 0 then
            shown = shown + 1
            local collapsed
            if searching then
                collapsed = false
            elseif collapsedByUser[category.key] ~= nil then
                collapsed = collapsedByUser[category.key]
            else
                collapsed = category.collapsedByDefault == true
            end
            headerIndex = headerIndex + 1
            local header = headerPool[headerIndex] or acquireHeader()
            setupHeader(header, category, collapsed, y)
            y = y + HEADER_HEIGHT
            if not collapsed then
                for _, data in ipairs(category.entries) do
                    entryIndex = entryIndex + 1
                    local row = entryPool[entryIndex] or acquireEntry()
                    setupEntry(row, data, y)
                    y = y + ENTRY_HEIGHT
                end
            end
        end
    end

    emptyText:SetShown(shown == 0)
    scroll:UpdateExtent(y + 4)
end

local function updatePlaceholder()
    local focused = searchBox:HasFocus()
    searchBox.placeholder:SetShown((searchBox:GetText() or "") == "" and not focused)
end

function SpellSidebar:Build(parent)
    if built then return end
    built = true
    self.frame = parent

    searchBox = Widgets:Search(parent, 100, SEARCH_HEIGHT, "Search spells")
    searchBox:SetPoint("TOPLEFT", PAD, -PAD)
    searchBox:SetPoint("TOPRIGHT", -PAD, -PAD)
    searchBox:HookScript("OnTextChanged", function()
        updatePlaceholder()
        SpellSidebar:Refresh()
    end)
    searchBox:HookScript("OnEditFocusGained", updatePlaceholder)
    searchBox:HookScript("OnEditFocusLost", updatePlaceholder)

    scroll = Widgets:Scroll(parent)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + SEARCH_HEIGHT + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -(PAD + 14), HINT_HEIGHT)
    scroll:SetScript("OnSizeChanged", function()
        SpellSidebar:Refresh()
    end)

    hint = Theme:Text(parent, "Tip: you can also drag from your spellbook", "small", "TEXT_MUTED")
    hint:SetPoint("BOTTOMLEFT", PAD + 4, 8)
    hint:SetPoint("BOTTOMRIGHT", -PAD - 4, 8)
    hint:SetWordWrap(true)
    hint:SetJustifyV("BOTTOM")

    emptyText = Theme:Text(scroll, "No spells match", "body", "TEXT_MUTED")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
    emptyText:SetJustifyH("CENTER")
    emptyText:Hide()

    parent:HookScript("OnShow", function()
        if SS.SpellSource and SS.SpellSource.Refresh then
            SS.SpellSource:Refresh()
        end
        SpellSidebar:Refresh()
    end)

    SS:On("SPELLS_UPDATED", function()
        if parent:IsVisible() then
            SpellSidebar:Refresh()
        end
    end)

    self:Refresh()
end
