local _, SS = ...

local Builder = {}
SS.Builder = Builder

local EPS = 1e-6
local BASE_GCD_MS, MIN_GCD = 1500, 0.75
local LONG_COOLDOWN_SLOTS = 32
local ROUNDING = {
    nice = { 1, 2, 3, 4, 6, 8, 12, 16, 24, 32 },
    coarse = { 1, 2, 4, 8, 16, 32 },
}

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return plain(a), plain(b)
end

local function ordinal(n)
    local lastTwo, last = n % 100, n % 10
    if lastTwo >= 11 and lastTwo <= 13 then return n .. "th" end
    if last == 1 then return n .. "st" end
    if last == 2 then return n .. "nd" end
    if last == 3 then return n .. "rd" end
    return n .. "th"
end
Builder.Ordinal = ordinal

local function seconds(value)
    if value == math.floor(value) then
        return tostring(value)
    end
    return string.format("%.1f", value)
end

local function slots(time, gcd)
    if not time or time <= 0 then return 0 end
    return math.ceil(time / gcd - EPS)
end

local function roundUp(n, steps)
    for _, v in ipairs(steps) do
        if v >= n then return v end
    end
    return n
end

local function roundDown(n, steps)
    local best = 1
    for _, v in ipairs(steps) do
        if v <= n then best = v end
    end
    return best
end

-- Simulates a fight in global-cooldown slots with every cooldown ready and no
-- buff up at the start. spells, in priority order:
--   { cooldown = s, charges = n, castTime = s }      a spell
--   buff = s                                          kept up: recast before it runs out
--   offGCD = true                                     fires on any press when ready
--   requires = i, consumes = i                        needs buff i up, and ends it
-- Each press first fires the off-GCD spells that are ready, then casts a missing
-- buff, else the most important ready spell, else waits for the first one back.
-- When the state repeats, the presses before the first repeat are the opener
-- and the presses between the repeats the loop.
function Builder.Simulate(spells, gcd, round)
    local n = #spells
    local castSlots, recharge, maxCharges, charges, remaining = {}, {}, {}, {}, {}
    local steps = round and (ROUNDING[round] or ROUNDING.nice)
    for i, spell in ipairs(spells) do
        local castTime = spell.castTime or 0
        castSlots[i] = spell.offGCD and 0 or math.max(1, slots(castTime, gcd))
        local r
        if spell.buff then
            r = math.max(1, math.floor(spell.buff / gcd - EPS))
            if steps then r = roundDown(r, steps) end
        else
            local cooldown = spell.cooldown or 0
            r = cooldown > 0 and slots(castTime + cooldown, gcd) or 0
            if r > 0 and r < castSlots[i] then r = castSlots[i] end
            if steps and r > 0 then r = roundUp(r, steps) end
        end
        recharge[i] = r
        maxCharges[i] = spell.buff and 1 or math.max(1, math.floor(spell.charges or 1))
        charges[i] = maxCharges[i]
        remaining[i] = 0
    end

    local function advance(k)
        for i = 1, n do
            local left = k
            while left > 0 and remaining[i] > 0 do
                if remaining[i] <= left then
                    left = left - remaining[i]
                    charges[i] = charges[i] + 1
                    remaining[i] = charges[i] < maxCharges[i] and recharge[i] or 0
                else
                    remaining[i] = remaining[i] - left
                    left = 0
                end
            end
        end
    end

    local function buffUp(i)
        return charges[i] == 0
    end

    local function ready(i)
        if recharge[i] ~= 0 and charges[i] < 1 then return false end
        local need = spells[i].requires
        return need == nil or buffUp(need)
    end

    local function use(i)
        if recharge[i] > 0 then
            charges[i] = charges[i] - 1
            if remaining[i] == 0 then remaining[i] = recharge[i] end
        end
        local gone = spells[i].consumes
        if gone and buffUp(gone) then
            charges[gone], remaining[gone] = 1, 0
        end
    end

    local function fireOffGCD()
        for i = 1, n do
            if spells[i].offGCD and ready(i) then use(i) end
        end
    end

    local function pickMain()
        for i = 1, n do
            if spells[i].buff and not spells[i].offGCD and ready(i) then return i end
        end
        for i = 1, n do
            if not spells[i].offGCD and ready(i) then return i end
        end
        return nil
    end

    local order, seen, waits = {}, {}, {}
    local parts = {}
    for press = 1, SS.MAX_STEPS * 2 + 1 do
        for i = 1, n do parts[i] = charges[i] .. ":" .. remaining[i] end
        local key = table.concat(parts, ",")
        if seen[key] then
            return {
                order = order, waits = waits, loopStart = seen[key], count = press - 1,
                recharge = recharge, rounded = steps ~= nil,
            }
        end
        seen[key] = press

        local waited = 0
        fireOffGCD()
        local pick = pickMain()
        while not pick do
            local soonest
            for i = 1, n do
                if remaining[i] > 0 and (not soonest or remaining[i] < remaining[soonest]) then soonest = i end
            end
            if not soonest then return nil end
            waited = waited + remaining[soonest]
            advance(remaining[soonest])
            fireOffGCD()
            pick = pickMain()
        end
        order[press] = pick
        waits[press] = waited
        use(pick)
        advance(castSlots[pick])
    end
    return nil
end

local function fits(result)
    if not result then return false end
    local openerLength = result.loopStart - 1
    local loopLength = result.count - openerLength
    return openerLength <= SS.MAX_STEPS and loopLength >= 1 and loopLength <= SS.MAX_STEPS
end

function Builder:GetGCD(baseMS)
    baseMS = baseMS or BASE_GCD_MS
    if baseMS < BASE_GCD_MS then
        return baseMS / 1000
    end
    local haste = call(UnitSpellHaste, "player") or 0
    return math.max(MIN_GCD, (baseMS / 1000) / (1 + haste / 100))
end

local UNIT_SECONDS = { sec = 1, min = 60, hour = 3600, hr = 3600 }

-- "Lasts 30 sec." / "for 2 min" in a tooltip: how long a buff stays up.
local function durationIn(description)
    if not description then return nil end
    local text = description:lower()
    for word, amount, unit in text:gmatch("(%a+) (%d+%.?%d*) (%a+)") do
        if word == "for" or word == "lasts" then
            for prefix, factor in pairs(UNIT_SECONDS) do
                if unit:sub(1, #prefix) == prefix then
                    return tonumber(amount) * factor
                end
            end
        end
    end
    return nil
end
Builder.DurationIn = durationIn

local function timeText(value)
    if value >= 120 and value % 60 == 0 then return (value / 60) .. " min" end
    return seconds(value) .. " s"
end

local function describeTiming(info)
    local parts = {}
    if info.charges and info.charges > 1 then
        parts[#parts + 1] = info.charges .. " charges, " .. seconds(info.cooldown) .. " s each"
    elseif info.cooldown > 0 then
        parts[#parts + 1] = seconds(info.cooldown) .. " s cooldown"
    else
        parts[#parts + 1] = "No cooldown"
    end
    if info.castTime > 0 then
        parts[#parts + 1] = seconds(info.castTime) .. " s cast"
    else
        parts[#parts + 1] = "instant"
    end
    return table.concat(parts, " \194\183 ")
end

-- Reads what the builder needs about one entry. Out of combat only.
function Builder:ReadEntry(entry)
    if type(entry) ~= "table" then return nil, "Unknown spell" end
    local kind, id = entry.kind, entry.id
    if kind == "emote" then return nil, "Emotes can't be planned" end
    local name = SS.Compiler.EntryName(entry)
    local info = {
        entry = entry, name = name or tostring(id), icon = SS.Compiler.EntryIcon(entry),
        cooldown = 0, charges = 1, castTime = 0, gcdMS = BASE_GCD_MS,
    }
    if kind == "item" or kind == "slot" then
        local itemID = kind == "item" and id or call(GetInventoryItemID, "player", id)
        if not itemID then return nil, "Nothing equipped in that slot" end
        local _, spellID = call(C_Item.GetItemSpell, itemID)
        if not spellID then return nil, "This item can't be used" end
        local cooldownMS = call(GetSpellBaseCooldown, spellID)
        info.cooldown = (cooldownMS or 0) / 1000
        info.extra = true
        info.info = (kind == "slot" and "Trinket" or "Item")
            .. (info.cooldown > 0 and (" \194\183 " .. seconds(info.cooldown) .. " s cooldown") or "")
        return info
    end
    if kind ~= "spell" and kind ~= "pet" then return nil, "Unknown spell" end
    if not name then return nil, "You don't know this spell" end
    local cooldownMS, gcdMS = call(GetSpellBaseCooldown, id)
    info.cooldown = (cooldownMS or 0) / 1000
    if gcdMS ~= nil then info.gcdMS = gcdMS end
    local chargeInfo = call(C_Spell.GetSpellCharges, id)
    if type(chargeInfo) == "table" then
        local maxCharges = plain(chargeInfo.maxCharges)
        local recharge = plain(chargeInfo.cooldownDuration)
        if maxCharges and maxCharges > 1 then
            info.charges = maxCharges
            if recharge and recharge > 0 then info.cooldown = recharge end
        end
    end
    local spellInfo = call(C_Spell.GetSpellInfo, id)
    local maxRange
    if type(spellInfo) == "table" then
        info.castTime = (plain(spellInfo.castTime) or 0) / 1000
        maxRange = plain(spellInfo.maxRange)
    end
    local description = call(C_Spell.GetSpellDescription, id)
    if type(description) ~= "string" or description == "" then
        call(C_Spell.RequestLoadSpellData, id)
        description = nil
    end
    info.description = description
    local lasts = info.cooldown == 0 and (maxRange or 0) == 0 and durationIn(description)
    if lasts and info.gcdMS ~= 0 then
        info.buff = lasts
        info.info = "No cooldown \194\183 lasts " .. timeText(lasts)
        return info
    end
    if info.gcdMS == 0 then
        info.extra = true
        info.info = "Doesn't use the global cooldown"
            .. (info.cooldown > 0 and (" \194\183 " .. seconds(info.cooldown) .. " s cooldown") or "")
    else
        info.info = describeTiming(info)
    end
    return info
end

local function frequencyNote(occurrences, loopLength, recharge)
    if occurrences == loopLength then return "Every press" end
    if recharge == 0 then return "Fills the gaps" end
    local gap = loopLength / occurrences
    local rounded = math.floor(gap + 0.5)
    if rounded <= 1 then return "Almost every press" end
    if math.abs(gap - rounded) < EPS then
        return "Every " .. ordinal(rounded) .. " press"
    end
    return "About every " .. ordinal(rounded)
end

function Builder:Plan(priority)
    local plan = {
        ok = false, opener = {}, loop = {}, extras = {}, rows = {}, warnings = {},
        summary = "", gcd = BASE_GCD_MS / 1000,
    }
    if InCombatLockdown() then
        plan.error = "Can't read cooldowns during combat. Try again after the fight."
        return plan
    end
    if type(priority) ~= "table" or #priority == 0 then
        plan.error = "Add at least one spell."
        return plan
    end

    local items, seen = {}, {}
    for i, entry in ipairs(priority) do
        local key = type(entry) == "table" and (tostring(entry.kind) .. ":" .. tostring(entry.id)) or "?"
        local info, reason
        if seen[key] then
            reason = "Already higher in the list"
        else
            seen[key] = true
            info, reason = self:ReadEntry(entry)
        end
        local row = {
            entry = entry,
            name = (info and info.name) or SS.Compiler.EntryName(entry) or "Unknown",
            icon = (info and info.icon) or SS.Compiler.EntryIcon(entry),
            info = info and info.info or "",
        }
        plan.rows[i] = row
        if info then
            items[#items + 1] = { info = info, row = row }
        else
            row.role, row.note, row.detail = "error", reason == "Already higher in the list" and "Duplicate" or "Can't plan", reason
        end
    end

    -- An off-GCD spell whose tooltip names a kept-up buff uses it up (Judgement and Seals).
    for _, buff in ipairs(items) do
        local word = buff.info.buff and buff.info.name:match("^(%a+)")
        if word then
            for _, other in ipairs(items) do
                local text = other.info.description
                if other ~= buff and other.info.extra and not other.consumes and text
                    and text:find("%f[%a]" .. word .. "%f[%A]") then
                    other.consumes = buff
                    buff.consumedBy = other
                end
            end
        end
    end

    local baseGCD
    for _, item in ipairs(items) do
        if not item.info.extra and (not baseGCD or item.info.gcdMS > baseGCD) then baseGCD = item.info.gcdMS end
    end
    local gcd = self:GetGCD(baseGCD)
    plan.gcd = gcd

    local sim, simIndex, openerOnly = {}, {}, {}
    local function addExtra(item, detail)
        if #plan.extras < SS.MAX_EXTRAS then
            plan.extras[#plan.extras + 1] = item.info.entry
            item.row.role, item.row.note, item.row.detail = "extras", "Every press", detail
            return true
        end
        item.row.role, item.row.note = "unused", "Not used"
        item.row.detail = "Every press is full (" .. SS.MAX_EXTRAS .. " spells)."
        return false
    end
    for _, item in ipairs(items) do
        local info = item.info
        if info.buff then
            if not item.consumedBy and math.floor(info.buff / gcd) > LONG_COOLDOWN_SLOTS then
                openerOnly[#openerOnly + 1] = item
                item.row.role, item.row.note = "opener", "Start of fight"
                item.row.detail = "Lasts " .. timeText(info.buff) .. ", so it's cast once at the start of each fight."
            else
                sim[#sim + 1] = item
            end
        elseif info.extra then
            local detail = "Doesn't use the global cooldown, so it fires on any press when it's ready."
            if item.consumes then
                detail = "Fires on any press when it's ready. It uses up " .. item.consumes.info.name
                    .. ", which is recast right after."
            end
            if addExtra(item, detail) and item.consumes then sim[#sim + 1] = item end
        elseif slots(info.castTime + info.cooldown, gcd) > LONG_COOLDOWN_SLOTS then
            addExtra(item, "Long cooldown, so it fires on any press when it's ready.")
        else
            sim[#sim + 1] = item
        end
    end
    local onGCD = 0
    for _, item in ipairs(sim) do
        if not item.info.extra then onGCD = onGCD + 1 end
    end
    if onGCD == 0 and #openerOnly == 0 then
        plan.error = "Add at least one spell that uses the global cooldown."
        return plan
    end

    local spells = {}
    for i, item in ipairs(sim) do simIndex[item] = i end
    for i, item in ipairs(sim) do
        local info = item.info
        spells[i] = {
            cooldown = info.cooldown, charges = info.charges, castTime = info.castTime,
            buff = info.buff, offGCD = info.extra or nil,
            requires = item.consumes and simIndex[item.consumes] or nil,
            consumes = item.consumes and simIndex[item.consumes] or nil,
        }
    end

    for _, item in ipairs(openerOnly) do
        plan.opener[#plan.opener + 1] = item.info.entry
    end

    local result
    if onGCD > 0 then
        result = Builder.Simulate(spells, gcd, false)
        if not fits(result) then result = Builder.Simulate(spells, gcd, "nice") end
        if not fits(result) then result = Builder.Simulate(spells, gcd, "coarse") end
        if not fits(result) or #plan.opener + result.loopStart - 1 > SS.MAX_STEPS then
            plan.error = "These cooldowns don't line up into a loop of " .. SS.MAX_STEPS
                .. " presses or fewer. Remove a spell or two."
            return plan
        end
    else
        plan.error = "Add a spell to cast between your buffs."
        return plan
    end

    local occurrences, total, waited = {}, {}, false
    for press, index in ipairs(result.order) do
        local entry = sim[index].info.entry
        total[index] = (total[index] or 0) + 1
        if press < result.loopStart then
            plan.opener[#plan.opener + 1] = entry
        else
            plan.loop[#plan.loop + 1] = entry
            occurrences[index] = (occurrences[index] or 0) + 1
            if result.waits[press] > 0 then waited = true end
        end
    end
    local loopLength = #plan.loop
    for index, item in ipairs(sim) do
        local info = item.info
        local recharge = result.recharge[index]
        if not info.extra then
            local count = occurrences[index] or 0
            if (total[index] or 0) == 0 then
                item.row.role, item.row.note = "unused", "Never cast"
                item.row.detail = "A spell above it is always ready. Move this one higher."
            elseif info.buff then
                item.row.role, item.row.note = "loop", "Kept up"
                if item.consumedBy then
                    item.row.detail = "Recast each time " .. item.consumedBy.info.name .. " uses it up."
                elseif count > 0 then
                    item.row.detail = "Recast about every " .. timeText(math.floor(recharge * gcd + 0.5))
                        .. ", before it runs out."
                end
            else
                item.row.role = "loop"
                local note = count > 0 and frequencyNote(count, loopLength, recharge) or "In the opener"
                if result.rounded and recharge > 0 then
                    local exact = slots(info.castTime + info.cooldown, gcd)
                    if exact ~= recharge then item.row.detail = "Rounded slightly so the loop stays short." end
                end
                item.row.note = note
            end
        end
    end

    if waited then
        plan.autoAttack = true
        plan.warnings[#plan.warnings + 1] = "There is nothing to cast between cooldowns, so auto-attack fills the gaps "
            .. "(Start auto-attack is turned on). Press when the next-up icon is ready."
    end
    for _, row in ipairs(plan.rows) do
        if row.role == "unused" and row.note == "Never cast" then
            plan.warnings[#plan.warnings + 1] = row.name .. " never gets cast. Move it above the spells without a cooldown."
        end
    end

    local openerLength = #plan.opener
    if openerLength > 0 then
        plan.summary = "Opener: " .. openerLength .. (openerLength == 1 and " press" or " presses")
            .. " \194\183 Loop: " .. loopLength .. (loopLength == 1 and " press" or " presses") .. ", then repeats"
    else
        plan.summary = "Loop: " .. loopLength .. (loopLength == 1 and " press" or " presses") .. ", then repeats"
    end
    plan.ok = true
    return plan
end

local textTimer

if SS.RegisterGameEvent then
    SS:RegisterGameEvent("SPELL_TEXT_UPDATE", function()
        if textTimer then return end
        textTimer = C_Timer.NewTimer(0.2, function()
            textTimer = nil
            SS:Fire("BUILDER_DATA_CHANGED")
        end)
    end)
end
