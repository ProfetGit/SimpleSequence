local _, SS = ...

local Share = {}
SS.Share = Share

local PREFIX = "SSEQ1:"
local MAX_TEXT = 400000
local MAX_RAW = 1000000
local MAX_ALL = 200
local BAD_STRING = "That does not look like a SimpleSequence string. Copy the whole text, starting with " .. PREFIX

local function exportBody(seq)
    local copy = SS.Database.DeepCopy(seq)
    copy.id = nil
    copy.key = nil
    copy.macroName = nil
    return copy
end

local function encode(payload)
    local ok, result = pcall(function()
        local cbor = C_EncodingUtil.SerializeCBOR(payload)
        local packed = C_EncodingUtil.CompressString(cbor)
        return PREFIX .. C_EncodingUtil.EncodeBase64(packed)
    end)
    if not ok or type(result) ~= "string" then
        return nil, "Could not create the share string."
    end
    return result
end

function Share:Export(id)
    local seq = SS.Database:GetSequence(id)
    if not seq then
        return nil, "That sequence no longer exists."
    end
    return encode({ v = 1, seq = exportBody(seq) })
end

function Share:ExportAll()
    local all = {}
    for _, specID in ipairs(self:SortedSpecIDs()) do
        for _, seq in ipairs(SS.Database:GetSequences(specID)) do
            local body = exportBody(seq)
            body.specID = seq.specID
            all[#all + 1] = body
        end
    end
    local text, err = encode({ v = 1, all = all })
    if text then
        SS.db.lastBackup = time()
    end
    return text, err
end

function Share:SortedSpecIDs()
    local ids = {}
    for specID in pairs(SS.db.specs) do
        ids[#ids + 1] = specID
    end
    table.sort(ids)
    return ids
end

-- Returns { sequences = {clean...}, specs = {specID|nil...}, isBackup = bool } or nil, message.
local function decodeUnsafe(text)
    if type(text) ~= "string" then
        return nil, BAD_STRING
    end
    text = text:gsub("%s+", "")
    if #text > MAX_TEXT or text:sub(1, #PREFIX) ~= PREFIX then
        return nil, BAD_STRING
    end
    local ok, raw = pcall(function()
        local packed = C_EncodingUtil.DecodeBase64(text:sub(#PREFIX + 1))
        local cbor = C_EncodingUtil.DecompressString(packed)
        if type(cbor) ~= "string" or #cbor > MAX_RAW then
            return nil
        end
        return C_EncodingUtil.DeserializeCBOR(cbor)
    end)
    if not ok or type(raw) ~= "table" then
        return nil, "That string is damaged or incomplete. Copy it again."
    end
    if raw.v ~= 1 then
        return nil, "That string was made by a different version of SimpleSequence."
    end

    local payload = { sequences = {}, specs = {}, isBackup = false }
    local function take(item)
        local clean = SS.Database:SanitizeSequence(item)
        if clean then
            payload.sequences[#payload.sequences + 1] = clean
            local specID = type(item) == "table" and item.specID
            if type(specID) == "number" and specID >= 0 and specID == math.floor(specID) then
                payload.specs[#payload.sequences] = specID
            end
        end
    end

    if type(raw.seq) == "table" then
        take(raw.seq)
    elseif type(raw.all) == "table" then
        payload.isBackup = true
        for i = 1, math.min(#raw.all, MAX_ALL) do
            take(raw.all[i])
        end
    end
    if #payload.sequences == 0 then
        return nil, "That string does not contain any sequences."
    end
    return payload
end

function Share:Decode(text)
    local ok, payload, err = pcall(decodeUnsafe, text)
    if not ok then
        return nil, BAD_STRING
    end
    return payload, err
end

local function collectUnknown(seq, unknown, seen)
    local function check(entry)
        if entry and (entry.kind == "spell" or entry.kind == "pet") and not seen[entry.id] then
            local bank = entry.kind == "pet" and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
            if not C_SpellBook.IsSpellKnownOrInSpellBook(entry.id, bank) then
                seen[entry.id] = true
                unknown[#unknown + 1] = C_Spell.GetSpellName(entry.id) or ("spell " .. entry.id)
            end
        end
    end
    for _, section in ipairs({ seq.opener, seq.loop }) do
        for _, step in ipairs(section) do
            check(step.entry)
            for _, modEntry in pairs(step.mods) do
                check(modEntry)
            end
        end
    end
    for _, extra in ipairs(seq.extras) do
        check(extra)
    end
end

function Share:Preview(payload)
    local lines, unknown, seen = {}, {}, {}
    for _, seq in ipairs(payload.sequences) do
        local before = #unknown
        collectUnknown(seq, unknown, seen)
        local line = seq.name .. " \226\128\148 " .. #seq.opener .. " opener, " .. #seq.loop .. " loop"
        local missing = #unknown - before
        if missing > 0 then
            local names = {}
            for i = before + 1, #unknown do
                names[#names + 1] = unknown[i]
            end
            line = line .. " \226\128\148 " .. missing .. (missing == 1 and " spell" or " spells")
                .. " you don't know: " .. table.concat(names, ", ")
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n"), unknown
end

function Share:Import(text)
    local payload, err = self:Decode(text)
    if not payload then
        return nil, err
    end
    local imported = {}
    for i, clean in ipairs(payload.sequences) do
        local specID = SS.currentSpec
        if payload.isBackup and payload.specs[i] then
            specID = payload.specs[i]
        end
        local seq = SS.Database:Import(specID, clean)
        if seq then
            imported[#imported + 1] = seq
        end
    end
    if #imported == 0 then
        return nil, "Nothing could be imported."
    end
    return imported
end
