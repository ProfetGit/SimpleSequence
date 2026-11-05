local _, SS = ...

local Compiler = {}
SS.Compiler = Compiler

local UNKNOWN_ICON = 134400
local EMOTE_ICON = 132311
local MODS = { "shift", "ctrl", "alt" }
local EVERY_LABEL = { [2] = "every 2nd time", [3] = "every 3rd time", [4] = "every 4th time" }
Compiler.EVERY_LABEL = EVERY_LABEL

local TARGET_CONDITIONS = {
    target = nil,
    player = "@player",
    mouseover = "@mouseover,exists,nodead",
    focus = "@focus,exists,nodead",
}

local function slotLabel(slot)
    if slot == 13 then return "Trinket 1" end
    if slot == 14 then return "Trinket 2" end
    return "Slot " .. tostring(slot)
end

function Compiler.EntryName(entry)
    if type(entry) ~= "table" then return nil end
    local kind, id = entry.kind, entry.id
    if kind == "spell" or kind == "pet" then
        return C_Spell.GetSpellName(id)
    elseif kind == "item" then
        return C_Item.GetItemNameByID(id)
    elseif kind == "slot" then
        return slotLabel(id)
    elseif kind == "emote" then
        return tostring(id)
    end
    return nil
end

function Compiler.EntryIcon(entry)
    if type(entry) ~= "table" then return nil end
    local kind, id = entry.kind, entry.id
    if kind == "spell" or kind == "pet" then
        return (C_Spell.GetSpellTexture(id))
    elseif kind == "item" then
        return C_Item.GetItemIconByID(id)
    elseif kind == "slot" then
        return GetInventoryItemTexture("player", id)
    elseif kind == "emote" then
        return EMOTE_ICON
    end
    return nil
end

local function entryArg(entry)
    local kind, id = entry.kind, entry.id
    if kind == "item" then
        return "item:" .. tostring(id)
    elseif kind == "slot" then
        return tostring(id)
    end
    return C_Spell.GetSpellName(id) or tostring(id)
end

local function verbFor(entries)
    for _, entry in ipairs(entries) do
        if entry.kind == "item" or entry.kind == "slot" then
            return "/use"
        end
    end
    return "/cast"
end

local CASTSEQUENCE = "/castsequence "
local RESET = "reset=combat "

-- A kept-up buff and the off-GCD spell that uses it up: the sequence only moves on
-- when a cast succeeds, so the buff is recast right after the spell, however fast
-- the key is pressed.
local function pairSequence(extra)
    return RESET .. entryArg(extra.buff) .. ", " .. entryArg(extra)
end
Compiler.PairSequence = pairSequence

local function everyPressLines(seq)
    local lines = {}
    if seq.autoTarget then
        lines[#lines + 1] = "/targetenemy [noexists][dead]"
    end
    if seq.startAttack then
        lines[#lines + 1] = "/startattack [harm,nodead]"
    end
    for _, extra in ipairs(seq.extras or {}) do
        if extra.kind ~= "emote" then
            if extra.buff then
                lines[#lines + 1] = CASTSEQUENCE .. pairSequence(extra)
            else
                lines[#lines + 1] = verbFor({ extra }) .. " " .. entryArg(extra)
            end
        end
    end
    return lines
end

function Compiler:StepText(seq, step)
    local entry = step and step.entry
    if not entry then return "" end
    if entry.kind == "emote" then
        return "/" .. tostring(entry.id)
    end

    local lines = everyPressLines(seq)
    local unit = TARGET_CONDITIONS[step.target]
    local fallback = (step.target == "mouseover" or step.target == "focus")
    local used = { entry }
    local clauses = {}
    for _, mod in ipairs(MODS) do
        local modEntry = step.mods and step.mods[mod]
        if modEntry and modEntry.kind ~= "emote" then
            used[#used + 1] = modEntry
            local conditions = "[mod:" .. mod .. (unit and ("," .. unit) or "") .. "]"
            if fallback then
                conditions = conditions .. "[mod:" .. mod .. "]"
            end
            clauses[#clauses + 1] = conditions .. " " .. entryArg(modEntry)
        end
    end

    local main
    if #clauses == 0 then
        if not unit then
            main = entryArg(entry)
        else
            main = "[" .. unit .. "]" .. (fallback and "[]" or "") .. " " .. entryArg(entry)
        end
    else
        local conditions = unit and ("[" .. unit .. "]") or "[]"
        if fallback then
            conditions = conditions .. "[]"
        end
        clauses[#clauses + 1] = conditions .. " " .. entryArg(entry)
        main = table.concat(clauses, "; ")
    end
    lines[#lines + 1] = verbFor(used) .. " " .. main
    return table.concat(lines, "\n")
end

local function gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

function Compiler:Compile(seq)
    local result = { steps = {}, entries = {}, waits = {}, queries = {}, pairs = {}, problems = {}, ok = true }
    local opener, loop = seq.opener or {}, seq.loop or {}

    local function problem(level, text)
        result.problems[#result.problems + 1] = { level = level, text = text }
        if level == "error" then
            result.ok = false
        end
    end

    local function add(step, repeated)
        local n = #result.steps + 1
        local text = self:StepText(seq, step)
        result.steps[n] = text
        result.entries[n] = step.entry
        result.waits[n] = step.waitFor
        if repeated then return end
        local kind = step.entry and step.entry.kind
        if (kind == "spell" or kind == "pet") and not C_Spell.GetSpellName(step.entry.id) then
            problem("warn", "Press " .. n .. ": spell " .. tostring(step.entry.id) .. " was not found.")
        end
        if #text > SS.MAX_STEP_TEXT then
            problem("error", "Press " .. n .. " is too long (" .. #text .. " of " .. SS.MAX_STEP_TEXT .. " characters). Remove extras or modifiers.")
        end
    end

    for _, extra in ipairs(seq.extras or {}) do
        if extra.buff and extra.kind ~= "emote" then
            result.pairs[#result.pairs + 1] = { sequence = pairSequence(extra), buff = extra.buff }
        end
    end

    for _, step in ipairs(opener) do add(step) end
    result.loopStart = #opener + 1
    local rounds, everyTime = 1, false
    for _, step in ipairs(loop) do
        local every = step.every or 1
        if every == 1 then
            everyTime = true
        elseif rounds % every ~= 0 then
            rounds = rounds * every / gcd(rounds, every)
        end
    end
    local unrolled = {}
    for round = 0, rounds - 1 do
        for _, step in ipairs(loop) do
            if round % (step.every or 1) == 0 then unrolled[#unrolled + 1] = { step = step, repeated = round > 0 } end
        end
    end
    local waitEach = seq.spamProof == true and #unrolled > 0
    if waitEach then
        for _, item in ipairs(unrolled) do
            if item.step.entry.kind == "emote" then
                waitEach = false
                problem("warn", "Emotes can't wait for each spell, so the Loop moves on with every press.")
                break
            end
        end
    end
    if waitEach then
        local names, entries, options = {}, {}, false
        for _, item in ipairs(unrolled) do
            local step = item.step
            names[#names + 1] = entryArg(step.entry)
            entries[#entries + 1] = step.entry
            if (step.target and step.target ~= "target") or next(step.mods or {}) then options = true end
            if not item.repeated and (step.entry.kind == "spell" or step.entry.kind == "pet")
                and not C_Spell.GetSpellName(step.entry.id) then
                problem("warn", "Loop: spell " .. tostring(step.entry.id) .. " was not found.")
            end
        end
        local sequence = RESET .. table.concat(names, ", ")
        local line = #names == 1 and (verbFor(entries) .. " " .. names[1]) or (CASTSEQUENCE .. sequence)
        local lines = everyPressLines(seq)
        lines[#lines + 1] = line
        local text = table.concat(lines, "\n")
        local n = #result.steps + 1
        result.steps[n] = text
        result.entries[n] = entries[1]
        if #names > 1 then result.queries[n] = { sequence = sequence, entries = entries } end
        if options then
            problem("warn", "Cast on and Hold-key options in the Loop don't work while it waits for each spell.")
        end
        if #text > SS.MAX_STEP_TEXT then
            problem("error", "The Loop is too long to wait for each spell (" .. #text .. " of " .. SS.MAX_STEP_TEXT
                .. " characters). Remove some spells, or turn off waiting for each spell.")
        end
    else
        for _, item in ipairs(unrolled) do add(item.step, item.repeated) end
    end
    if #loop > 0 and not everyTime then
        problem("warn", "Every Loop spell is set to \"every Nth time\". Set at least one to every time, or the timing has no effect.")
    end
    if #loop == 0 then
        local filler = table.concat(everyPressLines(seq), "\n")
        if filler ~= "" and (#opener > 0 or #(seq.extras or {}) > 0) then
            result.steps[#result.steps + 1] = filler
        elseif #opener > 0 then
            problem("error", "After the opener there is nothing to do. Add a spell to the Loop, or tick Start auto-attack.")
        else
            problem("error", "The loop is empty. Add at least one spell to the loop.")
        end
    end
    result.count = #result.steps
    if result.count > SS.MAX_COMPILED then
        problem("error", "This sequence unrolls to " .. result.count .. " presses (the limit is " .. SS.MAX_COMPILED
            .. "). Use fewer \"every 3rd/4th time\" steps or a shorter loop.")
    end
    return result
end

function Compiler:Describe(seq)
    local opener, loop = seq.opener or {}, seq.loop or {}
    if #loop == 0 and #opener == 0 then
        return "Add a spell to the loop to get started."
    end
    local parts = {}
    local n = 0
    for _, list in ipairs({ opener, loop }) do
        for _, step in ipairs(list) do
            n = n + 1
            local every = list == loop and step.every or 1
            local label = Compiler.EntryName(step.entry) or "Unknown"
            if every > 1 then
                label = label .. " (" .. (EVERY_LABEL[every] or ("every " .. every .. "th time")) .. ")"
            end
            parts[#parts + 1] = "Press " .. n .. ": " .. label
        end
    end
    if #loop == 0 then
        if seq.startAttack then
            parts[#parts + 1] = "then keeps auto-attacking"
        elseif #(seq.extras or {}) > 0 then
            parts[#parts + 1] = "then only the Every press spells"
        end
    elseif seq.spamProof then
        parts[#parts + 1] = "then repeats the Loop, each spell waiting until it's ready"
    elseif #opener > 0 then
        parts[#parts + 1] = "then repeats from Press " .. (#opener + 1)
    else
        parts[#parts + 1] = "then repeats"
    end
    return table.concat(parts, " \194\183 ")
end
