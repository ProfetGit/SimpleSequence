local _, SS = ...

local Database = {}
SS.Database = Database

local UNDO_LIMIT = 20
local MAX_NAME = 48
local MAX_ID = 2147483647
local TARGETS = { target = true, player = true, mouseover = true, focus = true }
local MOD_KEYS = { "shift", "ctrl", "alt" }
local SPELL_KINDS = { spell = true, pet = true, item = true, slot = true }

local undoStack = {}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end
Database.DeepCopy = deepCopy

local function clampIndex(i, low, high)
    if i < low then return low end
    if i > high then return high end
    return i
end

local function cleanString(value, maxLen)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("[%c|]", "")
    if #value > maxLen then
        value = value:sub(1, maxLen)
    end
    return value
end

local function isWholeNumber(n)
    return type(n) == "number" and n == math.floor(n) and n > 0 and n <= MAX_ID
end

-- allowEmote: only a step's main entry may be an emote
local function sanitizeEntry(entry, allowEmote)
    if type(entry) ~= "table" then
        return nil
    end
    local kind, id = entry.kind, entry.id
    if kind == "emote" then
        if not allowEmote or type(id) ~= "string" or #id > 24 or not id:match("^%a+$") then
            return nil
        end
        return { kind = "emote", id = id:lower() }
    end
    if not SPELL_KINDS[kind] then
        return nil
    end
    if kind == "slot" then
        if id ~= 13 and id ~= 14 then
            return nil
        end
    elseif not isWholeNumber(id) then
        return nil
    end
    return { kind = kind, id = id }
end

local function sanitizeStep(step)
    if type(step) ~= "table" then
        return nil
    end
    local entry = sanitizeEntry(step.entry, true)
    if not entry then
        return nil
    end
    local clean = { entry = entry, target = "target", mods = {} }
    if TARGETS[step.target] then
        clean.target = step.target
    end
    if isWholeNumber(step.every) and step.every >= 2 and step.every <= SS.MAX_EVERY then
        clean.every = step.every
    end
    if type(step.mods) == "table" then
        for _, mod in ipairs(MOD_KEYS) do
            local modEntry = sanitizeEntry(step.mods[mod], false)
            if modEntry then
                clean.mods[mod] = modEntry
            end
        end
    end
    return clean
end

local function sanitizeList(list, max, sanitizer)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    for i = 1, #list do
        if #out >= max then break end
        local item = sanitizer(list[i])
        if item then
            out[#out + 1] = item
        end
    end
    return out
end

-- Returns a clean sequence body (no id/key/macroName) or nil, reason.
function Database:SanitizeSequence(raw)
    if type(raw) ~= "table" then
        return nil, "That is not a sequence."
    end
    local seq = {
        name = cleanString(raw.name, MAX_NAME) or "Imported sequence",
        opener = sanitizeList(raw.opener, SS.MAX_STEPS, sanitizeStep),
        loop = sanitizeList(raw.loop, SS.MAX_STEPS, sanitizeStep),
        extras = sanitizeList(raw.extras, SS.MAX_EXTRAS, function(e) return sanitizeEntry(e, false) end),
        startAttack = raw.startAttack == true,
        autoTarget = raw.autoTarget ~= false,
        priority = sanitizeList(raw.priority, SS.MAX_PRIORITY, function(e) return sanitizeEntry(e, false) end),
        reset = { combat = true, target = false },
    }
    if seq.name == "" then
        seq.name = "Imported sequence"
    end
    if isWholeNumber(raw.icon) then
        seq.icon = raw.icon
    end
    if type(raw.reset) == "table" then
        seq.reset.combat = raw.reset.combat ~= false
        seq.reset.target = raw.reset.target == true
    end
    return seq
end

local function newSequenceBody(name)
    return {
        name = name or "New sequence",
        opener = {},
        loop = {},
        extras = {},
        startAttack = false,
        autoTarget = true,
        priority = {},
        reset = { combat = true, target = false },
    }
end

local function normalizeSequence(seq, id)
    seq.id = id
    seq.specID = tonumber(seq.specID) or 0
    seq.name = cleanString(seq.name, MAX_NAME) or "Sequence"
    seq.opener = type(seq.opener) == "table" and seq.opener or {}
    seq.loop = type(seq.loop) == "table" and seq.loop or {}
    seq.extras = type(seq.extras) == "table" and seq.extras or {}
    seq.reset = type(seq.reset) == "table" and seq.reset or {}
    if seq.reset.combat == nil then seq.reset.combat = true end
    seq.startAttack = seq.startAttack == true
    seq.autoTarget = seq.autoTarget ~= false
    seq.priority = type(seq.priority) == "table" and seq.priority or {}
end

function Database:Init()
    if type(_G.SimpleSequenceDB) ~= "table" then
        _G.SimpleSequenceDB = {}
    end
    local db = _G.SimpleSequenceDB
    db.schema = db.schema or 1
    if type(db.specs) ~= "table" then db.specs = {} end
    if type(db.sequences) ~= "table" then db.sequences = {} end
    if type(db.nextUp) ~= "table" then db.nextUp = {} end
    if db.nextUp.shown == nil then db.nextUp.shown = true end
    db.nextUp.scale = tonumber(db.nextUp.scale) or 1
    if type(db.window) ~= "table" then db.window = {} end
    db.lastBackup = tonumber(db.lastBackup) or 0
    if type(db.characters) ~= "table" then db.characters = {} end

    for id, seq in pairs(db.sequences) do
        if type(seq) ~= "table" then
            db.sequences[id] = nil
        else
            normalizeSequence(seq, id)
        end
    end
    for specID, spec in pairs(db.specs) do
        if type(spec) ~= "table" then
            db.specs[specID] = nil
        else
            spec.order = type(spec.order) == "table" and spec.order or {}
            for i = #spec.order, 1, -1 do
                if not db.sequences[spec.order[i]] then
                    table.remove(spec.order, i)
                end
            end
            if spec.selected and not db.sequences[spec.selected] then
                spec.selected = nil
            end
        end
    end
    SS.db = db
end

function Database:NoteCharacter()
    if not SS.db then return end
    local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
    if name then
        SS.db.characters[name .. "-" .. (realm or "")] = true
    end
end

SS:On("LOGIN", function()
    Database:NoteCharacter()
end)

function Database:NewID()
    local sequences = SS.db.sequences
    local id
    repeat
        id = string.format("%06x", math.random(0, 0xFFFFFF))
    until not sequences[id]
    return id
end

local function ensureSpec(specID)
    local specs = SS.db.specs
    local spec = specs[specID]
    if not spec then
        spec = { order = {} }
        specs[specID] = spec
    end
    return spec
end

function Database:GetSequence(id)
    return id and SS.db.sequences[id] or nil
end

function Database:GetOrder(specID)
    return ensureSpec(specID).order
end

function Database:GetSequences(specID)
    local out = {}
    local sequences = SS.db.sequences
    for _, id in ipairs(ensureSpec(specID).order) do
        local seq = sequences[id]
        if seq then
            out[#out + 1] = seq
        end
    end
    return out
end

function Database:GetSelected(specID)
    local spec = ensureSpec(specID)
    if spec.selected and SS.db.sequences[spec.selected] then
        return spec.selected
    end
    return nil
end

function Database:SetSelected(specID, id)
    local spec = ensureSpec(specID)
    if spec.selected == id then return end
    spec.selected = id
    SS:Fire("SELECTION_CHANGED", specID, id)
end

function Database:CountAll()
    local n = 0
    for _ in pairs(SS.db.sequences) do
        n = n + 1
    end
    return n
end

-- Undo: one snapshot holds the spec's order/selection plus a copy of every sequence the operation touches.
local function snapshot(specID, label, ids)
    local spec = ensureSpec(specID)
    local snap = {
        specID = specID,
        label = label,
        order = deepCopy(spec.order),
        selected = spec.selected,
        seqs = {},
    }
    for _, id in ipairs(ids) do
        local seq = SS.db.sequences[id]
        snap.seqs[id] = seq and deepCopy(seq) or false
    end
    undoStack[#undoStack + 1] = snap
    if #undoStack > UNDO_LIMIT then
        table.remove(undoStack, 1)
    end
    SS:Fire("UNDO_CHANGED", true)
    return snap
end

local function dropSnapshot(snap)
    if undoStack[#undoStack] == snap then
        undoStack[#undoStack] = nil
        SS:Fire("UNDO_CHANGED", #undoStack > 0)
    end
end

function Database:CanUndo()
    return #undoStack > 0
end

function Database:Undo()
    local snap = undoStack[#undoStack]
    if not snap then
        return false
    end
    undoStack[#undoStack] = nil
    local specID = snap.specID
    local spec = ensureSpec(specID)
    local sequences = SS.db.sequences

    local listChanged = #spec.order ~= #snap.order
    if not listChanged then
        for i = 1, #snap.order do
            if spec.order[i] ~= snap.order[i] then
                listChanged = true
                break
            end
        end
    end

    local updated, deleted = {}, {}
    for id, copy in pairs(snap.seqs) do
        if copy then
            sequences[id] = deepCopy(copy)
            updated[#updated + 1] = id
        else
            local current = sequences[id]
            if current then
                deleted[#deleted + 1] = { id = id, seq = deepCopy(current) }
                sequences[id] = nil
            end
        end
    end
    spec.order = deepCopy(snap.order)
    local selectionChanged = spec.selected ~= snap.selected
    spec.selected = snap.selected

    for _, gone in ipairs(deleted) do
        SS:Fire("SEQUENCE_DELETED", gone.id, gone.seq)
    end
    if listChanged or #deleted > 0 then
        SS:Fire("SEQUENCES_CHANGED", specID)
    end
    for _, id in ipairs(updated) do
        SS:Fire("SEQUENCE_UPDATED", id)
    end
    if selectionChanged then
        SS:Fire("SELECTION_CHANGED", specID, spec.selected)
    end
    SS:Fire("UNDO_CHANGED", #undoStack > 0)
    return true
end

function Database:ClearUndo()
    undoStack = {}
    SS:Fire("UNDO_CHANGED", false)
end

local function clampSequence(seq)
    for _, key in ipairs({ "opener", "loop" }) do
        local list = seq[key]
        for i = #list, SS.MAX_STEPS + 1, -1 do
            list[i] = nil
        end
    end
    for i = #seq.extras, SS.MAX_EXTRAS + 1, -1 do
        seq.extras[i] = nil
    end
    if type(seq.name) ~= "string" or seq.name == "" then
        seq.name = "Sequence"
    end
    if #seq.name > MAX_NAME then
        seq.name = seq.name:sub(1, MAX_NAME)
    end
end

-- fn may return false to cancel (nothing is recorded or fired).
function Database:Update(id, fn, label)
    local seq = self:GetSequence(id)
    if not seq then
        return false
    end
    local snap = snapshot(seq.specID, label or "Edit", { id })
    if fn(seq) == false then
        dropSnapshot(snap)
        return false
    end
    clampSequence(seq)
    SS:Fire("SEQUENCE_UPDATED", id)
    return true
end

local function addToSpec(specID, seq, afterId)
    local spec = ensureSpec(specID)
    local position = #spec.order + 1
    if afterId then
        for i, existing in ipairs(spec.order) do
            if existing == afterId then
                position = i + 1
                break
            end
        end
    end
    table.insert(spec.order, position, seq.id)
    SS.db.sequences[seq.id] = seq
    spec.selected = seq.id
end

local function announceNew(specID, id)
    SS:Fire("SEQUENCES_CHANGED", specID)
    SS:Fire("SELECTION_CHANGED", specID, id)
end

function Database:Create(specID, name)
    local id = self:NewID()
    snapshot(specID, "Create", { id })
    local seq = newSequenceBody(name)
    seq.id = id
    seq.specID = specID
    addToSpec(specID, seq)
    announceNew(specID, id)
    return seq
end

function Database:Duplicate(id)
    local source = self:GetSequence(id)
    if not source then return nil end
    local newId = self:NewID()
    snapshot(source.specID, "Duplicate", { newId })
    local seq = deepCopy(source)
    seq.id = newId
    seq.name = cleanString(source.name .. " copy", MAX_NAME)
    seq.key = nil
    seq.macroName = nil
    addToSpec(source.specID, seq, id)
    announceNew(source.specID, newId)
    return seq
end

function Database:Delete(id)
    local seq = self:GetSequence(id)
    if not seq then return false end
    local specID = seq.specID
    local spec = ensureSpec(specID)
    snapshot(specID, "Delete", { id })
    local copy = deepCopy(seq)
    local position
    for i, existing in ipairs(spec.order) do
        if existing == id then
            position = i
            break
        end
    end
    if position then
        table.remove(spec.order, position)
    end
    SS.db.sequences[id] = nil
    local selectionChanged = spec.selected == id
    if selectionChanged then
        spec.selected = spec.order[clampIndex(position or 1, 1, math.max(#spec.order, 1))]
    end
    SS:Fire("SEQUENCE_DELETED", id, copy)
    SS:Fire("SEQUENCES_CHANGED", specID)
    if selectionChanged then
        SS:Fire("SELECTION_CHANGED", specID, spec.selected)
    end
    return true
end

function Database:Rename(id, name)
    name = cleanString(name, MAX_NAME)
    if not name or name == "" then return false end
    return self:Update(id, function(seq)
        if seq.name == name then return false end
        seq.name = name
    end, "Rename")
end

function Database:MoveInList(specID, fromIndex, toIndex)
    local spec = ensureSpec(specID)
    local n = #spec.order
    if fromIndex < 1 or fromIndex > n then return false end
    toIndex = clampIndex(toIndex, 1, n)
    if fromIndex == toIndex then return false end
    snapshot(specID, "Move", {})
    local id = table.remove(spec.order, fromIndex)
    table.insert(spec.order, toIndex, id)
    SS:Fire("SEQUENCES_CHANGED", specID)
    return true
end

local function newStep(entry)
    return { entry = deepCopy(entry), target = "target", mods = {} }
end

local function isSection(section)
    return section == "opener" or section == "loop"
end

function Database:InsertStep(id, section, index, entry)
    if not isSection(section) then return false end
    local clean = sanitizeEntry(entry, true)
    if not clean then return false end
    return self:Update(id, function(seq)
        local list = seq[section]
        if #list >= SS.MAX_STEPS then return false end
        table.insert(list, clampIndex(index or #list + 1, 1, #list + 1), newStep(clean))
    end, "Add step")
end

function Database:RemoveStep(id, section, index)
    if not isSection(section) then return false end
    return self:Update(id, function(seq)
        if not seq[section][index] then return false end
        table.remove(seq[section], index)
    end, "Remove step")
end

function Database:MoveStep(id, fromSection, fromIndex, toSection, toIndex)
    if not isSection(fromSection) or not isSection(toSection) then return false end
    return self:Update(id, function(seq)
        local from, to = seq[fromSection], seq[toSection]
        if not from[fromIndex] then return false end
        if from ~= to and #to >= SS.MAX_STEPS then return false end
        local step = table.remove(from, fromIndex)
        table.insert(to, clampIndex(toIndex or #to + 1, 1, #to + 1), step)
    end, "Move step")
end

function Database:SetStepTarget(id, section, index, target)
    if not isSection(section) or not TARGETS[target] then return false end
    return self:Update(id, function(seq)
        local step = seq[section][index]
        if not step or step.target == target then return false end
        step.target = target
    end, "Change target")
end

function Database:SetStepEvery(id, section, index, every)
    if section ~= "loop" then return false end
    if every == 1 then every = nil end
    if every ~= nil and not (isWholeNumber(every) and every >= 2 and every <= SS.MAX_EVERY) then return false end
    return self:Update(id, function(seq)
        local step = seq.loop[index]
        if not step or step.every == every then return false end
        step.every = every
    end, "Change how often")
end

function Database:SetStepMod(id, section, index, mod, entry)
    if not isSection(section) then return false end
    if mod ~= "shift" and mod ~= "ctrl" and mod ~= "alt" then return false end
    local clean
    if entry ~= nil then
        clean = sanitizeEntry(entry, false)
        if not clean then return false end
    end
    return self:Update(id, function(seq)
        local step = seq[section][index]
        if not step then return false end
        step.mods = step.mods or {}
        step.mods[mod] = clean
    end, "Change modifier")
end

function Database:InsertExtra(id, index, entry)
    local clean = sanitizeEntry(entry, false)
    if not clean then return false end
    return self:Update(id, function(seq)
        if #seq.extras >= SS.MAX_EXTRAS then return false end
        table.insert(seq.extras, clampIndex(index or #seq.extras + 1, 1, #seq.extras + 1), clean)
    end, "Add extra")
end

function Database:RemoveExtra(id, index)
    return self:Update(id, function(seq)
        if not seq.extras[index] then return false end
        table.remove(seq.extras, index)
    end, "Remove extra")
end

function Database:MoveExtra(id, from, to)
    return self:Update(id, function(seq)
        if not seq.extras[from] then return false end
        local item = table.remove(seq.extras, from)
        table.insert(seq.extras, clampIndex(to, 1, #seq.extras + 1), item)
    end, "Move extra")
end

-- Moves between a step list (opener/loop) and the every-press extras.
-- Returns false, reason when refused.
function Database:MoveAcross(id, fromSection, fromIndex, toSection, toIndex)
    local toExtras = toSection == "extras"
    if toExtras == (fromSection == "extras") then return false end
    if not toExtras and not isSection(toSection) then return false end
    if toExtras and not isSection(fromSection) then return false end
    local reason
    local ok = self:Update(id, function(seq)
        if toExtras then
            local step = seq[fromSection][fromIndex]
            if not step then return false end
            local clean = sanitizeEntry(step.entry, false)
            if not clean then
                reason = "emote"
                return false
            end
            if #seq.extras >= SS.MAX_EXTRAS then
                reason = "full"
                return false
            end
            table.remove(seq[fromSection], fromIndex)
            table.insert(seq.extras, clampIndex(toIndex or #seq.extras + 1, 1, #seq.extras + 1), clean)
        else
            local entry = seq.extras[fromIndex]
            if not entry then return false end
            local list = seq[toSection]
            if #list >= SS.MAX_STEPS then
                reason = "full"
                return false
            end
            table.remove(seq.extras, fromIndex)
            table.insert(list, clampIndex(toIndex or #list + 1, 1, #list + 1), newStep(entry))
        end
    end, "Move step")
    return ok, reason
end

function Database:SetPriority(id, entries)
    if type(entries) ~= "table" then return false end
    local clean = {}
    for _, entry in ipairs(entries) do
        local item = sanitizeEntry(entry, false)
        if item and #clean < SS.MAX_PRIORITY then clean[#clean + 1] = item end
    end
    return self:Update(id, function(seq)
        local old = seq.priority or {}
        local same = #old == #clean
        for i = 1, #clean do
            if not same then break end
            same = old[i].kind == clean[i].kind and old[i].id == clean[i].id
        end
        if same then return false end
        seq.priority = clean
    end, "Change priority")
end

function Database:ApplyBuild(id, plan)
    if type(plan) ~= "table" or not plan.ok then return false end
    local function steps(list, max)
        local out = {}
        for _, entry in ipairs(list or {}) do
            local clean = sanitizeEntry(entry, false)
            if clean and #out < max then out[#out + 1] = newStep(clean) end
        end
        return out
    end
    local opener, loop = steps(plan.opener, SS.MAX_STEPS), steps(plan.loop, SS.MAX_STEPS)
    if #loop == 0 then return false end
    local extras = {}
    for _, entry in ipairs(plan.extras or {}) do
        local clean = sanitizeEntry(entry, false)
        if clean and #extras < SS.MAX_EXTRAS then extras[#extras + 1] = clean end
    end
    local autoAttack = plan.autoAttack == true
    return self:Update(id, function(seq)
        seq.opener, seq.loop, seq.extras = opener, loop, extras
        if autoAttack then seq.startAttack = true end
    end, "Build sequence")
end

function Database:SetFlag(id, path, value)
    value = value and true or false
    return self:Update(id, function(seq)
        if path == "startAttack" or path == "autoTarget" then
            if seq[path] == value then return false end
            seq[path] = value
        elseif path == "reset.combat" or path == "reset.target" then
            local field = path:sub(7)
            if seq.reset[field] == value then return false end
            seq.reset[field] = value
        else
            return false
        end
    end, "Change option")
end

function Database:SetIcon(id, fileID)
    if fileID ~= nil and not isWholeNumber(fileID) then return false end
    return self:Update(id, function(seq)
        if seq.icon == fileID then return false end
        seq.icon = fileID
    end, "Change icon")
end

function Database:SetKeyRaw(id, key)
    if key ~= nil and (type(key) ~= "string" or key == "" or #key > 64) then return false end
    return self:Update(id, function(seq)
        if seq.key == key then return false end
        seq.key = key
    end, "Change key")
end

function Database:Import(specID, raw)
    local body, err = self:SanitizeSequence(raw)
    if not body then
        return nil, err
    end
    local id = self:NewID()
    snapshot(specID, "Import", { id })
    body.id = id
    body.specID = specID
    addToSpec(specID, body)
    announceNew(specID, id)
    return body
end
