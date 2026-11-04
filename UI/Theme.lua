local _, SS = ...
local Theme = {}
SS.Theme = Theme

local unpack = unpack
Theme.colors = {
    PANEL_BG = { 0.065, 0.051, 0.041, 0.98 },
    -- Blizzard's translucent dialog ground (DialogBorderTranslucentTemplate): black at four fifths.
    DIALOG_BG = { 0, 0, 0, 0.8 },
    SURFACE = { 0.105, 0.086, 0.068, 0.98 },
    ROW_BG = { 0.145, 0.120, 0.094, 0.92 },
    BORDER_BRONZE = { 0.48, 0.34, 0.20, 1 },
    ACCENT_COPPER = { 0.78, 0.54, 0.30, 1 },
    TEXT_TITLE = { 0.91, 0.76, 0.49, 1 },
    TEXT_BODY = { 0.89, 0.84, 0.73, 1 },
    TEXT_MUTED = { 0.66, 0.62, 0.55, 1 },
    TEXT_HIGHLIGHT = { 1, 0.98, 0.94, 1 },
    TEXT_ACTIVE = { 0.90, 0.94, 0.80, 1 },
    TEXT_WARNING = { 1, 0.63, 0.35, 1 },
    -- Something broke rather than something missing: a feature that failed, not one that
    -- is unavailable.
    TEXT_ERROR = { 1, 0.40, 0.34, 1 },
    HIGHLIGHT = { 0.91, 0.75, 0.48, 0.20 },
    RING_SHADOW = { 0, 0, 0, 0.45 },
    -- The shade a window carries around the inside of its border, darkest at the edge.
    VIGNETTE = { 0, 0, 0, 0.42 },
    RING_SHADOW_SOFT = { 0, 0, 0, 0.16 },
    RING_TRACK = { 0.28, 0.24, 0.19, 0.85 },
    RING_FILL = { 0.85, 0.70, 0.42, 1 },
    RING_LAST = { 1, 0.86, 0.36, 1 },
    RING_DONE = { 0.43, 0.82, 0.40, 1 },
    -- The loot feed art is white with an alpha channel and carries no colour of its own.
    -- LOOT_ROW is the smudge behind a row, its alpha replaced by the opacity setting.
    LOOT_ROW = { 0.07, 0.05, 0.04, 0.85 },
    LOOT_UNDERLINE = { 0.48, 0.34, 0.20, 0.30 },
    -- The farm HUD art is white with an alpha channel too. HUD_BG is the smudge behind the
    -- whole HUD, its alpha replaced by the opacity setting; HUD_TRACK is the unfilled half
    -- of the goal meter, which has to stay readable over snow without competing with the fill.
    HUD_BG = { 0.07, 0.05, 0.04, 0.90 },
    HUD_TRACK = { 0.47, 0.41, 0.33, 0.55 },
    QUEST_VALUE = { 1, 1, 1, 1 },
    QUEST_TOTAL = { 0.90, 0.90, 0.86, 1 },
    TEXT_LAST = { 1, 0.86, 0.36, 1 },
    PLATE_DIM = { 0, 0, 0, 0.55 },
    MAP_UNEXPLORED = { 0.72, 0.72, 0.72, 1 },
    TILE_BG = { 0.082, 0.066, 0.052, 0.95 },
    SLOT_EMPTY = { 0.145, 0.120, 0.094, 0.55 },
    TOAST_BG = { 0.065, 0.051, 0.041, 0.96 },
    BANNER_BG = { 0.30, 0.20, 0.10, 0.92 },
    DROP_MARK = { 0.91, 0.75, 0.48, 0.85 },
}
-- Shared immutable gradient endpoints; allocated once, never during progress updates.
Theme.ringShadeBottom = CreateColor(0.55, 0.55, 0.55, 1)
Theme.ringShadeTop = CreateColor(1, 1, 1, 1)
Theme.fonts = { title = "GameFontNormalLarge", body = "GameFontNormal", small = "GameFontNormalSmall",
    editLabel = "GameFontHighlightLarge" }

-- The window border is one of Blizzard's NineSliceLayouts (12.1.0 NineSliceLayouts.lua),
-- applied by NineSliceUtil so every piece takes its size from the atlas. "Dialog" is the
-- DiamondMetal frame every Retail dialog wears; "GenericMetal" and "SimplePanelTemplate"
-- are the other window-sized kits.
Theme.panelLayout = "Dialog"

-- Refactor's own addon icon, one path per size. Nothing else in the addon spells these
-- paths out: UI code goes through the appIcon, minimapIcon and smallIcon assets, and the
-- namespace exposes this table as R.Media.icons.
Theme.icons = {
    app = "Interface\\AddOns\\SimpleSequence\\Media\\Icon64",
    minimap = "Interface\\AddOns\\SimpleSequence\\Media\\IconMinimap",
    small = "Interface\\AddOns\\SimpleSequence\\Media\\Icon32",
    -- Blizzard's AddOn list scales the .toc icon into a fixed box, so this copy is cropped
    -- tighter than Icon64: the mark fills the box instead of floating in its own margin.
    list = "Interface\\AddOns\\SimpleSequence\\Media\\IconList",
}

-- Verified in Blizzard's 12.1.0 UI source: ThreeSliceButtonMixin and MinimalScrollBar.
-- Never fall back to legacy panel art.
Theme.assets = {
    panelFill = { atlas = "ui-frame-dragonflight-backgroundtile", fallback = "PANEL_BG" },
    header = { atlas = "dragonriding-talents-line", fallback = "BORDER_BRONZE" },
    -- UIPanelButtonTemplate's own kit (ThreeSliceButtonMixin, atlasName "128-RedButton"). The
    -- caps are 114 and 292 px wide at 128 px tall, so they are scaled by height, never squashed.
    buttonLeft = { atlas = "128-RedButton-Left", fallback = "ROW_BG" },
    buttonCenter = { atlas = "_128-RedButton-Center", fallback = "ROW_BG" },
    buttonRight = { atlas = "128-RedButton-Right", fallback = "ROW_BG" },
    buttonLeftPressed = { atlas = "128-RedButton-Left-Pressed", fallback = "SURFACE" },
    buttonCenterPressed = { atlas = "_128-RedButton-Center-Pressed", fallback = "SURFACE" },
    buttonRightPressed = { atlas = "128-RedButton-Right-Pressed", fallback = "SURFACE" },
    buttonLeftDisabled = { atlas = "128-RedButton-Left-Disabled", fallback = "SURFACE" },
    buttonCenterDisabled = { atlas = "_128-RedButton-Center-Disabled", fallback = "SURFACE" },
    buttonRightDisabled = { atlas = "128-RedButton-Right-Disabled", fallback = "SURFACE" },
    buttonHighlight = { atlas = "128-RedButton-Highlight", fallback = "HIGHLIGHT" },
    -- UIPanelCloseButtonNoScripts, SettingsCategoryListButtonMixin, MinimalTabTemplate,
    -- InputBoxVisualTemplate, SearchBoxTemplate, SettingsList and MinimalCheckboxArtTemplate,
    -- all read from the 12.1.0 UI source.
    closeNormal = { atlas = "RedButton-Exit", fallback = "ACCENT_COPPER" },
    closePressed = { atlas = "RedButton-Exit-Pressed", fallback = "BORDER_BRONZE" },
    closeHighlight = { atlas = "RedButton-Highlight", fallback = "HIGHLIGHT" },
    listActive = { atlas = "Options_List_Active", fallback = "HIGHLIGHT" },
    listHover = { atlas = "Options_List_Hover", fallback = "HIGHLIGHT" },
    tabLeft = { atlas = "Options_Tab_Left", fallback = "SURFACE" },
    tabMiddle = { atlas = "Options_Tab_Middle", fallback = "SURFACE" },
    tabRight = { atlas = "Options_Tab_Right", fallback = "SURFACE" },
    tabActiveLeft = { atlas = "Options_Tab_Active_Left", fallback = "ROW_BG" },
    tabActiveMiddle = { atlas = "Options_Tab_Active_Middle", fallback = "ROW_BG" },
    tabActiveRight = { atlas = "Options_Tab_Active_Right", fallback = "ROW_BG" },
    inputLeft = { atlas = "common-search-border-left", fallback = "SURFACE" },
    inputMiddle = { atlas = "common-search-border-middle", fallback = "SURFACE" },
    inputRight = { atlas = "common-search-border-right", fallback = "SURFACE" },
    searchIcon = { atlas = "common-search-magnifyingglass", fallback = "TEXT_MUTED" },
    rowDivider = { atlas = "Options_HorizontalDivider", fallback = "BORDER_BRONZE" },
    -- Interface\Common\help-i, the "i" Blizzard's HelpPlate and Communities frames use.
    infoIcon = { file = 616343 },
    undoIcon = { atlas = "talents-button-undo", fallback = "ACCENT_COPPER" },
    -- PanelResizeButtonTemplate's grabber, the same one on every resizable Blizzard panel.
    resizeGrip = { file = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" },
    resizeGripPressed = { file = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" },
    resizeGripHighlight = { file = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight" },
    -- MinimalScrollBar.xml stacks three pieces per bar: a cap at each end at its own atlas
    -- size and a middle stretched between them. One stretched middle on its own is what
    -- squares off the ends. Track caps come from the full-size kit and the thumb from the
    -- small kit, which is the pairing Blizzard's own template uses.
    scrollTrackTop = { atlas = "minimal-scrollbar-track-top", fallback = "SURFACE" },
    scrollTrackMiddle = { atlas = "!minimal-scrollbar-track-middle", fallback = "SURFACE" },
    scrollTrackBottom = { atlas = "minimal-scrollbar-track-bottom", fallback = "SURFACE" },
    scrollThumbTop = { atlas = "minimal-scrollbar-small-thumb-top", fallback = "ACCENT_COPPER" },
    scrollThumbMiddle = { atlas = "minimal-scrollbar-small-thumb-middle", fallback = "ACCENT_COPPER" },
    scrollThumbBottom = { atlas = "minimal-scrollbar-small-thumb-bottom", fallback = "ACCENT_COPPER" },
    scrollThumbTopOver = { atlas = "minimal-scrollbar-small-thumb-top-over", fallback = "HIGHLIGHT" },
    scrollThumbMiddleOver = { atlas = "minimal-scrollbar-small-thumb-middle-over", fallback = "HIGHLIGHT" },
    scrollThumbBottomOver = { atlas = "minimal-scrollbar-small-thumb-bottom-over", fallback = "HIGHLIGHT" },
    scrollThumbTopDown = { atlas = "minimal-scrollbar-small-thumb-top-down", fallback = "BORDER_BRONZE" },
    scrollThumbMiddleDown = { atlas = "minimal-scrollbar-small-thumb-middle-down", fallback = "BORDER_BRONZE" },
    scrollThumbBottomDown = { atlas = "minimal-scrollbar-small-thumb-bottom-down", fallback = "BORDER_BRONZE" },
    scrollUp = { atlas = "minimal-scrollbar-arrow-top", fallback = "ACCENT_COPPER" },
    scrollUpOver = { atlas = "minimal-scrollbar-arrow-top-over", fallback = "HIGHLIGHT" },
    scrollUpDown = { atlas = "minimal-scrollbar-arrow-top-down", fallback = "BORDER_BRONZE" },
    scrollDown = { atlas = "minimal-scrollbar-arrow-bottom", fallback = "ACCENT_COPPER" },
    scrollDownOver = { atlas = "minimal-scrollbar-arrow-bottom-over", fallback = "HIGHLIGHT" },
    scrollDownDown = { atlas = "minimal-scrollbar-arrow-bottom-down", fallback = "BORDER_BRONZE" },
    -- Objective atlases selected in TextureAtlasViewer on the installed client.
    columnGround = { fallback = "SURFACE" },
    questRing = { file = "Interface\\AddOns\\SimpleSequence\\Media\\RefactorRing.tga" },
    questIconKill = { atlas = "Crosshair_Attack_48", fallback = "TEXT_MUTED" },
    questIconItem = { atlas = "Crosshair_buy_48", fallback = "TEXT_MUTED" },
    questIconOther = { atlas = "QuestNormal", fallback = "TEXT_MUTED" },
    questCheck = { atlas = "common-icon-checkmark", fallback = "RING_DONE" },
    checkboxBox = { atlas = "checkbox-minimal", fallback = "SURFACE" },
    checkboxTick = { atlas = "checkmark-minimal", fallback = "RING_DONE" },
    checkboxTickDisabled = { atlas = "checkmark-minimal-disabled", fallback = "TEXT_MUTED" },
    checkboxHighlight = { atlas = "checkbox-minimal", fallback = "HIGHLIGHT" },
    minimapBorder = { file = 136430 },
    -- Interface\\Minimap\\UI-Minimap-Background, the circle Blizzard draws under the minimap
    -- itself. IconMinimap.tga is a transparent mark, so it needs something to sit on.
    minimapIconBackdrop = { file = 136467 },
    minimapHighlight = { file = 136477 },
    -- The mail attachment slot (MailFrame.xml): an empty slot to drop an item into, the white
    -- icon frame Blizzard tints with the item's quality, and the question mark for an item the
    -- client has not described yet.
    itemSlot = { file = "Interface\\Buttons\\UI-EmptySlot-White" },
    itemBorder = { file = "Interface\\Common\\WhiteIconFrame" },
    unknownItem = { file = 134400 },
    -- Refactor's own: a 32 px white diamond with a soft edge, tinted copper where it is used.
    headerMark = { file = "Interface\\AddOns\\SimpleSequence\\Media\\Diamond.tga", fallback = "ACCENT_COPPER" },
    appIcon = { file = Theme.icons.app },
    minimapIcon = { file = Theme.icons.minimap },
    smallIcon = { file = Theme.icons.small },
    -- MinimalSliderTemplate and MinimalSliderWithSteppersTemplate, the slider Blizzard's own
    -- Edit Mode dialog uses for every numeric system setting (12.1.0 MinimalSlider.xml).
    sliderLeft = { atlas = "Minimal_SliderBar_Left", fallback = "SURFACE" },
    sliderMiddle = { atlas = "_Minimal_SliderBar_Middle", fallback = "SURFACE" },
    sliderRight = { atlas = "Minimal_SliderBar_Right", fallback = "SURFACE" },
    sliderThumb = { atlas = "Minimal_SliderBar_Button", fallback = "ACCENT_COPPER" },
    sliderBack = { atlas = "Minimal_SliderBar_Button_Left", fallback = "ACCENT_COPPER" },
    sliderForward = { atlas = "Minimal_SliderBar_Button_Right", fallback = "ACCENT_COPPER" },
    -- Refactor's own loot feed art, white with an alpha channel: every colour comes from
    -- SetVertexColor at the call site, so these are never drawn untinted.
    lootRow = { file = "Interface\\AddOns\\SimpleSequence\\Media\\LootRow.tga", fallback = "LOOT_ROW" },
    lootRowHover = { file = "Interface\\AddOns\\SimpleSequence\\Media\\LootRowHover.tga", fallback = "LOOT_ROW" },
    lootIconFrame = { file = "Interface\\AddOns\\SimpleSequence\\Media\\LootIconFrame.tga",
        fallback = "BORDER_BRONZE" },
    lootUnderline = { file = "Interface\\AddOns\\SimpleSequence\\Media\\LootUnderline.tga",
        fallback = "LOOT_UNDERLINE" },
    -- Blizzard's classic coin icons, the files the client's money text draws. Not the
    -- coin-*-20x20 atlases: the atlas index lists them, but GetAtlasInfo on Forever 1.60.1
    -- knew none of the three and every coin drew as its fallback square (25 Sep 2026).
    coinGold = { file = "Interface\\MoneyFrame\\UI-GoldIcon", fallback = "TEXT_TITLE" },
    coinSilver = { file = "Interface\\MoneyFrame\\UI-SilverIcon", fallback = "TEXT_BODY" },
    coinCopper = { file = "Interface\\MoneyFrame\\UI-CopperIcon", fallback = "ACCENT_COPPER" },
    -- Refactor's own farm HUD art, same rule as the loot feed: white plus alpha, tinted at
    -- the call site, never drawn untinted.
    hudBackdrop = { file = "Interface\\AddOns\\SimpleSequence\\Media\\HudBackdrop.tga", fallback = "HUD_BG" },
    hudMeterTrack = { file = "Interface\\AddOns\\SimpleSequence\\Media\\MeterTrack.tga", fallback = "HUD_TRACK" },
    hudMeterFill = { file = "Interface\\AddOns\\SimpleSequence\\Media\\MeterFill.tga", fallback = "ACCENT_COPPER" },
    hudGrip = { file = "Interface\\AddOns\\SimpleSequence\\Media\\DragGrip.tga", fallback = "TEXT_MUTED" },
    hudClock = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconClock.tga", fallback = "TEXT_MUTED" },
    hudCoins = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconCoins.tga", fallback = "TEXT_MUTED" },
    hudBag = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconBag.tga", fallback = "TEXT_MUTED" },
    hudTrend = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconTrend.tga", fallback = "TEXT_MUTED" },
    hudReset = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconReset.tga", fallback = "TEXT_MUTED" },
    hudPause = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconPause.tga", fallback = "TEXT_MUTED" },
    hudSettings = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconSettings.tga", fallback = "TEXT_MUTED" },
    hudCollapse = { file = "Interface\\AddOns\\SimpleSequence\\Media\\IconCollapse.tga", fallback = "TEXT_MUTED" },
}

-- Blizzard's Edit Mode selection nine-slice. EditModeSystemSelectionLayout is a local in
-- EditModeSystemTemplates.lua, so the same table is repeated here and handed to Blizzard's
-- own NineSliceUtil with the same two texture kits. Verified atlases, 12.1.0.
Theme.editModeLayout = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}
Theme.editModeKits = { highlight = "editmode-actionbar-highlight", selected = "editmode-actionbar-selected" }
Theme.missingAtlases = {}
-- Custom files the client refused. Populated by the loot feed, read by /refactor loottest.
Theme.missingFiles = {}

function Theme:SetAsset(key, asset)
    assert(self.assets[key], "Unknown theme asset")
    assert(type(asset) == "table", "Theme assets must be tables")
    self.assets[key] = asset
end

function Theme:SetColor(key, color)
    assert(self.colors[key], "Unknown theme color")
    self.colors[key] = color
end

function Theme:Color(region, token, text)
    if text then region:SetTextColor(unpack(self.colors[token]))
    else region:SetVertexColor(unpack(self.colors[token])) end
end

-- An unexplored map overlay: the art the client shows once explored, part greyed and dimmed.
-- Full grey at 55 percent read as a black slab in game (20 Sep 2026); this keeps the terrain
-- readable while still plainly not the explored art. Tunable from Media/CustomTheme.lua.
Theme.unexploredDesaturation = 0.6
function Theme:Unexplored(texture)
    texture:SetDesaturation(self.unexploredDesaturation)
    self:Color(texture, "MAP_UNEXPLORED")
end

-- "ff" plus six hex digits, for text markup that cannot take a colour object.
function Theme:Hex(token)
    local color = self.colors[token]
    return string.format("ff%02x%02x%02x", math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

function Theme:ApplyAsset(texture, key)
    local asset = self.assets[key]
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
    if asset.file then
        texture:SetTexture(asset.file)
        if asset.texcoords then texture:SetTexCoord(unpack(asset.texcoords)) end
    elseif asset.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset.atlas) then
        texture:SetAtlas(asset.atlas, false)
    else
        if asset.atlas then self.missingAtlases[asset.atlas] = true end
        texture:SetColorTexture(unpack(self.colors[asset.fallback or "SURFACE"]))
    end
    if asset.tint then self:Color(texture, asset.tint) end
end

function Theme:Texture(parent, key, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    self:ApplyAsset(texture, key)
    return texture
end

function Theme:Fill(parent, token, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(unpack(self.colors[token]))
    return texture
end

local FLAT_BORDER_SIDES = {
    { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
}

-- One-pixel bronze rule on each side: the border for frames too small for corner art,
-- and the border everywhere when the client has no NineSliceUtil.
function Theme:FlatBorder(frame)
    for _, side in ipairs(FLAT_BORDER_SIDES) do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(unpack(self.colors.BORDER_BRONZE))
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] then line:SetHeight(1) else line:SetWidth(1) end
    end
end

-- Window-sized frames wear a Blizzard nine-slice; NineSliceUtil sizes every piece from its
-- atlas, which is what hand-placed pieces got wrong. Compact frames (a toast, a one-line
-- readout) cannot host 64 px corners and take the flat border instead.
local NINE_SLICE_INSET, FLAT_INSET = 10, 1
Theme.panelInset = NINE_SLICE_INSET

-- Four gradients inside the border, opaque at the edge and gone by the band's width. They
-- live on a frame of their own above the content rather than on textures of the window,
-- so a row scrolling towards the edge dissolves into the shade instead of being cut by it.
local VIGNETTE_BAND, VIGNETTE_LEVEL = 56, 5
Theme.vignetteLevel = VIGNETTE_LEVEL
-- Anchor pair, orientation, and whether the solid end is the one the orientation names
-- first: bottom for VERTICAL, left for HORIZONTAL.
local VIGNETTE_EDGES = {
    { "TOPLEFT", "TOPRIGHT", "VERTICAL", false },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true },
    { "TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true },
    { "TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false },
}

function Theme:Vignette(frame, inset)
    local color = self.colors.VIGNETTE
    local shade = CreateFrame("Frame", nil, frame)
    shade:SetPoint("TOPLEFT", inset, -inset)
    shade:SetPoint("BOTTOMRIGHT", -inset, inset)
    shade:SetFrameLevel(frame:GetFrameLevel() + VIGNETTE_LEVEL)
    for _, edge in ipairs(VIGNETTE_EDGES) do
        local band = shade:CreateTexture(nil, "OVERLAY")
        band:SetColorTexture(color[1], color[2], color[3], color[4])
        band:SetPoint(edge[1])
        band:SetPoint(edge[2])
        if edge[3] == "VERTICAL" then band:SetHeight(VIGNETTE_BAND) else band:SetWidth(VIGNETTE_BAND) end
        local solid = CreateColor(color[1], color[2], color[3], color[4])
        local clear = CreateColor(color[1], color[2], color[3], 0)
        if edge[4] then
            band:SetGradient(edge[3], solid, clear)
        else
            band:SetGradient(edge[3], clear, solid)
        end
    end
    return shade
end

function Theme:Panel(frame, compact)
    local nineSlice = not compact and NineSliceUtil and NineSliceUtil.GetLayout
        and NineSliceUtil.GetLayout(self.panelLayout)
    -- The nine-slice edges are drawn inside the frame rect, so both backgrounds stop short
    -- of it; filling to the edge makes the tile spill over the bevel at the corners.
    local inset = nineSlice and NINE_SLICE_INSET or FLAT_INSET
    local base = self:Fill(frame, "PANEL_BG")
    base:ClearAllPoints()
    base:SetPoint("TOPLEFT", inset, -inset)
    base:SetPoint("BOTTOMRIGHT", -inset, inset)
    local fill = self:Texture(frame, "panelFill", "BACKGROUND")
    fill:SetPoint("TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", -inset, inset)
    fill:SetAlpha(0.38)
    if nineSlice then
        NineSliceUtil.ApplyLayoutByName(frame, self.panelLayout)
        return
    end
    self:FlatBorder(frame)
end

-- The look of Blizzard's own Edit Mode dialogs: the same border as Panel over a plain
-- translucent black, no tile, so a window of ours that sits beside one reads as its sibling.
function Theme:Dialog(frame)
    local nineSlice = NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.GetLayout(self.panelLayout)
    local inset = nineSlice and NINE_SLICE_INSET or FLAT_INSET
    local base = self:Fill(frame, "DIALOG_BG")
    base:ClearAllPoints()
    base:SetPoint("TOPLEFT", inset, -inset)
    base:SetPoint("BOTTOMRIGHT", -inset, inset)
    if nineSlice then
        NineSliceUtil.ApplyLayoutByName(frame, self.panelLayout)
        return
    end
    self:FlatBorder(frame)
end

function Theme:Text(parent, text, style, token)
    local label = parent:CreateFontString(nil, "OVERLAY", self.fonts[style or "body"])
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    self:Color(label, token or "TEXT_BODY", true)
    return label
end

local BUTTON_HEIGHT, FALLBACK_CAP = 22, 8
Theme.buttonHeight = BUTTON_HEIGHT
local BUTTON_PARTS = { "Left", "Center", "Right" }

function Theme:AtlasInfo(key)
    local asset = self.assets[key]
    if asset and asset.atlas and C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(asset.atlas)
    end
end

-- Cap widths the way ThreeSliceButtonMixin:UpdateScale computes them: each cap keeps its
-- atlas aspect at the button height, and only when the two caps together overflow the
-- button is width taken off their inner edges. Returns left width, right width and the
-- fraction of each cap that survives, so the caller can trim the texture coordinates.
function Theme:SliceWidths(width, height, leftInfo, rightInfo)
    if not leftInfo or not rightInfo or not leftInfo.height or leftInfo.height <= 0 then
        return FALLBACK_CAP, FALLBACK_CAP, 1, 1
    end
    local scale = height / leftInfo.height
    local left, right = leftInfo.width * scale, rightInfo.width * scale
    local extra = left + right - width
    if extra <= 0 then return left, right, 1, 1 end
    local newLeft, newRight = left, right
    if left - extra > right then
        newLeft = left - extra
    elseif right - extra > left then
        newRight = right - extra
    else
        if left ~= right then
            extra = extra - math.abs(left - right)
            newLeft = math.min(left, right)
            newRight = newLeft
        end
        newLeft = newLeft - extra / 2
        newRight = newRight - extra / 2
    end
    return newLeft, newRight, newLeft / left, newRight / right
end

function Theme:ButtonState(button, state)
    local suffix = state or ""
    for _, part in ipairs(BUTTON_PARTS) do
        self:ApplyAsset(button.art[part], "button" .. part .. suffix)
    end
    local leftWidth, rightWidth, leftKept, rightKept = self:SliceWidths(button.width, button.height,
        self:AtlasInfo("buttonLeft" .. suffix), self:AtlasInfo("buttonRight" .. suffix))
    button.art.Left:SetWidth(leftWidth)
    button.art.Right:SetWidth(rightWidth)
    if leftKept < 1 then button.art.Left:SetTexCoord(0, leftKept, 0, 1) end
    if rightKept < 1 then button.art.Right:SetTexCoord(1 - rightKept, 1, 0, 1) end
    self:Color(button.label, suffix == "Disabled" and "TEXT_MUTED" or "TEXT_TITLE", true)
end

-- The red three-slice is for one thing only: a click that performs an action or writes a
-- value now (Save, Create, Import, Assign, Delete, Turn mine off, a value cycler). Never
-- for navigation (sidebar rows, tabs), never to display a state, never as an icon holder.
-- Close is CloseButton, resize is ResizeGrip, details are InfoIcon.
function Theme:Button(parent, width, text, callback, height)
    local button = CreateFrame("Button", nil, parent)
    button.width, button.height = width, height or BUTTON_HEIGHT
    button:SetSize(button.width, button.height)
    button.art = {}
    for _, part in ipairs(BUTTON_PARTS) do
        button.art[part] = self:Texture(button, "button" .. part, "BACKGROUND")
    end
    button.art.Left:SetPoint("TOPLEFT")
    button.art.Left:SetPoint("BOTTOMLEFT")
    button.art.Right:SetPoint("TOPRIGHT")
    button.art.Right:SetPoint("BOTTOMRIGHT")
    button.art.Center:SetPoint("TOPLEFT", button.art.Left, "TOPRIGHT")
    button.art.Center:SetPoint("BOTTOMRIGHT", button.art.Right, "BOTTOMLEFT")
    button.label = self:Text(button, text)
    button.label:SetPoint("CENTER", 0, 0)
    button.label:SetWidth(width - 16)
    button.label:SetJustifyH("CENTER")
    local highlight = self:Texture(button, "buttonHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()
    button:SetHighlightTexture(highlight)
    button:SetScript("OnClick", callback)
    button:SetScript("OnMouseDown", function(widget)
        if widget:IsEnabled() then self:ButtonState(widget, "Pressed") end
    end)
    button:SetScript("OnMouseUp", function(widget)
        self:ButtonState(widget, widget:IsEnabled() and "" or "Disabled")
    end)
    button:SetScript("OnEnable", function(widget) self:ButtonState(widget) end)
    button:SetScript("OnDisable", function(widget) self:ButtonState(widget, "Disabled") end)
    self:ButtonState(button)
    return button
end

-- The X every Retail panel closes with. No text, no red bar.
function Theme:CloseButton(parent, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button.art = self:Texture(button, "closeNormal", "ARTWORK")
    button.art:SetAllPoints()
    local highlight = self:Texture(button, "closeHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    button:SetScript("OnMouseDown", function(widget) self:ApplyAsset(widget.art, "closePressed") end)
    button:SetScript("OnMouseUp", function(widget) self:ApplyAsset(widget.art, "closeNormal") end)
    button:SetScript("OnClick", callback)
    return button
end

-- A sidebar row in the Settings panel's own style: text, a hover wash, a gold bar when
-- selected. No button art, because choosing a page is navigation, not an action.
local MIN_FADE = 0.01

-- A fade that can be reversed mid-flight. An Alpha animation always starts from the value
-- it was given, so an interrupted fade would snap before easing back; reading the smooth
-- progress gives the alpha actually on screen, and the new leg starts there with its
-- duration cut to the distance left. Crossing a list quickly therefore never flickers.
function Theme:Fader(region, fadeIn, fadeOut)
    local fader = { region = region, fadeIn = fadeIn, fadeOut = fadeOut, resting = 0 }
    region:SetAlpha(0)
    fader.group = region:CreateAnimationGroup()
    fader.group:SetToFinalAlpha(true)
    fader.anim = fader.group:CreateAnimation("Alpha")
    fader.group:SetScript("OnFinished", function() fader.resting = fader.to end)

    function fader:Current()
        if self.anim:IsPlaying() then
            return self.from + (self.to - self.from) * self.anim:GetSmoothProgress()
        end
        return self.resting
    end

    function fader:To(target)
        local current = self:Current()
        self.group:Stop()
        self.region:SetAlpha(current)
        self.resting = current
        if current == target then return end
        local full = target > current and self.fadeIn or self.fadeOut
        self.from, self.to = current, target
        self.anim:SetFromAlpha(current)
        self.anim:SetToAlpha(target)
        self.anim:SetDuration(math.max(MIN_FADE, full * math.abs(target - current)))
        self.anim:SetSmoothing(target > current and "OUT" or "IN")
        self.group:Play()
    end

    function fader:Snap(alpha)
        self.group:Stop()
        self.resting = alpha
        self.region:SetAlpha(alpha)
    end

    return fader
end

local HOVER_IN, HOVER_OUT = 0.08, 0.13

function Theme:ListButton(parent, width, height, text, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.selection = self:Texture(button, "listActive", "BACKGROUND")
    button.selection:SetAllPoints()
    button.selection:Hide()
    button.hover = self:Texture(button, "listHover", "BACKGROUND")
    button.hover:SetAllPoints()
    button.hoverFade = self:Fader(button.hover, HOVER_IN, HOVER_OUT)
    button.label = self:Text(button, text, "body", "TEXT_BODY")
    button.label:SetPoint("LEFT", 12, 0)
    button.label:SetPoint("RIGHT", -8, 0)
    button:SetScript("OnClick", callback)
    button:SetScript("OnEnter", function(widget)
        if not widget.selected then widget.hoverFade:To(1) end
    end)
    button:SetScript("OnLeave", function(widget) widget.hoverFade:To(0) end)
    self:ListButtonState(button, false)
    return button
end

-- The same hover wash the sidebar uses, for a row that is its own click target. The fade
-- is an Alpha animation, so nothing runs while the pointer sits still.
function Theme:RowHighlight(frame)
    local wash = self:Texture(frame, "listHover", "BACKGROUND")
    wash:SetAllPoints()
    return self:Fader(wash, HOVER_IN, HOVER_OUT)
end

function Theme:ListButtonState(button, selected, tone)
    button.selected = selected == true
    button.selection:SetShown(button.selected)
    -- Selection wins outright: a fade under the active row would read as a stuck highlight.
    if button.selected then button.hoverFade:Snap(0) end
    self:Color(button.label, button.selected and "TEXT_HIGHLIGHT" or tone or "TEXT_BODY", true)
end

local TAB_HEIGHT, TAB_ACTIVE_HEIGHT, TAB_CAP, TAB_PAD = 23, 26, 7, 40
local TAB_PARTS = { "Left", "Middle", "Right" }

-- MinimalTabTemplate: the selected tab stands 3 px taller and reads in white.
function Theme:Tab(parent, text, callback)
    local tab = CreateFrame("Button", nil, parent)
    tab.art = {}
    for _, part in ipairs(TAB_PARTS) do
        tab.art[part] = self:Texture(tab, "tab" .. part, "BACKGROUND")
    end
    tab.art.Left:SetPoint("BOTTOMLEFT")
    tab.art.Right:SetPoint("BOTTOMRIGHT")
    tab.art.Middle:SetPoint("BOTTOMLEFT", tab.art.Left, "BOTTOMRIGHT")
    tab.art.Middle:SetPoint("BOTTOMRIGHT", tab.art.Right, "BOTTOMLEFT")
    tab.label = self:Text(tab, text, "small", "TEXT_TITLE")
    tab.label:SetJustifyH("CENTER")
    tab:SetSize(tab.label:GetStringWidth() + TAB_PAD, TAB_ACTIVE_HEIGHT)
    tab:SetScript("OnClick", callback)
    tab:SetScript("OnEnter", function(widget)
        if not widget.selected then self:Color(widget.label, "TEXT_HIGHLIGHT", true) end
    end)
    tab:SetScript("OnLeave", function(widget)
        if not widget.selected then self:Color(widget.label, "TEXT_TITLE", true) end
    end)
    self:TabState(tab, false)
    return tab
end

function Theme:TabState(tab, selected)
    tab.selected = selected == true
    local prefix = tab.selected and "tabActive" or "tab"
    local height = tab.selected and TAB_ACTIVE_HEIGHT or TAB_HEIGHT
    for _, part in ipairs(TAB_PARTS) do
        self:ApplyAsset(tab.art[part], prefix .. part)
        tab.art[part]:SetHeight(height)
    end
    tab.art.Left:SetWidth(TAB_CAP)
    tab.art.Right:SetWidth(TAB_CAP)
    tab.label:ClearAllPoints()
    tab.label:SetPoint("BOTTOM", 0, tab.selected and 7 or 5)
    self:Color(tab.label, tab.selected and "TEXT_HIGHLIGHT" or "TEXT_TITLE", true)
end

-- InputBoxVisualTemplate's border, sized from the box height (the art is 16 by 40).
function Theme:InputBorder(frame, height)
    local cap = math.floor(height * 0.4 + 0.5)
    local left = self:Texture(frame, "inputLeft", "BACKGROUND")
    left:SetSize(cap, height)
    left:SetPoint("LEFT")
    local right = self:Texture(frame, "inputRight", "BACKGROUND")
    right:SetSize(cap, height)
    right:SetPoint("RIGHT")
    local middle = self:Texture(frame, "inputMiddle", "BACKGROUND")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end

-- One UI unit is less than one physical pixel at most UI scales, so a rule of height 1
-- lands between pixels and vanishes on some rows and not others. Hairlines are sized in
-- real pixels instead, and re-sized when the scale or the resolution changes.
local hairlines = setmetatable({}, { __mode = "k" })

function Theme:PixelSize(frame)
    if not GetPhysicalScreenSize then return 1 end
    local _, physical = GetPhysicalScreenSize()
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if type(physical) ~= "number" or physical <= 0 or type(scale) ~= "number" or scale <= 0 then
        return 1
    end
    return 768 / physical / scale
end

function Theme:Snap(frame, value)
    local pixel = self:PixelSize(frame)
    if pixel <= 0 then return value end
    return math.floor(value / pixel + 0.5) * pixel
end

-- The one-pixel rule Blizzard's SettingsList draws between rows. Its atlas really is one
-- pixel tall (options_horizontaldivider, 630x1), and the texel snapping the client applies
-- by default drops a source row that thin whenever it lands off the grid, which is what
-- made these rules blink while the list scrolled. NineSliceUtil.DisableSharpening turns
-- the same two switches off for the same reason.
function Theme:Divider(parent, layer)
    local line = self:Texture(parent, "rowDivider", layer or "ARTWORK")
    if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
    if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
    line:SetHeight(self:PixelSize(parent))
    line:SetAlpha(0.6)
    hairlines[line] = parent
    return line
end

-- Invalidated by UI_SCALE_CHANGED and DISPLAY_SIZE_CHANGED, the only two events that can
-- change how many pixels a UI unit is worth.
function Theme:RefreshHairlines()
    for line, parent in pairs(hairlines) do
        line:SetHeight(self:PixelSize(parent))
    end
end

-- A one pixel rule is only drawn as one pixel if its top edge lands on a whole pixel. The
-- offset that decides that is the sum of every anchor above it, and an integer offset in
-- UI units is not a whole number of pixels at any normal UI scale, so rules at different
-- offsets straddle by different amounts and some round away to nothing. Stretching the
-- line between two points on the same edge, rather than a top corner and a side, keeps it
-- from being over-constrained; measuring where it actually landed puts it on the grid.
function Theme:AlignHairline(line, parent, y)
    local pixel = self:PixelSize(parent)
    local function place(offset)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
        line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -offset)
    end
    place(y)
    line:SetHeight(pixel)
    if pixel <= 0 or not line.GetTop then return end
    local top = line:GetTop()
    if type(top) ~= "number" then return end
    local drift = top / pixel
    drift = drift - math.floor(drift)
    if drift > 0 then place(y + drift * pixel) end
end

local HEADER_TITLE_HEIGHT, HEADER_HELP_HEIGHT, HEADER_LINE_Y = 26, 32, 20
-- The copper diamond a heading starts with (PRD 8.3), centred on the title's first line. A
-- rotated colour texture stays square, since rotation turns the texture, not the region, so
-- the shape is art of its own. A client that has not read the file yet (new art loads only on
-- a full restart) shows the heading without it rather than a square.
local HEADER_MARK, HEADER_MARK_X, HEADER_MARK_Y, HEADER_TITLE_X = 9, 4, -7, 14

function Theme:SectionHeader(parent, title, help)
    local header = CreateFrame("Frame", nil, parent)
    header.mark = self:Texture(header, "headerMark", "ARTWORK")
    self:Color(header.mark, "ACCENT_COPPER")
    header.mark:SetSize(HEADER_MARK, HEADER_MARK)
    header.mark:SetPoint("CENTER", header, "TOPLEFT", HEADER_MARK_X, HEADER_MARK_Y)
    self:VerifyFile(header.mark, "headerMark")
    header.title = self:Text(header, title, "body", "TEXT_TITLE")
    header.title:SetPoint("TOPLEFT", HEADER_TITLE_X, 0)
    header.line = self:Divider(header)
    header.lineY = HEADER_LINE_Y
    self:AlignHairline(header.line, header, HEADER_LINE_Y)
    header.height = HEADER_TITLE_HEIGHT
    if help then
        header.help = self:Text(header, help, "small", "TEXT_MUTED")
        header.help:SetPoint("TOPLEFT", 0, -HEADER_TITLE_HEIGHT)
        header.help:SetPoint("RIGHT")
        header.help:SetHeight(HEADER_HELP_HEIGHT - 4)
        header.help:SetJustifyV("TOP")
        header.height = header.height + HEADER_HELP_HEIGHT
    end
    header:SetHeight(header.height)
    return header
end

-- Hover target, not a button: nothing happens on click, the detail lives in the tooltip.
function Theme:InfoIcon(parent, size)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(size, size)
    icon:EnableMouse(true)
    icon.art = self:Texture(icon, "infoIcon", "ARTWORK")
    icon.art:SetAllPoints()
    icon.art:SetAlpha(0.75)
    icon:SetScript("OnEnter", function(widget)
        widget.art:SetAlpha(1)
        if widget.onEnter then widget.onEnter(widget) end
    end)
    icon:SetScript("OnLeave", function(widget)
        widget.art:SetAlpha(0.75)
        if widget.onLeave then widget.onLeave(widget) end
    end)
    return icon
end

-- Icon-only button that puts a value back to its default. Shown only while there is
-- something to undo, so the row reads clean at rest.
function Theme:UndoButton(parent, size, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.art = self:Texture(button, "undoIcon", "ARTWORK")
    button.art:SetAllPoints()
    local highlight = self:Texture(button, "undoIcon", "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    button:SetScript("OnClick", callback)
    button:Hide()
    return button
end

-- MinimalScrollBar, 12.1.0: an 8 px bar, 8 px caps, a 17x11 stepper at each end and a
-- track inset by 19 so the steppers clear it. The thumb never goes below 23 px or it
-- cannot be grabbed.
local BAR_WIDTH, BAR_CAP, MIN_THUMB = 8, 8, 23
local STEPPER_WIDTH, STEPPER_HEIGHT, STEPPER_GAP = 17, 11, 8
Theme.scrollBar = { width = BAR_WIDTH, minThumb = MIN_THUMB,
    stepperGap = STEPPER_GAP, trackInset = STEPPER_HEIGHT + STEPPER_GAP }

local THUMB_STATES = { normal = "", over = "Over", down = "Down" }

local function threeSlice(parent, prefix, layer)
    local slice = { prefix = prefix }
    slice.top = Theme:Texture(parent, prefix .. "Top", layer)
    slice.top:SetSize(BAR_WIDTH, BAR_CAP)
    slice.top:SetPoint("TOPLEFT")
    slice.bottom = Theme:Texture(parent, prefix .. "Bottom", layer)
    slice.bottom:SetSize(BAR_WIDTH, BAR_CAP)
    slice.bottom:SetPoint("BOTTOMLEFT")
    -- Anchored cap to cap: the middle must not run under a rounded cap, or the square
    -- corners of the stretched piece show through the transparent part of the cap.
    slice.middle = Theme:Texture(parent, prefix .. "Middle", layer)
    slice.middle:SetPoint("TOPLEFT", slice.top, "BOTTOMLEFT")
    slice.middle:SetPoint("BOTTOMRIGHT", slice.bottom, "TOPRIGHT")
    return slice
end

function Theme:ScrollThumbState(thumb, state)
    local suffix = THUMB_STATES[state] or ""
    self:ApplyAsset(thumb.slice.top, "scrollThumbTop" .. suffix)
    self:ApplyAsset(thumb.slice.middle, "scrollThumbMiddle" .. suffix)
    self:ApplyAsset(thumb.slice.bottom, "scrollThumbBottom" .. suffix)
end

-- The Slider widget takes a single thumb texture, which cannot be a three-slice. The
-- texture it moves is kept empty and used purely as an anchor: the visible thumb is a
-- frame pinned to it, so the caps ride along with no per-frame work.
function Theme:ScrollBar(parent)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(BAR_WIDTH)
    threeSlice(slider, "scrollTrack", "BACKGROUND")
    local anchor = slider:CreateTexture(nil, "ARTWORK")
    anchor:SetSize(BAR_WIDTH, MIN_THUMB)
    slider:SetThumbTexture(anchor)
    local thumb = CreateFrame("Frame", nil, slider)
    thumb:SetAllPoints(anchor)
    thumb.anchor = anchor
    thumb.slice = threeSlice(thumb, "scrollThumb", "ARTWORK")
    slider.thumb = thumb
    return slider
end

function Theme:ScrollStepper(parent, key, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(STEPPER_WIDTH, STEPPER_HEIGHT)
    for method, suffix in pairs({ SetNormalTexture = "", SetPushedTexture = "Down",
        SetHighlightTexture = "Over" }) do
        local art = self:Texture(button, key .. suffix)
        art:SetAllPoints()
        button[method](button, art)
    end
    button:SetScript("OnClick", onClick)
    return button
end

function Theme:ResizeGrip(parent, onStart, onStop)
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(16, 16)
    grip.art = self:Texture(grip, "resizeGrip", "ARTWORK")
    grip.art:SetAllPoints()
    local highlight = self:Texture(grip, "resizeGripHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()
    grip:SetHighlightTexture(highlight)
    grip:SetScript("OnMouseDown", function(widget)
        self:ApplyAsset(widget.art, "resizeGripPressed")
        onStart()
    end)
    grip:SetScript("OnMouseUp", function(widget)
        self:ApplyAsset(widget.art, "resizeGrip")
        onStop()
    end)
    return grip
end

local INDICATOR_SIZE = 18
local ICON_KEYS = { kill = "questIconKill", item = "questIconItem", other = "questIconOther" }

-- Objective indicator: quest type icon (sword for kill, bag for loot) with progress numbers.
-- Progress is carried purely by numbers (e.g. 5/6) and the gold highlight on the last mob,
-- eliminating redundant circular/radial progress bars that clutter nameplates.
function Theme:QuestIndicator(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(INDICATOR_SIZE, INDICATOR_SIZE)

    frame.icon = self:Texture(frame, "questIconOther", "OVERLAY")
    frame.icon:SetSize(INDICATOR_SIZE, INDICATOR_SIZE)
    frame.icon:SetPoint("CENTER")
    frame.check = self:Texture(frame, "questCheck", "OVERLAY")
    frame.check:SetSize(INDICATOR_SIZE + 2, INDICATOR_SIZE + 2)
    frame.check:SetPoint("CENTER")
    frame.check:Hide()
    -- Two strings, with value anchored in a stationary holder so only the number
    -- animates while "/6" stays completely still without bouncing or shifting.
    local valueHolder = CreateFrame("Frame", nil, frame)
    valueHolder:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    valueHolder:SetSize(10, 16)
    frame.valueHolder = valueHolder

    frame.value = self:Text(valueHolder, "", "body", "QUEST_VALUE")
    frame.value:SetPoint("CENTER", valueHolder, "CENTER", 0, 0)
    frame.value:SetJustifyH("CENTER")
    frame.value:SetSmoothScaling(true)
    frame.total = self:Text(frame, "", "body", "QUEST_TOTAL")
    frame.total:SetPoint("LEFT", valueHolder, "RIGHT", -2, 0)
    frame.total:SetJustifyH("LEFT")
    local fontFile = frame.value:GetFont()
    frame.value:SetFont(fontFile, 16, "OUTLINE")
    frame.total:SetFont(fontFile, 14, "OUTLINE")
    frame.value:SetShadowOffset(1, -1)
    frame.total:SetShadowOffset(1, -1)
    frame.count = frame.value

    -- Calm, elegant: pure soft alpha fade-in on the updated number.
    -- No scaling or geometric transformation, avoiding FontString outline re-rasterization flicker.
    local pop = frame.value:CreateAnimationGroup()
    local fadeAnim = pop:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(0.20)
    fadeAnim:SetToAlpha(1)
    fadeAnim:SetDuration(0.25)
    fadeAnim:SetSmoothing("OUT")
    frame.pop = pop

    local fade = frame:CreateAnimationGroup()
    local out = fade:CreateAnimation("Alpha")
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(0.15)
    out:SetStartDelay(0.6)
    fade:SetScript("OnFinished", function() frame:Hide() end)
    frame.fade = fade

    function frame:SetFraction(fraction)
        self.fraction = fraction
    end

    function frame:SetIconKind(kind)
        Theme:ApplyAsset(self.icon, ICON_KEYS[kind] or ICON_KEYS.other)
    end

    function frame:SetIconShown(shown)
        self.icon:SetShown(shown == true)
    end

    function frame:SetProgress(fulfilled, required, lastOne)
        self.fraction = (required and required > 0) and math.min(1, (fulfilled or 0) / required) or 0
        Theme:Color(self.value, lastOne and "TEXT_LAST" or "QUEST_VALUE", true)
    end

    function frame:SetComplete(complete)
        if complete then
            self.fraction = 1
        end
        self.icon:SetShown(not complete)
        self.check:SetShown(complete == true)
    end

    function frame:SetCountText(value, total)
        self.value:SetText(value or "")
        local width = self.value:GetStringWidth()
        if width and width > 0 then
            self.valueHolder:SetWidth(width)
        end
        self.total:SetText(total or "")
    end

    function frame:SetRingShown(shown)
        self.ringShown = shown == true
    end

    function frame:Pop(reduceAnimation)
        if reduceAnimation then
            return
        end
        self.pop:Stop()
        self.pop:Play()
    end

    function frame:FadeOut(reduceAnimation)
        self.fade:Stop()
        if reduceAnimation then
            self:Hide()
            return
        end
        self.fade:Play()
    end

    function frame:ResetIndicator()
        self.pop:Stop()
        self.fade:Stop()
        self:SetAlpha(1)
        self.value:SetAlpha(1)
        self:SetCountText(nil, nil)
        self.fraction = 0
        self.check:Hide()
        self.icon:Show()
        self:ClearAllPoints()
        self:SetParent(nil)
        self:Hide()
    end

    frame:Hide()
    return frame
end

-- Refactor's own overlay, never a change to Blizzard's plate textures or alpha.
function Theme:PlateDim(parent)
    local dim = CreateFrame("Frame", nil, parent)
    dim:SetFrameStrata("BACKGROUND")
    self:Fill(dim, "PLATE_DIM")
    dim:Hide()
    return dim
end

local CHECK_SIZE = 26
Theme.checkboxSize = CHECK_SIZE

-- A real CheckButton wearing the Settings panel's minimal checkbox. An on/off setting
-- should look like every other on/off setting the player has ever seen.
function Theme:Checkbox(parent, width, text, callback)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(CHECK_SIZE, CHECK_SIZE)
    box:SetHitRectInsets(0, -(width or 200) + CHECK_SIZE, 0, 0)
    box.background = self:Texture(box, "checkboxBox", "BACKGROUND")
    box.background:SetAllPoints()
    box.tick = self:Texture(box, "checkboxTick", "ARTWORK")
    box.tick:SetAllPoints()
    box:SetCheckedTexture(box.tick)
    box.tickDisabled = self:Texture(box, "checkboxTickDisabled", "ARTWORK")
    box.tickDisabled:SetAllPoints()
    box:SetDisabledCheckedTexture(box.tickDisabled)
    local highlight = self:Texture(box, "checkboxHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")
    box:SetHighlightTexture(highlight)
    box.label = self:Text(box, text, "body", "TEXT_BODY")
    box.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    box.label:SetWidth((width or 200) - 34)
    box:SetScript("OnClick", callback)
    return box
end

local SLIDER_TRACK, SLIDER_CAP, SLIDER_THUMB = 17, 11, 20
local SLIDER_ROW_HEIGHT, SLIDER_STEPPER_GAP, SLIDER_UNDO = 44, 4, 16
Theme.sliderRowHeight = SLIDER_ROW_HEIGHT

-- The slider Blizzard's own Edit Mode dialog puts on every numeric system setting: a
-- three-slice minimal bar, a stepper button at each end, the label left and the value
-- right (MinimalSlider.xml, 12.1.0). Sizes come from the atlas pieces themselves.
function Theme:Slider(parent, width, minimum, maximum, step, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, SLIDER_ROW_HEIGHT)
    holder.label = self:Text(holder, "", "body", "TEXT_BODY")
    holder.label:SetPoint("TOPLEFT")
    -- Shown only while the value differs from its default, the same rule the module rows
    -- follow, so a row at its default reads clean.
    holder.undo = self:UndoButton(holder, SLIDER_UNDO, function()
        if holder.onUndo then holder.onUndo() end
    end)
    holder.undo:SetPoint("TOPRIGHT", 0, -2)
    holder.valueText = self:Text(holder, "", "small", "TEXT_TITLE")
    holder.valueText:SetPoint("TOPRIGHT", holder.undo, "TOPLEFT", -6, 2)
    holder.valueText:SetJustifyH("RIGHT")

    local slider = CreateFrame("Slider", nil, holder)
    -- MinimalSliderTemplate carries enableMouse="true"; a Slider built in Lua does not
    -- inherit that, and without it the thumb cannot be dragged.
    slider:EnableMouse(true)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(SLIDER_TRACK)
    slider:SetPoint("BOTTOMLEFT", SLIDER_CAP + SLIDER_STEPPER_GAP * 2, 2)
    slider:SetPoint("BOTTOMRIGHT", -(SLIDER_CAP + SLIDER_STEPPER_GAP * 2), 2)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local left = self:Texture(slider, "sliderLeft", "BACKGROUND")
    left:SetSize(SLIDER_CAP, SLIDER_TRACK)
    left:SetPoint("LEFT")
    local right = self:Texture(slider, "sliderRight", "BACKGROUND")
    right:SetSize(SLIDER_CAP, SLIDER_TRACK)
    right:SetPoint("RIGHT")
    local middle = self:Texture(slider, "sliderMiddle", "BACKGROUND")
    middle:SetHeight(SLIDER_TRACK)
    middle:SetPoint("LEFT", left, "RIGHT")
    middle:SetPoint("RIGHT", right, "LEFT")
    local thumb = self:Texture(slider, "sliderThumb", "OVERLAY")
    thumb:SetSize(SLIDER_THUMB, SLIDER_TRACK + 2)
    slider:SetThumbTexture(thumb)
    holder.slider = slider

    local function stepper(key, point, relativePoint, direction)
        local button = CreateFrame("Button", nil, holder)
        button:SetSize(SLIDER_CAP, SLIDER_TRACK + 2)
        button:SetPoint(point, slider, relativePoint, direction * SLIDER_STEPPER_GAP, 0)
        button.art = self:Texture(button, key, "ARTWORK")
        button.art:SetAllPoints()
        button:SetScript("OnClick", function()
            local low, high = slider:GetMinMaxValues()
            slider:SetValue(math.max(low, math.min(high, slider:GetValue() + direction * step)))
        end)
        return button
    end
    holder.back = stepper("sliderBack", "RIGHT", "LEFT", -1)
    holder.forward = stepper("sliderForward", "LEFT", "RIGHT", 1)

    function holder:Display(value)
        self.valueText:SetText(self.formatter and self.formatter(value) or tostring(value))
    end

    function holder:SetLabel(text, formatter)
        self.label:SetText(text)
        self.formatter = formatter
    end

    -- Writing a value back into the slider must not look like the player moved it, or
    -- every refresh would write the setting again. While the thumb is actually being
    -- dragged nothing is written back at all: each step of a drag saves the setting, and
    -- whatever that redraws would otherwise push the thumb out from under the cursor.
    function holder:SetValue(value)
        if self.dragging then
            self:Display(value)
            return
        end
        self.updating = true
        self.slider:SetValue(value)
        self.updating = nil
        self:Display(value)
    end

    slider:SetScript("OnMouseDown", function() holder.dragging = true end)
    slider:SetScript("OnMouseUp", function() holder.dragging = false end)
    -- Released off the slider, OnMouseUp never arrives; leaving the flag set would freeze
    -- the thumb against every later refresh.
    slider:SetScript("OnHide", function() holder.dragging = false end)
    slider:SetScript("OnValueChanged", function(_, value)
        holder:Display(value)
        if not holder.updating and onChange then
            onChange(value)
        end
    end)
    return holder
end

-- A tinted dot for inline use in a FontString. The texture escape's vertex colour is the
-- only way to tint art inside text, so this cannot be an atlas: the |A| escape takes none.
-- The path lives here rather than in widget code, like every other asset (PRD 8.3).
--
-- The texture has to be white. A vertex colour multiplies, it cannot brighten, so tinting
-- Indicator-Gray with a quality colour returned it darkened by that art's own grey and no
-- tint could recover it. This is a mask circle: white, round, with a soft alpha edge.
local DOT_SIZE = 12
Theme.dotTexture = "Interface\\Common\\CommonMaskCircle"

function Theme:Dot(r, g, b)
    return string.format("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", self.dotTexture,
        DOT_SIZE, DOT_SIZE, math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local DROPDOWN_ROW_HEIGHT, DROPDOWN_WIDTH, DROPDOWN_HEIGHT = 30, 170, 26
Theme.dropdownRowHeight = DROPDOWN_ROW_HEIGHT

-- Blizzard's own dropdown button and the menu behind it (WowStyle1DropdownTemplate, from
-- Blizzard_Menu; the pattern is the one in its 11_0_0_MenuImplementationGuide). This is the
-- one widget Refactor inherits a template for instead of assembling from atlases: the art
-- could be rebuilt, but the menu it opens could not, and reimplementing that is both a
-- large surface and the part with a taint history. Nothing here touches a Blizzard frame.
--
-- entries is an ordered list of { value, text }. A radio per entry means the button labels
-- itself from whichever one reports as selected.
-- Both the DropdownButton frame type and this template come from Blizzard_Menu, which is
-- not load-on-demand on this build, so they are there. Forever has not been seen, and the
-- whole options window erroring at load over a missing template is not a trade worth
-- taking: a client without it gets a button that steps through the same entries instead.
Theme.dropdownTemplate = "WowStyle1DropdownTemplate"

function Theme:DropdownButton(holder)
    if not self.dropdownTemplate then return nil end
    local ok, button = pcall(CreateFrame, "DropdownButton", nil, holder, self.dropdownTemplate)
    if ok and button and button.SetupMenu then return button end
    return nil
end

-- The fallback, wearing the same surface the dropdown button offers so nothing above it
-- has to know which one it got: a click advances to the next entry and wraps.
function Theme:SteppedChoice(holder, isSelected, setSelected)
    local button = self:Button(holder, DROPDOWN_WIDTH, "", function()
        local entries = holder.entries
        for index, entry in ipairs(entries) do
            if isSelected(entry.value) then
                setSelected(entries[index % #entries + 1].value)
                return
            end
        end
        if entries[1] then setSelected(entries[1].value) end
    end, DROPDOWN_HEIGHT)
    function button:SetDefaultText(text) self.defaultText = text; self.label:SetText(text or "") end
    function button:GetDefaultText() return self.defaultText end
    function button:GenerateMenu() end
    return button
end

function Theme:Dropdown(parent, width, entries, isSelected, setSelected)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, DROPDOWN_ROW_HEIGHT)
    holder.label = self:Text(holder, "", "body", "TEXT_BODY")
    holder.label:SetPoint("LEFT")
    holder.entries = entries

    local button = self:DropdownButton(holder)
    if button then
        button:SetupMenu(function(_, rootDescription)
            for _, entry in ipairs(holder.entries) do
                rootDescription:CreateRadio(entry.text, isSelected, setSelected, entry.value)
            end
        end)
    else
        button = self:SteppedChoice(holder, isSelected, setSelected)
    end
    button:SetSize(DROPDOWN_WIDTH, DROPDOWN_HEIGHT)
    button:SetPoint("RIGHT")
    holder.button = button

    function holder:SetLabel(text)
        self.label:SetText(text)
    end

    -- The menu lists whatever entries are current when it opens, so a dropdown whose
    -- choices depend on another setting needs no rebuilding, only a new list.
    function holder:SetEntries(list)
        self.entries = list
    end

    function holder:SetValueText(text)
        -- Both paths land on the same string: the selection names it when a radio reports
        -- itself selected, and the default covers the pass before any menu was generated.
        self.button:SetDefaultText(text or "")
        self.button:GenerateMenu()
    end

    return holder
end

local ROW_HEIGHT, ROW_ICON, ROW_GAP = 34, 30, 8
-- Every item icon ships with a dark margin baked into the art. Cropping it is what makes
-- the icon meet the frame instead of floating inside it.
local ICON_CROP = 0.08
local ROW_BG_SCALE, ROW_BG_BLEED = 1.4, 12
local ROW_UNDERLINE_HEIGHT, ROW_CHEVRON = 6, 12
-- The accessory's Equip button: short enough to leave the name most of the row, tall enough
-- to read as the red action button everywhere else.
local ROW_ACTION_WIDTH, ROW_ACTION_HEIGHT, ROW_BADGE_GAP = 56, 20, 6
local ROW_FADE, ROW_SLIDE = 0.15, 0.12
local ROW_SHADOW_X, ROW_SHADOW_Y = 1, -1
-- Gold, silver, copper, largest first, with the gaps GetCoinTextureString leaves.
local COIN_KEYS, COIN_VALUES = { "coinGold", "coinSilver", "coinCopper" }, { 10000, 100, 1 }
local COIN_ICON, COIN_ICON_GAP, COIN_GAP = 12, 2, 4
local CoinStrip = {}
CoinStrip.__index = CoinStrip
-- Where each text line starts, relative to the row, once the icon inset is added.
local LINE_ANCHORS = { name = { "TOPLEFT", -3 }, detail = { "BOTTOMLEFT", 5 } }
Theme.lootRowHeight = ROW_HEIGHT

-- A file the client refuses returns nothing from GetTexture. It cannot tell us about a
-- file that exists but was added after the client started: those load only on a full
-- restart, which is why /refactor loottest says so in its own words.
local function verifyFile(texture, key)
    if texture.GetTexture and not texture:GetTexture() then
        Theme.missingFiles[key] = true
        texture:Hide()
        return false
    end
    return true
end

local function shadowed(label)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(ROW_SHADOW_X, ROW_SHADOW_Y)
    return label
end

-- Exported so the farm HUD gets the same one-pixel shadow without repeating black here or
-- carrying a colour literal of its own (rule 12). Snow and Northrend ice are why it exists.
function Theme:Shadow(label)
    return shadowed(label)
end

-- Money as coin textures beside a line of text, never |T escapes inside it: a texture in a
-- FontString does not reliably follow a Translation, so escaped coins trailed the loot
-- feed's rows as they slid and the farm HUD's panel as it opened. Every region is made
-- here, once, so placing an amount later creates nothing.
function Theme:Coins(parent)
    local strip = setmetatable({ pieces = {} }, CoinStrip)
    for index, key in ipairs(COIN_KEYS) do
        local icon = self:Texture(parent, key, "ARTWORK")
        icon:SetSize(COIN_ICON, COIN_ICON)
        verifyFile(icon, key)
        strip.pieces[index] = { amount = shadowed(self:Text(parent, "", "small", "TEXT_MUTED")), icon = icon }
    end
    strip.suffix = shadowed(self:Text(parent, "", "small", "TEXT_MUTED"))
    strip:Hide()
    return strip
end

-- Denominations that are zero are left out, as Blizzard's GetMoneyString does, so a grey
-- sells for 8 copper and not 0 gold 0 silver 8 copper.
local function coinCount(amount, index)
    local count = math.floor(amount / COIN_VALUES[index])
    if index > 1 then count = count % 100 end
    return count > 0 or (amount == 0 and index == #COIN_VALUES), count
end

-- The amounts wear the font and colour of `like`, the text they belong with, when given.
local function dress(label, like, text)
    if like then
        label:SetFontObject(like:GetFontObject())
        label:SetTextColor(like:GetTextColor())
    end
    label:SetText(text)
    label:ClearAllPoints()
    label:Show()
end

function CoinStrip:Hide()
    for _, piece in ipairs(self.pieces) do
        piece.amount:Hide()
        piece.icon:Hide()
    end
    self.suffix:Hide()
end

-- Left to right from one anchor, then suffix. Returns the rightmost region.
function CoinStrip:Place(like, amount, suffix, point, relativeTo, relativePoint, x, y)
    self:Hide()
    local previous
    for index, piece in ipairs(self.pieces) do
        local shown, count = coinCount(amount, index)
        if shown then
            dress(piece.amount, like, count)
            if previous then
                piece.amount:SetPoint("LEFT", previous, "RIGHT", COIN_GAP, 0)
            else
                piece.amount:SetPoint(point, relativeTo, relativePoint, x, y)
            end
            piece.icon:ClearAllPoints()
            piece.icon:SetPoint("LEFT", piece.amount, "RIGHT", COIN_ICON_GAP, 0)
            piece.icon:Show()
            previous = piece.icon
        end
    end
    if suffix and suffix ~= "" then
        dress(self.suffix, like, suffix)
        self.suffix:SetPoint("LEFT", previous, "RIGHT")
        previous = self.suffix
    end
    return previous
end

-- Right to left from one anchor, for a value kept flush right. Returns the leftmost region,
-- so the text before it can stop there and truncate instead of running under the coins.
function CoinStrip:PlaceRight(like, amount, point, relativeTo, relativePoint, x, y)
    self:Hide()
    local previous
    for index = #self.pieces, 1, -1 do
        local piece = self.pieces[index]
        local shown, count = coinCount(amount, index)
        if shown then
            piece.icon:ClearAllPoints()
            if previous then
                piece.icon:SetPoint("RIGHT", previous, "LEFT", -COIN_GAP, 0)
            else
                piece.icon:SetPoint(point, relativeTo, relativePoint, x, y)
            end
            piece.icon:Show()
            dress(piece.amount, like, count)
            piece.amount:SetPoint("RIGHT", piece.icon, "LEFT", -COIN_ICON_GAP, 0)
            previous = piece.amount
        end
    end
    return previous
end

function Theme:VerifyFile(texture, key)
    return verifyFile(texture, key)
end

-- One row of the loot feed: a soft smudge behind an icon in a quality-tinted frame, the
-- item name in its quality colour, and a muted line for price and source. A Button, not a
-- Frame, so Gear Refactor's upgrade badge and Equip button have a home: row.accessory holds
-- them (Gear Refactor PRD 5.3) and grows to fit what it shows.
-- Motion is three animation groups and no OnUpdate: fade in, hold then fade out, and the
-- slide the feed plays when the row above it goes away.
function Theme:LootRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.width = width
    row.background = self:Texture(row, "lootRow", "BACKGROUND")
    row.background:SetPoint("LEFT", -ROW_BG_BLEED, 0)
    row.background:SetSize(width + ROW_BG_BLEED * 2, ROW_HEIGHT * ROW_BG_SCALE)
    verifyFile(row.background, "lootRow")
    row.hover = self:Texture(row, "lootRowHover", "BACKGROUND")
    row.hover:SetAllPoints(row.background)
    verifyFile(row.hover, "lootRowHover")
    row.hover:SetShown(false)
    row.underline = self:Texture(row, "lootUnderline", "BORDER")
    row.underline:SetPoint("BOTTOMLEFT")
    row.underline:SetPoint("BOTTOMRIGHT", -ROW_GAP, 0)
    row.underline:SetHeight(ROW_UNDERLINE_HEIGHT)
    verifyFile(row.underline, "lootUnderline")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT")
    row.iconFrame = self:Texture(row, "lootIconFrame", "OVERLAY")
    row.iconFrame:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
    row.iconFrame:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
    verifyFile(row.iconFrame, "lootIconFrame")
    row.name = shadowed(self:Text(row, "", "body", "TEXT_BODY"))
    row.detail = shadowed(self:Text(row, "", "small", "TEXT_MUTED"))
    -- One set of coins, since a row carries money on one line at most.
    row.coins = self:Coins(row)
    -- The chevron is the scrollbar's own arrow: an expander that already reads as one on
    -- this client, rather than a new piece of art.
    row.chevron = CreateFrame("Button", nil, row)
    row.chevron:SetSize(ROW_CHEVRON, ROW_CHEVRON)
    row.chevron:SetPoint("RIGHT", -ROW_GAP, 0)
    row.chevron.art = self:Texture(row.chevron, "scrollDown", "OVERLAY")
    row.chevron.art:SetAllPoints()
    row.chevron.row = row
    row.chevron:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.chevron:Hide()
    -- Gear Refactor's badge and Equip button (its PRD 5.3), made here with the row so a loot
    -- burst never creates a frame; the feed fills them from Gear Refactor's API.
    row.accessory = CreateFrame("Frame", nil, row)
    row.accessory:SetSize(ROW_ICON, ROW_ICON)
    row.accessory:SetPoint("RIGHT", row.chevron, "LEFT", -ROW_GAP, 0)
    row.badge = shadowed(self:Text(row.accessory, "", "small", "TEXT_BODY"))
    row.badge:Hide()
    row.action = self:Button(row.accessory, ROW_ACTION_WIDTH, "", nil, ROW_ACTION_HEIGHT)
    row.action:SetPoint("RIGHT")
    row.action.row = row
    row.action:Hide()

    local show = row:CreateAnimationGroup()
    local fadeIn = show:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(ROW_FADE)
    row.show = show
    local hide = row:CreateAnimationGroup()
    row.fadeOut = hide:CreateAnimation("Alpha")
    row.fadeOut:SetFromAlpha(1)
    row.fadeOut:SetToAlpha(0)
    row.fadeOut:SetDuration(ROW_FADE)
    hide:SetScript("OnFinished", function()
        row:Hide()
        if row.onHidden then row.onHidden(row) end
    end)
    row.hide = hide
    -- A Translation ends where it started, so the row is pointed at its destination only
    -- when the slide finishes and the offset it travelled is released.
    local slide = row:CreateAnimationGroup()
    row.slideAnim = slide:CreateAnimation("Translation")
    row.slideAnim:SetDuration(ROW_SLIDE)
    row.slideAnim:SetSmoothing("OUT")
    slide:SetScript("OnFinished", function() row:PlaceNow() end)
    row.slide = slide

    -- Hovering holds the row on screen: reading a price should never race a fade. Leaving
    -- starts its life again from the beginning rather than resuming a part-spent one.
    -- The chevron is a child button, so the mouse entering it leaves the row; both wear the
    -- same pair of handlers, or reaching for the chevron would start the row fading.
    local function enterRow(widget)
        local target = widget.row or widget
        target.hover:SetShown(true)
        target.hide:Stop()
        target:SetAlpha(1)
        if target.link and GameTooltip then
            GameTooltip:SetOwner(target, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(target.link)
            GameTooltip:Show()
        end
    end
    local function leaveRow(widget)
        local target = widget.row or widget
        if target:IsMouseOver() then
            return
        end
        target.hover:SetShown(false)
        if target.link and GameTooltip then
            GameTooltip:Hide()
        end
        if target.lifetime and not target.paused then
            target:Present(target.lifetime)
        end
    end
    -- Right click is the feed's own dismiss: the row goes now and the rest close the gap.
    -- Left click stays free for Gear Refactor's Equip button (PRD 5.3).
    local function dismissRow(target)
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == target then
            GameTooltip:Hide()
        end
        if target.onDismiss then
            target.onDismiss(target)
        end
    end
    row:SetScript("OnEnter", enterRow)
    row:SetScript("OnLeave", leaveRow)
    row:SetScript("OnClick", function(widget, button)
        if button == "RightButton" then
            dismissRow(widget)
        end
    end)
    row.chevron:SetScript("OnEnter", enterRow)
    row.chevron:SetScript("OnLeave", leaveRow)
    row.chevron:SetScript("OnClick", function(widget, button)
        if button == "RightButton" then
            dismissRow(widget.row)
        elseif widget.onToggle then
            widget.onToggle(widget)
        end
    end)
    -- The same pair as the chevron, for the same reason: moving onto the button must not
    -- start the row fading, and leaving it for open screen must.
    row.action:SetScript("OnEnter", enterRow)
    row.action:SetScript("OnLeave", leaveRow)
    row.action:SetScript("OnClick", function(widget)
        if widget.onAction then
            widget.onAction(widget.row)
        end
    end)

    -- Opacity is a setting, so the tint is applied per row rather than baked into a token.
    function row:SetRowOpacity(opacity)
        local tint, line = Theme.colors.LOOT_ROW, Theme.colors.LOOT_UNDERLINE
        self.background:SetVertexColor(tint[1], tint[2], tint[3], tint[4] * opacity)
        self.hover:SetVertexColor(tint[1], tint[2], tint[3], tint[4] * opacity)
        self.underline:SetVertexColor(line[1], line[2], line[3], line[4] * opacity)
    end

    -- Gold and currency use the same row without the icon frame, so the frame follows its
    -- own flag rather than the presence of an icon.
    function row:SetIcon(fileID, r, g, b, framed)
        local shown = fileID ~= nil
        self.icon:SetShown(shown)
        self.iconFrame:SetShown(shown and framed ~= false and Theme.missingFiles.lootIconFrame ~= true)
        if shown then
            self.icon:SetTexture(fileID)
            self.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            self.iconFrame:SetVertexColor(r or 1, g or 1, b or 1, 1)
        end
        self:LayoutText(shown and ROW_ICON + ROW_GAP or 0)
    end

    function row:LayoutText(inset)
        self.textInset = inset
        for key, anchor in pairs(LINE_ANCHORS) do
            local line = self[key]
            line:ClearAllPoints()
            line:SetPoint(anchor[1], inset, anchor[2])
            -- A line carrying money sizes to its own text so the coins can follow it.
            if key ~= self.moneyLine then
                line:SetPoint("RIGHT", self.accessory, "LEFT", -ROW_GAP, 0)
            end
        end
        self.underline:ClearAllPoints()
        self.underline:SetPoint("BOTTOMLEFT", inset, 0)
        self.underline:SetPoint("BOTTOMRIGHT", -ROW_GAP, 0)
        self:LayoutMoney()
    end

    function row:LayoutMoney()
        local line = self.moneyLine and self[self.moneyLine]
        if not line then
            self.coins:Hide()
        elseif line:GetText() ~= "" then
            self.coins:Place(line, self.money, self.moneySuffixText, "LEFT", line, "RIGHT", 0, 0)
        else
            -- An empty line has no height to centre on, so the coins take its place.
            local anchor = LINE_ANCHORS[self.moneyLine]
            self.coins:Place(line, self.money, self.moneySuffixText, anchor[1], self, anchor[1],
                self.textInset, anchor[2])
        end
    end

    -- Money shown on one line ("name" or "detail"), after whatever text SetLines gave that
    -- line and before suffix. Call after SetLines, which sets the colour the coins copy.
    function row:SetMoney(lineKey, amount, suffix)
        local shown = LINE_ANCHORS[lineKey] ~= nil and type(amount) == "number" and amount >= 0
        self.moneyLine = shown and lineKey or nil
        self.money = shown and math.floor(amount) or nil
        self.moneySuffixText = shown and suffix ~= "" and suffix or nil
        self:LayoutText(self.textInset)
    end

    -- A row with no quality of its own (a group, gold) takes the ordinary body colour.
    function row:SetLines(name, detail, r, g, b)
        self.name:SetText(name or "")
        if r then
            self.name:SetTextColor(r, g, b, 1)
        else
            Theme:Color(self.name, "TEXT_BODY", true)
        end
        self.detail:SetText(detail or "")
        Theme:Color(self.detail, "TEXT_MUTED", true)
    end

    function row:SetUnderlineShown(shown)
        self.underline:SetShown(shown and Theme.missingFiles.lootUnderline ~= true)
    end

    function row:SetExpander(expandable, expanded, onToggle)
        self.chevron:SetShown(expandable == true)
        self.chevron.onToggle = onToggle
        Theme:ApplyAsset(self.chevron.art, expanded and "scrollUp" or "scrollDown")
        Theme:Color(self.chevron.art, "ACCENT_COPPER")
    end

    -- The colour is the badge owner's own, handed over at runtime, never a literal here.
    function row:SetBadge(text, r, g, b)
        self.badge:SetShown(text ~= nil)
        if text then
            self.badge:SetText(text)
            self.badge:SetTextColor(r or 1, g or 1, b or 1, 1)
        end
        self:LayoutAccessory()
    end

    -- label nil hides the button. onAction(row) runs on a left click while it is enabled.
    function row:SetAction(label, enabled, onAction)
        self.action:SetShown(label ~= nil)
        self.action.onAction = onAction
        if label then
            self.action.label:SetText(label)
            self.action:SetEnabled(enabled == true)
        end
        self:LayoutAccessory()
    end

    -- The accessory never shrinks below its reserved icon width, so text does not reflow
    -- as badges come and go on neighbouring rows.
    function row:LayoutAccessory()
        local used = self.action:IsShown() and ROW_ACTION_WIDTH or 0
        self.badge:ClearAllPoints()
        if self.badge:IsShown() then
            if used > 0 then
                self.badge:SetPoint("RIGHT", self.action, "LEFT", -ROW_BADGE_GAP, 0)
                used = used + ROW_BADGE_GAP
            else
                self.badge:SetPoint("RIGHT")
            end
            used = used + self.badge:GetStringWidth()
        end
        self.accessory:SetWidth(math.max(ROW_ICON, used))
    end

    -- Called again for a row already on screen (a second drop of the same item): the hold
    -- restarts from now and nothing flashes.
    function row:Present(lifetime)
        self.lifetime, self.paused = lifetime, nil
        self.hide:Stop()
        if not self:IsShown() then
            self:SetAlpha(1)
            self:Show()
            self.show:Stop()
            self.show:Play()
        end
        self.fadeOut:SetStartDelay(lifetime)
        self.hide:Play()
    end

    -- An expanded group and its children have no countdown: the row waits for the player.
    function row:HoldTimer()
        self.hide:Stop()
        self.paused = true
        self:SetAlpha(1)
        self:Show()
    end

    function row:PlaceNow()
        self.slide:Stop()
        if not self.anchor then return end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", self.anchorX, self.anchorY)
    end

    -- A slide interrupted by another slide restarts from the target it was heading for,
    -- which is a shorter jump than it looks: the feed only relayouts when a row leaves.
    function row:PlaceAt(anchor, x, y, animate)
        local previous = self.anchor == anchor and self.anchorX == x and self.anchorY or nil
        self.anchor, self.anchorX, self.anchorY = anchor, x, y
        if not animate or not previous or previous == y then
            self:PlaceNow()
            return
        end
        self.slide:Stop()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, previous)
        self.slideAnim:SetOffset(0, y - previous)
        self.slide:Play()
    end

    function row:ResetRow()
        self.show:Stop()
        self.hide:Stop()
        self.slide:Stop()
        self:SetAlpha(1)
        self.hover:SetShown(false)
        self.lifetime, self.paused, self.link = nil, nil, nil
        self.anchor, self.anchorX, self.anchorY, self.key = nil, nil, nil, nil
        self:SetLines(nil, nil)
        self:SetMoney(nil)
        self:SetIcon(nil)
        self:SetExpander(false, false, nil)
        self:SetBadge(nil)
        self:SetAction(nil)
        self:SetUnderlineShown(false)
        self:ClearAllPoints()
        self:Hide()
    end

    row:LayoutText(ROW_ICON + ROW_GAP)
    row:Hide()
    return row
end

-- A stand-in for an Edit Mode system frame. Refactor cannot register a real system without
-- touching secure code, so this is our own frame wearing Blizzard's selection art: the same
-- nine-slice, the same two states, the same drag behaviour. Nothing Blizzard owns is touched.
function Theme:EditModeSelection(parent, labelText)
    local usable = NineSliceUtil and NineSliceUtil.ApplyLayout
    local selection = CreateFrame("Frame", nil, parent, usable and "NineSliceCodeTemplate" or nil)
    selection:SetAllPoints()
    selection:SetFrameStrata("HIGH")
    selection:SetFrameLevel(parent:GetFrameLevel() + 10)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    if not usable then
        self:Panel(selection)
    end
    selection.label = selection:CreateFontString(nil, "OVERLAY", self.fonts.editLabel)
    selection.label:SetPoint("CENTER")
    selection.label:SetText(labelText or "")

    -- Blizzard reapplies the layout only when the kit actually changes, and so does this.
    function selection:SetSelected(selected)
        local kit = selected and Theme.editModeKits.selected or Theme.editModeKits.highlight
        if usable and self.kit ~= kit then
            self.kit = kit
            NineSliceUtil.ApplyLayout(self, Theme.editModeLayout, kit)
        end
    end

    selection:SetSelected(false)
    selection:Hide()
    return selection
end

local MINIMAP_ICON_NUDGE_X, MINIMAP_ICON_NUDGE_Y = 0, 0

-- Refactor's own button, parented to the minimap but never altering it.
function Theme:MinimapButton(parent, size, inset)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(parent:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    -- IconMinimap.tga is already circle-masked with a transparent surround, so it is drawn
    -- as it ships: no crop, no mask, no tint.
    button.backdrop = self:Texture(button, "minimapIconBackdrop", "BACKGROUND")
    button.backdrop:SetPoint("TOPLEFT", inset, -inset)
    button.backdrop:SetPoint("BOTTOMRIGHT", -inset, inset)
    button.icon = self:Texture(button, "minimapIcon", "ARTWORK")
    -- The mark sits centred at zero nudge (checked in game); the offset stays for art that is not.
    button.icon:SetPoint("TOPLEFT", inset + MINIMAP_ICON_NUDGE_X, -inset + MINIMAP_ICON_NUDGE_Y)
    button.icon:SetPoint("BOTTOMRIGHT", -inset + MINIMAP_ICON_NUDGE_X, inset + MINIMAP_ICON_NUDGE_Y)
    -- Match the Retail border used by BugSack's LibDBIcon; the old path missed a hyphen.
    button.border = self:Texture(button, "minimapBorder", "OVERLAY")
    button.border:SetSize(50, 50)
    button.border:SetPoint("TOPLEFT", 0, 0)
    -- Use the same full-button highlight and default blending as BugSack's LibDBIcon.
    button:SetHighlightTexture(self.assets.minimapHighlight.file)
    return button
end
