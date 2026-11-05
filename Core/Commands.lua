local _, SS = ...

local Commands = {}
SS.Commands = Commands

local function selectedId()
    return SS.Database:GetSelected(SS.currentSpec)
end

local function requireSelected()
    local id = selectedId()
    if not id then
        SS:Print("No sequence selected. Create one with /seq first.")
    end
    return id
end

local function emote(token)
    return { kind = "emote", id = token }
end

function Commands.demo()
    local seq = SS.Database:Create(SS.currentSpec, "Emote test")
    local id = seq.id
    SS.Database:InsertStep(id, "opener", nil, emote("wave"))
    SS.Database:InsertStep(id, "loop", nil, emote("cheer"))
    SS.Database:InsertStep(id, "loop", nil, emote("dance"))
    SS.Database:SetSelected(SS.currentSpec, id)
    SS.Engine:Apply(id)
    if SS.Window then SS.Window:Show() end
    SS:Print("Press Set key or Put on action bar, then press it: wave, cheer, dance, cheer")
end

function Commands.reset()
    if SS.Engine:Reset(nil) then
        SS:Print("All sequences restarted from the first press.")
    end
end

function Commands.export()
    local id = requireSelected()
    if not id then return end
    local text, err = SS.Share:Export(id)
    if not text then
        SS:Print(err)
    elseif SS.ShareDialog then
        SS.ShareDialog:ShowExport("Share sequence", text)
    else
        SS:Print(text)
    end
end

function Commands.import()
    if SS.ShareDialog then
        SS.ShareDialog:ShowImport()
    else
        SS:Print("The import window is not available. Reload the UI and try again.")
    end
end

function Commands.nextup()
    if SS.NextUp then
        SS.NextUp:Toggle()
    else
        SS:Print("The next-up icon is not available.")
    end
end

function Commands.minimap()
    if SS.MinimapButton then
        SS.MinimapButton:Toggle()
    else
        SS:Print("The minimap button is not available.")
    end
end

function Commands.mute()
    if SS.Settings then SS.Settings:ToggleMashSilenced() end
end

function Commands.debug()
    local id = requireSelected()
    if not id then return end
    for _, line in ipairs(SS.Engine:DebugLines(id)) do
        SS:Print(line)
    end
    if SS.Settings and SS.Settings:IsMashSilenced() then
        local messages = SS.Settings:SilencedMessages()
        SS:Print("Errors silenced lately: " .. (#messages > 0 and table.concat(messages, " | ") or "none"))
    end
end

function Commands.help()
    SS:Print("Commands:")
    print("  /seq - open or close the window")
    print("  /seq demo - make a test sequence that uses emotes")
    print("  /seq reset - restart all sequences from the first press")
    print("  /seq export - share the selected sequence")
    print("  /seq import - paste a shared sequence")
    print("  /seq nextup - show or hide the next-spell icon")
    print("  /seq minimap - show or hide the minimap button")
    print("  /seq mute - silence or bring back \"not ready yet\" errors")
    print("  /seq debug - show what the selected sequence will cast")
end

local SUBCOMMANDS = { demo = true, reset = true, export = true, import = true, nextup = true, minimap = true, mute = true, debug = true, help = true }

SLASH_SIMPLESEQUENCE1 = "/seq"
SLASH_SIMPLESEQUENCE2 = "/simplesequence"
SlashCmdList["SIMPLESEQUENCE"] = function(msg)
    local command = (msg or ""):match("^%s*(%S*)"):lower()
    if command == "" then
        if SS.Window then
            SS.Window:Toggle()
        else
            SS:Print("The window failed to load. Type /seq help for text commands.")
        end
        return
    end
    local handler = SUBCOMMANDS[command] and Commands[command]
    if handler then
        handler()
    else
        SS:Print("Unknown command \"" .. command .. "\".")
        Commands.help()
    end
end
