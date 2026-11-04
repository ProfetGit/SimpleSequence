package.path = "./Tests/spec/helpers/?.lua;" .. package.path
local env = require("env")
local spell = env.spell

describe("Database", function()
    local SS, DB
    before_each(function()
        SS = env.new({ "Core/Database.lua", "Core/Compiler.lua", "Core/Share.lua" })
        DB = SS.Database
    end)

    it("creates, selects and orders sequences per spec", function()
        local a = DB:Create(63, "A")
        local b = DB:Create(63, "B")
        local c = DB:Create(64, "C")
        assert.same({ a.id, b.id }, DB:GetOrder(63))
        assert.equals(b.id, DB:GetSelected(63))
        assert.equals(c.id, DB:GetSelected(64))
        assert.equals(2, #DB:GetSequences(63))
        assert.is_true(SS:count("SEQUENCES_CHANGED") >= 3)
        assert.matches("^%x%x%x%x%x%x$", a.id)
        assert.is_true(a.reset.combat)
    end)

    it("inserts, moves and removes steps", function()
        local s = DB:Create(63)
        DB:InsertStep(s.id, "loop", nil, spell(1))
        DB:InsertStep(s.id, "loop", nil, spell(2))
        DB:InsertStep(s.id, "loop", 1, spell(3))
        assert.equals(3, s.loop[1].entry.id)
        assert.equals("target", s.loop[1].target)
        DB:InsertStep(s.id, "opener", nil, spell(4))
        DB:MoveStep(s.id, "loop", 1, "opener", 1)
        assert.equals(3, s.opener[1].entry.id)
        assert.equals(2, #s.loop)
        DB:RemoveStep(s.id, "loop", 1)
        assert.equals(1, #s.loop)
        assert.equals(2, s.loop[1].entry.id)
    end)

    it("enforces step and extra limits", function()
        local s = DB:Create(63)
        for i = 1, 70 do DB:InsertStep(s.id, "loop", nil, spell(1 + (i % 6))) end
        assert.equals(SS.MAX_STEPS, #s.loop)
        for i = 1, 12 do DB:InsertExtra(s.id, nil, { kind = "slot", id = 13 }) end
        assert.equals(SS.MAX_EXTRAS, #s.extras)
    end)

    it("sets targets, mods, flags and icon", function()
        local s = DB:Create(63)
        DB:InsertStep(s.id, "loop", nil, spell(1))
        DB:SetStepTarget(s.id, "loop", 1, "player")
        DB:SetStepMod(s.id, "loop", 1, "shift", spell(2))
        assert.equals("player", s.loop[1].target)
        assert.equals(2, s.loop[1].mods.shift.id)
        DB:SetStepMod(s.id, "loop", 1, "shift", nil)
        assert.is_nil(s.loop[1].mods.shift)
        assert.is_false(DB:SetStepTarget(s.id, "loop", 1, "bogus"))
        DB:SetFlag(s.id, "startAttack", true)
        DB:SetFlag(s.id, "reset.target", true)
        assert.is_true(s.startAttack)
        assert.is_true(s.reset.target)
        DB:SetIcon(s.id, 555)
        assert.equals(555, s.icon)
    end)

    it("moves sequences in the list", function()
        local a, b, c = DB:Create(63, "A"), DB:Create(63, "B"), DB:Create(63, "C")
        DB:MoveInList(63, 1, 3)
        assert.same({ b.id, c.id, a.id }, DB:GetOrder(63))
    end)

    it("undoes a step edit", function()
        local s = DB:Create(63)
        DB:InsertStep(s.id, "loop", nil, spell(1))
        DB:InsertStep(s.id, "loop", nil, spell(2))
        assert.is_true(DB:CanUndo())
        assert.is_true(DB:Undo())
        assert.equals(1, #DB:GetSequence(s.id).loop)
    end)

    it("undoes delete and restores order and selection", function()
        local a, b = DB:Create(63, "A"), DB:Create(63, "B")
        DB:InsertStep(a.id, "loop", nil, spell(1))
        DB:Delete(a.id)
        assert.is_nil(DB:GetSequence(a.id))
        assert.same({ b.id }, DB:GetOrder(63))
        assert.is_true(DB:Undo())
        assert.same({ a.id, b.id }, DB:GetOrder(63))
        assert.equals(1, #DB:GetSequence(a.id).loop)
        assert.equals(b.id, DB:GetSelected(63))
    end)

    it("fires SEQUENCE_DELETED on delete and when undoing a create", function()
        local a = DB:Create(63)
        DB:Delete(a.id)
        assert.equals(1, SS:count("SEQUENCE_DELETED"))
        DB:Undo()
        DB:Undo()
        assert.equals(2, SS:count("SEQUENCE_DELETED"))
        assert.is_nil(DB:GetSequence(a.id))
    end)

    it("undoes a list move", function()
        local a, b = DB:Create(63, "A"), DB:Create(63, "B")
        DB:MoveInList(63, 1, 2)
        DB:Undo()
        assert.same({ a.id, b.id }, DB:GetOrder(63))
    end)

    it("cancelled updates leave no undo entry", function()
        local s = DB:Create(63)
        DB:Undo()
        assert.is_false(DB:CanUndo())
        local s2 = DB:Create(63)
        DB:RemoveStep(s2.id, "loop", 5)
        DB:Undo()
        assert.is_nil(DB:GetSequence(s2.id))
        assert.is_nil(DB:GetSequence(s.id))
    end)

    it("keeps at most 20 undo snapshots", function()
        local s = DB:Create(63)
        for i = 1, 30 do DB:Rename(s.id, "Name" .. i) end
        local n = 0
        while DB:Undo() do n = n + 1 end
        assert.equals(20, n)
    end)

    it("duplicates without key or macro", function()
        local a = DB:Create(63, "A")
        a.key, a.macroName = "F", "SS A"
        DB:InsertStep(a.id, "loop", nil, spell(1))
        local d = DB:Duplicate(a.id)
        assert.is_nil(d.key)
        assert.is_nil(d.macroName)
        assert.equals(1, #d.loop)
        assert.are_not.equal(a.id, d.id)
        assert.same({ a.id, d.id }, DB:GetOrder(63))
    end)

    describe("import sanitisation", function()
        it("drops bad entries and unknown kinds", function()
            local s = DB:Import(63, {
                name = "X|cffff0000Y",
                opener = { { entry = { kind = "spell", id = 1 } }, { entry = { kind = "hack", id = 1 } }, "junk" },
                loop = {
                    { entry = { kind = "spell", id = -4 } },
                    { entry = { kind = "slot", id = 15 } },
                    { entry = { kind = "slot", id = 13 }, target = "evil", mods = { shift = { kind = "emote", id = "wave" }, ctrl = spell(2), bogus = spell(3) } },
                },
                extras = { { kind = "emote", id = "dance" }, spell(1) },
                key = "F", macroName = "SS X", id = "zzzzzz",
            })
            assert.equals("Xcffff0000Y", s.name)
            assert.equals(1, #s.opener)
            assert.equals(1, #s.loop)
            assert.equals("target", s.loop[1].target)
            assert.is_nil(s.loop[1].mods.shift)
            assert.equals(2, s.loop[1].mods.ctrl.id)
            assert.is_nil(s.loop[1].mods.bogus)
            assert.equals(1, #s.extras)
            assert.is_nil(s.key)
            assert.is_nil(s.macroName)
            assert.are_not.equal("zzzzzz", s.id)
            assert.equals(63, s.specID)
        end)

        it("truncates oversized lists and names", function()
            local loop = {}
            for i = 1, 100 do loop[i] = { entry = spell(1) } end
            local extras = {}
            for i = 1, 20 do extras[i] = spell(1) end
            local s = DB:Import(63, { name = string.rep("n", 500), loop = loop, extras = extras })
            assert.equals(SS.MAX_STEPS, #s.loop)
            assert.equals(SS.MAX_EXTRAS, #s.extras)
            assert.is_true(#s.name <= 48)
        end)

        it("rejects non-tables", function()
            assert.is_nil(DB:Import(63, "nope"))
            assert.is_nil(DB:Import(63, nil))
        end)

        it("rejects non-integer and huge ids", function()
            local s = DB:Import(63, { loop = { { entry = spell(1.5) }, { entry = spell(2 ^ 40) }, { entry = spell("1") } } })
            assert.equals(0, #s.loop)
        end)
    end)

    it("normalises a damaged saved table", function()
        _G.SimpleSequenceDB = { sequences = { bad = "x", ok = { name = "Ok" } }, specs = { [63] = { order = { "ok", "ghost" }, selected = "ghost" } } }
        DB:Init()
        assert.is_nil(SS.db.sequences.bad)
        assert.same({ "ok" }, DB:GetOrder(63))
        assert.is_nil(DB:GetSelected(63))
        assert.same({}, SS.db.sequences.ok.loop)
    end)
end)
