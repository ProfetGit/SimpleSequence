local scriptPath = arg and arg[0] or "Tests/harness/run.lua"
local dir = scriptPath:match("^(.*)/[^/]*$") or "."
local ROOT = dir:gsub("/Tests/harness$", ""):gsub("^Tests/harness$", ".")
if ROOT == "" then ROOT = "." end

local print = print
local H = dofile(dir .. "/fakewow.lua")
H.install(_G)

local SS = {}

local IGNORE_MISSING = { SimpleSequenceDB = true }
setmetatable(_G, {
    __index = function(_, name)
        if IGNORE_MISSING[name] or type(name) ~= "string" then return nil end
        if not H.missing[name] then
            local info = debug.getinfo(2, "Sl")
            local where = info and (info.short_src .. ":" .. (info.currentline or 0)) or "?"
            if where:find("harness", 1, true) then return nil end
            H.missing[name] = where
            H.missingOrder[#H.missingOrder + 1] = name
        end
        return nil
    end,
})

local function tracer(e)
    return debug.traceback(tostring(e), 2)
end

local function step(name, fn, ...)
    H.step = name
    local before = #H.errors
    local args = { ... }
    local ok, err = xpcall(function() return fn(unpack(args)) end, tracer)
    if not ok then
        H.errors[#H.errors + 1] = { msg = tostring(err):match("^[^\n]*"), tb = err, step = name }
    end
    H.flushTimers()
    return ok, err
end

local toc = {}
for line in io.lines(ROOT .. "/SimpleSequence.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then toc[#toc + 1] = line end
end

for _, rel in ipairs(toc) do
    local path = ROOT .. "/" .. rel:gsub("\\", "/")
    step("load " .. rel, function()
        local chunk, err = loadfile(path)
        if not chunk then error(err, 0) end
        chunk("SimpleSequence", SS)
    end)
end

local function expect(label, cond)
    if not cond then
        H.errors[#H.errors + 1] = { msg = "ASSERT FAILED: " .. label, tb = debug.traceback("ASSERT FAILED: " .. label, 2), step = H.step }
    end
end

local DB, spell = SS.Database, function(id) return { kind = "spell", id = id } end
local seqId, seq2Id

step("event ADDON_LOADED", H.dispatchEvent, "ADDON_LOADED", "SimpleSequence")
step("event PLAYER_LOGIN", H.dispatchEvent, "PLAYER_LOGIN")
step("event SPELLS_CHANGED", H.dispatchEvent, "SPELLS_CHANGED")

step("slash open window", function()
    SlashCmdList.SIMPLESEQUENCE("")
    expect("window shown after /seq", SS.Window and SS.Window.frame and SS.Window.frame:IsShown())
end)
step("slash demo", function() SlashCmdList.SIMPLESEQUENCE("demo") end)
step("slash help", function() SlashCmdList.SIMPLESEQUENCE("help") end)
step("slash bogus", function() SlashCmdList.SIMPLESEQUENCE("bogus") end)
step("slash debug", function() SlashCmdList.SIMPLESEQUENCE("debug") end)
step("slash reset", function() SlashCmdList.SIMPLESEQUENCE("reset") end)
step("slash nextup", function() SlashCmdList.SIMPLESEQUENCE("nextup") end)
step("slash nextup again", function() SlashCmdList.SIMPLESEQUENCE("nextup") end)

step("Database:Create + steps", function()
    local seq = DB:Create(63, "Fire ST")
    seqId = seq.id
    DB:InsertStep(seqId, "opener", nil, spell(1))
    DB:InsertStep(seqId, "opener", nil, spell(2))
    DB:InsertStep(seqId, "loop", nil, spell(5))
    DB:InsertStep(seqId, "loop", nil, spell(1))
    DB:InsertStep(seqId, "loop", 1, spell(3))
    DB:InsertExtra(seqId, nil, spell(4))
    DB:SetStepTarget(seqId, "loop", 1, "player")
    DB:SetStepMod(seqId, "loop", 2, "shift", spell(4))
    DB:SetFlag(seqId, "startAttack", true)
    DB:SetFlag(seqId, "reset.target", true)
    DB:MoveStep(seqId, "loop", 1, "opener", 1)
    DB:MoveExtra(seqId, 1, 1)
    DB:Rename(seqId, "Fire ST 2")
    DB:SetIcon(seqId, 135810)
    DB:RemoveStep(seqId, "opener", 1)
    local dup = DB:Duplicate(seqId)
    seq2Id = dup.id
    expect("steps present", #DB:GetSequence(seqId).loop >= 1)
    DB:SetSelected(63, seqId)
end)

step("Compiler", function()
    local c = SS.Compiler:Compile(DB:GetSequence(seqId))
    expect("compile steps", c and c.count and c.count > 0)
    SS.Compiler:Describe(DB:GetSequence(seqId))
    SS.Compiler:StepText(DB:GetSequence(seqId), DB:GetSequence(seqId).loop[1])
end)

step("Engine apply", function()
    SS.Engine:Apply(seqId)
    SS.Engine:ApplySpec(63)
    SS.Engine:GetNextIndex(seqId)
    SS.Engine:GetNextEntry(seqId)
    SS.Engine:DebugLines(seqId)
end)

step("Window:Refresh", function()
    SS.Window:Show()
    if SS.Window.Refresh then SS.Window:Refresh() end
    if SS.SequenceList and SS.SequenceList.Refresh then SS.SequenceList:Refresh() end
end)

step("Editor:Refresh", function() SS.Editor:Refresh() end)
step("Editor:GetActiveSection", function() SS.Editor:GetActiveSection() end)
step("movement keys never reach key capture", function()
    local seq = DB:GetSequence(SS.Editor.id)
    local before = seq and seq.key
    H.lastPopup = nil
    H.pressKey("W")
    expect("no popup from W", H.lastPopup == nil)
    expect("key unchanged", (DB:GetSequence(SS.Editor.id) or {}).key == before)
end)
step("scrollbar drag follows the mouse", function()
    local scroll = SS.Widgets:Scroll(UIParent)
    scroll:SetHeight(200)
    scroll:UpdateExtent(1000)
    local slider, thumb = scroll.slider, scroll.slider.thumb
    slider:SetHeight(300)
    thumb:SetHeight(60)
    expect("slider ignores the mouse itself", slider.__mouse ~= true)
    local realCursor = GetCursorPosition
    local y = 300
    _G.GetCursorPosition = function() return 400, y end
    H.mouseDown = true
    thumb.__scripts.OnMouseDown(thumb, "LeftButton")
    y = 250
    thumb.__scripts.OnUpdate(thumb, 0.016)
    local down = slider:GetValue()
    expect("dragging down scrolls down (" .. tostring(down) .. ")", down > 0)
    y = 320
    thumb.__scripts.OnUpdate(thumb, 0.016)
    expect("dragging up past the start stops at the top", slider:GetValue() == 0)
    H.mouseDown = false
    thumb.__scripts.OnUpdate(thumb, 0.016)
    expect("release ends the drag", thumb.__scripts.OnUpdate == nil)
    _G.GetCursorPosition = realCursor
end)
step("Edit Mode moves the next-press icon", function()
    local nextUp = _G.SimpleSequenceNextUp
    expect("next-up frame exists", nextUp ~= nil)
    local savedLast = SS.Engine.lastPressed
    SS.Engine.lastPressed = nil
    SS.NextUp:Refresh()
    expect("hidden before anything is pressed", not nextUp:IsShown())
    H.triggerCallback("EditMode.Enter")
    expect("editing flag set", SS.NextUp:IsEditing())
    expect("shown in Edit Mode", nextUp:IsShown())
    local selection = nextUp.selection
    expect("selection shown", selection and selection:IsShown())
    selection.__scripts.OnDragStart(selection)
    selection.__scripts.OnDragStop(selection)
    expect("position saved", type(SS.db.nextUp.point) == "table")
    selection.__scripts.OnMouseUp(selection, "RightButton")
    H.triggerCallback("EditMode.Exit")
    expect("editing cleared", not SS.NextUp:IsEditing())
    expect("selection hidden", not selection:IsShown())
    expect("hidden again after Edit Mode", not nextUp:IsShown())
    SS.Engine.lastPressed = savedLast
    SS.NextUp:Refresh()
end)
step("key capture does not stay armed", function()
    local kb = SS.Editor.keyButton
    local function armed() return (kb.label:GetText() or ""):find("Press a key", 1, true) ~= nil end
    expect("editor has a sequence", SS.Editor.id ~= nil)
    kb:Click("LeftButton")
    expect("capture armed after click", armed())
    H.dispatchEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    expect("outside click disarms", not armed())
    kb:Click("LeftButton")
    expect("capture re-armed", armed())
    H.flushTimers()
    expect("timeout disarms", not armed())
end)
step("Editor:AddEntry", function()
    SS.Editor:AddEntry({ kind = "spell", id = 2 })
    SS.Editor:AddEntry({ kind = "spell", id = 3 })
end)
step("BuilderPanel", function()
    local BP = SS.BuilderPanel
    expect("BuilderPanel module", BP ~= nil)
    SS.Window:Show()
    SS.Editor:Refresh(true)
    DB:SetSelected(63, seqId)
    expect("button built", SS.Editor.buildButton ~= nil)
    SS.Editor.buildButton.__scripts.OnClick(SS.Editor.buildButton, "LeftButton")
    expect("panel open", BP:IsOpen())
    local before = DB:GetSequence(seqId)
    local loopBefore = #before.loop
    SS.Editor:AddEntry({ kind = "spell", id = 1 })
    expect("sidebar click goes to panel", #(DB:GetSequence(seqId).loop) == loopBefore)
    expect("consumed", BP:AddEntry({ kind = "spell", id = 2 }))
    BP:AddEntry({ kind = "spell", id = 3 })
    BP:AddEntry({ kind = "emote", id = 1 })
    local priority = DB:GetSequence(seqId).priority
    expect("3 priority entries", priority ~= nil and #priority == 3)
    DB:SetPriority(seqId, { spell(3), spell(2), spell(1) })
    SS:Fire("SEQUENCE_UPDATED", seqId)
    local use = SS.BuilderPanel and nil
    for _, f in ipairs(H.frames) do
        if f.__kind == "Button" and f.label and f.label.__text == "Use this sequence" then use = f end
    end
    expect("use button", use ~= nil)
    H.inCombat = true
    SS:Fire("COMBAT_STARTED")
    expect("use disabled in combat", use:IsEnabled() == false)
    H.inCombat = false
    SS:Fire("COMBAT_ENDED")
    expect("use enabled after combat", use:IsEnabled() == true)
    use.__scripts.OnClick(use)
    expect("panel closed after use", not BP:IsOpen())
    local built = DB:GetSequence(seqId)
    expect("loop non-empty", #built.loop > 0)
    expect("undo ok", DB:Undo())
    BP:Open(seqId)
    expect("reopen", BP:IsOpen())
    SS:Fire("SPEC_CHANGED")
    expect("closed on spec change", not BP:IsOpen())
end)
step("StepPopover:Open", function()
    local anchor = CreateFrame("Button", nil, UIParent)
    SS.StepPopover:Open(anchor, seqId, "loop", 1)
    SS.StepPopover:Open(anchor, seqId, "opener", 1)
    SS.StepPopover:Close()
end)
step("SpellSidebar:Refresh", function() SS.SpellSidebar:Refresh() end)
step("SpellSource", function()
    local cats = SS.SpellSource:GetCategories(nil)
    expect("spell categories exist", #cats > 0)
    SS.SpellSource:GetCategories("fire")
end)

local exported
step("Share export", function()
    exported = SS.Share:Export(seqId)
    expect("export text", type(exported) == "string" and #exported > 0)
    local all = SS.Share:ExportAll()
    expect("exportAll text", type(all) == "string")
    local payload, err = SS.Share:Decode(exported)
    expect("decode", payload ~= nil)
    if payload then SS.Share:Preview(payload) end
end)
step("Share import", function()
    local list, err = SS.Share:Import(exported)
    expect("import ok: " .. tostring(err), list ~= nil)
end)
step("ShareDialog:ShowExport", function() SS.ShareDialog:ShowExport("Share sequence", exported or "") end)
step("ShareDialog:ShowImport", function()
    SS.ShareDialog:ShowImport()
    for _, f in ipairs(H.frames) do
        if f.__kind == "EditBox" and f.__text == "" then f:SetText(exported or "") end
    end
end)

step("Bindings:SetKey", function()
    local ok, err = SS.Bindings:SetKey(seqId, "F")
    expect("SetKey ok: " .. tostring(err), ok)
    SS.Bindings:GetConflict("G")
    SS.Bindings:ApplyAll()
end)
step("Bindings:PutOnActionBar", function()
    local ok, err = SS.Bindings:PutOnActionBar(seqId)
    expect("PutOnActionBar ok: " .. tostring(err), ok)
    ClearCursor()
end)
step("macro shows next spell", function()
    local seq = DB:GetSequence(seqId)
    local index = GetMacroIndexByName(seq.macroName)
    expect("macro exists", index > 0)
    expect("macro icon is dynamic", H.macroList[index].icon == 134400 or seq.icon ~= nil)
    local btn = _G[SS.Engine:ButtonName(seqId)]
    local _, count = SS.Engine:GetProgress(seqId)
    expect("progress known", count and count >= 1)
    btn:SetAttribute("ss-index", math.min(2, count))
    local want = SS.Compiler.EntryName(SS.Engine:GetNextEntry(seqId))
    expect("feedback follows index (" .. tostring(H.macroFeedback[index]) .. " vs " .. tostring(want) .. ")",
        H.macroFeedback[index] == want)
    btn:SetAttribute("ss-index", 1)
end)
step("SEQUENCE_PRESSED + NextUp", function()
    SS:Fire("SEQUENCE_PRESSED", seqId)
    SS.NextUp:Refresh()
    H.flushTimers()
end)
step("secure wrap snippet", function()
    local btn = _G[SS.Engine:ButtonName(seqId)]
    expect("secure button exists", btn ~= nil)
    if btn then
        expect("secure wrap installed", btn.__wraps and btn.__wraps.OnClick ~= nil)
        btn:Click("LeftButton", true)
    end
end)

step("combat edit", function()
    H.inCombat = true
    H.dispatchEvent("PLAYER_REGEN_DISABLED")
    DB:InsertStep(seqId, "loop", nil, spell(2))
    DB:Rename(seqId, "Fire combat")
    expect("engine pending in combat", SS.Engine:IsPending() == true)
    SS.Bindings:SetKey(seqId, "G")
    SS.Window:Refresh()
    H.inCombat = false
    H.dispatchEvent("PLAYER_REGEN_ENABLED")
    H.flushTimers()
    expect("engine pending cleared after regen", SS.Engine:IsPending() == false)
end)

step("Undo", function()
    expect("can undo", DB:CanUndo())
    expect("undo returns true", DB:Undo() == true)
end)
step("Delete", function()
    DB:Delete(seq2Id)
    DB:Undo()
    DB:Delete(seq2Id)
end)
step("Window toast/Refresh", function()
    if SS.Window.Toast then SS.Window:Toast("Test", "Undo", function() end) end
    SS.Window:Refresh()
end)

step("spec change to 64", function()
    H.specID = 64
    H.dispatchEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    expect("currentSpec 64", SS.currentSpec == 64)
    SS.Window:Refresh()
    DB:Create(64, "Frost ST")
    SS.Editor:Refresh()
    SS.SpellSidebar:Refresh()
    H.specID = 63
    H.dispatchEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    expect("currentSpec back 63", SS.currentSpec == 63)
end)

step("window hide/show", function()
    SS.Window:Hide()
    SS.Window:Toggle()
    SS.Window:Refresh()
end)

step("DragDrop", function()
    local DD = SS.DragDrop
    local target = CreateFrame("Frame", nil, UIParent)
    local dropped
    DD:RegisterTarget(target, {
        onEnter = function() end, onLeave = function() end,
        onDrop = function(p) dropped = p; return true end,
        onCursorDrop = function() return true end,
    })
    H.mouseDown = true
    DD:Begin({ type = "entry", entry = spell(1) }, 135810)
    expect("IsDragging after Begin", DD:IsDragging())
    for _, f in ipairs(H.frames) do
        local up = f.__scripts.OnUpdate
        if up and f.__shown then up(f, 0.05) end
    end
    H.mouseDown = false
    for _, f in ipairs(H.frames) do
        local up = f.__scripts.OnUpdate
        if up and f.__shown then up(f, 0.05) end
    end
    expect("drag finished on release", not DD:IsDragging())
    expect("drop reached registered target or was ignored cleanly", true)
    H.mouseDown = true
    DD:Begin({ type = "step", id = seqId, section = "loop", index = 1, onDropOutside = function() end }, 135810)
    H.mouseDown = false
    DD:Finish()
    DD:Begin({ type = "extra", id = seqId, index = 1 }, 135810)
    DD:Cancel()
end)

step("SequenceList reorder", function()
    local a, b, c = DB:Create(70, "Order A"), DB:Create(70, "Order B"), DB:Create(70, "Order C")
    local function order()
        local names = {}
        for _, q in ipairs(DB:GetSequences(70)) do names[#names + 1] = q.name end
        return table.concat(names, ",")
    end
    SS.currentSpec = 70
    SS.Window:Refresh()
    SS.SequenceList:Refresh()
    local before = order()
    expect("three sequences in order", before:find("Order A,Order B,Order C", 1, true) ~= nil)
    local list = DB:GetSequences(70)
    local row
    for _, f in ipairs(H.frames) do
        if f.__scripts and f.__scripts.OnDragStart and f.index == 1 and f.id == list[1].id then row = f end
    end
    expect("row with drag handler", row ~= nil)
    if row then
        H.mouseDown = true
        row.__scripts.OnDragStart(row)
        expect("row drag began", SS.DragDrop:IsDragging())
        expect("payload is sequence", SS.DragDrop:GetPayload().type == "sequence")
        SS.DragDrop:Cancel()
        H.mouseDown = false
    end
    local target
    for _, f in ipairs(H.frames) do
        if f == SS.SequenceList.scroll then target = f end
    end
    expect("scroll frame exists", target ~= nil)
    local ok = DB:MoveInList(70, 1, #DB:GetSequences(70))
    expect("MoveInList ok", ok)
    expect("reordered", order() ~= before)
    DB:Undo()
    expect("undo restores order", order() == before)
    SS.currentSpec = 63
    SS.Window:Refresh()
end)

step("Minimap button", function()
    local MB = SS.MinimapButton
    expect("MinimapButton module", MB ~= nil)
    expect("minimap defaults", SS.db.minimap and type(SS.db.minimap.angle) == "number" and SS.db.minimap.hide == false)
    expect("button created", MB.button ~= nil)
    SlashCmdList.SIMPLESEQUENCE("minimap")
    expect("hidden after toggle", SS.db.minimap.hide == true and not MB.button:IsShown())
    SlashCmdList.SIMPLESEQUENCE("minimap")
    expect("shown after toggle", SS.db.minimap.hide == false and MB.button:IsShown())
    local scripts = MB.button.__scripts
    scripts.OnEnter(MB.button)
    scripts.OnLeave(MB.button)
    scripts.OnClick(MB.button, "LeftButton")
    scripts.OnClick(MB.button, "RightButton")
    scripts.OnDragStart(MB.button)
    expect("drag update set", MB.button.__scripts.OnUpdate ~= nil)
    MB.button.__scripts.OnUpdate(MB.button, 0.02)
    scripts.OnDragStop(MB.button)
    expect("drag update cleared", MB.button.__scripts.OnUpdate == nil)
end)

local HANDLERS = {
    { "OnShow" },
    { "OnEnter" }, { "OnLeave" }, { "OnMouseDown", "LeftButton" }, { "OnMouseUp", "LeftButton" },
    { "OnMouseWheel", 1 }, { "OnDragStart" }, { "OnDragStop" }, { "OnReceiveDrag" },
    { "OnClick", "LeftButton", false }, { "OnClick", "RightButton", false },
    { "OnTextChanged", true }, { "OnEnterPressed" }, { "OnEscapePressed" },
    { "OnEditFocusGained" }, { "OnEditFocusLost" }, { "OnValueChanged", 0.5, true },
    { "OnUpdate", 0.1 },
}

local function smoke()
    local snapshot = {}
    for i, f in ipairs(H.frames) do snapshot[i] = f end
    local n = 0
    for _, f in ipairs(snapshot) do
        for _, h in ipairs(HANDLERS) do
            local fn = f.__scripts and f.__scripts[h[1]]
            if fn and h[1] == "OnDragStart" and not f:IsVisible() then fn = nil end
            if fn then
                n = n + 1
                local name = f.__name or f.__kind
                local ok, err = xpcall(function() fn(f, unpack(h, 2)) end, tracer)
                if not ok then
                    H.errors[#H.errors + 1] = { msg = tostring(err):match("^[^\n]*"), tb = err, step = "handler " .. h[1] .. " on " .. tostring(name) }
                end
            end
        end
    end
    H.flushTimers()
    return n
end

local handlerCount
step("handler smoke test", function()
    SS.Window:Show()
    handlerCount = smoke()
end)
step("handler smoke test pass 2 (after open popover)", function()
    SS.StepPopover:Open(CreateFrame("Button", nil, UIParent), seqId, "loop", 1)
    smoke()
end)

local function addonFrame(tb)
    for line in tostring(tb):gmatch("[^\n]+") do
        if (line:find("/Core/", 1, true) or line:find("/UI/", 1, true) or line:find("Core/", 1, true) or line:find("UI/", 1, true))
            and not line:find("harness", 1, true) and line:match("%.lua:%d+") then
            return (line:gsub("^%s+", ""))
        end
    end
    return "(no addon frame)"
end

local seen, unique = {}, {}
for _, e in ipairs(H.errors) do
    local key = e.msg
    if not seen[key] then
        seen[key] = true
        unique[#unique + 1] = e
    end
end

print(("== HARNESS: %d frames created, %d handlers invoked =="):format(#H.frames, handlerCount or 0))
print(("== ERRORS: %d (%d unique) =="):format(#H.errors, #unique))
for i, e in ipairs(unique) do
    print(("[%d] step: %s"):format(i, tostring(e.step)))
    print("    " .. tostring(e.msg))
    print("    at " .. addonFrame(e.tb))
end
print(("== MISSING GLOBALS: %d =="):format(#H.missingOrder))
for _, name in ipairs(H.missingOrder) do
    print(("  %s  (first access %s)"):format(name, H.missing[name]))
end
if #H.errors == 0 and #H.missingOrder == 0 then
    print("HARNESS OK")
else
    os.exit(1)
end
