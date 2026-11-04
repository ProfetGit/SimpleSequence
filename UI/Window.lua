local _, SS = ...
local Theme = SS.Theme
local Window = {}
SS.Window = Window

BINDING_HEADER_SIMPLESEQUENCE = "SimpleSequence"
BINDING_NAME_SIMPLESEQUENCE_TOGGLE = "Toggle window"

local WIDTH, HEIGHT, PAD = 920, 660, 24
local LEFT_WIDTH, RIGHT_WIDTH, GUTTER = 190, 250, 16
local HEADER_HEIGHT, RULE_Y = 48, 44
local COLUMN_TOP, COLUMN_BOTTOM = -70, 24
local GROUND_OUTSET = 6
local FADE_TIME, TOAST_TIME = 0.15, 3
local TOAST_LEVEL, TOAST_HEIGHT, TOAST_PAD, TOAST_GAP = 30, 34, 14, 16
local PENDING_TEXT = "Changes apply when combat ends"

local VALID_POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

local frame = CreateFrame("Frame", "SimpleSequenceFrame", UIParent)
Window.frame = frame
frame:SetSize(WIDTH, HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
tinsert(UISpecialFrames, "SimpleSequenceFrame")

Theme:Panel(frame)
Theme:Vignette(frame, Theme.panelInset)

local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", PAD, -12)
header:SetPoint("TOPRIGHT", -PAD, -12)
header:SetHeight(HEADER_HEIGHT)
local title = Theme:Text(header, "SimpleSequence", "title", "TEXT_TITLE")
title:SetPoint("TOPLEFT", 0, -10)
local specLabel = Theme:Text(header, "", "body", "TEXT_MUTED")
specLabel:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 12, 0)
local rule = Theme:Divider(header)

local close = Theme:CloseButton(frame, function() frame:Hide() end)
close:SetPoint("CENTER", frame, "TOPRIGHT", -10, -10)
close:SetFrameLevel(frame:GetFrameLevel() + Theme.vignetteLevel + 1)

local banner = CreateFrame("Frame", nil, header)
banner:SetHeight(22)
banner:SetPoint("TOPRIGHT", -28, -8)
Theme:Fill(banner, "BANNER_BG")
local bannerText = Theme:Text(banner, "", "small", "TEXT_WARNING")
bannerText:SetPoint("CENTER")
banner:Hide()

local columns = {}
Window.columns = columns

local function makeColumn(name, ground)
    local column = CreateFrame("Frame", nil, frame)
    columns[name] = column
    if ground then
        local fill = column:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", -GROUND_OUTSET, GROUND_OUTSET)
        fill:SetPoint("BOTTOMRIGHT", GROUND_OUTSET, -GROUND_OUTSET)
        Theme:ApplyAsset(fill, "columnGround")
    end
    return column
end

local left = makeColumn("left", true)
left:SetPoint("TOPLEFT", PAD, COLUMN_TOP)
left:SetPoint("BOTTOMLEFT", PAD, COLUMN_BOTTOM)
left:SetWidth(LEFT_WIDTH)
local right = makeColumn("right", true)
right:SetPoint("TOPRIGHT", -PAD, COLUMN_TOP)
right:SetPoint("BOTTOMRIGHT", -PAD, COLUMN_BOTTOM)
right:SetWidth(RIGHT_WIDTH)
local middle = makeColumn("middle", false)
middle:SetPoint("TOPLEFT", left, "TOPRIGHT", GUTTER, 0)
middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -GUTTER, 0)

frame.fadeIn = frame:CreateAnimationGroup()
local fade = frame.fadeIn:CreateAnimation("Alpha")
fade:SetFromAlpha(0)
fade:SetToAlpha(1)
fade:SetDuration(FADE_TIME)
fade:SetSmoothing("OUT")

local function guarded(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local built = {}

local MODULES = {
    { key = "SequenceList", column = "left" },
    { key = "Editor", column = "middle" },
    { key = "SpellSidebar", column = "right" },
}

local function buildColumns()
    for _, entry in ipairs(MODULES) do
        local module = SS[entry.key]
        if not built[entry.key] and module and module.Build then
            built[entry.key] = true
            guarded(module.Build, module, columns[entry.column])
        end
    end
end

function Window:Refresh(only)
    for _, entry in ipairs(MODULES) do
        local module = SS[entry.key]
        if built[entry.key] and module and module.Refresh and (not only or only[entry.key]) then
            guarded(module.Refresh, module)
        end
    end
end

function Window:RefreshSpec()
    local label = SS:GetSpecLabel()
    specLabel:SetText(label or "")
end

function Window:SetBanner(text)
    if text and text ~= "" then
        bannerText:SetText(text)
        banner:SetWidth(bannerText:GetStringWidth() + 20)
        banner:Show()
    else
        banner:Hide()
    end
end

function Window:SavePosition()
    if not (SS.db and SS.db.window) then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point and type(x) == "number" and type(y) == "number" then
        SS.db.window.point = { point, relativePoint, x, y }
    end
end

function Window:RestorePosition()
    local saved = SS.db and SS.db.window and SS.db.window.point
    if type(saved) ~= "table" then return end
    local point, relativePoint, x, y = saved[1], saved[2], saved[3], saved[4]
    if VALID_POINTS[point] and VALID_POINTS[relativePoint] and type(x) == "number" and type(y) == "number" then
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, Theme:Snap(frame, x), Theme:Snap(frame, y))
    end
end

local function snapPosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(x) ~= "number" or type(y) ~= "number" then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, Theme:Snap(frame, x), Theme:Snap(frame, y))
end

local function alignRule()
    Theme:AlignHairline(rule, header, RULE_Y)
end

frame:SetScript("OnDragStart", function(widget) widget:StartMoving() end)
frame:SetScript("OnDragStop", function(widget)
    widget:StopMovingOrSizing()
    snapPosition()
    Window:SavePosition()
    alignRule()
end)

frame:SetScript("OnShow", function(widget)
    if not widget.restored then
        widget.restored = true
        Window:RestorePosition()
    end
    buildColumns()
    Window:RefreshSpec()
    alignRule()
    widget.fadeIn:Stop()
    widget.fadeIn:Play()
    local pending = SS.Engine and SS.Engine.IsPending and SS.Engine:IsPending()
    Window:SetBanner(pending and PENDING_TEXT or nil)
    Window:Refresh()
end)

frame:SetScript("OnHide", function()
    Window:SavePosition()
    if GameTooltip then GameTooltip:Hide() end
end)

local toast = CreateFrame("Frame", nil, frame)
toast:SetFrameLevel(frame:GetFrameLevel() + TOAST_LEVEL)
toast:SetHeight(TOAST_HEIGHT)
toast:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
toast:EnableMouse(true)
Theme:Panel(toast, true)
toast.text = Theme:Text(toast, "", "body", "TEXT_BODY")
toast.text:SetPoint("LEFT", TOAST_PAD, 0)
toast.text:SetWordWrap(false)
toast.action = CreateFrame("Button", nil, toast)
toast.action:SetHeight(TOAST_HEIGHT)
toast.action:SetPoint("RIGHT", -TOAST_PAD, 0)
toast.action.label = Theme:Text(toast.action, "", "body", "TEXT_TITLE")
toast.action.label:SetPoint("CENTER")
toast.action:SetScript("OnEnter", function(widget) Theme:Color(widget.label, "TEXT_HIGHLIGHT", true) end)
toast.action:SetScript("OnLeave", function(widget) Theme:Color(widget.label, "TEXT_TITLE", true) end)
toast.fader = Theme:Fader(toast, 0.12, 0.25)
toast.fader.group:HookScript("OnFinished", function()
    if toast.fader.resting == 0 then toast:Hide() end
end)
toast:Hide()

local function dismissToast()
    if toast.timer then
        toast.timer:Cancel()
        toast.timer = nil
    end
    toast.fader:To(0)
end

toast.action:SetScript("OnClick", function()
    local fn = toast.actionFn
    toast.actionFn = nil
    dismissToast()
    if fn then fn() end
end)

function Window:Toast(text, actionLabel, actionFn)
    if not frame:IsShown() then
        SS:Print(text)
        return
    end
    if toast.timer then toast.timer:Cancel() end
    toast.text:SetText(text or "")
    local width = TOAST_PAD * 2 + toast.text:GetStringWidth()
    if actionLabel and actionFn then
        toast.action.label:SetText(actionLabel)
        local actionWidth = toast.action.label:GetStringWidth() + 8
        toast.action:SetWidth(actionWidth)
        toast.action:Show()
        toast.actionFn = actionFn
        width = width + TOAST_GAP + actionWidth
    else
        toast.action:Hide()
        toast.actionFn = nil
    end
    toast:SetWidth(math.min(width, WIDTH - 2 * PAD))
    toast:Show()
    toast.fader:To(1)
    toast.timer = C_Timer.NewTimer(TOAST_TIME, function()
        toast.timer = nil
        toast.fader:To(0)
    end)
end

function Window:Show()
    frame:Show()
end

function Window:Hide()
    frame:Hide()
end

function Window:Toggle()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Window:IsShown()
    return frame:IsShown()
end

SS:On("SPEC_CHANGED", function()
    if not frame:IsShown() then return end
    Window:RefreshSpec()
    Window:Refresh()
end)

local function refreshList()
    if frame:IsShown() then Window:Refresh({ SequenceList = true }) end
end

SS:On("SEQUENCES_CHANGED", refreshList)
SS:On("SELECTION_CHANGED", refreshList)
SS:On("SEQUENCE_UPDATED", refreshList)

SS:On("ENGINE_PENDING", function(isPending)
    Window:SetBanner(isPending and PENDING_TEXT or nil)
end)

local function onPixelsChanged()
    Theme:RefreshHairlines()
    if frame:IsShown() then alignRule() end
end

SS:RegisterGameEvent("UI_SCALE_CHANGED", onPixelsChanged)
SS:RegisterGameEvent("DISPLAY_SIZE_CHANGED", onPixelsChanged)
