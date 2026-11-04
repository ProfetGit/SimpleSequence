local _, SS = ...

local Theme = SS.Theme
local DragDrop = {}
SS.DragDrop = DragDrop

local GHOST_SIZE, GHOST_ALPHA = 36, 0.85
local ICON_CROP = 0.08
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

local targets = setmetatable({}, { __mode = "k" })
local ghost, payload, hovered

local function cursorScaled()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function buildGhost()
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("FULLSCREEN_DIALOG")
    ghost:SetSize(GHOST_SIZE, GHOST_SIZE)
    ghost:SetAlpha(GHOST_ALPHA)
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints()
    ghost.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ghost:Hide()
end

local function accepts(handlers, data)
    if handlers.accept then
        local ok, result = pcall(handlers.accept, data)
        return ok and result and true or false
    end
    return true
end

local function pickTarget()
    local best, bestRank
    for frame, handlers in pairs(targets) do
        if frame:IsVisible() and frame:IsMouseOver() and accepts(handlers, payload) then
            local rank = (STRATA_RANK[frame:GetFrameStrata()] or 0) * 100000 + frame:GetFrameLevel()
            if not bestRank or rank > bestRank then
                best, bestRank = frame, rank
            end
        end
    end
    return best
end

local function call(handler, ...)
    if not handler then return end
    local ok, result = pcall(handler, ...)
    if not ok then
        geterrorhandler()(result)
        return nil
    end
    return result
end

local function setHovered(frame)
    if frame == hovered then return end
    if hovered and targets[hovered] then
        call(targets[hovered].onLeave, payload)
    end
    hovered = frame
    if hovered then
        call(targets[hovered].onEnter, payload)
    end
end

local function onUpdate()
    if not payload then return end
    local x, y = cursorScaled()
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    if not IsMouseButtonDown("LeftButton") then
        DragDrop:Finish()
        return
    end
    setHovered(pickTarget())
    if hovered then
        call(targets[hovered].onMove, payload)
    end
end

function DragDrop:IsDragging()
    return payload ~= nil
end

function DragDrop:GetPayload()
    return payload
end

function DragDrop:Begin(data, icon)
    if payload then self:Cancel() end
    if not ghost then buildGhost() end
    payload = data
    hovered = nil
    ghost.icon:SetTexture(icon or Theme.assets.unknownItem.file)
    ghost:Show()
    ghost:SetScript("OnUpdate", onUpdate)
    onUpdate()
end

local function stop()
    if ghost then
        ghost:SetScript("OnUpdate", nil)
        ghost:Hide()
    end
    local data = payload
    payload, hovered = nil, nil
    return data
end

function DragDrop:Cancel()
    if not payload then return end
    setHovered(nil)
    stop()
end

function DragDrop:Finish()
    if not payload then return end
    local data, target = payload, hovered or pickTarget()
    if target and targets[target] then
        hovered = target
        call(targets[target].onDrop, data)
        call(targets[target].onLeave, data)
        stop()
        return
    end
    setHovered(nil)
    stop()
    if data.onDropOutside then
        call(data.onDropOutside)
    end
end

function DragDrop:RegisterSource(frame, getPayload)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local data, icon = getPayload(self)
        if data then
            DragDrop:Begin(data, icon)
        end
    end)
    frame:SetScript("OnDragStop", function()
        DragDrop:Finish()
    end)
end

local function cursorEntry()
    local ok, kind, v1, v2, v3, v4 = pcall(GetCursorInfo)
    if not ok or not kind then return nil end
    if kind == "spell" then
        local id = type(v3) == "number" and v3
        if not id then
            for _, value in ipairs({ v1, v2, v3, v4 }) do
                if type(value) == "number" then id = value end
            end
        end
        if id and id > 0 then
            return { kind = "spell", id = id }
        end
    elseif kind == "item" then
        if type(v1) == "number" then
            return { kind = "item", id = v1 }
        end
    elseif kind == "petaction" then
        if type(v1) == "number" and v1 > 0 then
            return { kind = "pet", id = v1 }
        end
    end
    return nil
end

local function receiveCursor(frame)
    local handlers = targets[frame]
    if not handlers or not handlers.onCursorDrop then return end
    local entry = cursorEntry()
    if not entry then return end
    call(handlers.onCursorDrop, entry)
    ClearCursor()
end

function DragDrop:ReceiveCursor(frame)
    receiveCursor(frame)
end

function DragDrop:RegisterTarget(frame, handlers)
    local known = targets[frame] ~= nil
    targets[frame] = handlers
    if known or not handlers.onCursorDrop then return end
    frame:EnableMouse(true)
    frame:HookScript("OnReceiveDrag", receiveCursor)
    frame:HookScript("OnMouseUp", receiveCursor)
end

function DragDrop:UnregisterTarget(frame)
    if hovered == frame then setHovered(nil) end
    targets[frame] = nil
end
