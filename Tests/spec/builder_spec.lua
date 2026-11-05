package.path = "./Tests/spec/helpers/?.lua;" .. package.path
local env = require("env")
local spell = env.spell

describe("Builder", function()
    local SS, B
    local cooldowns, gcds, casts, charges, descriptions, ranges
    local inCombat

    before_each(function()
        SS = env.new({ "Core/Database.lua", "Core/Compiler.lua", "Core/Builder.lua" })
        B = SS.Builder
        cooldowns, gcds, casts, charges, descriptions, ranges = {}, {}, {}, {}, {}, {}
        env.SPELLS[10], env.SPELLS[11], env.SPELLS[12] = "Holy Strike", "Seal of Righteousness", "Judgement"
        env.SPELLS[13], env.SPELLS[14] = "Battle Shout", "Frostbolt"
        inCombat = false
        _G.InCombatLockdown = function() return inCombat end
        _G.UnitSpellHaste = function() return 0 end
        _G.GetSpellBaseCooldown = function(id) return cooldowns[id] or 0, gcds[id] or 1500 end
        _G.C_Spell.GetSpellCharges = function(id)
            if charges[id] then return { maxCharges = charges[id], cooldownDuration = (cooldowns[id] or 0) / 1000 } end
            return nil
        end
        _G.C_Spell.GetSpellInfo = function(id) return { castTime = casts[id] or 0, maxRange = ranges[id] or 0 } end
        _G.C_Spell.GetSpellDescription = function(id) return descriptions[id] or "" end
        _G.C_Item.GetItemSpell = function(id) if id == 100 then return "Drink", 900 end end
    end)

    local function names(result, from, to)
        local out = {}
        for i = from, to do out[#out + 1] = result.order[i] end
        return out
    end

    -- Every spell's casts, laid end to end over two loops, must be at least its recharge apart.
    local function respectsCooldowns(result, spells, gcd)
        local timeline, t = {}, 0
        local order = {}
        for i = 1, result.count do order[#order + 1] = i end
        for i = result.loopStart, result.count do order[#order + 1] = i end
        for _, press in ipairs(order) do
            t = t + result.waits[press]
            local index = result.order[press]
            timeline[#timeline + 1] = { index = index, t = t }
            local castSlots = math.max(1, math.ceil((spells[index].castTime or 0) / gcd - 1e-6))
            t = t + castSlots
        end
        local last = {}
        for _, cast in ipairs(timeline) do
            local r = result.recharge[cast.index]
            if r > 0 and (spells[cast.index].charges or 1) == 1 and last[cast.index] then
                if cast.t - last[cast.index] < r then return false end
            end
            last[cast.index] = cast.t
        end
        return true
    end

    describe("Simulate", function()
        it("a single filler loops every press", function()
            local r = B.Simulate({ { cooldown = 0 } }, 1.5)
            assert.equals(1, r.loopStart)
            assert.equals(1, r.count)
        end)

        it("fits a 10 s cooldown every 7th press", function()
            local spells = { { cooldown = 10 }, { cooldown = 0 } }
            local r = B.Simulate(spells, 1.5)
            assert.equals(1, r.loopStart)
            assert.equals(7, r.count)
            assert.same({ 1, 2, 2, 2, 2, 2, 2 }, names(r, 1, 7))
            assert.is_true(respectsCooldowns(r, spells, 1.5))
        end)

        it("interleaves two cooldowns without breaking either", function()
            local spells = { { cooldown = 6 }, { cooldown = 9 }, { cooldown = 0 } }
            local r = B.Simulate(spells, 1.5)
            assert.truthy(r)
            assert.is_true(respectsCooldowns(r, spells, 1.5))
            assert.equals(1, r.order[1])
            assert.equals(2, r.order[2])
        end)

        it("spends charges in the opener", function()
            local spells = { { cooldown = 6, charges = 2 }, { cooldown = 0 } }
            local r = B.Simulate(spells, 1.5)
            assert.equals(1, r.order[1])
            assert.equals(1, r.order[2])
            assert.is_true(r.loopStart > 1)
        end)

        it("waits when nothing is ready", function()
            local r = B.Simulate({ { cooldown = 3 } }, 1.5)
            assert.equals(1, r.count - r.loopStart + 1)
            local waited = false
            for _, w in ipairs(r.waits) do if w > 0 then waited = true end end
            assert.is_true(waited)
        end)

        it("treats a long cast as several slots", function()
            local spells = { { cooldown = 6 }, { cooldown = 0, castTime = 3 } }
            local r = B.Simulate(spells, 1.5)
            assert.is_true(respectsCooldowns(r, spells, 1.5))
        end)

        it("recasts a kept-up buff just before it runs out", function()
            local r = B.Simulate({ { buff = 30 }, { cooldown = 0 } }, 1.5)
            assert.equals(1, r.order[1])
            local loop = r.count - r.loopStart + 1
            assert.equals(19, loop)
            local buffs = 0
            for i = r.loopStart, r.count do if r.order[i] == 1 then buffs = buffs + 1 end end
            assert.equals(1, buffs)
        end)

        it("recasts a buff right after an off-GCD spell uses it up", function()
            local spells = {
                { cooldown = 10 },
                { buff = 30 },
                { cooldown = 10, offGCD = true, requires = 2, consumes = 2 },
            }
            local r = B.Simulate(spells, 1.5)
            assert.equals(2, r.order[1])
            assert.equals(2, r.order[2])
            local loop = {}
            for i = r.loopStart, r.count do loop[#loop + 1] = r.order[i] end
            assert.same({ 1, 2 }, loop)
            assert.is_true(r.waits[r.count] > 0)
            assert.equals(3, r.gates[r.count])
            assert.is_nil(r.gates[r.loopStart])
        end)

        it("rounding keeps awkward cooldowns short", function()
            local spells = { { cooldown = 7.5 }, { cooldown = 24 }, { cooldown = 0 } }
            local exact = B.Simulate(spells, 1.5, false)
            local rounded = B.Simulate(spells, 1.5, "nice")
            assert.is_true(exact.count - exact.loopStart + 1 > 64)
            assert.is_true(rounded.count - rounded.loopStart + 1 <= 64)
            assert.is_true(rounded.rounded)
            assert.is_true(respectsCooldowns(rounded, spells, 1.5))
        end)
    end)

    describe("Plan", function()
        it("builds a loop with notes from game data", function()
            cooldowns[1] = 10000
            local plan = B:Plan({ spell(1), spell(2) })
            assert.is_true(plan.ok)
            assert.equals(7, #plan.loop)
            assert.equals(0, #plan.opener)
            assert.equals("Every 7th press", plan.rows[1].note)
            assert.equals("Fills the gaps", plan.rows[2].note)
            assert.equals("10 s cooldown \194\183 instant", plan.rows[1].info)
            assert.equals(0, #plan.warnings)
            assert.truthy(plan.summary:find("Loop: 7 spells", 1, true))
            assert.is_true(plan.spamProof)
        end)

        it("sends off-GCD spells and items to every press", function()
            gcds[3] = 0
            cooldowns[3] = 60000
            local plan = B:Plan({ spell(3), { kind = "item", id = 100 }, spell(2) })
            assert.is_true(plan.ok)
            assert.equals(2, #plan.extras)
            assert.equals("extras", plan.rows[1].role)
            assert.equals("extras", plan.rows[2].role)
            assert.same({ spell(2) }, plan.loop)
        end)

        it("flags a cooldown spell below a filler as never cast", function()
            cooldowns[1] = 10000
            local plan = B:Plan({ spell(2), spell(1) })
            assert.is_true(plan.ok)
            assert.equals("unused", plan.rows[2].role)
            assert.equals(1, #plan.warnings)
        end)

        it("warns when there is no filler", function()
            cooldowns[1] = 3000
            local plan = B:Plan({ spell(1) })
            assert.is_true(plan.ok)
            assert.equals(1, #plan.warnings)
        end)

        it("refuses in combat, empty lists and unknown spells", function()
            inCombat = true
            assert.is_false(B:Plan({ spell(1) }).ok)
            inCombat = false
            assert.is_false(B:Plan({}).ok)
            local plan = B:Plan({ spell(999), spell(2) })
            assert.is_true(plan.ok)
            assert.equals("error", plan.rows[1].role)
        end)

        it("ignores a spell listed twice", function()
            cooldowns[1] = 10000
            local plan = B:Plan({ spell(1), spell(2), spell(1) })
            assert.is_true(plan.ok)
            assert.equals("error", plan.rows[3].role)
            assert.equals(7, #plan.loop)
        end)

        it("casts long cooldowns at the start of each fight", function()
            cooldowns[1] = 120000
            local plan = B:Plan({ spell(1), spell(2) })
            assert.is_true(plan.ok)
            assert.same({}, plan.extras)
            assert.same({ spell(1) }, plan.opener)
            assert.equals("opener", plan.rows[1].role)
            assert.same({ spell(2) }, plan.loop)
        end)

        it("reads buff durations from tooltips", function()
            assert.equals(30, B.DurationIn("Fills the Paladin with holy spirit for 30 sec, granting damage."))
            assert.equals(120, B.DurationIn("Increases attack power of party members. Lasts 2 min."))
            assert.equals(600, B.DurationIn("Lasts 10 minutes."))
            assert.is_nil(B.DurationIn("Deals 30 Holy damage."))
            assert.is_nil(B.DurationIn(nil))
        end)

        it("plans the Paladin seal and judgement rotation", function()
            cooldowns[10] = 10000
            descriptions[11] = "Fills the Paladin with holy spirit for 30 sec, granting each melee attack Holy damage."
            gcds[12], cooldowns[12] = 0, 10000
            descriptions[12] = "Unleashes the energy of a Seal spell to judge an enemy for 10 sec."
            local plan = B:Plan({ spell(10), spell(11), spell(12) })
            assert.is_true(plan.ok)
            assert.equals("Kept up", plan.rows[2].note)
            assert.truthy(plan.rows[2].detail:find("each time Judgement uses it up", 1, true))
            assert.equals("No cooldown \194\183 lasts 30 s", plan.rows[2].info)
            assert.equals("extras", plan.rows[2].role)
            assert.equals("extras", plan.rows[3].role)
            assert.equals("Every press", plan.rows[3].note)
            assert.truthy(plan.rows[3].detail:find("Seal of Righteousness is recast", 1, true))
            assert.same({ { kind = "spell", id = 12, buff = spell(11) } }, plan.extras)
            assert.same({ spell(10) }, plan.loop)
            assert.same({}, plan.opener)
            assert.is_true(plan.autoAttack)
            assert.is_true(plan.spamProof)
            assert.equals(1, #plan.warnings)
        end)

        it("casts a long buff once at the start of each fight", function()
            descriptions[13] = "Increases melee attack power of party members. Lasts 2 min."
            local plan = B:Plan({ spell(13), spell(2) })
            assert.is_true(plan.ok)
            assert.equals("opener", plan.rows[1].role)
            assert.same({ spell(13) }, plan.opener)
            assert.same({ spell(2) }, plan.loop)
        end)

        it("does not mistake a ranged spell's effect for a buff", function()
            descriptions[14] = "Launches a bolt of frost. Slows the target for 9 sec."
            ranges[14] = 30
            local plan = B:Plan({ spell(14) })
            assert.is_true(plan.ok)
            assert.equals("Every press", plan.rows[1].note)
        end)

        it("applies haste to the global cooldown", function()
            _G.UnitSpellHaste = function() return 50 end
            assert.equals(1, B:GetGCD(1500))
            _G.UnitSpellHaste = function() return 500 end
            assert.equals(0.75, B:GetGCD(1500))
            assert.equals(1, B:GetGCD(1000))
        end)

        it("writes ordinals", function()
            assert.equals("1st", B.Ordinal(1))
            assert.equals("2nd", B.Ordinal(2))
            assert.equals("3rd", B.Ordinal(3))
            assert.equals("11th", B.Ordinal(11))
            assert.equals("12th", B.Ordinal(12))
            assert.equals("22nd", B.Ordinal(22))
        end)
    end)

    describe("Database", function()
        it("saves the priority list and applies a plan in one undo step", function()
            local DB = SS.Database
            cooldowns[1] = 10000
            local s = DB:Create(63)
            DB:InsertStep(s.id, "loop", nil, spell(5))
            assert.is_true(DB:SetPriority(s.id, { spell(1), spell(2), { kind = "emote", id = "wave" } }))
            assert.equals(2, #DB:GetSequence(s.id).priority)
            assert.is_false(DB:SetPriority(s.id, { spell(1), spell(2) }))
            local plan = B:Plan(DB:GetSequence(s.id).priority)
            assert.is_true(DB:ApplyBuild(s.id, plan))
            s = DB:GetSequence(s.id)
            assert.equals(7, #s.loop)
            assert.equals(1, s.loop[1].entry.id)
            assert.equals("target", s.loop[1].target)
            DB:Undo()
            s = DB:GetSequence(s.id)
            assert.equals(1, #s.loop)
            assert.equals(5, s.loop[1].entry.id)
            assert.is_false(DB:ApplyBuild(s.id, { ok = false }))
        end)

        it("builds the Paladin rotation into one mash-safe press", function()
            local DB = SS.Database
            cooldowns[10] = 10000
            descriptions[11] = "Fills the Paladin with holy spirit for 30 sec."
            gcds[12], cooldowns[12] = 0, 10000
            descriptions[12] = "Unleashes the energy of a Seal spell to judge an enemy for 10 sec."
            local s = DB:Create(63)
            assert.is_true(DB:ApplyBuild(s.id, B:Plan({ spell(10), spell(11), spell(12) })))
            s = DB:GetSequence(s.id)
            assert.is_true(s.spamProof)
            assert.is_true(s.startAttack)
            assert.same(spell(11), s.extras[1].buff)
            local compiled = SS.Compiler:Compile(s)
            assert.is_true(compiled.ok)
            assert.equals(1, compiled.count)
            assert.equals("/targetenemy [noexists][dead]\n/startattack [harm,nodead]\n"
                .. "/castsequence reset=combat Seal of Righteousness, Judgement\n/cast Holy Strike", compiled.steps[1])
            assert.equals("reset=combat Seal of Righteousness, Judgement", compiled.pairs[1].sequence)
        end)

        it("keeps the priority list through share sanitising", function()
            local clean = SS.Database:SanitizeSequence({ priority = { spell(1), { kind = "bogus" }, spell(2) } })
            assert.equals(2, #clean.priority)
        end)
    end)
end)
