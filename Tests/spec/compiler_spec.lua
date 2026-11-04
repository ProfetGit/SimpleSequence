package.path = "./Tests/spec/helpers/?.lua;" .. package.path
local env = require("env")
local spell, step = env.spell, env.step

describe("Compiler", function()
    local SS, C
    before_each(function()
        SS = env.new({ "Core/Database.lua", "Core/Compiler.lua" })
        C = SS.Compiler
    end)

    local function seq(extra)
        local s = { opener = {}, loop = {}, extras = {}, startAttack = false }
        for k, v in pairs(extra or {}) do s[k] = v end
        return s
    end

    it("plain target has no conditional", function()
        assert.equals("/cast Fireball", C:StepText(seq(), step(spell(1))))
    end)

    it("maps player, mouseover and focus targets", function()
        assert.equals("/cast [@player] Fireball", C:StepText(seq(), step(spell(1), "player")))
        assert.equals("/cast [@mouseover,exists,nodead][] Fireball", C:StepText(seq(), step(spell(1), "mouseover")))
        assert.equals("/cast [@focus,exists,nodead][] Fireball", C:StepText(seq(), step(spell(1), "focus")))
    end)

    it("puts modifier clauses first with the step target", function()
        local s = step(spell(5), "player", { shift = spell(3), ctrl = spell(4) })
        assert.equals("/cast [mod:shift,@player] Ice Block; [mod:ctrl,@player] Blink; [@player] Fire Blast",
            C:StepText(seq(), s))
    end)

    it("uses [] for the main clause when mods exist on plain target", function()
        local s = step(spell(1), "target", { alt = spell(2) })
        assert.equals("/cast [mod:alt] Pyroblast; [] Fireball", C:StepText(seq(), s))
    end)

    it("repeats the fallback form in mod clauses for mouseover", function()
        local s = step(spell(1), "mouseover", { shift = spell(3) })
        assert.equals("/cast [mod:shift,@mouseover,exists,nodead][mod:shift] Ice Block; [@mouseover,exists,nodead][] Fireball",
            C:StepText(seq(), s))
    end)

    it("orders startattack, then extras, then the main line", function()
        local s = seq({
            startAttack = true,
            extras = { { kind = "slot", id = 13 }, { kind = "spell", id = 6 }, { kind = "item", id = 100 } },
        })
        assert.equals("/startattack [harm,nodead]\n/use 13\n/cast Scorch\n/use item:100\n/cast Fireball",
            C:StepText(s, step(spell(1))))
    end)

    it("uses /use when the main entry is an item or slot", function()
        assert.equals("/use item:100", C:StepText(seq(), step({ kind = "item", id = 100 })))
        assert.equals("/use 14", C:StepText(seq(), step({ kind = "slot", id = 14 })))
    end)

    it("emote steps ignore everything else", function()
        local s = seq({ startAttack = true, extras = { spell(6) } })
        local st = step({ kind = "emote", id = "wave" }, "player", { shift = spell(3) })
        assert.equals("/wave", C:StepText(s, st))
    end)

    it("falls back to the spell id when the name is unknown", function()
        assert.equals("/cast 99999", C:StepText(seq(), step(spell(99999))))
    end)

    describe("Compile", function()
        it("sets loopStart and count", function()
            local s = seq({
                opener = { step(spell(1)), step(spell(2)) },
                loop = { step(spell(3)), step(spell(4)), step(spell(5)) },
            })
            local r = C:Compile(s)
            assert.equals(3, r.loopStart)
            assert.equals(5, r.count)
            assert.equals("/cast Fireball", r.steps[1])
            assert.equals("/cast Ice Block", r.steps[3])
            assert.equals(5, #r.entries)
            assert.is_true(r.ok)
            assert.equals(0, #r.problems)
        end)

        it("flags an empty loop as an error", function()
            local r = C:Compile(seq({ opener = { step(spell(1)) } }))
            assert.is_false(r.ok)
            assert.equals("error", r.problems[1].level)
        end)

        it("warns about unresolved spells but keeps the step", function()
            local r = C:Compile(seq({ loop = { step(spell(99999)) } }))
            assert.is_true(r.ok)
            assert.equals(1, r.count)
            assert.equals("warn", r.problems[1].level)
        end)

        it("errors when step text is too long", function()
            local extras = {}
            for i = 1, 8 do extras[i] = { kind = "item", id = 100 } end
            local s = seq({ loop = { step(spell(1)) }, extras = extras })
            SS.MAX_STEP_TEXT = 40
            local r = C:Compile(s)
            assert.is_false(r.ok)
            assert.equals("error", r.problems[1].level)
            assert.truthy(r.problems[1].text:find("too long"))
        end)
    end)

    it("describes a sequence", function()
        local s = seq({ opener = { step(spell(1)) }, loop = { step(spell(2)), step(spell(3)) } })
        assert.equals("Press 1: Fireball \194\183 Press 2: Pyroblast \194\183 Press 3: Ice Block \194\183 then repeats from Press 2",
            C:Describe(s))
        assert.equals("Press 1: Fireball \194\183 then repeats", C:Describe(seq({ loop = { step(spell(1)) } })))
    end)

    it("names and icons", function()
        assert.equals("Fireball", C.EntryName(spell(1)))
        assert.equals("Trinket 1", C.EntryName({ kind = "slot", id = 13 }))
        assert.equals("Healing Potion", C.EntryName({ kind = "item", id = 100 }))
        assert.equals(1001, C.EntryIcon(spell(1)))
        assert.equals(3014, C.EntryIcon({ kind = "slot", id = 14 }))
        assert.is_number(C.EntryIcon({ kind = "emote", id = "wave" }))
    end)
end)
