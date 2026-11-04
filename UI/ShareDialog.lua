local _, SS = ...
local Theme = SS.Theme
local Widgets = SS.Widgets
local Dialog = {}
SS.ShareDialog = Dialog

local WIDTH, HEIGHT, PAD = 560, 380, 24
local TITLE_Y, HINT_Y, BOX_TOP, BOX_BOTTOM = -22, -52, -80, 78
local SCROLL_RIGHT = 28
local CHAR_WIDTH, LINE_HEIGHT, TEXT_INSET = 8, 14, 20
local PREVIEW_DELAY = 0.15
local FRAME_NAME = "SimpleSequenceShareDialog"

local frame, box, scroll, titleText, hintText, previewText, importButton, placeholder
local mode, exportText

local function toast(...)
    if SS.Window then SS.Window:Toast(...) end
end

local function resizeBox()
    local visible = scroll:GetHeight()
    local width = scroll:GetWidth()
    if not width or width < 1 then width = WIDTH - 2 * PAD - SCROLL_RIGHT end
    local usable = math.max(1, width - TEXT_INSET)
    local lines = math.ceil(box:GetNumLetters() * CHAR_WIDTH / usable) + 1
    local height = math.max(visible or 0, lines * LINE_HEIGHT + 12)
    box:SetWidth(width)
    scroll:UpdateExtent(height)
    box:SetHeight(height)
end

local function setPreview(text, token)
    previewText:SetText(text or "")
    Theme:Color(previewText, token or "TEXT_BODY", true)
end

local function updatePreview()
    local text = strtrim(box:GetText())
    if text == "" then
        setPreview("")
        importButton:Disable()
        return
    end
    local payload, err = SS.Share:Decode(text)
    if not payload then
        setPreview(err or "That is not a SimpleSequence string.", "TEXT_ERROR")
        importButton:Disable()
        return
    end
    local summary, unknown = SS.Share:Preview(payload)
    summary = summary or ""
    if unknown and #unknown > 0 and not summary:find(unknown[1], 1, true) then
        summary = summary .. " (spells you don't know: " .. table.concat(unknown, ", ") .. ")"
    end
    setPreview(summary, "TEXT_BODY")
    importButton:Enable()
end

local function doImport()
    local text = strtrim(box:GetText())
    local sequences, err = SS.Share:Import(text)
    if not sequences or #sequences == 0 then
        setPreview(err or "Nothing could be imported.", "TEXT_ERROR")
        importButton:Disable()
        return
    end
    frame:Hide()
    SS.Database:SetSelected(SS.currentSpec, sequences[1].id)
    if #sequences == 1 then
        toast("Imported \"" .. (sequences[1].name or "sequence") .. "\"")
    else
        toast("Imported " .. #sequences .. " sequences")
    end
end

local function onTextChanged(_, userInput)
    resizeBox()
    if mode == "export" then
        if userInput and exportText then
            box:SetText(exportText)
            box:HighlightText()
        end
        return
    end
    placeholder:SetShown(box:GetText() == "")
    SS:Debounce("ShareDialogPreview", PREVIEW_DELAY, updatePreview)
end

local function build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(widget) widget:StartMoving() end)
    frame:SetScript("OnDragStop", function(widget) widget:StopMovingOrSizing() end)
    frame:Hide()
    tinsert(UISpecialFrames, FRAME_NAME)
    Theme:Panel(frame)

    local close = Theme:CloseButton(frame, function() frame:Hide() end)
    close:SetPoint("CENTER", frame, "TOPRIGHT", -10, -10)

    titleText = Theme:Text(frame, "", "title", "TEXT_TITLE")
    titleText:SetPoint("TOPLEFT", PAD, TITLE_Y)
    titleText:SetPoint("RIGHT", frame, "RIGHT", -PAD - 24, 0)
    titleText:SetWordWrap(false)
    hintText = Theme:Text(frame, "", "body", "TEXT_MUTED")
    hintText:SetPoint("TOPLEFT", PAD, HINT_Y)

    scroll = Widgets:Scroll(frame)
    scroll:SetPoint("TOPLEFT", PAD, BOX_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLL_RIGHT, BOX_BOTTOM)

    box = Widgets:Input(scroll, WIDTH - 2 * PAD - SCROLL_RIGHT, 200, true)
    box:SetMaxLetters(0)
    scroll:SetScrollChild(box)
    scroll.child = box
    box:SetScript("OnTextChanged", onTextChanged)
    box:SetScript("OnEscapePressed", function(widget)
        widget:ClearFocus()
        frame:Hide()
    end)

    placeholder = Theme:Text(box, "Paste a SimpleSequence string", "body", "TEXT_MUTED")
    placeholder:SetPoint("TOPLEFT", 10, -8)

    previewText = Theme:Text(frame, "", "body", "TEXT_BODY")
    previewText:SetPoint("BOTTOMLEFT", PAD, 34)
    previewText:SetPoint("RIGHT", frame, "RIGHT", -PAD - 130, 0)
    previewText:SetJustifyV("MIDDLE")
    previewText:SetHeight(32)
    previewText:SetWordWrap(true)

    importButton = Theme:Button(frame, 110, "Import", doImport, 26)
    importButton:SetPoint("BOTTOMRIGHT", -PAD, 34)
    frame:SetScript("OnHide", function()
        box:ClearFocus()
        exportText = nil
    end)
end

local function open(newMode, title, hint)
    if not frame then build() end
    mode = newMode
    titleText:SetText(title)
    hintText:SetText(hint)
    setPreview("")
    importButton:SetShown(newMode == "import")
    placeholder:SetShown(newMode == "import")
    previewText:SetShown(newMode == "import")
    frame:Show()
    frame:Raise()
end

function Dialog:ShowExport(name, text)
    open("export", "Export: " .. (name or ""), "Press Ctrl+C to copy")
    exportText = text or ""
    box:SetText(exportText)
    resizeBox()
    scroll:ScrollTo(0, true)
    box:SetFocus()
    box:HighlightText()
end

function Dialog:ShowImport()
    open("import", "Import sequences", "Paste a SimpleSequence string")
    exportText = nil
    importButton:Disable()
    box:SetText("")
    resizeBox()
    scroll:ScrollTo(0, true)
    box:SetFocus()
end
