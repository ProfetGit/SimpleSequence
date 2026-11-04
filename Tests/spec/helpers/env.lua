local M = {}

local SPELLS = {
    [1] = "Fireball", [2] = "Pyroblast", [3] = "Ice Block", [4] = "Blink", [5] = "Fire Blast", [6] = "Scorch",
}
local ITEMS = { [100] = "Healing Potion" }

local function serialize(value)
    local t = type(value)
    if t == "table" then
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local function installGlobals(known)
    _G.C_Spell = {
        GetSpellName = function(id) return SPELLS[id] end,
        GetSpellTexture = function(id) return SPELLS[id] and (1000 + id) or nil end,
    }
    _G.C_Item = {
        GetItemNameByID = function(id) return ITEMS[id] end,
        GetItemIconByID = function(id) return ITEMS[id] and 2000 or nil end,
    }
    _G.GetInventoryItemTexture = function(_, slot) return 3000 + slot end
    _G.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } }
    _G.C_SpellBook = {
        IsSpellKnownOrInSpellBook = function(id) return known[id] == true end,
    }
    _G.C_EncodingUtil = {
        SerializeCBOR = function(v) return serialize(v) end,
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
        EncodeBase64 = function(s)
            return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
        end,
        DecodeBase64 = function(s)
            assert(#s % 2 == 0 and not s:find("%X"), "bad base64")
            return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
        end,
    }
    _G.time = os.time
    _G.UnitName = function() return "Tester" end
    _G.GetRealmName = function() return "Realm" end
    _G.geterrorhandler = function() return function(e) error(e) end end
end

function M.new(files, opts)
    opts = opts or {}
    _G.SimpleSequenceDB = nil
    local known = opts.known or {}
    installGlobals(known)

    local SS = {
        MAX_STEPS = 64, MAX_EXTRAS = 8, MAX_STEP_TEXT = 1023,
        BUTTON_PREFIX = "SimpleSequenceBtn_", MACRO_PREFIX = "SS ",
        currentSpec = 63, events = {}, listeners = {}, printed = {},
    }
    function SS:On(event, fn)
        self.listeners[event] = self.listeners[event] or {}
        table.insert(self.listeners[event], fn)
    end
    function SS:Fire(event, ...)
        self.events[#self.events + 1] = { event, ... }
        for _, fn in ipairs(self.listeners[event] or {}) do fn(...) end
    end
    function SS:Print(...) self.printed[#self.printed + 1] = table.concat({ ... }, " ") end
    function SS:count(event)
        local n = 0
        for _, e in ipairs(self.events) do if e[1] == event then n = n + 1 end end
        return n
    end

    for _, file in ipairs(files) do
        local chunk = assert(loadfile(file))
        chunk("SimpleSequence", SS)
    end
    if SS.Database then SS.Database:Init() end
    return SS
end

M.SPELLS = SPELLS

function M.spell(id) return { kind = "spell", id = id } end

function M.step(entry, target, mods)
    return { entry = entry, target = target or "target", mods = mods or {} }
end

return M
