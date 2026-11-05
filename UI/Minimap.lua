local _, SS = ...
local Theme = SS.Theme
local MinimapButton = {}
SS.MinimapButton = MinimapButton

local BUTTON_SIZE, ICON_INSET, ORBIT_MARGIN = 31, 3, 5
local DEFAULT_ANGLE = 225

local button

local function saved()
    if not SS.db then return nil end
    local store = SS.db.minimap
    if type(store) ~= "table" then
        store = {}
        SS.db.minimap = store
    end
    if type(store.angle) ~= "number" then store.angle = DEFAULT_ANGLE end
    store.hide = store.hide == true
    return store
end

local function orbitRadius(parent)
    local width = parent:GetWidth()
    if type(width) ~= "number" or width <= 0 then width = 140 end
    return width / 2 + ORBIT_MARGIN
end

local function place(widget, angle)
    local radians = math.rad(angle)
    local parent = widget:GetParent()
    local radius = orbitRadius(parent)
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", parent, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function drag(widget)
    local parent = widget:GetParent()
    local centerX, centerY = parent:GetCenter()
    if not centerX then return end
    local x, y = GetCursorPosition()
    local scale = parent:GetEffectiveScale()
    local angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
    local store = saved()
    if store then store.angle = angle end
    place(widget, angle)
end

local function showTooltip(widget)
    if not GameTooltip then return end
    GameTooltip:SetOwner(widget, "ANCHOR_LEFT")
    local title, body, muted = Theme.colors.TEXT_TITLE, Theme.colors.TEXT_BODY, Theme.colors.TEXT_MUTED
    GameTooltip:AddLine("SimpleSequence", title[1], title[2], title[3])
    GameTooltip:AddLine("Left-click: open", body[1], body[2], body[3])
    GameTooltip:AddLine("Right-click: options", body[1], body[2], body[3])
    GameTooltip:AddLine("Drag: move", muted[1], muted[2], muted[3])
    GameTooltip:Show()
end

local function showMenu(owner)
    SS.Widgets:ContextMenu(owner, {
        { text = "Hide minimap button", fn = function() MinimapButton:SetHidden(true) end },
        { text = "Show or hide next-up icon", fn = function()
            if SS.NextUp then SS.NextUp:Toggle() end
        end },
    })
end

function MinimapButton:Create()
    if button or not Minimap then return button end
    button = Theme:MinimapButton(Minimap, BUTTON_SIZE, ICON_INSET)
    self.button = button
    button:SetScript("OnClick", function(widget, mouseButton)
        if mouseButton == "RightButton" then
            showMenu(widget)
        elseif SS.Window then
            SS.Window:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(widget)
        if GameTooltip then GameTooltip:Hide() end
        widget:SetScript("OnUpdate", drag)
    end)
    button:SetScript("OnDragStop", function(widget)
        widget:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    self:Refresh()
    return button
end

function MinimapButton:Refresh()
    if not button then return end
    local store = saved()
    place(button, store and store.angle or DEFAULT_ANGLE)
    button:SetShown(not (store and store.hide))
end

function MinimapButton:SetHidden(hidden)
    local store = saved()
    if not store then return end
    store.hide = hidden == true
    if not button then self:Create() end
    self:Refresh()
    if store.hide then
        SS:Print("Minimap button hidden. Show it again with /seq minimap")
    end
end

function MinimapButton:Toggle()
    local store = saved()
    if not store then return end
    self:SetHidden(not store.hide)
    if not store.hide then SS:Print("Minimap button shown.") end
end

SS:On("DB_READY", function() saved() end)
SS:On("LOGIN", function() MinimapButton:Create() end)
