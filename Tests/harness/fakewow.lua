local H = {
    frames = {},
    errors = {},
    missing = {},
    missingOrder = {},
    timers = {},
    inCombat = false,
    spec = 1,
    specID = 63,
    cursor = nil,
    macros = {},
    macroList = {},
}

local function recordError(err)
    H.errors[#H.errors + 1] = { msg = tostring(err), tb = debug.traceback(tostring(err), 2), step = H.step }
end
H.recordError = recordError

local Frame = {}
Frame.__index = function(self, key)
    local v = rawget(Frame, key)
    if v ~= nil then return v end
    if type(key) == "string" and key:match("^[A-Z]") then
        local fn
        if key:match("^Is") or key:match("^Has") or key:match("^Can") then
            fn = function() return false end
        else
            fn = function(this) return H.newProxy("Region", nil, this) end
        end
        return fn
    end
    return nil
end

function H.newProxy(kind, name, parent)
    local f = setmetatable({}, Frame)
    rawset(f, "__kind", kind or "Frame")
    rawset(f, "__name", name)
    rawset(f, "__parent", parent)
    rawset(f, "__scripts", {})
    rawset(f, "__hooks", {})
    rawset(f, "__attrs", {})
    rawset(f, "__events", {})
    rawset(f, "__shown", true)
    rawset(f, "__text", "")
    rawset(f, "__children", {})
    H.frames[#H.frames + 1] = f
    return f
end

local function fire(self, script, ...)
    local fn = self.__scripts[script]
    if fn then fn(self, ...) end
    local hooks = self.__hooks[script]
    if hooks then
        for _, h in ipairs(hooks) do h(self, ...) end
    end
end
H.fireScript = fire

function Frame:SetScript(name, fn)
    self.__scripts[name] = fn
    if fn and (name == "OnKeyDown" or name == "OnKeyUp") then rawset(self, "__keyboard", true) end
end
function Frame:EnableKeyboard(on) rawset(self, "__keyboard", on and true or false) end
function Frame:IsKeyboardEnabled() return rawget(self, "__keyboard") == true end
function H.pressKey(key)
    for _, f in ipairs(H.frames) do
        if rawget(f, "__keyboard") and f:IsVisible() and f.__scripts.OnKeyDown then
            f.__scripts.OnKeyDown(f, key)
        end
    end
end
function Frame:GetScript(name) return self.__scripts[name] end
function Frame:HookScript(name, fn)
    self.__hooks[name] = self.__hooks[name] or {}
    table.insert(self.__hooks[name], fn)
end
function Frame:HasScript() return true end
function Frame:SetAttribute(k, v)
    self.__attrs[k] = v
    fire(self, "OnAttributeChanged", k, v)
end
function Frame:GetAttribute(k) return self.__attrs[k] end
function Frame:SetFrameRef(k, v) self.__attrs["frameref-" .. k] = v end
function Frame:GetFrameRef(k) return self.__attrs["frameref-" .. k] end
function Frame:Show()
    if not self.__shown or not self.__everShown then
        self.__shown = true
        self.__everShown = true
        fire(self, "OnShow")
    end
end
function Frame:Hide()
    if self.__shown then
        self.__shown = false
        fire(self, "OnHide")
    end
end
function Frame:SetShown(s) if s then self:Show() else self:Hide() end end
function Frame:IsShown() return self.__shown end
function Frame:IsVisible()
    if not self.__shown then return false end
    local p = self.__parent
    if p and p.IsVisible and p ~= self then return p:IsVisible() end
    return true
end
function Frame:Raise() end
function Frame:IsMouseOver() return false end
function Frame:GetFrameLevel() return self.__level or 1 end
function Frame:SetFrameLevel(l) self.__level = l end
function Frame:GetFrameStrata() return self.__strata or "MEDIUM" end
function Frame:SetFrameStrata(s) self.__strata = s end
function Frame:GetName() return self.__name end
function Frame:GetParent() return self.__parent end
function Frame:SetParent(p) self.__parent = p end
function Frame:GetObjectType() return self.__kind end
function Frame:IsObjectType(t) return self.__kind == t end
function Frame:GetNumChildren() return 0 end
function Frame:GetChildren() end
function Frame:GetNumRegions() return 0 end
function Frame:GetRegions() end
function Frame:SetSize(w, h) self.__w, self.__h = w, h end
function Frame:SetWidth(w) self.__w = w end
function Frame:SetHeight(h) self.__h = h end
function Frame:GetWidth() return self.__w or 200 end
function Frame:GetHeight() return self.__h or 200 end
function Frame:GetSize() return self:GetWidth(), self:GetHeight() end
function Frame:GetLeft() return 100 end
function Frame:GetRight() return 100 + self:GetWidth() end
function Frame:GetTop() return 500 end
function Frame:GetBottom() return 500 - self:GetHeight() end
function Frame:GetCenter() return 100, 400 end
function Frame:GetRect() return 100, 300, self:GetWidth(), self:GetHeight() end
function Frame:GetScale() return self.__scale or 1 end
function Frame:SetScale(s) self.__scale = s end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetAlpha() return self.__alpha or 1 end
function Frame:SetAlpha(a) self.__alpha = a end
function Frame:GetEffectiveAlpha() return self:GetAlpha() end
function Frame:SetPoint(...) self.__points = self.__points or {}; table.insert(self.__points, { ... }) end
function Frame:ClearAllPoints() self.__points = nil end
function Frame:GetPoint(i)
    local p = self.__points and self.__points[i or 1]
    if p then return p[1], p[2] == nil and UIParent or p[2], p[3] or p[1], tonumber(p[4]) or 0, tonumber(p[5]) or 0 end
    return "CENTER", UIParent, "CENTER", 0, 0
end
function Frame:GetNumPoints() return self.__points and #self.__points or 1 end
function Frame:SetText(t) self.__text = t == nil and "" or t end
function Frame:GetText() return self.__text end
function Frame:GetStringWidth() return #tostring(self.__text or "") * 7 end
function Frame:GetStringHeight() return 12 end
function Frame:GetUnboundedStringWidth() return self:GetStringWidth() end
function Frame:GetNumLetters() return #tostring(self.__text or "") end
function Frame:GetTextColor() return 1, 1, 1, 1 end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:GetFontObject() return H.newProxy("Font") end
function Frame:GetJustifyH() return "LEFT" end
function Frame:GetCursorPosition() return 0 end
function Frame:SetCursorPosition() end
function Frame:HasFocus() return self.__focus == true end
function Frame:SetFocus() self.__focus = true; fire(self, "OnEditFocusGained") end
function Frame:ClearFocus() if self.__focus then self.__focus = false; fire(self, "OnEditFocusLost") end end
function Frame:IsEnabled() return self.__enabled ~= false end
function Frame:Enable() self.__enabled = true end
function Frame:Disable() self.__enabled = false end
function Frame:SetEnabled(e) self.__enabled = e end
function Frame:GetChecked() return self.__checked == true end
function Frame:SetChecked(c) self.__checked = c end
function Frame:SetValue(v) self.__value = v end
function Frame:GetValue() return self.__value or 0 end
function Frame:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Frame:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function Frame:GetVerticalScroll() return self.__vs or 0 end
function Frame:SetVerticalScroll(v) self.__vs = v end
function Frame:GetVerticalScrollRange() return 0 end
function Frame:GetHorizontalScroll() return 0 end
function Frame:GetTexture() return self.__texture end
function Frame:SetTexture(t) self.__texture = t end
function Frame:SetAtlas(a) self.__atlas = a end
function Frame:GetAtlas() return self.__atlas end
function Frame:GetDrawLayer() return "ARTWORK", 0 end
function Frame:GetVertexColor() return 1, 1, 1, 1 end
function Frame:GetBackdropColor() return 0, 0, 0, 1 end
function Frame:IsDragging() return false end
function Frame:GetNormalTexture() return H.newProxy("Texture", nil, self) end
function Frame:GetHighlightTexture() return H.newProxy("Texture", nil, self) end
function Frame:GetPushedTexture() return H.newProxy("Texture", nil, self) end
function Frame:GetDisabledTexture() return H.newProxy("Texture", nil, self) end
function Frame:GetThumbTexture() return H.newProxy("Texture", nil, self) end
function Frame:GetScrollChild() return self.__scrollChild end
function Frame:SetScrollChild(c) self.__scrollChild = c end
function Frame:GetOwner() return self.__owner end
function Frame:SetOwner(o) self.__owner = o end
function Frame:NumLines() return 0 end
function Frame:IsPlaying() return self.__playing == true end
function Frame:Play() self.__playing = true end
function Frame:Stop() self.__playing = false end
function Frame:Finish() self.__playing = false end
function Frame:IsMovable() return true end
function Frame:IsUserPlaced() return false end
function Frame:IsClampedToScreen() return true end
function Frame:IsMouseEnabled() return true end
function Frame:IsProtected() return false end
function Frame:IsForbidden() return false end
function Frame:GetBoundsRect() return 100, 300, 200, 200 end
function Frame:GetPropagateKeyboardInput() return false end
function Frame:GetNumPoints() return 1 end
function Frame:GetAnimationGroups() end
function Frame:GetFadeOutAnimation() end
function Frame:GetHitRectInsets() return 0, 0, 0, 0 end
function Frame:GetShadowOffset() return 0, 0 end
function Frame:GetSpacing() return 0 end
function Frame:GetWrappedWidth() return self:GetWidth() end
function Frame:GetMaxLines() return 1 end
function Frame:GetTextInsets() return 0, 0, 0, 0 end
function Frame:GetBlendMode() return "BLEND" end
function Frame:GetSmoothProgress() return 0 end
function Frame:GetOrder() return 1 end
function Frame:GetLooping() return "NONE" end
function Frame:GetProgress() return 0 end
function Frame:GetDuration() return 0 end

function Frame:RegisterEvent(e) self.__events[e] = true end
function Frame:RegisterUnitEvent(e) self.__events[e] = true end
function Frame:UnregisterEvent(e) self.__events[e] = nil end
function Frame:UnregisterAllEvents() self.__events = {} end
function Frame:IsEventRegistered(e) return self.__events[e] == true end
function Frame:RegisterForClicks() end
function Frame:RegisterForDrag() end

function Frame:CreateTexture(name) return H.newProxy("Texture", name, self) end
function Frame:CreateMaskTexture(name) return H.newProxy("MaskTexture", name, self) end
function Frame:CreateFontString(name) return H.newProxy("FontString", name, self) end
function Frame:CreateAnimationGroup(name) return H.newProxy("AnimationGroup", name, self) end
function Frame:CreateAnimation(kind) return H.newProxy("Animation", nil, self) end
function Frame:CreateLine(name) return H.newProxy("Line", name, self) end

function Frame:Click(button, down)
    fire(self, "OnClick", button or "LeftButton", down or false)
end
function Frame:Execute() end

function Frame:AddLine(...) end
function Frame:AddDoubleLine(...) end
function Frame:ClearLines() end

local SPELLS = {
    [1] = { name = "Fireball", icon = 135810, cd = 0, gcd = 1500 },
    [2] = { name = "Pyroblast", icon = 135808, cd = 10000, gcd = 1500 },
    [3] = { name = "Ice Block", icon = 135841, cd = 24000, gcd = 1500 },
    [4] = { name = "Blink", icon = 135736, cd = 15000, gcd = 0 },
    [5] = { name = "Fire Blast", icon = 135807, cd = 8000, gcd = 1500 },
}
H.SPELLS = SPELLS

function H.createFrame(kind, name, parent, template)
    local f = H.newProxy(kind or "Frame", name, parent)
    f.__template = template
    f.__shown = true
    if kind == "Button" or kind == "CheckButton" then
        f.Text = nil
    end
    if name then
        _G[name] = f
    end
    if template and tostring(template):find("Scroll") then
        f.ScrollBar = nil
    end
    return f
end

function H.install(env)
    local G = env

    G.UIParent = H.newProxy("Frame", "UIParent")
    G.UIParent.GetWidth = nil
    rawset(G.UIParent, "__w", 1920)
    rawset(G.UIParent, "__h", 1080)
    G.WorldFrame = H.newProxy("Frame", "WorldFrame")
    G.GameTooltip = H.newProxy("GameTooltip", "GameTooltip")
    G.UISpecialFrames = {}
    G.StaticPopupDialogs = {}
    G.SlashCmdList = {}
    G.CreateFrame = H.createFrame
    G.StaticPopup_Show = function(which, a, b, data)
        H.lastPopup = { which = which, data = data }
        return H.newProxy("Frame")
    end
    G.StaticPopup_Hide = function() end
    G.geterrorhandler = function() return recordError end
    G.seterrorhandler = function() end
    G.InCombatLockdown = function() return H.inCombat end
    G.issecretvalue = function() return false end
    G.issecrettable = function() return false end
    G.canaccessvalue = function() return true end
    G.hooksecurefunc = function(a, b, c)
        local tbl, name, fn
        if type(a) == "table" then tbl, name, fn = a, b, c else tbl, name, fn = G, a, b end
        local orig = tbl[name]
        tbl[name] = function(...)
            local r = { pcall(orig or function() end, ...) }
            fn(...)
            return unpack(r, 2)
        end
    end

    G.C_Timer = {
        After = function(sec, fn) H.timers[#H.timers + 1] = { fn = fn, sec = sec } end,
        NewTimer = function(sec, fn)
            local t = { fn = fn, sec = sec }
            function t:Cancel() self.cancelled = true end
            function t:IsCancelled() return self.cancelled == true end
            H.timers[#H.timers + 1] = t
            return t
        end,
        NewTicker = function(sec, fn)
            local t = { fn = fn, sec = sec, ticker = true }
            function t:Cancel() self.cancelled = true end
            function t:IsCancelled() return self.cancelled == true end
            return t
        end,
    }
    G.C_AddOns = {
        GetAddOnMetadata = function(_, field) if field == "Version" then return "0.1.0" end return "x" end,
        IsAddOnLoaded = function() return true end,
    }
    G.GetAddOnMetadata = nil
    G.C_SpecializationInfo = {
        GetSpecialization = function() return H.spec end,
        GetSpecializationInfo = function(i)
            if H.specID == 64 then return 64, "Frost", "desc", 135846, "DAMAGER" end
            return 63, "Fire", "desc", 135810, "DAMAGER"
        end,
    }
    G.GetSpecialization = nil
    G.UnitClass = function() return "Mage", "MAGE", 8 end
    G.UnitName = function() return "Tester" end
    G.GetRealmName = function() return "Realm" end
    G.UnitGUID = function() return "Player-1-1" end
    G.UnitExists = function() return true end
    G.UnitAffectingCombat = function() return false end

    G.GetSpellBaseCooldown = function(id) local s = SPELLS[id]; return s and s.cd or 0, s and s.gcd or 1500 end
    G.UnitSpellHaste = function() return 0 end

    G.C_Spell = {
        GetSpellName = function(id) local s = SPELLS[id]; return s and s.name end,
        GetSpellTexture = function(id) local s = SPELLS[id]; return s and s.icon end,
        GetSpellInfo = function(id)
            local s = SPELLS[id]
            if not s then return nil end
            return { name = s.name, iconID = s.icon, originalIconID = s.icon, spellID = id, castTime = 0, minRange = 0, maxRange = 0 }
        end,
        IsSpellPassive = function() return false end,
        DoesSpellExist = function(id) return SPELLS[id] ~= nil end,
    }
    G.C_Item = {
        GetItemNameByID = function(id) return id == 100 and "Healing Potion" or nil end,
        GetItemIconByID = function(id) return id == 100 and 134400 or nil end,
        GetItemSpell = function(id) return id == 100 and "Heal" or nil end,
        GetItemInfo = function(id) return id == 100 and "Healing Potion" or nil end,
    }
    G.GetInventoryItemID = function(_, slot) return slot == 13 and 100 or nil end
    G.GetInventoryItemTexture = function(_, slot) return 3000 + slot end
    G.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 } }
    G.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 3 end,
        GetSpellBookSkillLineInfo = function(i)
            if i == 1 then return { name = "General", iconID = 1, itemIndexOffset = 0, numSpellBookItems = 1 } end
            if i == 2 then return { name = "Fire", iconID = 2, itemIndexOffset = 1, numSpellBookItems = 3, specID = 63 } end
            return { name = "Mage", iconID = 3, itemIndexOffset = 4, numSpellBookItems = 2 }
        end,
        GetSpellBookItemInfo = function(slot, bank)
            if bank == 1 then
                if slot == 1 then return { spellID = 4, name = "Blink", iconID = 135736, itemType = 3 } end
                return nil
            end
            local id = ({ 4, 1, 2, 5, 3, 5 })[slot]
            local s = id and SPELLS[id]
            if not s then return nil end
            return { spellID = id, actionID = id, name = s.name, iconID = s.icon, itemType = 1, isPassive = false, subName = "" }
        end,
        HasPetSpells = function() return 1 end,
        IsSpellKnownOrInSpellBook = function(id) return SPELLS[id] ~= nil end,
    }
    G.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerItemInfo = function() return nil end,
    }
    G.C_Texture = { GetAtlasInfo = function() return nil end }
    G.C_CVar = { GetCVar = function() return "1" end, GetCVarBool = function() return true end }
    G.NUM_BAG_SLOTS = 4
    G.CANCEL = "Cancel"
    G.ACCEPT = "Accept"
    G.OKAY = "Okay"
    G.YES = "Yes"
    G.NO = "No"
    G.CLOSE = "Close"
    G.DELETE = "Delete"

    local function ser(v)
        if type(v) == "table" then
            local p = {}
            for k, x in pairs(v) do p[#p + 1] = "[" .. ser(k) .. "]=" .. ser(x) end
            return "{" .. table.concat(p, ",") .. "}"
        elseif type(v) == "string" then
            return string.format("%q", v)
        end
        return tostring(v)
    end
    G.C_EncodingUtil = {
        SerializeCBOR = ser,
        DeserializeCBOR = function(s)
            local fn = assert(loadstring("return " .. s))
            setfenv(fn, {})
            return fn()
        end,
        CompressString = function(s) return "Z" .. s end,
        DecompressString = function(s)
            assert(s:sub(1, 1) == "Z", "bad data")
            return s:sub(2)
        end,
        EncodeBase64 = function(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end,
        DecodeBase64 = function(s)
            assert(#s % 2 == 0 and not s:find("%X"), "bad base64")
            return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
        end,
    }

    G.SecureHandlerWrapScript = function(frame, script, header, pre, post)
        frame.__wraps = frame.__wraps or {}
        frame.__wraps[script] = { header = header, pre = pre, post = post }
    end
    G.RegisterStateDriver = function(frame, state, cond) frame.__states = frame.__states or {}; frame.__states[state] = cond end
    G.UnregisterStateDriver = function() end
    G.SetOverrideBindingClick = function(owner, pri, key, btn, mb) H.bound = H.bound or {}; H.bound[key] = btn end
    G.ClearOverrideBindings = function() H.bound = {} end
    G.GetBindingAction = function(key) return "" end
    G.GetBindingKey = function() return nil end
    G.SetBinding = function() return true end
    G.SaveBindings = function() end
    G.GetCurrentBindingSet = function() return 1 end

    G.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
    G.MAX_ACCOUNT_MACROS = 120
    G.MAX_CHARACTER_MACROS = 30
    G.CreateMacro = function(name, icon, body, perChar)
        H.macroList[#H.macroList + 1] = { name = name, icon = icon, body = body }
        return #H.macroList
    end
    G.EditMacro = function(i, name, icon, body)
        local m = H.macroList[i]
        if not m then error("EditMacro: bad index " .. tostring(i)) end
        m.name = name or m.name; m.icon = icon or m.icon; m.body = body or m.body
        return i
    end
    G.GetMacroIndexByName = function(name)
        for i, m in ipairs(H.macroList) do if m.name == name then return i end end
        return 0
    end
    G.GetNumMacros = function() return 0, #H.macroList end
    G.PickupMacro = function(x) H.cursor = { "macro", type(x) == "number" and x or G.GetMacroIndexByName(x) } end
    G.DeleteMacro = function(i) if type(i) == "string" then i = G.GetMacroIndexByName(i) end table.remove(H.macroList, i) end
    G.GetMacroInfo = function(i) local m = H.macroList[i]; if m then return m.name, m.icon, m.body end end
    G.GetMacroBody = function(i) local m = H.macroList[i]; return m and m.body end
    H.macroFeedback = {}
    G.SetMacroSpell = function(i, spell) H.macroFeedback[i] = spell end
    G.SetMacroItem = function(i, item) H.macroFeedback[i] = item end
    G.GetCursorInfo = function() if H.cursor then return unpack(H.cursor) end end
    G.ClearCursor = function() H.cursor = nil end
    G.GetCursorPosition = function() return 400, 300 end
    G.IsMouseButtonDown = function() return H.mouseDown == true end
    G.IsShiftKeyDown = function() return false end
    G.IsControlKeyDown = function() return false end
    G.IsAltKeyDown = function() return false end
    G.IsModifiedClick = function() return false end
    G.GetCurrentKeyBoardFocus = function() return nil end
    G.GetPhysicalScreenSize = function() return 1920, 1080 end
    G.GetScreenWidth = function() return 1920 end
    G.GetScreenHeight = function() return 1080 end
    G.GetTime = function() return 1000 end
    G.GetServerTime = function() return os.time() end
    G.PlaySound = function() end
    G.PlaySoundFile = function() end
    G.PlayerFrame = nil
    G.DEFAULT_ICON = nil
    G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    G.ChatFrame_OpenChat = function() end
    G.GetLocale = function() return "enUS" end
    G.IsLoggedIn = function() return true end
    G.GetCVar = function() return "1" end
    G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
    G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
    G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0, GetRGB = function() return 1, 0.82, 0 end }
    G.WHITE_FONT_COLOR = { r = 1, g = 1, b = 1 }
    G.GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
    G.RED_FONT_COLOR = { r = 1, g = 0.1, b = 0.1 }

    G.time = os.time
    G.date = os.date
    G.strtrim = function(s, chars)
        chars = chars or "%s"
        return (s:gsub("^[" .. chars .. "]+", ""):gsub("[" .. chars .. "]+$", ""))
    end
    G.strsplit = function(d, s, n)
        local out, pos = {}, 1
        while true do
            local a, b = s:find(d, pos, true)
            if not a or (n and #out >= n - 1) then out[#out + 1] = s:sub(pos); break end
            out[#out + 1] = s:sub(pos, a - 1)
            pos = b + 1
        end
        return unpack(out)
    end
    G.strjoin = function(d, ...) return table.concat({ ... }, d) end
    G.strlower = string.lower
    G.strupper = string.upper
    G.strfind = string.find
    G.strsub = string.sub
    G.strlen = string.len
    G.strrep = string.rep
    G.strbyte = string.byte
    G.strchar = string.char
    G.format = string.format
    G.gsub = string.gsub
    G.gmatch = string.gmatch
    G.tinsert = table.insert
    G.tremove = table.remove
    G.sort = table.sort
    G.floor = math.floor
    G.ceil = math.ceil
    G.abs = math.abs
    G.min = math.min
    G.max = math.max
    G.sqrt = math.sqrt
    G.random = math.random
    G.tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
    G.tIndexOf = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.CopyTable = function(t)
        local function copy(x)
            if type(x) ~= "table" then return x end
            local o = {}
            for k, v in pairs(x) do o[copy(k)] = copy(v) end
            return o
        end
        return copy(t)
    end
    G.Mixin = function(obj, ...)
        for _, m in ipairs({ ... }) do for k, v in pairs(m) do obj[k] = v end end
        return obj
    end
    G.CreateFromMixins = function(...) return G.Mixin({}, ...) end
    G.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
    G.Lerp = function(a, b, t) return a + (b - a) * t end
    G.Round = function(v) return math.floor(v + 0.5) end
    G.Saturate = function(v) return math.max(0, math.min(1, v)) end
    G.nop = function() end
    G.CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a or 1,
            GetRGB = function(self) return self.r, self.g, self.b end,
            GetRGBA = function(self) return self.r, self.g, self.b, self.a end,
            GenerateHexColor = function() return "ffffffff" end,
            WrapTextInColorCode = function(_, t) return t end }
    end
    G.CreateFont = function(name) local f = H.newProxy("Font", name); if name then G[name] = f end return f end
    G.NineSliceUtil = { ApplyLayout = function() end, ApplyLayoutByName = function() end, GetLayout = function() return {} end }
    G.NineSliceLayouts = setmetatable({}, { __index = function() return {} end })
    G.Mixin = G.Mixin

    local function menuRoot(log)
        local root = {}
        function root:CreateButton(text, fn) log[#log + 1] = { text = text, fn = fn }; return root end
        function root:CreateTitle(text) return root end
        function root:CreateDivider() return root end
        function root:CreateCheckbox(text, ...) return root end
        function root:CreateRadio(text, ...) return root end
        function root:SetScrollMode() end
        return root
    end
    H.menus = {}
    G.MenuUtil = {
        CreateContextMenu = function(owner, gen)
            local log = {}
            gen(owner, menuRoot(log))
            H.menus[#H.menus + 1] = log
        end,
    }
    G.Menu = { PopupMenu = G.MenuUtil.CreateContextMenu }
    H.callbacks = {}
    G.EventRegistry = {
        RegisterCallback = function(_, event, fn, owner)
            H.callbacks[event] = H.callbacks[event] or {}
            table.insert(H.callbacks[event], { fn = fn, owner = owner })
        end,
    }
    function H.triggerCallback(event, ...)
        for _, cb in ipairs(H.callbacks[event] or {}) do cb.fn(cb.owner, ...) end
    end
    H.editMode = false
    G.EditModeManagerFrame = { IsEditModeActive = function() return H.editMode end }
    G.CreateCallbackRegistry = nil
    G.ColorPickerFrame = H.newProxy("Frame", "ColorPickerFrame")
    G.GameFontNormal = H.newProxy("Font", "GameFontNormal")
    G.GameFontHighlight = H.newProxy("Font", "GameFontHighlight")
    G.SystemFont_Shadow_Med1 = H.newProxy("Font", "SystemFont_Shadow_Med1")
    G.SELECTED_CHAT_FRAME = nil
    G.ReloadUI = function() end
    G.Minimap = H.newProxy("Frame", "Minimap")
    G.IsAddOnLoaded = nil
    G.print = function(...) H.printed[#H.printed + 1] = table.concat((function(...)
        local t = {}
        for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
        return t
    end)(...), " ") end
    H.printed = {}
end

function H.flushTimers()
    local guard = 0
    while #H.timers > 0 and guard < 2000 do
        guard = guard + 1
        local t = table.remove(H.timers, 1)
        if not t.cancelled then
            local ok, err = xpcall(t.fn, function(e) return debug.traceback(tostring(e), 2) end)
            if not ok then
                H.errors[#H.errors + 1] = { msg = tostring(err):match("^[^\n]*"), tb = err, step = "timer" }
            end
        end
    end
end

function H.dispatchEvent(event, ...)
    local targets = {}
    for _, f in ipairs(H.frames) do
        if f.__events and f.__events[event] then targets[#targets + 1] = f end
    end
    for _, f in ipairs(targets) do
        local fn = f.__scripts.OnEvent
        if fn then
            local args = { ... }
            local ok, err = xpcall(function() fn(f, event, unpack(args)) end, function(e) return debug.traceback(tostring(e), 2) end)
            if not ok then
                H.errors[#H.errors + 1] = { msg = tostring(err):match("^[^\n]*"), tb = err, step = "event " .. event }
            end
        end
    end
end

return H
