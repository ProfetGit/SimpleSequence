package.path = "./Tests/spec/helpers/?.lua;" .. package.path
local env = require("env")
local spell, step = env.spell, env.step

describe("Share", function()
    local SS, DB, Share
    before_each(function()
        SS = env.new({ "Core/Database.lua", "Core/Compiler.lua", "Core/Share.lua" }, { known = { [1] = true } })
        DB, Share = SS.Database, SS.Share
    end)

    local function sample()
        local s = DB:Create(63, "Fire ST")
        DB:InsertStep(s.id, "opener", nil, spell(1))
        DB:InsertStep(s.id, "loop", nil, spell(2))
        DB:InsertStep(s.id, "loop", nil, spell(1))
        DB:SetStepTarget(s.id, "loop", 1, "player")
        DB:SetStepMod(s.id, "loop", 1, "shift", spell(3))
        DB:InsertExtra(s.id, nil, { kind = "slot", id = 13 })
        DB:SetFlag(s.id, "startAttack", true)
        s.key = "SHIFT-F"
        s.macroName = "SS Fire ST"
        return s
    end

    it("round-trips a sequence", function()
        local s = sample()
        local text = Share:Export(s.id)
        assert.matches("^SSEQ1:", text)
        local imported = Share:Import(text)
        assert.equals(1, #imported)
        local n = imported[1]
        assert.are_not.equal(s.id, n.id)
        assert.equals("Fire ST", n.name)
        assert.is_nil(n.key)
        assert.is_nil(n.macroName)
        assert.same(s.opener, n.opener)
        assert.same(s.loop, n.loop)
        assert.same(s.extras, n.extras)
        assert.is_true(n.startAttack)
        assert.equals(2, #DB:GetOrder(63))
    end)

    it("tolerates whitespace in pasted text", function()
        local s = sample()
        local text = Share:Export(s.id)
        local wrapped = "  " .. text:sub(1, 20) .. "\n " .. text:sub(21) .. "\n"
        assert.is_table(Share:Import(wrapped))
    end)

    it("backs up everything and records the time", function()
        sample()
        DB:Create(64, "Other")
        local text = Share:ExportAll()
        assert.is_true(SS.db.lastBackup > 0)
        local payload = Share:Decode(text)
        assert.is_true(payload.isBackup)
        assert.equals(2, #payload.sequences)
        SS.currentSpec = 70
        local imported = Share:Import(text)
        assert.equals(2, #imported)
        assert.equals(2, #DB:GetOrder(63))
        assert.equals(2, #DB:GetOrder(64))
    end)

    it("previews unknown spells", function()
        local s = sample()
        local payload = Share:Decode(Share:Export(s.id))
        local summary, unknown = Share:Preview(payload)
        assert.matches("Fire ST", summary)
        assert.matches("1 opener, 2 loop", summary)
        assert.matches("2 spells you don't know", summary)
        assert.same({ "Pyroblast", "Ice Block" }, unknown)
    end)

    it("rejects malformed input", function()
        for _, bad in ipairs({ "", "hello", "SSEQ1:", "SSEQ1:zz", "SSEQ1:abc", "SSEQ2:abcd", 42 }) do
            local payload, err = Share:Decode(bad)
            assert.is_nil(payload)
            assert.is_string(err)
        end
        local before = #DB:GetOrder(63)
        local result, err = Share:Import("SSEQ1:0011")
        assert.is_nil(result)
        assert.is_string(err)
        assert.equals(before, #DB:GetOrder(63))
    end)

    it("rejects payloads with the wrong version or no sequences", function()
        local C = _G.C_EncodingUtil
        local function make(v) return "SSEQ1:" .. C.EncodeBase64(C.CompressString(C.SerializeCBOR(v))) end
        assert.is_nil(Share:Decode(make({ v = 2, seq = {} })))
        assert.is_nil(Share:Decode(make({ v = 1 })))
        assert.is_nil(Share:Decode(make({ v = 1, all = { "junk", 5 } })))
        assert.is_nil(Share:Decode(make("string")))
    end)

    it("sanitises hostile payload contents", function()
        local C = _G.C_EncodingUtil
        local raw = { v = 1, seq = { name = "Evil", loop = { { entry = { kind = "lua", id = "os.exit()" } }, { entry = spell(1) } }, key = "F" } }
        local payload = Share:Decode("SSEQ1:" .. C.EncodeBase64(C.CompressString(C.SerializeCBOR(raw))))
        assert.equals(1, #payload.sequences[1].loop)
        assert.is_nil(payload.sequences[1].key)
    end)

    it("reports export failure for unknown ids", function()
        local text, err = Share:Export("nope00")
        assert.is_nil(text)
        assert.is_string(err)
    end)
end)
